// lib/im/models/im_print_form.dart — แบบฟอร์มพิมพ์กลาง (im_print_form / im_print_form_copy)
// ตำแหน่ง/ขนาดทุกชิ้นงานเป็นมิลลิเมตร, ขนาดตัวอักษรเป็น point (pt)
// โหมด LASER = พิมพ์รูปพื้นหลังของแต่ละสำเนา + ข้อมูล (1 เอกสาร = จำนวนแผ่นเท่าจำนวนสำเนา)
// โหมด PREPRINTED = พิมพ์ข้อมูลอย่างเดียวลงกระดาษก๊อปปี้ (รูปพื้นหลังใช้จัดตำแหน่งในหน้าจอออกแบบเท่านั้น)

double _d(dynamic v, [double def = 0]) =>
    v == null ? def : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? def);

// ── แหล่งข้อมูล / ฟิลด์ ──────────────────────────────────────────────────────
class PrintField {
  final String key;
  final String labelTh;
  final String labelEn;
  final String group; // company / customer / document / total / print / line
  final String type; // text / money / qty / number / date / image
  final String scope; // H = หัวเอกสาร, L = รายการ, P = คำนวณตอนพิมพ์

  const PrintField({
    required this.key,
    required this.labelTh,
    required this.labelEn,
    required this.group,
    required this.type,
    required this.scope,
  });

  bool get isLine => scope == 'L';
  String label(bool isEnglish) => isEnglish ? labelEn : labelTh;

  factory PrintField.fromJson(Map<String, dynamic> j) => PrintField(
        key: j['key'] ?? '',
        labelTh: j['label_th'] ?? '',
        labelEn: j['label_en'] ?? j['label_th'] ?? '',
        group: j['group'] ?? '',
        type: j['type'] ?? 'text',
        scope: j['scope'] ?? 'H',
      );
}

const Map<String, List<String>> printFieldGroupLabels = {
  'company': ['บริษัท/สาขา', 'Company/Branch'],
  'customer': ['ลูกค้า', 'Customer'],
  'document': ['เอกสาร', 'Document'],
  'total': ['ยอดรวม', 'Totals'],
  'print': ['การพิมพ์', 'Printing'],
  'line': ['รายการ', 'Lines'],
};

class PrintDataSource {
  final String key;
  final String nameTh;
  final String nameEn;
  final List<PrintField> fields;

  const PrintDataSource({required this.key, required this.nameTh, required this.nameEn, required this.fields});

  String name(bool isEnglish) => isEnglish ? nameEn : nameTh;
  List<PrintField> get headerFields => fields.where((f) => !f.isLine).toList();
  List<PrintField> get lineFields => fields.where((f) => f.isLine).toList();

  PrintField? field(String? key, {bool line = false}) {
    if (key == null) return null;
    for (final f in fields) {
      if (f.key == key && f.isLine == line) return f;
    }
    return null;
  }

  // ฟิลด์คู่ภาษา (xxx <-> xxx_en) — null = ไม่มีคู่
  PrintField? pairOf(PrintField f) =>
      field(f.key.endsWith('_en') ? f.key.substring(0, f.key.length - 3) : '${f.key}_en', line: f.isLine);

  // ชื่อที่แสดงในหน้าจอออกแบบ — ฟิลด์ที่มีคู่ไทย/อังกฤษแสดงชื่อตามภาษาของข้อมูล เช่น [ชื่อบริษัท] [Company name]
  String displayLabel(PrintField f, bool isEnglish) {
    if (pairOf(f) == null) return f.label(isEnglish);
    return f.key.endsWith('_en') ? f.labelEn.replaceAll(RegExp(r'\s*\(EN\)|,\s*EN(?=\))'), '') : f.labelTh;
  }

  factory PrintDataSource.fromJson(Map<String, dynamic> j) => PrintDataSource(
        key: j['key'] ?? '',
        nameTh: j['name_th'] ?? '',
        nameEn: j['name_en'] ?? j['name_th'] ?? '',
        fields: ((j['fields'] as List?) ?? []).map((e) => PrintField.fromJson(e)).toList(),
      );
}

// สีพื้นกรอบที่เลือกได้ (RRGGBB)
const printFillColors = <String, List<String>>{
  '000000': ['ดำ', 'Black'],
  '808080': ['เทา', 'Gray'],
  'D9D9D9': ['เทาอ่อน', 'Light gray'],
  '1F4E79': ['น้ำเงิน', 'Navy'],
  'BDD7EE': ['ฟ้าอ่อน', 'Light blue'],
  '548235': ['เขียว', 'Green'],
  'E2EFDA': ['เขียวอ่อน', 'Light green'],
  'C00000': ['แดง', 'Red'],
  'FCE4D6': ['ส้มอ่อน', 'Light orange'],
  'FFF2CC': ['เหลืองอ่อน', 'Light yellow'],
};

// ── ชิ้นงาน ─────────────────────────────────────────────────────────────────
// type: field = ค่าจากฟิลด์ (+ข้อความนำหน้า/ต่อท้าย), text = ข้อความคงที่ (แทรก {key} ได้), line = เส้น (x,y)->(x+w,y+h),
//       rect = กรอบ, image = รูป (โลโก้บริษัท หรือรูปที่อัปโหลด), table = ตารางรายการ (ขึ้นหน้าใหม่เมื่อเกินจำนวนแถว)
class PrintColumn {
  String field;
  String title;
  double w;
  String align; // L / C / R
  String fmt; // ว่าง = ตามชนิดฟิลด์
  bool blankZero;

  PrintColumn({required this.field, this.title = '', this.w = 20, this.align = 'L', this.fmt = '', this.blankZero = false});

  factory PrintColumn.fromJson(Map<String, dynamic> j) => PrintColumn(
        field: j['field'] ?? '',
        title: j['title'] ?? '',
        w: _d(j['w'], 20),
        align: j['align'] ?? 'L',
        fmt: j['fmt'] ?? '',
        blankZero: j['blankZero'] == true,
      );

  Map<String, dynamic> toJson() => {
        'field': field, 'title': title, 'w': w, 'align': align,
        if (fmt.isNotEmpty) 'fmt': fmt,
        if (blankZero) 'blankZero': true,
      };

  PrintColumn copy() => PrintColumn.fromJson(toJson());
}

class PrintElement {
  String id;
  String type;
  double x, y, w, h;
  String? field; // field: คีย์ฟิลด์ / image: 'company_logo' หรือ null = รูปที่อัปโหลด
  String text; // text: ข้อความ (แทรก {key})
  String prefix, suffix; // field
  double fontSize;
  bool bold;
  String align; // L / C / R
  int maxLines; // 0 = ตัดบรรทัดตามความกว้างจนเต็มความสูง
  String fmt;
  bool blankZero;
  double strokeWidth; // line / rect / เส้นตาราง (pt) — rect: 0 = ไม่มีเส้นขอบ
  String fillColor; // rect: สีพื้น RRGGBB (ว่าง = ไม่เติมสี)
  double fillOpacity; // rect: ความทึบของสีพื้น 0-1 (1 = ทึบ)
  String pages; // all / first / last
  List<int> copies; // สำเนาที่แสดง (ว่าง = ทุกสำเนา) — ใช้กับโหมด LASER
  String? imageData; // data URL ของรูปที่อัปโหลด
  // table
  double rowHeight;
  bool showHeader;
  double headerHeight;
  String border; // grid / rows / box / none
  List<PrintColumn> columns;

  PrintElement({
    required this.id,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.w = 40,
    this.h = 6,
    this.field,
    this.text = '',
    this.prefix = '',
    this.suffix = '',
    this.fontSize = 14,
    this.bold = false,
    this.align = 'L',
    this.maxLines = 1,
    this.fmt = '',
    this.blankZero = false,
    this.strokeWidth = 0.5,
    this.fillColor = '',
    this.fillOpacity = 1,
    this.pages = 'all',
    List<int>? copies,
    this.imageData,
    this.rowHeight = 6,
    this.showHeader = true,
    this.headerHeight = 7,
    this.border = 'grid',
    List<PrintColumn>? columns,
  })  : copies = copies ?? [],
        columns = columns ?? [];

  // จำนวนแถวรายการต่อหน้า (ตาราง)
  int get rowsPerPage {
    if (type != 'table' || rowHeight <= 0) return 0;
    final n = ((h - (showHeader ? headerHeight : 0)) / rowHeight + 0.0001).floor();
    return n < 1 ? 1 : n;
  }

  bool visibleOnCopy(int copyNo) => copies.isEmpty || copies.contains(copyNo);

  factory PrintElement.fromJson(Map<String, dynamic> j) => PrintElement(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: j['type'] ?? 'text',
        x: _d(j['x']),
        y: _d(j['y']),
        w: _d(j['w'], 40),
        h: _d(j['h'], 6),
        field: j['field'],
        text: j['text'] ?? '',
        prefix: j['prefix'] ?? '',
        suffix: j['suffix'] ?? '',
        fontSize: _d(j['fontSize'], 14),
        bold: j['bold'] == true,
        align: j['align'] ?? 'L',
        maxLines: (j['maxLines'] as num?)?.toInt() ?? 1,
        fmt: j['fmt'] ?? '',
        blankZero: j['blankZero'] == true,
        strokeWidth: _d(j['strokeWidth'], 0.5),
        fillColor: j['fillColor'] ?? '',
        fillOpacity: _d(j['fillOpacity'], 1),
        pages: j['pages'] ?? 'all',
        copies: ((j['copies'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
        imageData: j['imageData'],
        rowHeight: _d(j['rowHeight'], 6),
        showHeader: j['showHeader'] != false,
        headerHeight: _d(j['headerHeight'], 7),
        border: j['border'] ?? 'grid',
        columns: ((j['columns'] as List?) ?? []).map((e) => PrintColumn.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id, 'type': type, 'x': x, 'y': y, 'w': w, 'h': h,
      'pages': pages,
      if (copies.isNotEmpty) 'copies': copies,
    };
    switch (type) {
      case 'field':
      case 'text':
        m.addAll({
          if (type == 'field') 'field': field,
          if (type == 'text') 'text': text,
          if (prefix.isNotEmpty) 'prefix': prefix,
          if (suffix.isNotEmpty) 'suffix': suffix,
          'fontSize': fontSize, 'bold': bold, 'align': align, 'maxLines': maxLines,
          if (fmt.isNotEmpty) 'fmt': fmt,
          if (blankZero) 'blankZero': true,
        });
        break;
      case 'line':
        m['strokeWidth'] = strokeWidth;
        break;
      case 'rect':
        m['strokeWidth'] = strokeWidth;
        if (fillColor.isNotEmpty) m.addAll({'fillColor': fillColor, 'fillOpacity': fillOpacity});
        break;
      case 'image':
        m['field'] = field;
        if (field == null && imageData != null) m['imageData'] = imageData;
        break;
      case 'table':
        m.addAll({
          'fontSize': fontSize, 'bold': bold, 'strokeWidth': strokeWidth,
          'rowHeight': rowHeight, 'showHeader': showHeader, 'headerHeight': headerHeight, 'border': border,
          'columns': columns.map((c) => c.toJson()).toList(),
        });
        break;
    }
    return m;
  }

  PrintElement copy({String? newId}) {
    final e = PrintElement.fromJson(toJson());
    if (newId != null) e.id = newId;
    return e;
  }
}

// ── ชุดสำเนา ────────────────────────────────────────────────────────────────
class PrintFormCopy {
  String nameTh;
  String nameEn;
  String? bgImage; // data URL
  double bgOffsetX, bgOffsetY, bgScale, bgRotate;

  PrintFormCopy({
    required this.nameTh,
    this.nameEn = '',
    this.bgImage,
    this.bgOffsetX = 0,
    this.bgOffsetY = 0,
    this.bgScale = 1,
    this.bgRotate = 0,
  });

  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;

  factory PrintFormCopy.fromJson(Map<String, dynamic> j) => PrintFormCopy(
        nameTh: j['copy_name_th'] ?? '',
        nameEn: j['copy_name_en'] ?? '',
        bgImage: j['bg_image'],
        bgOffsetX: _d(j['bg_offset_x_mm']),
        bgOffsetY: _d(j['bg_offset_y_mm']),
        bgScale: _d(j['bg_scale'], 1),
        bgRotate: _d(j['bg_rotate_deg']),
      );

  Map<String, dynamic> toJson() => {
        'copy_name_th': nameTh, 'copy_name_en': nameEn, 'bg_image': bgImage,
        'bg_offset_x_mm': bgOffsetX, 'bg_offset_y_mm': bgOffsetY, 'bg_scale': bgScale, 'bg_rotate_deg': bgRotate,
      };
}

// ── แบบฟอร์ม ────────────────────────────────────────────────────────────────
class PrintForm {
  int? id;
  String code;
  String nameTh;
  String nameEn;
  String dataSource;
  String printMode; // LASER / PREPRINTED
  String paperSize;
  double paperWidth, paperHeight;
  double offsetX, offsetY;
  bool isDefault;
  bool isActive;
  String remark;
  int copyCount; // จากรายการ (ไม่ได้โหลด copies)
  List<PrintElement> elements;
  List<PrintFormCopy> copies;

  PrintForm({
    this.id,
    this.code = '',
    this.nameTh = '',
    this.nameEn = '',
    this.dataSource = '',
    this.printMode = 'LASER',
    this.paperSize = 'A4',
    this.paperWidth = 210,
    this.paperHeight = 297,
    this.offsetX = 0,
    this.offsetY = 0,
    this.isDefault = false,
    this.isActive = true,
    this.remark = '',
    this.copyCount = 0,
    List<PrintElement>? elements,
    List<PrintFormCopy>? copies,
  })  : elements = elements ?? [],
        copies = copies ?? [];

  bool get isPreprinted => printMode == 'PREPRINTED';
  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;

  factory PrintForm.fromJson(Map<String, dynamic> j) {
    final layout = j['layout_json'];
    return PrintForm(
      id: j['id'],
      code: j['form_code'] ?? '',
      nameTh: j['form_name_th'] ?? '',
      nameEn: j['form_name_en'] ?? '',
      dataSource: j['data_source'] ?? '',
      printMode: j['print_mode'] ?? 'LASER',
      paperSize: j['paper_size'] ?? 'CUSTOM',
      paperWidth: _d(j['paper_width_mm'], 210),
      paperHeight: _d(j['paper_height_mm'], 297),
      offsetX: _d(j['offset_x_mm']),
      offsetY: _d(j['offset_y_mm']),
      isDefault: j['is_default'] == true,
      isActive: j['is_active'] != false,
      remark: j['remark'] ?? '',
      copyCount: (j['copy_count'] as num?)?.toInt() ?? ((j['copies'] as List?)?.length ?? 0),
      elements: layout is Map
          ? ((layout['elements'] as List?) ?? []).map((e) => PrintElement.fromJson(Map<String, dynamic>.from(e))).toList()
          : [],
      copies: ((j['copies'] as List?) ?? []).map((e) => PrintFormCopy.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'form_code': code, 'form_name_th': nameTh, 'form_name_en': nameEn, 'data_source': dataSource,
        'print_mode': printMode, 'paper_size': paperSize, 'paper_width_mm': paperWidth, 'paper_height_mm': paperHeight,
        'offset_x_mm': offsetX, 'offset_y_mm': offsetY, 'is_default': isDefault, 'is_active': isActive, 'remark': remark,
        'layout_json': {'elements': elements.map((e) => e.toJson()).toList()},
        'copies': copies.map((c) => c.toJson()).toList(),
      };

  PrintForm clone() => PrintForm.fromJson({...toJson(), 'id': id, 'copy_count': copyCount});
}

// ── ข้อมูลพิมพ์ ─────────────────────────────────────────────────────────────
class PrintDoc {
  final String key;
  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> lines;

  const PrintDoc({required this.key, required this.header, required this.lines});

  factory PrintDoc.fromJson(Map<String, dynamic> j) => PrintDoc(
        key: j['key'] ?? '',
        header: Map<String, dynamic>.from(j['header'] ?? {}),
        lines: ((j['lines'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
}

class PrintData {
  final Map<String, dynamic> company;
  final List<PrintDoc> docs;
  final List<String> skipped;

  const PrintData({required this.company, required this.docs, this.skipped = const []});

  factory PrintData.fromJson(Map<String, dynamic> j) => PrintData(
        company: Map<String, dynamic>.from(j['company'] ?? {}),
        docs: ((j['docs'] as List?) ?? []).map((e) => PrintDoc.fromJson(e)).toList(),
        skipped: ((j['skipped'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

// เอกสารในหน้าจอพิมพ์
class PrintDocRow {
  final String key;
  final String module;
  final String docCode;
  final String docNo;
  final String docDate;
  final String customerCode;
  final String customerName;
  final double totalAmount;
  // สกุลเงินของเอกสาร — สกุลเงินหลักไม่ต้องแสดงรหัสต่อท้ายยอด
  final String currencyCode;
  final bool isBaseCurrency;
  final int printCount;

  const PrintDocRow({
    required this.key,
    required this.module,
    required this.docCode,
    required this.docNo,
    required this.docDate,
    required this.customerCode,
    required this.customerName,
    required this.totalAmount,
    this.currencyCode = '',
    this.isBaseCurrency = true,
    required this.printCount,
  });

  factory PrintDocRow.fromJson(Map<String, dynamic> j) => PrintDocRow(
        key: j['key'] ?? '',
        module: j['module'] ?? '',
        docCode: j['doc_code'] ?? '',
        docNo: j['doc_no'] ?? '',
        docDate: j['doc_date'] ?? '',
        customerCode: j['customer_code'] ?? '',
        customerName: j['customer_name'] ?? '',
        totalAmount: _d(j['total_amount']),
        currencyCode: j['currency_code'] ?? '',
        isBaseCurrency: j['is_base_currency'] != false,
        printCount: (j['print_count'] as num?)?.toInt() ?? 0,
      );
}

class PrintDocType {
  final int id;
  final String module;
  final String docCode;
  final String nameTh;
  final String nameEn;

  const PrintDocType({required this.id, required this.module, required this.docCode, required this.nameTh, required this.nameEn});

  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;

  factory PrintDocType.fromJson(Map<String, dynamic> j) => PrintDocType(
        id: j['id'],
        module: j['module'] ?? '',
        docCode: j['doc_code'] ?? '',
        nameTh: j['doc_name_thai'] ?? '',
        nameEn: j['doc_name_eng'] ?? '',
      );
}
