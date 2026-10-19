// พนักงานขายของลูกค้า / เอกสารขาย พร้อมสัดส่วน (% และจำนวนเงิน)
// backend: utils/docSalesperson.js — ar_customer_salesperson, <doc>_salesperson
class DocSalesperson {
  final int salespersonId;
  final String salespersonCode;
  final String salespersonNameThai;
  final String? salespersonNameEng;
  final bool isPrimary;
  final double? sharePercent;
  final double? shareAmount; // สกุลท้องถิ่น จากยอดก่อน VAT ของเอกสาร (ลูกค้าไม่ใช้)

  const DocSalesperson({
    required this.salespersonId,
    required this.salespersonCode,
    required this.salespersonNameThai,
    this.salespersonNameEng,
    this.isPrimary = false,
    this.sharePercent,
    this.shareAmount,
  });

  String displayName(bool isEnglish) =>
      isEnglish && (salespersonNameEng ?? '').isNotEmpty ? salespersonNameEng! : salespersonNameThai;

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory DocSalesperson.fromJson(Map<String, dynamic> j) => DocSalesperson(
        salespersonId: j['salesperson_id'] as int,
        salespersonCode: j['salesperson_code'] ?? '',
        salespersonNameThai: j['salesperson_name_thai'] ?? '',
        salespersonNameEng: j['salesperson_name_eng'] as String?,
        isPrimary: j['is_primary'] == true,
        sharePercent: _num(j['share_percent']),
        shareAmount: _num(j['share_amount']),
      );

  Map<String, dynamic> toJson() => {
        'salesperson_id': salespersonId,
        'is_primary': isPrimary,
        'share_percent': sharePercent,
        'share_amount': shareAmount,
      };

  static List<DocSalesperson> listFromJson(dynamic list) => (list as List? ?? [])
      .map((e) => DocSalesperson.fromJson(e as Map<String, dynamic>))
      .toList();

  // รายชื่ออย่างเดียว (ไม่มีสัดส่วน) — ผู้ป้อนเอกสารเลือกแค่รายชื่อ backend เติม % / จำนวนเงินจากข้อมูลลูกค้าตอนบันทึก
  static List<DocSalesperson> namesOnly(List<DocSalesperson> list) => list
      .map((e) => e.copyWith(sharePercent: () => null, shareAmount: () => null))
      .toList();

  // ชื่อสำหรับพิมพ์ในฟอร์ม เรียงตามลำดับ คั่นด้วยจุลภาค
  static String names(List<DocSalesperson> list, bool isEnglish) =>
      list.map((e) => e.displayName(isEnglish)).join(', ');

  DocSalesperson copyWith({
    bool? isPrimary,
    double? Function()? sharePercent,
    double? Function()? shareAmount,
  }) =>
      DocSalesperson(
        salespersonId: salespersonId,
        salespersonCode: salespersonCode,
        salespersonNameThai: salespersonNameThai,
        salespersonNameEng: salespersonNameEng,
        isPrimary: isPrimary ?? this.isPrimary,
        sharePercent: sharePercent != null ? sharePercent() : this.sharePercent,
        shareAmount: shareAmount != null ? shareAmount() : this.shareAmount,
      );
}
