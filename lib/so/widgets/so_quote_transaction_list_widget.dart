import 'package:flutter/material.dart';
import '../models/so_quote_transaction.dart';
import '../services/so_quote_transaction_service.dart';
import '../../sa/widgets/sa_order_doc_list.dart';

// หน้ารายการ — แบบเดียวกับหน้ารายการ IM: ใช้ OrderDocListWidget (sa_order_doc_list.dart) ร่วมกับ SO/PO/ใบเสนอราคา/PR
class QuoteTransactionListWidget extends StatelessWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const QuoteTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  static final _service = QuoteTransactionService();

  static final _config = OrderDocListConfig(
    prefKey: 'quote_list_filter_collapsed',
    statuses: const ['Draft', 'Submitted', 'Approved', 'Rejected', 'PartiallyConverted', 'FullyConverted', 'Closed', 'Void', 'Deleted'],
    statusLabel: quoteTransactionStatusLabel,
    partyLabel: (en) => en ? 'Customer' : 'ลูกค้า',
    docNoLabel: (en) => en ? 'Quote No. / Warehouse' : 'เลขที่ใบเสนอราคา / คลัง',
    dueLabel: (en) => en ? 'Valid Until' : 'ยืนราคาถึง',
    personLabel: (en) => en ? 'Preparer' : 'ผู้จัดทำ',
    valueLabel: (en) => en ? 'Quoted Value' : 'มูลค่าเสนอราคา',
    searchTooltip: (en) => en ? 'Doc no. / preparer / customer / description' : 'เลขที่ / ผู้จัดทำ / ลูกค้า / คำอธิบาย',
  );

  static OrderDocRow _row(QuoteTransactionHeader r) => OrderDocRow(
        id: r.id,
        docNo: r.docNo,
        docDate: r.docDate,
        status: r.status,
        partyCode: r.customerCode,
        partyNameTh: r.customerNameTh,
        partyNameEn: r.customerNameEn,
        warehouseCode: r.warehouseCode,
        warehouseNameTh: r.warehouseNameTh,
        warehouseNameEn: r.warehouseNameEn,
        dueDate: r.validUntilDate,
        person: r.preparedByName,
        totalQty: r.totalQty,
        valueLc: r.totalValueLc,
        totalLc: r.totalAmountLc,
        description: r.description,
      );

  @override
  Widget build(BuildContext context) => OrderDocListWidget(
        config: _config,
        fetch: ({required dateFrom, required dateTo, required includeDeleted}) async =>
            (await _service.fetchRows(dateFrom: dateFrom, dateTo: dateTo, includeDeleted: includeDeleted)).map(_row).toList(),
        onEditPressed: onEditPressed,
        onViewPressed: onViewPressed,
        shouldRefresh: shouldRefresh,
        onRefreshComplete: onRefreshComplete,
        enableEditButton: enableEditButton,
      );
}
