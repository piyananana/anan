// lib/im/utils/im_print_form_templates.dart — โครงแบบฟอร์มเริ่มต้นเมื่อสร้างฟอร์มใหม่ (ผู้ใช้ปรับต่อในหน้าจอออกแบบ)
import '../models/im_print_form.dart';

// ── โครงตัวอย่างใบส่งสินค้า/ใบกำกับภาษี (A4) ───────────────────────────────
List<PrintElement> starterSalesInvoiceLayout(String Function() newId) {
  PrintElement fld(String key, double x, double y, double w, double h,
          {double fs = 14, bool bold = false, String align = 'L', int maxLines = 1, String fmt = '', String prefix = '', String pages = 'all'}) =>
      PrintElement(
          id: newId(), type: 'field', field: key, x: x, y: y, w: w, h: h, fontSize: fs, bold: bold, align: align,
          maxLines: maxLines, fmt: fmt, prefix: prefix, pages: pages);
  PrintElement txt(String text, double x, double y, double w, double h,
          {double fs = 14, bool bold = false, String align = 'L', int maxLines = 1, String pages = 'all'}) =>
      PrintElement(
          id: newId(), type: 'text', text: text, x: x, y: y, w: w, h: h, fontSize: fs, bold: bold, align: align, maxLines: maxLines, pages: pages);
  PrintElement box(double x, double y, double w, double h, {String pages = 'all'}) =>
      PrintElement(id: newId(), type: 'rect', x: x, y: y, w: w, h: h, strokeWidth: 0.7, pages: pages);
  PrintElement line(double x, double y, double w) => PrintElement(id: newId(), type: 'line', x: x, y: y, w: w, h: 0, pages: 'last');
  return [
    PrintElement(id: newId(), type: 'image', field: 'company_logo', x: 10, y: 10, w: 25, h: 22),
    fld('company_name', 38, 10, 100, 8, fs: 18, bold: true),
    fld('company_address', 38, 18, 100, 11, fs: 13, maxLines: 2),
    txt('เลขประจำตัวผู้เสียภาษี {company_tax_id}  {branch_name}', 38, 29, 100, 6, fs: 13),
    txt('ใบส่งสินค้า/ใบกำกับภาษี', 130, 10, 70, 9, fs: 20, bold: true, align: 'R'),
    fld('copy_name', 130, 19, 70, 7, fs: 16, bold: true, align: 'R'),
    fld('reprint_label', 130, 26, 70, 6, fs: 13, align: 'R'),
    box(10, 37, 120, 33),
    txt('ลูกค้า', 12, 38, 18, 6, bold: true),
    fld('customer_name', 30, 38, 98, 6, bold: true),
    fld('customer_address', 30, 44, 98, 12, maxLines: 2),
    txt('เลขประจำตัวผู้เสียภาษี {customer_tax_id_branch}', 12, 57, 116, 6),
    txt('รหัสลูกค้า {customer_code}', 12, 63, 116, 6),
    box(132, 37, 68, 33),
    txt('เลขที่', 134, 38, 22, 6, bold: true),
    fld('doc_no', 156, 38, 42, 6),
    txt('วันที่', 134, 44, 22, 6, bold: true),
    fld('doc_date', 156, 44, 42, 6, fmt: 'dmy_be'),
    txt('ครบกำหนด', 134, 50, 22, 6, bold: true),
    fld('due_date', 156, 50, 42, 6, fmt: 'dmy_be'),
    txt('เงื่อนไข', 134, 56, 22, 6, bold: true),
    fld('credit_term', 156, 56, 42, 6),
    txt('พนักงานขาย', 134, 62, 22, 6, bold: true),
    fld('salespersons', 156, 62, 42, 6),
    PrintElement(
      id: newId(),
      type: 'table',
      x: 10,
      y: 73,
      w: 190,
      h: 140,
      fontSize: 14,
      rowHeight: 7,
      headerHeight: 8,
      border: 'box',
      strokeWidth: 0.7,
      columns: [
        PrintColumn(field: 'line_no', title: 'ลำดับ', w: 12, align: 'C'),
        PrintColumn(field: 'item_code', title: 'รหัสสินค้า', w: 28),
        PrintColumn(field: 'item_desc', title: 'รายการ', w: 70),
        PrintColumn(field: 'qty', title: 'จำนวน', w: 18, align: 'R'),
        PrintColumn(field: 'unit', title: 'หน่วย', w: 14, align: 'C'),
        PrintColumn(field: 'unit_price', title: 'ราคา/หน่วย', w: 22, align: 'R'),
        PrintColumn(field: 'amount', title: 'จำนวนเงิน', w: 26, align: 'R'),
      ],
    ),
    box(10, 215, 120, 24, pages: 'last'),
    txt('จำนวนเงิน (ตัวอักษร)', 12, 216, 116, 6, bold: true, pages: 'last'),
    txt('({amount_text})', 12, 225, 116, 7, fs: 15, bold: true, align: 'C', pages: 'last'),
    box(132, 215, 68, 24, pages: 'last'),
    txt('รวมเงิน', 134, 216, 36, 6, pages: 'last'),
    fld('subtotal', 170, 216, 28, 6, align: 'R', pages: 'last'),
    txt('ส่วนลด', 134, 222, 36, 6, pages: 'last'),
    fld('discount_amount', 170, 222, 28, 6, align: 'R', pages: 'last'),
    txt('ภาษีมูลค่าเพิ่ม {vat_rate}%', 134, 228, 36, 6, pages: 'last'),
    fld('vat_amount', 170, 228, 28, 6, align: 'R', pages: 'last'),
    txt('รวมทั้งสิ้น', 134, 234, 36, 6, bold: true, pages: 'last'),
    fld('total_amount', 170, 234, 28, 6, bold: true, align: 'R', pages: 'last'),
    fld('description', 10, 241, 190, 6, prefix: 'หมายเหตุ: ', pages: 'last'),
    line(15, 268, 50),
    txt('ผู้รับสินค้า', 15, 269, 50, 6, align: 'C', pages: 'last'),
    txt('วันที่ ______/______/______', 15, 275, 50, 6, align: 'C', pages: 'last'),
    line(80, 268, 50),
    txt('ผู้ส่งสินค้า', 80, 269, 50, 6, align: 'C', pages: 'last'),
    txt('วันที่ ______/______/______', 80, 275, 50, 6, align: 'C', pages: 'last'),
    line(145, 268, 50),
    txt('ผู้มีอำนาจลงนาม', 145, 269, 50, 6, align: 'C', pages: 'last'),
    txt('วันที่ ______/______/______', 145, 275, 50, 6, align: 'C', pages: 'last'),
    fld('page_label', 150, 287, 50, 6, fs: 12, align: 'R'),
  ];
}
