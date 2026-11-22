// lib/im/widgets/im_cash_sale_panel.dart
// ขายเงินสด ('33') — ส่วนที่เพิ่มจากส่งสินค้าพร้อมใบแจ้งหนี้ ('31'): ผู้ซื้อที่ระบุในเอกสาร, วิธีรับชำระหลายแบบ,
// ภาษีที่ลูกค้าหัก ณ ที่จ่าย, เงินที่รับมา/เงินทอน และเลขที่ใบแจ้งหนี้/ใบเสร็จ AR ที่สร้างตอน Post
// ซื้อเงินสด ('14', purchase = true) ใช้แผงเดียวกัน: ผู้ขายจริง + ประเภทใบกำกับภาษี, วิธีจ่าย, ภาษีที่เราหัก ณ ที่จ่าย,
// เลขที่ใบตั้งหนี้/ใบจ่าย AP (ไม่มีเงินที่รับมา/เงินทอน)
// state (controller) อยู่กับหน้าเอกสาร IM — widget นี้แค่แสดงและแก้ค่าใน ImCashSaleController
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/im_transaction.dart';
import '../../cd/models/cd_wht_type.dart';
import '../../cm/models/cm_payment_method.dart';
import '../../cm/widgets/cm_payment_method_list_widget.dart';

double _num(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;
String _fmtInput(double v) => v == 0 ? '' : v.toStringAsFixed(2);

class ImCashPaymentRow {
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String paymentMethodType;
  final int? cmBankAccountId;
  final int? glAccountId;
  final TextEditingController amountCtrl;
  final TextEditingController refNoCtrl;
  final TextEditingController remarkCtrl;
  final TextEditingController drawerBankNameCtrl;
  final TextEditingController drawerBankBranchCtrl;
  final TextEditingController drawerAccountNoCtrl;
  String? cardType;
  final TextEditingController cardLast4Ctrl;
  final TextEditingController approvalCodeCtrl;

  ImCashPaymentRow({
    this.paymentMethodId, this.paymentMethodCode, this.paymentMethodName, this.paymentMethodType = 'CASH',
    this.cmBankAccountId, this.glAccountId, double amount = 0, String? refNo, String? remark,
    String? drawerBankName, String? drawerBankBranch, String? drawerAccountNo,
    this.cardType, String? cardLast4, String? approvalCode,
  })  : amountCtrl = TextEditingController(text: _fmtInput(amount)),
        refNoCtrl = TextEditingController(text: refNo ?? ''),
        remarkCtrl = TextEditingController(text: remark ?? ''),
        drawerBankNameCtrl = TextEditingController(text: drawerBankName ?? ''),
        drawerBankBranchCtrl = TextEditingController(text: drawerBankBranch ?? ''),
        drawerAccountNoCtrl = TextEditingController(text: drawerAccountNo ?? ''),
        cardLast4Ctrl = TextEditingController(text: cardLast4 ?? ''),
        approvalCodeCtrl = TextEditingController(text: approvalCode ?? '');

  factory ImCashPaymentRow.fromModel(ImCashPayment p) => ImCashPaymentRow(
        paymentMethodId: p.paymentMethodId, paymentMethodCode: p.paymentMethodCode, paymentMethodName: p.paymentMethodName,
        paymentMethodType: p.paymentMethodType, cmBankAccountId: p.cmBankAccountId, glAccountId: p.glAccountId,
        amount: p.amountFc, refNo: p.refNo, remark: p.remark,
        drawerBankName: p.drawerBankName, drawerBankBranch: p.drawerBankBranch, drawerAccountNo: p.drawerAccountNo,
        cardType: p.cardType, cardLast4: p.cardLast4, approvalCode: p.approvalCode,
      );

  double get amount => _num(amountCtrl.text);

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  ImCashPayment toModel() => ImCashPayment(
        paymentMethodId: paymentMethodId, paymentMethodCode: paymentMethodCode, paymentMethodName: paymentMethodName,
        paymentMethodType: paymentMethodType, cmBankAccountId: cmBankAccountId, glAccountId: glAccountId,
        amountFc: amount, refNo: _t(refNoCtrl), remark: _t(remarkCtrl),
        drawerBankName: _t(drawerBankNameCtrl), drawerBankBranch: _t(drawerBankBranchCtrl), drawerAccountNo: _t(drawerAccountNoCtrl),
        cardType: cardType, cardLast4: _t(cardLast4Ctrl), approvalCode: _t(approvalCodeCtrl),
      );

  void dispose() {
    for (final c in [amountCtrl, refNoCtrl, remarkCtrl, drawerBankNameCtrl, drawerBankBranchCtrl, drawerAccountNoCtrl,
        cardLast4Ctrl, approvalCodeCtrl]) {
      c.dispose();
    }
  }
}

// ภาษีถูกหัก ณ ที่จ่าย — กรอก/แสดงเป็นสกุลเงินเอกสาร เก็บเป็นเงินบาท (× อัตราแลกเปลี่ยน) เหมือนใบเสร็จ AR
class ImCashWhtRow {
  CdWhtType? whtType;
  final TextEditingController baseCtrl;
  final TextEditingController whtCtrl;
  final TextEditingController certCtrl;
  final TextEditingController descCtrl;

  ImCashWhtRow({this.whtType, double base = 0, double wht = 0, String? cert, String? desc})
      : baseCtrl = TextEditingController(text: _fmtInput(base)),
        whtCtrl = TextEditingController(text: _fmtInput(wht)),
        certCtrl = TextEditingController(text: cert ?? ''),
        descCtrl = TextEditingController(text: desc ?? '');

  double get whtAmount => _num(whtCtrl.text);

  void recalc() => whtCtrl.text = (_num(baseCtrl.text) * (whtType?.whtRate ?? 0) / 100).toStringAsFixed(2);

  void dispose() {
    baseCtrl.dispose(); whtCtrl.dispose(); certCtrl.dispose(); descCtrl.dispose();
  }
}

class ImCashSaleController {
  final billToNameCtrl = TextEditingController();
  final billToAddressCtrl = TextEditingController();
  final billToTaxIdCtrl = TextEditingController();
  final billToBranchCtrl = TextEditingController();
  final cashReceivedCtrl = TextEditingController();
  List<ImCashPaymentRow> payments = [];
  List<ImCashWhtRow> whts = [];
  String? linkedInvoiceNo;
  String? linkedReceiptNo;
  // ซื้อเงินสด: ประเภทใบกำกับภาษีของผู้ขาย FULL / ABB / NONE
  String taxInvoiceKind = 'FULL';

  double get paymentTotal => payments.fold(0.0, (t, p) => t + p.amount);
  double get cashTotal => payments.where((p) => p.paymentMethodType == 'CASH').fold(0.0, (t, p) => t + p.amount);
  double get whtTotal => whts.fold(0.0, (t, w) => t + w.whtAmount);
  double get cashReceived => _num(cashReceivedCtrl.text);
  // เงินทอน = เงินที่รับมา − ยอดรับชำระด้วยเงินสด (วิธีชำระประเภท CASH เท่านั้น ไม่รวมโอน/บัตร/เช็ค)
  double get change => cashReceived > 0 ? cashReceived - cashTotal : 0;
  bool get receivedWithoutCash => cashReceived > 0 && cashTotal <= 0.005;

  void clear() {
    for (final c in [billToNameCtrl, billToAddressCtrl, billToTaxIdCtrl, billToBranchCtrl, cashReceivedCtrl]) {
      c.clear();
    }
    for (final p in payments) {
      p.dispose();
    }
    for (final w in whts) {
      w.dispose();
    }
    payments = [];
    whts = [];
    linkedInvoiceNo = null;
    linkedReceiptNo = null;
    taxInvoiceKind = 'FULL';
  }

  void load(ImTransaction tx, List<CdWhtType> whtTypes) {
    clear();
    final h = tx.header;
    billToNameCtrl.text = h.billToName ?? '';
    billToAddressCtrl.text = h.billToAddress ?? '';
    billToTaxIdCtrl.text = h.billToTaxId ?? '';
    billToBranchCtrl.text = h.billToBranch ?? '';
    cashReceivedCtrl.text = _fmtInput(h.cashReceived);
    linkedInvoiceNo = h.linkedArInvoiceNo ?? h.linkedApInvoiceNo;
    linkedReceiptNo = h.linkedArReceiptNo ?? h.linkedApPaymentNo;
    taxInvoiceKind = h.taxInvoiceKind ?? 'FULL';
    payments = tx.payments.map(ImCashPaymentRow.fromModel).toList();
    final rate = h.exchangeRate > 0 ? h.exchangeRate : 1;
    whts = tx.whts
        .map((w) => ImCashWhtRow(
              whtType: whtTypes.cast<CdWhtType?>().firstWhere((t) => t!.id == w.whtTypeId, orElse: () => null),
              base: w.baseAmountLc / rate, wht: w.whtAmountLc / rate, cert: w.certificateNo, desc: w.description,
            ))
        .toList();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  String? get billToName => _t(billToNameCtrl);
  String? get billToAddress => _t(billToAddressCtrl);
  String? get billToTaxId => _t(billToTaxIdCtrl);
  String? get billToBranch => _t(billToBranchCtrl);

  List<ImCashPayment> paymentsForSave() => [for (final p in payments) if (p.amount > 0) p.toModel()];

  List<ImCashWht> whtsForSave(double rate) => [
        for (final w in whts)
          if (w.whtAmount > 0)
            ImCashWht(
              whtTypeId: w.whtType?.id, whtCode: w.whtType?.whtCode, whtName: w.whtType?.whtName,
              incomeType: w.whtType?.incomeType, whtRate: w.whtType?.whtRate ?? 0,
              baseAmountLc: double.parse((_num(w.baseCtrl.text) * rate).toStringAsFixed(2)),
              whtAmountLc: double.parse((w.whtAmount * rate).toStringAsFixed(2)),
              certificateNo: _t(w.certCtrl), description: _t(w.descCtrl),
            ),
      ];

  // ตรวจก่อนบันทึก — คืนข้อความผิดพลาด หรือ null = ผ่าน; post = ตรวจยอดรับชำระครบด้วย
  String? validate({required bool post, required double dueFc, required bool isEnglish, required NumberFormat fmt, bool purchase = false}) {
    final party = purchase ? (isEnglish ? 'vendor' : 'ผู้ขาย') : (isEnglish ? 'buyer' : 'ผู้ซื้อ');
    // ข้อมูลผู้ซื้อ/ผู้ขายใช้เมื่อระบุชื่อเท่านั้น — กรอกช่องอื่นโดยไม่มีชื่อ ข้อมูลจะไม่ถูกใช้
    if (billToName == null && (billToAddress != null || billToTaxId != null || billToBranch != null)) {
      return isEnglish ? 'Please enter the $party name' : 'กรุณาระบุชื่อ$party';
    }
    if (billToBranch != null && !RegExp(r'^\d{5}$').hasMatch(billToBranch!)) {
      return isEnglish ? 'The $party tax branch must be 5 digits (00000 = head office)' : 'สาขา$partyต้องเป็นตัวเลข 5 หลัก (00000 = สำนักงานใหญ่)';
    }
    for (final w in whts) {
      if (w.whtAmount > 0 && w.whtType == null) {
        return isEnglish ? 'Please select the withholding tax type' : 'กรุณาเลือกประเภทภาษีหัก ณ ที่จ่าย';
      }
    }
    if (!purchase && receivedWithoutCash) {
      return isEnglish
          ? 'Cash received is entered but there is no cash payment method — add a cash line or clear Cash received'
          : 'กรอกรับเงินมาแล้ว แต่ไม่มีวิธีรับชำระเป็นเงินสด — เพิ่มรายการเงินสด หรือล้างช่องรับเงินมา';
    }
    if (!purchase && cashReceived > 0 && cashReceived < cashTotal - 0.005) {
      return isEnglish
          ? 'Cash received (${fmt.format(cashReceived)}) is less than the cash payment (${fmt.format(cashTotal)})'
          : 'เงินที่รับมา (${fmt.format(cashReceived)}) น้อยกว่ายอดรับชำระด้วยเงินสด (${fmt.format(cashTotal)})';
    }
    if (!post) return null;
    if (dueFc <= 0.005) {
      if (paymentTotal > 0 || whtTotal > 0) {
        return isEnglish
            ? 'Deposits cover the whole ${purchase ? 'purchase' : 'sale'} — remove the payment methods and withholding tax'
            : 'เงินมัดจำครอบคลุมยอด${purchase ? 'ซื้อ' : 'ขาย'}ทั้งหมดแล้ว ไม่ต้องระบุวิธี${purchase ? 'จ่าย' : 'รับชำระ'}และภาษีหัก ณ ที่จ่าย';
      }
      return null;
    }
    if ((paymentTotal + whtTotal - dueFc).abs() > 0.01) {
      return isEnglish
          ? 'Payments (${fmt.format(paymentTotal)}) + withholding tax (${fmt.format(whtTotal)}) must equal the amount due (${fmt.format(dueFc)})'
          : 'ยอด${purchase ? 'จ่าย' : 'รับชำระ'} (${fmt.format(paymentTotal)}) + ภาษี${purchase ? '' : 'ถูก'}หัก ณ ที่จ่าย (${fmt.format(whtTotal)}) ต้องเท่ากับยอดที่ต้อง${purchase ? 'จ่าย' : 'ชำระ'} (${fmt.format(dueFc)})';
    }
    return null;
  }

  void dispose() {
    clear();
    for (final c in [billToNameCtrl, billToAddressCtrl, billToTaxIdCtrl, billToBranchCtrl, cashReceivedCtrl]) {
      c.dispose();
    }
  }
}

class ImCashSalePanel extends StatefulWidget {
  final ImCashSaleController controller;
  final bool readOnly;
  final bool isEnglish;
  final double dueFc; // ยอดที่ต้องชำระ (ใบแจ้งหนี้รวม VAT − เงินมัดจำที่หัก)
  final double whtBaseFc; // ฐานภาษีเริ่มต้นของรายการภาษีถูกหักใหม่ (ยอดก่อน VAT)
  final String currencyCode;
  final List<CdWhtType> whtTypes;
  final String? customerLabel; // ลูกค้า/ผู้ขายในเอกสาร — ใช้เป็นคำแนะนำของช่องชื่อผู้ซื้อ/ผู้ขาย
  final bool purchase; // ซื้อเงินสด ('14')
  final VoidCallback? onTaxInvoiceKindChanged;
  // ทุกครั้งที่วิธีรับชำระ/ภาษีหัก ณ ที่จ่าย/ยอดเปลี่ยน — ให้หน้าหลักสร้างตัวอย่างรายการบัญชี (ใบเสร็จ) ใหม่
  final VoidCallback? onChanged;

  const ImCashSalePanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.isEnglish,
    required this.dueFc,
    required this.whtBaseFc,
    required this.currencyCode,
    required this.whtTypes,
    this.customerLabel,
    this.purchase = false,
    this.onTaxInvoiceKindChanged,
    this.onChanged,
  });

  @override
  State<ImCashSalePanel> createState() => _ImCashSalePanelState();
}

class _ImCashSalePanelState extends State<ImCashSalePanel> {
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onChanged?.call();
  }

  final _fmt = NumberFormat('#,##0.00');
  static final _numInput = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

  ImCashSaleController get _c => widget.controller;
  bool get _ro => widget.readOnly;
  bool get _en => widget.isEnglish;
  bool get _buy => widget.purchase;

  // สีช่องตามการ์ดข้อมูลเอกสาร: ขาว = กรอกเอง, ฟ้า = ระบบเติมให้ (แก้ได้), เทา = อ่านอย่างเดียว
  static const _fillAuto = Color(0xFFE3EEFA);
  static const _fillRo = Color(0xFFEEF0F2);
  // กรอบสูง 40 เท่ากับการ์ดข้อมูลเอกสาร — ไม่ dense + จำกัดความสูง 40 (ช่องหลายบรรทัดสูงตามเนื้อหา); ห้ามมีตัวนับ/ข้อความใต้ช่อง
  InputDecoration _deco(String label, {String? hint, bool auto = false, bool ro = false, bool multiline = false}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: false,
        constraints: multiline ? null : const BoxConstraints.tightFor(height: 40),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // ระยะน้อย ไม่บีบกล่องข้อความที่ Aa 125% (ข้อความจัดกึ่งกลางอยู่แล้ว)
        border: const OutlineInputBorder(),
        filled: ro || _ro || auto,
        fillColor: ro || _ro ? _fillRo : _fillAuto,
      );

  Widget _field(String label, TextEditingController ctrl,
      {double? width, bool numeric = false, String? hint, int? maxLength, int maxLines = 1, bool auto = false}) {
    final f = TextFormField(
      controller: ctrl,
      readOnly: _ro,
      maxLines: maxLines,
      textAlign: numeric ? TextAlign.right : TextAlign.start,
      inputFormatters: [...?(numeric ? _numInput : null), if (maxLength != null) LengthLimitingTextInputFormatter(maxLength)],
      decoration: _deco(label, hint: hint, auto: auto, multiline: maxLines > 1),
      onChanged: (_) => setState(() {}),
    );
    return width == null ? f : SizedBox(width: width, child: f);
  }

  // ── การ์ดรับชำระ (ตามแบบ Money): หัวการ์ด = ชื่อ + ชิปสถานะ / เนื้อหา 3 กลุ่ม ② ผู้ซื้อ · ③ วิธีรับชำระ (+ภาษีหัก) · ④ สรุปยอด/เงินทอน ──
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);
  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
      );

  Widget _groupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
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

  // กลุ่มฟิลด์แบบเดียวกับการ์ดข้อมูลเอกสาร: แถบสีด้านบน + ชื่อกลุ่ม (+ ปุ่มด้านขวา)
  Widget _group(int no, String title, Color color, List<Widget> rows, {Widget? action, Color background = const Color(0xFFFBFCFD)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: const Color(0xFFDDE3EA)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: _groupLabel(no, title, color)),
                if (action != null) action,
              ]),
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onPressed) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: const Color(0xFF0F5C5C),
          side: const BorderSide(color: Color(0xFF9CC5C5)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );

  Widget _deleteButton(VoidCallback onPressed) => IconButton(
        icon: Icon(Icons.close, size: 18, color: Colors.red.shade700),
        tooltip: _en ? 'Remove' : 'ลบ',
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );

  Widget _roBox(String label, String value, {bool bold = false, Color? color}) => InputDecorator(
        decoration: _deco(label, ro: true),
        child: Text(value,
            textAlign: TextAlign.right,
            style: _numStyle.copyWith(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      );

  // ชิปสถานะที่หัวการ์ด: ครบยอด · เงินทอน / ขาด / เกิน
  Widget? _statusChip() {
    final diff = widget.dueFc - _c.paymentTotal - _c.whtTotal;
    if (widget.dueFc <= 0.005 && _c.payments.isEmpty) {
      return _chip(_buy ? (_en ? 'No payment needed' : 'ไม่ต้องจ่าย') : (_en ? 'No payment needed' : 'ไม่ต้องรับชำระ'),
          const Color(0xFF33404D), const Color(0xFFEEF0F2));
    }
    if (diff > 0.005) {
      return _chip('${_en ? 'Short' : 'ขาด'} ${_fmt.format(diff)}', const Color(0xFF8A4B00), const Color(0xFFFFF0D9));
    }
    if (diff < -0.005) {
      return _chip('${_en ? 'Over' : 'เกิน'} ${_fmt.format(-diff)}', Colors.red.shade800, const Color(0xFFFDECEA));
    }
    final change = _c.change;
    final withChange = !_buy && !_c.receivedWithoutCash && change > 0.005;
    return _chip(
        (_en ? 'Fully paid' : 'ครบยอด') + (withChange ? ' · ${_en ? 'change' : 'เงินทอน'} ${_fmt.format(change)}' : ''),
        const Color(0xFF1E6B3A),
        const Color(0xFFE6F4EA));
  }

  @override
  Widget build(BuildContext context) {
    final linked = [
      if (_c.linkedInvoiceNo != null) _buy ? '${_en ? 'AP invoice' : 'ใบตั้งหนี้'} ${_c.linkedInvoiceNo}' : '${_en ? 'AR invoice' : 'ใบแจ้งหนี้'} ${_c.linkedInvoiceNo}',
      if (_c.linkedReceiptNo != null) _buy ? '${_en ? 'AP payment' : 'ใบจ่ายชำระ'} ${_c.linkedReceiptNo}' : '${_en ? 'Receipt' : 'ใบเสร็จรับเงิน'} ${_c.linkedReceiptNo}',
    ];
    final status = _statusChip();
    final party = _buildParty();
    final pay = _buildPayments();
    final sum = _buildSummary();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_buy ? (_en ? 'Payment' : 'จ่ายชำระ') : (_en ? 'Receipt' : 'รับชำระ'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (_buy) _chip(_taxKindLabel(_c.taxInvoiceKind), const Color(0xFF33404D), const Color(0xFFEEF0F2)),
                for (final s in linked) _chip(s, const Color(0xFF1E4F8F), const Color(0xFFE3EEFA)),
              ]),
              if (status != null) status,
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, cons) {
            if (cons.maxWidth >= 1000) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 10, child: party),
                const SizedBox(width: 10),
                Expanded(flex: 16, child: pay),
                const SizedBox(width: 10),
                Expanded(flex: 9, child: sum),
              ]);
            }
            if (cons.maxWidth >= 700) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 10, child: party),
                  const SizedBox(width: 10),
                  Expanded(flex: 9, child: sum),
                ]),
                const SizedBox(height: 10),
                pay,
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              party,
              const SizedBox(height: 10),
              pay,
              const SizedBox(height: 10),
              sum,
            ]);
          }),
        ]),
      ),
    );
  }

  static const _taxKinds = ['FULL', 'ABB', 'NONE'];
  String _taxKindLabel(String k) => switch (k) {
        'ABB' => _en ? 'Abbreviated tax invoice' : 'ใบกำกับภาษีอย่างย่อ',
        'NONE' => _en ? 'No tax invoice' : 'ไม่มีใบกำกับภาษี',
        _ => _en ? 'Full tax invoice' : 'ใบกำกับภาษีเต็มรูป',
      };

  // ② ผู้ซื้อ (ขาย) / ผู้ขาย (ซื้อ)
  Widget _buildParty() {
    final partyName = _buy ? (_en ? 'Vendor name' : 'ชื่อผู้ขาย') : (_en ? 'Buyer name' : 'ชื่อผู้ซื้อ');
    return _group(
      2,
      _buy
          ? (_en ? 'Vendor (as on the vendor\'s tax invoice / receipt)' : 'ผู้ขาย (ตามใบกำกับภาษี/ใบเสร็จของผู้ขาย)')
          : (_en ? 'Buyer (printed on the tax invoice / receipt)' : 'ผู้ซื้อ (พิมพ์ในใบกำกับ/ใบเสร็จ)'),
      _gParty,
      [
        if (_buy) ...[
          DropdownButtonFormField<String>(
            value: _c.taxInvoiceKind,
            isExpanded: true,
            decoration: _deco(_en ? 'Tax invoice received' : 'เอกสารที่ได้รับจากผู้ขาย', auto: true),
            items: _taxKinds.map((k) => DropdownMenuItem(value: k, child: Text(_taxKindLabel(k)))).toList(),
            onChanged: _ro
                ? null
                : (v) {
                    setState(() => _c.taxInvoiceKind = v ?? 'FULL');
                    widget.onTaxInvoiceKindChanged?.call();
                  },
          ),
          Text(
            _c.taxInvoiceKind == 'FULL'
                ? (_en ? 'Input VAT is claimable — enter the tax invoice number in the reference field above.'
                    : 'ขอคืนภาษีซื้อได้ — กรอกเลขที่ใบกำกับภาษีในช่องเลขที่อ้างอิงด้านบน')
                : (_en ? 'Input VAT is not claimable — VAT is added to the item cost when saved, and is not in the input VAT report.'
                    : 'ขอคืนภาษีซื้อไม่ได้ — ตอนบันทึก VAT จะรวมเข้าต้นทุนสินค้า และไม่ลงรายงานภาษีซื้อ'),
            style: TextStyle(fontSize: 12, color: _c.taxInvoiceKind == 'FULL' ? Colors.grey.shade700 : Colors.orange.shade800),
          ),
        ],
        _field(partyName, _c.billToNameCtrl, auto: _c.billToNameCtrl.text.trim().isEmpty,
            hint: widget.customerLabel != null ? (_en ? 'Blank = ${widget.customerLabel}' : 'ว่าง = ${widget.customerLabel}') : null),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 16, child: _field(_en ? 'Tax ID' : 'เลขประจำตัวผู้เสียภาษี', _c.billToTaxIdCtrl, maxLength: 13)),
          const SizedBox(width: 8),
          Expanded(
              flex: 10,
              child: _field(_en ? 'Branch (5 digits)' : 'สาขา (5 หลัก)', _c.billToBranchCtrl, maxLength: 5,
                  hint: _en ? '00000 = head office' : '00000 = สนญ.')),
        ]),
        _field(_en ? 'Address' : 'ที่อยู่', _c.billToAddressCtrl, maxLines: 2),
        Text(
          _buy
              ? (_en
                  ? 'Blank name = the vendor on the document. With a vendor name, the name, address, tax ID and branch here replace the cash vendor on the AP invoice, payment and input VAT report (blank fields stay blank).'
                  : 'ไม่ระบุชื่อ = ใช้ผู้ขายในเอกสาร ระบุชื่อผู้ขายแล้ว ชื่อ ที่อยู่ เลขผู้เสียภาษี และสาขาในช่องนี้ใช้แทนผู้ขายเงินสดทั้งชุดในใบตั้งหนี้ ใบจ่ายชำระ และรายงานภาษีซื้อ (ช่องที่ว่างจะว่าง)')
              : _en
                  ? 'Blank name = the customer\'s details. With a buyer name, the name, address, tax ID and branch here replace the cash customer on the AR invoice, receipt, print form and output VAT report (blank fields stay blank).'
                  : 'ไม่ระบุชื่อ = ใช้ข้อมูลของลูกค้า ระบุชื่อผู้ซื้อแล้ว ชื่อ ที่อยู่ เลขผู้เสียภาษี และสาขาในช่องนี้ใช้แทนลูกค้าเงินสดทั้งชุดในใบแจ้งหนี้ ใบเสร็จ ฟอร์มพิมพ์ และรายงานภาษีขาย (ช่องที่ว่างจะว่าง)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Future<void> _addPayment() async {
    await CmPaymentMethodListWidget.search(context, onSelected: (pm) {
      final rest = widget.dueFc - _c.paymentTotal - _c.whtTotal;
      setState(() => _c.payments.add(ImCashPaymentRow(
            paymentMethodId: pm.id,
            paymentMethodCode: pm.methodCode,
            paymentMethodName: pm.methodNameTh,
            paymentMethodType: pm.methodType,
            cmBankAccountId: pm.cmBankAccountId,
            glAccountId: pm.glAccountId,
            amount: rest > 0 ? double.parse(rest.toStringAsFixed(2)) : 0,
          )));
    });
  }

  // ③ วิธีรับชำระ/จ่ายเงิน + ภาษีหัก ณ ที่จ่าย
  Widget _buildPayments() {
    final subTitle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700);
    return _group(
      3,
      _buy ? (_en ? 'Payment methods' : 'วิธีจ่ายเงิน') : (_en ? 'Payment methods' : 'วิธีรับชำระเงิน'),
      _gFin,
      action: _ro ? null : _smallButton(_en ? 'Add payment method' : 'เพิ่มวิธีชำระ', _addPayment),
      [
        if (_c.payments.isEmpty)
          Text(
            widget.dueFc <= 0.005
                ? (_buy
                    ? (_en ? 'Deposits cover the whole purchase — no payment needed' : 'เงินมัดจำครอบคลุมยอดซื้อทั้งหมด ไม่ต้องจ่าย')
                    : (_en ? 'Deposits cover the whole sale — no payment needed' : 'เงินมัดจำครอบคลุมยอดขายทั้งหมด ไม่ต้องรับชำระ'))
                : (_buy ? (_en ? 'No payment methods yet' : 'ยังไม่มีวิธีจ่าย') : (_en ? 'No payment methods yet' : 'ยังไม่มีวิธีรับชำระ')),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          )
        else
          for (var i = 0; i < _c.payments.length; i++) _paymentRow(i, _c.payments[i]),
        const Divider(height: 8),
        Row(children: [
          Expanded(
              child: Text(_buy ? (_en ? 'Withholding tax (deducted from the vendor)' : 'ภาษีหัก ณ ที่จ่าย (หักจากผู้ขาย)')
                  : (_en ? 'Withholding tax deducted by the customer' : 'ภาษีที่ลูกค้าหัก ณ ที่จ่าย'),
                  style: subTitle)),
          if (!_ro)
            _smallButton(_en ? 'Add WHT' : 'เพิ่มภาษีหัก',
                () => setState(() => _c.whts.add(ImCashWhtRow(base: double.parse(widget.whtBaseFc.toStringAsFixed(2)))))),
        ]),
        if (_c.whts.isEmpty)
          Text(_en ? 'None' : 'ไม่มี', style: const TextStyle(color: Colors.grey, fontSize: 13))
        else
          for (var i = 0; i < _c.whts.length; i++) _whtRow(i, _c.whts[i], widget.currencyCode),
      ],
    );
  }

  // แถวแรก: วิธีชำระ · จำนวนเงิน · ลบ / แถวสอง: ข้อมูลประกอบตามประเภท (เลขที่อ้างอิง ธนาคาร บัตร หมายเหตุ)
  Widget _paymentRow(int index, ImCashPaymentRow r) {
    final type = r.paymentMethodType;
    final isCheck = type == 'CHECK';
    final isCard = type == 'CREDIT_CARD' || type == 'DEBIT_CARD';
    final needDrawer = isCheck || type == 'TRANSFER' || type == 'MOBILE_BANKING' || type == 'BILL_OF_EXCHANGE';
    final needRef = needDrawer || type == 'QR_CODE' || type == 'OTHER';
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: _deco(cmMethodTypeLabel(type, _en), ro: true),
              child: Text('${r.paymentMethodCode ?? ''} ${r.paymentMethodName ?? ''}'.trim(),
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          _field('${_en ? 'Amount' : 'จำนวนเงิน'} (${widget.currencyCode})', r.amountCtrl, width: 140, numeric: true, auto: true),
          if (!_ro)
            _deleteButton(() => setState(() {
                  r.dispose();
                  _c.payments.removeAt(index);
                }))
          else
            const SizedBox(width: 8),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (needRef)
            _field(
                isCheck
                    ? (_en ? 'Check no.' : 'เลขที่เช็ค')
                    : type == 'BILL_OF_EXCHANGE'
                        ? (_en ? 'Bill no.' : 'เลขที่ตั๋ว')
                        : (_en ? 'Reference no.' : 'เลขที่อ้างอิง'),
                r.refNoCtrl,
                width: 150),
          if (needDrawer) ...[
            _field(_en ? 'Bank' : 'ธนาคาร', r.drawerBankNameCtrl, width: 140),
            _field(_en ? 'Branch' : 'สาขา', r.drawerBankBranchCtrl, width: 110),
            if (isCheck) _field(_en ? 'Drawer account no.' : 'เลขที่บัญชีเจ้าของเช็ค', r.drawerAccountNoCtrl, width: 160),
          ],
          if (isCard) ...[
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: r.cardType,
                isExpanded: true,
                decoration: _deco(_en ? 'Card type' : 'ประเภทบัตร'),
                items: cmCardNetworkOptions.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _ro ? null : (v) => setState(() => r.cardType = v),
              ),
            ),
            _field(_en ? 'Last 4 digits' : '4 หลักท้าย', r.cardLast4Ctrl, width: 100, maxLength: 4),
            _field(_en ? 'Approval code' : 'รหัสอนุมัติ', r.approvalCodeCtrl, width: 120),
          ],
          _field(_en ? 'Remark' : 'หมายเหตุ', r.remarkCtrl, width: 180),
        ]),
      ]),
    );
  }

  // แถวแรก: ประเภทภาษี · ภาษีที่หัก · ลบ / แถวสอง: อัตรา ฐานภาษี เลขที่หนังสือรับรอง คำอธิบาย
  Widget _whtRow(int index, ImCashWhtRow w, String cur) {
    final rate = w.whtType?.whtRate ?? 0;
    String typeLabel(CdWhtType t) => '${t.whtCode} — ${_en && (t.whtNameEn ?? '').isNotEmpty ? t.whtNameEn! : t.whtName}';
    // ประเภทที่บันทึกไว้แต่ปิดใช้งานแล้ว ยังต้องแสดงได้
    final types = [
      ...widget.whtTypes,
      if (w.whtType != null && !widget.whtTypes.any((t) => t.id == w.whtType!.id)) w.whtType!,
    ];
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: w.whtType?.id,
              isExpanded: true,
              decoration: _deco(_en ? 'WHT type' : 'ประเภทภาษี'),
              items: [
                DropdownMenuItem(value: null, child: Text(_en ? '— Select type —' : '— เลือกประเภท —')),
                ...types.map((t) => DropdownMenuItem(value: t.id, child: Text(typeLabel(t), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: _ro
                  ? null
                  : (id) => setState(() {
                        w.whtType = types.cast<CdWhtType?>().firstWhere((t) => t!.id == id, orElse: () => null);
                        w.recalc();
                      }),
            ),
          ),
          const SizedBox(width: 8),
          _field('${_en ? 'WHT' : 'ภาษีที่หัก'} ($cur)', w.whtCtrl, width: 140, numeric: true, auto: true),
          if (!_ro)
            _deleteButton(() => setState(() {
                  w.dispose();
                  _c.whts.removeAt(index);
                }))
          else
            const SizedBox(width: 8),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 80, child: _roBox(_en ? 'Rate' : 'อัตรา', rate > 0 ? '${rate.toStringAsFixed(2)}%' : '-')),
          SizedBox(
            width: 140,
            child: TextFormField(
              controller: w.baseCtrl,
              readOnly: _ro,
              textAlign: TextAlign.right,
              inputFormatters: _numInput,
              decoration: _deco('${_en ? 'Tax base' : 'ฐานภาษี'} ($cur)', auto: true),
              onChanged: (_) => setState(w.recalc),
            ),
          ),
          _field(_en ? 'Certificate no.' : 'เลขที่หนังสือรับรอง', w.certCtrl, width: 150),
          _field(_en ? 'Description' : 'คำอธิบาย', w.descCtrl, width: 180),
        ]),
      ]),
    );
  }

  // ④ สรุปยอด: ยอดที่ต้องชำระ → รับชำระ → ภาษีถูกหัก → ส่วนต่าง / เงินสด: ยอดที่รับเป็นเงินสด → รับเงินมา → เงินทอน
  Widget _buildSummary() {
    final cur = widget.currencyCode;
    final diff = widget.dueFc - _c.paymentTotal - _c.whtTotal;
    final change = _c.change;
    Widget row(String label, double v, {bool line = false, Color? color}) => Container(
          padding: EdgeInsets.only(top: line ? 6 : 3, bottom: 3),
          margin: EdgeInsets.only(top: line ? 2 : 0),
          decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
            Text(_fmt.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.w600, color: color)),
          ]),
        );
    final diffColor = diff.abs() <= 0.005
        ? const Color(0xFF1E6B3A)
        : diff > 0
            ? Colors.orange.shade800
            : Colors.red.shade700;
    return _group(
      4,
      '${_en ? 'Summary' : 'สรุปการรับชำระ'} ($cur)',
      _gMore,
      background: Colors.white,
      [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row(_buy ? (_en ? 'Amount due' : 'ยอดที่ต้องจ่าย') : (_en ? 'Amount due' : 'ยอดที่ต้องชำระ'), widget.dueFc),
          row(_buy ? (_en ? 'Total paid' : 'รวมจ่าย') : (_en ? 'Total received' : 'รวมรับชำระ'), _c.paymentTotal),
          if (_c.whtTotal.abs() > 0.005)
            row(_buy ? (_en ? 'Withholding tax' : 'ภาษีหัก ณ ที่จ่าย') : (_en ? 'WHT deducted' : 'ภาษีถูกหัก ณ ที่จ่าย'), _c.whtTotal),
          row(_en ? 'Difference' : 'ส่วนต่าง', diff, color: diffColor),
          if (!_buy) row(_en ? 'Cash portion' : 'ยอดที่รับเป็นเงินสด', _c.cashTotal, line: true),
        ]),
        if (!_buy) ...[
          _field('${_en ? 'Cash received' : 'รับเงินมา'} ($cur)', _c.cashReceivedCtrl, numeric: true),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1B232C), width: 2))),
            child: Row(children: [
              Expanded(child: Text(_en ? 'Change' : 'เงินทอน', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              Text(
                _c.receivedWithoutCash ? '—' : _fmt.format(change),
                style: _numStyle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: change < -0.005 ? Colors.red.shade700 : const Color(0xFF0F5C5C)),
              ),
            ]),
          ),
          if (_c.receivedWithoutCash)
            Text(_en ? 'No cash payment method — change is not calculated' : 'ไม่มีวิธีรับชำระเป็นเงินสด — ไม่คิดเงินทอน',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700))
          else if (_c.cashReceived > 0 && change < -0.005)
            Text(_en ? 'Cash received is less than the cash portion' : 'รับเงินมาน้อยกว่ายอดที่รับเป็นเงินสด',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
        ],
      ],
    );
  }
}
