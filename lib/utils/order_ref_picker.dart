// ใบมัดจำ (AR/AP 60) อ้างอิงใบสั่งขาย/ใบสั่งซื้อ — dialog เลือกใบสั่งของลูกค้า/ผู้ขายที่เลือก (user-approved 2026-10-31)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'date_utils.dart';

class OrderRef {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status;
  final double totalAmountLc;
  const OrderRef({required this.id, required this.docNo, required this.docDate, required this.status, this.totalAmountLc = 0});
}

// สถานะที่อ้างอิงไม่ได้ — ตรงกับ CLOSED_ORDER_STATUSES ใน backend utils/depositRef.js
const closedOrderStatuses = {'Void', 'Deleted', 'Closed', 'Rejected'};

Future<OrderRef?> showOrderRefPicker(BuildContext context, {required String title, required Future<List<OrderRef>> Function() load,
    required bool isEnglish}) {
  final dateFmt = DateFormat('dd/MM/yyyy');
  final fmt = NumberFormat('#,##0.00');
  return showDialog<OrderRef>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        height: 400,
        child: FutureBuilder<List<OrderRef>>(
          future: load(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text('${isEnglish ? 'Error' : 'เกิดข้อผิดพลาด'}: ${snap.error}'));
            final rows = (snap.data ?? []).where((o) => !closedOrderStatuses.contains(o.status)).toList();
            if (rows.isEmpty) return Center(child: Text(isEnglish ? 'No open orders' : 'ไม่มีใบสั่งที่อ้างอิงได้'));
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = rows[i];
                return ListTile(
                  dense: true,
                  title: Text(o.docNo),
                  subtitle: Text('${dateFmt.format(o.docDate)}  ·  ${o.status}'),
                  trailing: Text(fmt.format(o.totalAmountLc)),
                  onTap: () => Navigator.pop(ctx, o),
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
    ),
  );
}

// ช่องแสดง/เลือกใบสั่งที่อ้างอิงในหัวเอกสารใบมัดจำ
class OrderRefField extends StatelessWidget {
  final String? docNo;
  final bool readOnly;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final InputDecoration decoration;
  const OrderRefField({super.key, required this.docNo, required this.readOnly, required this.onPick,
      required this.onClear, required this.decoration});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: readOnly ? null : onPick,
      child: InputDecorator(
        decoration: decoration,
        child: Row(children: [
          Expanded(child: Text(docNo ?? '-')),
          if (!readOnly && docNo != null) InkWell(onTap: onClear, child: const Icon(Icons.clear, size: 14)),
          if (!readOnly) const Icon(Icons.search, size: 14),
        ]),
      ),
    );
  }
}

// ใบมัดจำที่อ้างอิงใบสั่งขาย/ใบสั่งซื้อ (deposits ใน fetchRow ของ SO/PO — backend utils/depositRef.js fetchOrderDeposits)
class OrderDeposit {
  final int id;
  final String docNo;
  final DateTime? docDate;
  final String status;
  final double totalAmountLc;
  final double balanceAmountLc;
  const OrderDeposit({required this.id, required this.docNo, this.docDate, this.status = '', this.totalAmountLc = 0, this.balanceAmountLc = 0});

  factory OrderDeposit.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return OrderDeposit(
      id: j['id'] ?? 0,
      docNo: j['doc_no'] ?? '',
      docDate: parseLocalDateNullable(j['doc_date']),
      status: j['status'] ?? '',
      totalAmountLc: d(j['total_amount_lc']),
      balanceAmountLc: d(j['balance_amount_lc']),
    );
  }
  static List<OrderDeposit> listFromJson(dynamic v) =>
      v is List ? v.map((e) => OrderDeposit.fromJson(Map<String, dynamic>.from(e))).toList() : const [];
}

// ใบมัดจำที่ยังมียอดคงเหลือ (ใบที่ Post แล้ว) — ใช้เตือนตอนปิดใบสั่ง
List<OrderDeposit> openOrderDeposits(List<OrderDeposit> deposits) =>
    deposits.where((d) => d.status == 'Posted' && d.balanceAmountLc > 0.005).toList();

// ข้อความต่อท้ายคำยืนยันปิดใบสั่ง เมื่อยังมีมัดจำคงเหลือ
String orderDepositCloseNote(List<OrderDeposit> deposits, bool isEnglish) {
  final open = openOrderDeposits(deposits);
  if (open.isEmpty) return '';
  final fmt = NumberFormat('#,##0.00');
  final list = open.map((d) => '${d.docNo} ${fmt.format(d.balanceAmountLc)}').join(', ');
  return isEnglish
      ? '\n\nWarning: deposits referencing this order still have a balance ($list) — refund or deduct them separately.'
      : '\n\nคำเตือน: ใบมัดจำที่อ้างอิงใบสั่งนี้ยังมียอดคงเหลือ ($list) — ต้องคืนเงินหรือหักกับเอกสารอื่นเอง';
}

// แผงแสดงใบมัดจำที่อ้างอิงใบสั่ง (หน้าจอ SO/PO)
class OrderDepositPanel extends StatelessWidget {
  final List<OrderDeposit> deposits;
  final bool isEnglish;
  final String baseCurrencyCode;
  const OrderDepositPanel({super.key, required this.deposits, required this.isEnglish, required this.baseCurrencyCode});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final fmt = NumberFormat('#,##0.00');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEnglish ? 'Deposits referencing this order' : 'ใบมัดจำที่อ้างอิงใบสั่งนี้',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          for (final d in deposits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(flex: 2, child: Text(d.docNo, style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(d.docDate != null ? dateFmt.format(d.docDate!) : '', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(d.status, style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 3,
                  child: Text('${isEnglish ? 'Total' : 'ยอด'} ${fmt.format(d.totalAmountLc)} $baseCurrencyCode',
                      textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('${isEnglish ? 'Balance' : 'คงเหลือ'} ${fmt.format(d.balanceAmountLc)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: d.balanceAmountLc > 0.005 ? Colors.orange[800] : Colors.grey[700])),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
