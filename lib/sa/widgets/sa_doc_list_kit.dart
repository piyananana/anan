import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ชุดส่วนประกอบหน้ารายการเอกสาร (user design 2026-11-22, ต้นแบบ = หน้ารายการธุรกรรม IM) — สไตล์เดียวกับหน้ารายละเอียด:
// การ์ดเงื่อนไข fix ด้านบน (กลุ่มสี ①–④ ย่อเป็นแถบสรุปได้) + การ์ดรายการ (ตารางแบบการ์ดรายการสินค้า)
// ขนาด: ช่อง 40 px / ตัวอักษร 13, ป้ายลอย 12, หัวการ์ด 16 ตัวหนา, หัวคอลัมน์ 12 ตัวหนา, แถว 44 px (2 บรรทัด)
class DocListKit {
  static const gDoc = Color(0xFF1E5AA8);
  static const gParty = Color(0xFF1F7A4D);
  static const gFin = Color(0xFFB45309);
  static const gMore = Color(0xFF5B6B7C);
  static const fillAuto = Color(0xFFE3EEFA);
  static const ink2 = Color(0xFF4A5562);
  static const ink3 = Color(0xFF6B7682);
  static const docNoColor = Color(0xFF0F5C5C);
  static const accent = Color(0xFF0F6E6E);
  static const rowLine = Color(0xFFEEF1F4);
  static const groupLine = Color(0xFFDDE3EA);
  static const negative = Color(0xFFC62828);
  static const double fieldH = 40;
  static const double fontSize = 13;
  static const double cardTitleSize = 16;
  static const double rowH = 44;
  static const numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
  static final dateFmt = DateFormat('dd/MM/yyyy');

  static Color groupColor(int g) => g == 1 ? gDoc : g == 2 ? gParty : g == 3 ? gFin : gMore;

  /// สีป้ายสถานะ (ตัวอักษร, พื้น) — ใช้ร่วมทุกโมดูล
  static (Color, Color) statusColors(String status) {
    switch (status) {
      case 'Draft':
        return (const Color(0xFFE65100), const Color(0xFFFFF0D9));
      case 'Submitted':
      case 'Pending':
      case 'PendingApproval':
        return (const Color(0xFF8A4B00), const Color(0xFFFFF3C4));
      case 'Posted':
      case 'Approved':
      case 'Released':
      case 'Completed':
      case 'FullyReceived':
      case 'FullyDelivered':
      case 'Converted':
      case 'Accepted':
      case 'Cleared':
        return (const Color(0xFF1E6B3A), const Color(0xFFE6F4EA));
      case 'Received':
      case 'Delivered':
      case 'InProgress':
      case 'PartiallyReceived':
      case 'PartiallyDelivered':
      case 'PartiallyConverted':
      case 'Sent':
        return (const Color(0xFF1E4F8F), const Color(0xFFE3EEFA));
      case 'Closed':
        return (const Color(0xFF33404D), const Color(0xFFE4E8EC));
      case 'Void':
      case 'Cancelled':
      case 'Rejected':
      case 'Expired':
      case 'Lost':
      case 'Bounced':
        return (const Color(0xFFB71C1C), const Color(0xFFFDECEA));
      default:
        return (const Color(0xFF5B6B7C), const Color(0xFFEEF0F2));
    }
  }
}

/// ธีมขนาดตัวอักษร 13 ทั้งหน้ารายการ (ค่าเริ่มต้นของ Flutter ต่างกันตามชนิดฟิลด์) — ป้ายลอยบนกรอบ 12 (16 × 0.75)
Widget docListTheme(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  TextStyle? sz(TextStyle? s) => (s ?? const TextStyle()).copyWith(fontSize: DocListKit.fontSize);
  return Theme(
    data: theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        bodyLarge: sz(theme.textTheme.bodyLarge),
        bodyMedium: sz(theme.textTheme.bodyMedium),
        titleMedium: sz(theme.textTheme.titleMedium),
        titleSmall: sz(theme.textTheme.titleSmall),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: const TextStyle(fontSize: DocListKit.fontSize),
        floatingLabelStyle: const TextStyle(fontSize: 16),
      ),
    ),
    child: child,
  );
}

/// ช่องสูง 40 พอดีทุกชนิด: ไม่ dense (กรอบขั้นต่ำ 48) + จำกัดความสูง 40; ระยะบนล่าง 4 ไม่บีบข้อความไทยที่ Aa 125%
InputDecoration docFieldDec(String label, {bool auto = false, Widget? suffixIcon}) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: false,
      constraints: const BoxConstraints.tightFor(height: DocListKit.fieldH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
      filled: auto,
      fillColor: DocListKit.fillAuto,
    );

const _searchIcon = Icon(Icons.search, size: 18, color: DocListKit.accent);

Widget docGroupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]);

/// กลุ่มเงื่อนไข: แถบสีด้านบน + ชื่อกลุ่ม (แบบกลุ่มในการ์ดข้อมูลเอกสาร)
Widget docFilterGroup(int no, String title, List<Widget> rows, {Color? color}) {
  final c = color ?? DocListKit.groupColor(no);
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        border: Border.all(color: DocListKit.groupLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 3, color: c),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            docGroupLabel(no, title, c),
            for (final r in rows) ...[const SizedBox(height: 10), r],
          ]),
        ),
      ]),
    ),
  );
}

Widget docChip(String text, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
    );

/// ป้ายสถานะ — label = ชื่อที่แสดง (เช่น ชื่อไทยของสถานะใบสั่งขาย) สีตามรหัสสถานะ
Widget docStatusBadge(String status, {String? label}) {
  final (fg, bg) = DocListKit.statusColors(status);
  return docChip(label ?? status, fg, bg);
}

/// เซลล์ 2 บรรทัด: รหัสตัวหนา 13 + ชื่อ 12 สีเทา (แบบช่องสินค้าในการ์ดรายการสินค้า)
Widget docTwoLine(String a, String b, {Color? aColor}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: aColor)),
        if (b.isNotEmpty) Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: DocListKit.ink3)),
      ],
    );

const docDash = Text('—', style: TextStyle(color: Color(0xFF9AA3AD)));

/// ตัวเลขชิดขวา (ติดลบสีแดง, 0 = ขีด เมื่อ dashZero)
Widget docNum(double v, NumberFormat fmt, {bool bold = false, bool dashZero = false, Color? color}) {
  if (dashZero && v == 0) return const Align(alignment: Alignment.centerRight, child: docDash);
  return Text(fmt.format(v),
      textAlign: TextAlign.right,
      maxLines: 1,
      style: DocListKit.numStyle.copyWith(
          fontWeight: bold ? FontWeight.bold : null, color: color ?? (v < 0 ? DocListKit.negative : null)));
}

Widget docDateField(String label, DateTime value, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: docFieldDec(label, auto: true, suffixIcon: const Icon(Icons.calendar_today, size: 16, color: DocListKit.accent)),
        child: Text(DocListKit.dateFmt.format(value), maxLines: 1),
      ),
    );

Widget docSearchField(TextEditingController ctrl, String label, VoidCallback onChanged, {String? tooltip}) {
  final f = TextField(
    controller: ctrl,
    decoration: docFieldDec(label, suffixIcon: _searchIcon),
    onChanged: (_) => onChanged(),
  );
  return tooltip == null ? f : Tooltip(message: tooltip, child: f);
}

/// dropdown สูง 40 ("ทั้งหมด" = null)
Widget docDropdown<T>({
  required String label,
  required T? value,
  required String allLabel,
  required List<(T, String)> items,
  required ValueChanged<T?> onChanged,
}) =>
    DropdownButtonFormField<T?>(
      value: items.any((e) => e.$1 == value) ? value : null,
      isExpanded: true,
      isDense: true,
      decoration: docFieldDec(label),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
        for (final (v, l) in items) DropdownMenuItem<T?>(value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );

// ── ช่วงวันที่ ──
class DocDatePresets {
  static const keys = ['month', 'prev', 'quarter', 'year'];

  static (DateTime, DateTime) range(String p) {
    final now = DateTime.now();
    final y = now.year, m = now.month;
    switch (p) {
      case 'prev':
        return (DateTime(y, m - 1, 1), DateTime(y, m, 0));
      case 'quarter':
        final q = ((m - 1) ~/ 3) * 3 + 1;
        return (DateTime(y, q, 1), DateTime(y, q + 3, 0));
      case 'year':
        return (DateTime(y, 1, 1), DateTime(y, 12, 31));
      default:
        return (DateTime(y, m, 1), DateTime(y, m + 1, 0));
    }
  }

  static String label(String p, bool en) => switch (p) {
        'month' => en ? 'This month' : 'เดือนนี้',
        'prev' => en ? 'Last month' : 'เดือนก่อน',
        'quarter' => en ? 'This quarter' : 'ไตรมาสนี้',
        _ => en ? 'This year' : 'ปีนี้',
      };
}

/// ปุ่มช่วงวันที่สำเร็จรูป บรรทัดเดียวเสมอ — ที่ไม่พอแสดง "…" ชี้เมาส์เห็นชื่อเต็ม
Widget docPresetRow({required String? selected, required ValueChanged<String> onPick, required bool isEnglish}) {
  Widget chip(String p) {
    final on = selected == p;
    final label = DocDatePresets.label(p, isEnglish);
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onPick(p),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEAF1FB) : Colors.white,
            border: Border.all(color: on ? DocListKit.gDoc : DocListKit.groupLine),
            borderRadius: BorderRadius.circular(13),
          ),
          // widthFactor 1 = กว้างตามข้อความ แต่ย่อแล้วตัดเป็น "…" เมื่อที่ไม่พอ
          child: Align(
            widthFactor: 1,
            child: Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: on ? DocListKit.gDoc : DocListKit.ink2, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  return Row(children: [
    for (final (i, p) in DocDatePresets.keys.indexed) ...[
      if (i > 0) const SizedBox(width: 6),
      Flexible(child: chip(p)),
    ],
  ]);
}

/// ชิปสถานะกดเลือกได้หลายค่า พร้อมจำนวน (count null = ไม่แสดงจำนวน)
Widget docStatusToggles({
  required List<String> statuses,
  required Set<String> selected,
  required int? Function(String) count,
  required ValueChanged<String> onToggle,
  required bool isEnglish,
  String Function(String)? label,
}) {
  Widget toggle(String s) {
    final on = selected.contains(s);
    final (fg, bg) = DocListKit.statusColors(s);
    final n = count(s);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => onToggle(s),
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(left: 8, right: 10),
        decoration: BoxDecoration(
          color: on ? bg : Colors.white,
          border: Border.all(color: on ? fg : DocListKit.groupLine),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text(label?.call(s) ?? s,
              style: TextStyle(fontSize: 12, color: on ? fg : DocListKit.ink2, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          if (n != null) ...[
            const SizedBox(width: 6),
            Text('$n', style: DocListKit.numStyle.copyWith(fontSize: 12, color: on ? fg : DocListKit.ink3)),
          ],
        ]),
      ),
    );
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
    Wrap(spacing: 6, runSpacing: 6, children: [for (final s in statuses) toggle(s)]),
    const SizedBox(height: 10),
    Text(isEnglish ? 'None selected = all except deleted · multiple allowed' : 'ไม่เลือก = ทุกสถานะ ยกเว้นลบแล้ว · เลือกได้หลายสถานะ',
        style: const TextStyle(fontSize: 12, color: DocListKit.ink3)),
  ]);
}

// ── การ์ดเงื่อนไขการค้นหา ──
class DocSummaryItem {
  final Color color;
  final String label;
  final String value;
  const DocSummaryItem(this.color, this.label, this.value);
}

/// จำสถานะย่อ/ขยายของการ์ดเงื่อนไขต่อเครื่อง
class DocListPrefs {
  static Future<bool> loadCollapsed(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveCollapsed(String key, bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, v);
    } catch (_) {}
  }
}

class DocFilterCard extends StatelessWidget {
  final bool isEnglish;
  final String countText;
  final bool hasActive;
  final VoidCallback onClear;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  /// กลุ่ม ①–④ (จอกว้าง: แถวเดียว / จอกลาง: แถวละ 2 / จอแคบ: เรียงลง)
  final List<Widget> groups;
  /// สัดส่วนความกว้างของแต่ละกลุ่มบนจอกว้าง (ไม่ระบุ = เท่ากัน)
  final List<int>? flexes;
  final List<DocSummaryItem> summary;

  const DocFilterCard({
    super.key,
    required this.isEnglish,
    required this.countText,
    required this.hasActive,
    required this.onClear,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.groups,
    required this.summary,
    this.flexes,
  });

  @override
  Widget build(BuildContext context) {
    // ซ้าย: ชื่อ + ชิปจำนวน (Expanded กินพื้นที่ว่างทั้งหมด) / ขวาสุด: ล้างเงื่อนไข + ย่อ/ขยาย
    final titleRow = Row(children: [
      Expanded(
        child: Row(children: [
          Text(isEnglish ? 'Search Criteria' : 'เงื่อนไขการค้นหา',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DocListKit.cardTitleSize)),
          const SizedBox(width: 10),
          Flexible(child: docChip(countText, const Color(0xFF1E4F8F), const Color(0xFFE3EEFA))),
        ]),
      ),
      if (hasActive)
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: DocListKit.accent),
          onPressed: onClear,
          child: Text(isEnglish ? 'Clear filters' : 'ล้างเงื่อนไข', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18),
        label: Text(collapsed ? (isEnglish ? 'Expand' : 'ขยาย') : (isEnglish ? 'Collapse' : 'ย่อ'), style: const TextStyle(fontSize: 12)),
        onPressed: onToggleCollapse,
      ),
    ]);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          if (collapsed) _summary() else _groups(),
        ]),
      ),
    );
  }

  Widget _groups() => LayoutBuilder(builder: (context, c) {
        Widget row(List<int> idx) => IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < idx.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(flex: flexes != null && flexes!.length == groups.length ? flexes![idx[i]] : 1, child: groups[idx[i]]),
                ],
              ]),
            );
        final n = groups.length;
        if (c.maxWidth >= 1150 || (n <= 2 && c.maxWidth >= 640)) return row([for (var i = 0; i < n; i++) i]);
        if (c.maxWidth >= 640) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < n; i += 2) ...[
              if (i > 0) const SizedBox(height: 10),
              i + 1 < n ? row([i, i + 1]) : groups[i],
            ],
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < n; i++) ...[if (i > 0) const SizedBox(height: 10), groups[i]],
        ]);
      });

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _summary() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
        child: Wrap(spacing: 22, runSpacing: 6, children: [
          for (final s in summary)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 6),
              Text('${s.label} ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(s.value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ]),
        ]),
      );
}

// ── การ์ดรายการ ──
/// คอลัมน์: width 0 = ยืดตามพื้นที่ที่เหลือ; group 1-4 = แถบสีเหนือหัวคอลัมน์ (0 = ไม่มี)
class DocListColumn {
  final String key;
  final String label;
  final double width;
  final int group;
  final bool right;
  final String? sortKey;
  const DocListColumn(this.key, this.label, this.width, this.group, {this.right = false, this.sortKey});
}

class DocListCard extends StatefulWidget {
  final String title;
  final List<Widget> chips;
  final Widget? trailing;
  final List<DocListColumn> columns;
  final String Function(int group) groupTitle;
  final int rowCount;
  final Widget Function(int row, String key) cell;
  final void Function(int row) onTap;
  final bool loading;
  final String emptyText;
  final String? sortKey;
  final bool sortAsc;
  final ValueChanged<String>? onSort;
  /// แถวรวมท้ายตาราง: key ของคอลัมน์ → widget (null = ไม่มีแถวรวม)
  final Map<String, Widget>? footer;

  const DocListCard({
    super.key,
    required this.title,
    required this.columns,
    required this.groupTitle,
    required this.rowCount,
    required this.cell,
    required this.onTap,
    required this.loading,
    required this.emptyText,
    this.chips = const [],
    this.trailing,
    this.sortKey,
    this.sortAsc = false,
    this.onSort,
    this.footer,
  });

  @override
  State<DocListCard> createState() => _DocListCardState();
}

class _DocListCardState extends State<DocListCard> {
  static const double _gap = 8;
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleRow = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: DocListKit.cardTitleSize)),
          ...widget.chips,
        ]),
        if (widget.trailing != null) widget.trailing!,
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          Expanded(child: _table()),
        ]),
      ),
    );
  }

  Widget _table() {
    final cols = widget.columns;
    final fixed = cols.fold<double>(0, (t, c) => t + c.width) + _gap * (cols.length - 1);
    return LayoutBuilder(builder: (context, cons) {
      final flexW = cons.maxWidth - fixed > 180 ? cons.maxWidth - fixed : 180.0;
      final tableW = fixed + flexW;
      double w(DocListColumn c) => c.width == 0 ? flexW : c.width;
      Widget cells(List<Widget> ws) => Row(children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(width: w(cols[i]), child: ws[i]),
            ],
          ]);

      // แถบสีกลุ่มเหนือหัวคอลัมน์ — แบบการ์ดรายการสินค้า
      final groupRow = <Widget>[];
      var i = 0;
      while (i < cols.length) {
        var j = i;
        var span = w(cols[i]);
        while (j + 1 < cols.length && cols[j + 1].group == cols[i].group) {
          j++;
          span += _gap + w(cols[j]);
        }
        if (i > 0) groupRow.add(const SizedBox(width: _gap));
        final g = cols[i].group;
        groupRow.add(SizedBox(
          width: span,
          child: g == 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(color: DocListKit.groupColor(g), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 3),
                  docGroupLabel(g, widget.groupTitle(g), DocListKit.groupColor(g)),
                ]),
        ));
        i = j + 1;
      }

      const hdStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DocListKit.ink2);
      Widget header(DocListColumn c) {
        final text = Text(c.label, style: hdStyle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: c.right ? TextAlign.right : TextAlign.left);
        if (c.sortKey == null || widget.onSort == null) return Tooltip(message: c.label, child: text);
        final on = widget.sortKey == c.sortKey;
        return InkWell(
          onTap: () => widget.onSort!(c.sortKey!),
          child: Row(mainAxisAlignment: c.right ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
            Flexible(child: text),
            const SizedBox(width: 2),
            Icon(on ? (widget.sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                size: 14, color: on ? DocListKit.accent : Colors.grey.shade400),
          ]),
        );
      }

      final Widget body;
      if (widget.loading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (widget.rowCount == 0) {
        body = Center(child: Text(widget.emptyText, style: const TextStyle(color: DocListKit.ink3), textAlign: TextAlign.center));
      } else {
        body = ListView.builder(
          itemCount: widget.rowCount,
          itemExtent: DocListKit.rowH + 1,
          itemBuilder: (context, n) => InkWell(
            onTap: () => widget.onTap(n),
            hoverColor: const Color(0xFFEEF6F5),
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DocListKit.rowLine))),
              child: cells([
                for (final c in cols)
                  Align(alignment: c.right ? Alignment.centerRight : Alignment.centerLeft, child: widget.cell(n, c.key)),
              ]),
            ),
          ),
        );
      }

      final table = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: groupRow),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DocListKit.groupLine))),
          child: cells([for (final c in cols) header(c)]),
        ),
        Expanded(child: body),
        if (!widget.loading && widget.footer != null && widget.rowCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFFF6F8FA), border: Border(top: BorderSide(color: DocListKit.groupLine))),
            child: cells([
              for (final c in cols)
                widget.footer![c.key] == null
                    ? const SizedBox.shrink()
                    : Align(alignment: c.right ? Alignment.centerRight : Alignment.centerLeft, child: widget.footer![c.key]),
            ]),
          ),
      ]);

      if (tableW <= cons.maxWidth + 0.5) return table;
      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableW, height: cons.maxHeight, child: table),
        ),
      );
    });
  }
}

/// โครงหน้ารายการ: การ์ดเงื่อนไข fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) + การ์ดรายการเต็มพื้นที่ที่เหลือ
Widget docListLayout(BuildContext context, {required Widget filterCard, required Widget listCard}) => docListTheme(
      context,
      LayoutBuilder(
        builder: (context, box) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
              child: SingleChildScrollView(child: filterCard),
            ),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.all(12), child: listCard)),
        ]),
      ),
    );

/// แถวรวมท้ายตาราง: ข้อความ "รวม n เอกสาร (ไม่นับ ...)"
Widget docFooterCount(int n, bool isEnglish, {String? exclude}) => Text.rich(
      TextSpan(children: [
        TextSpan(text: isEnglish ? 'Total $n docs' : 'รวม $n เอกสาร', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (exclude != null) TextSpan(text: '  $exclude', style: const TextStyle(fontSize: 12, color: DocListKit.ink3)),
      ]),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );

/// มูลค่ารวมที่หัวการ์ดรายการ
Widget docTotalLabel(String label, double v, String currency) => Text.rich(TextSpan(children: [
      TextSpan(text: '$label ', style: const TextStyle(fontSize: 12, color: DocListKit.ink3)),
      TextSpan(text: NumberFormat('#,##0.00').format(v), style: DocListKit.numStyle.copyWith(fontWeight: FontWeight.bold)),
      TextSpan(text: ' $currency', style: const TextStyle(fontSize: 12, color: DocListKit.ink3)),
    ]));

/// ค้นหาหลายคำ: ทุกคำต้องพบในข้อความรวม
bool docKeywordMatch(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = fields.map((s) => (s ?? '').toLowerCase()).join(' ');
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// ปุ่มเพิ่มเอกสารบน AppBar ของหน้ารายการ — ใช้ร่วมกับ buildDocBarActions
String docAddLabel(bool isEnglish) => isEnglish ? 'Add Document' : 'เพิ่มเอกสาร';
