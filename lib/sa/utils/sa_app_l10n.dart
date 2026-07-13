import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/sa_language_provider.dart';

/// Central localization helper for all in-screen UI strings.
///
/// Usage in build():
///   final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
///   Text(l.save), Text(l.cancel), Text(l.status), …
///
/// Usage in callbacks / showDialog builders (no rebuild needed):
///   final l = AppL10n(context.read<LanguageProvider>().isEnglish);
class AppL10n {
  final bool isEnglish;
  const AppL10n(this.isEnglish);

  // ── Action buttons ────────────────────────────────────────────────────────
  String get save          => isEnglish ? 'Save'            : 'บันทึก';
  String get cancel        => isEnglish ? 'Cancel'          : 'ยกเลิก';
  String get delete        => isEnglish ? 'Delete'          : 'ลบ';
  String get edit          => isEnglish ? 'Edit'            : 'แก้ไข';
  String get add           => isEnglish ? 'Add'             : 'เพิ่ม';
  String get search        => isEnglish ? 'Search'          : 'ค้นหา';
  String get clear         => isEnglish ? 'Clear'           : 'ล้าง';
  String get close         => isEnglish ? 'Close'           : 'ปิด';
  String get confirm       => isEnglish ? 'Confirm'         : 'ยืนยัน';
  String get approve       => isEnglish ? 'Approve'         : 'อนุมัติ';
  // ignore: non_constant_identifier_names
  String get print_        => isEnglish ? 'Print'           : 'พิมพ์';
  String get export_       => isEnglish ? 'Export'          : 'ส่งออก';
  String get import_       => isEnglish ? 'Import'          : 'นำเข้า';
  String get post          => isEnglish ? 'Post'            : 'ผ่านรายการ';
  String get voidTx        => isEnglish ? 'Void'            : 'ยกเลิกรายการ';
  String get refresh       => isEnglish ? 'Refresh'         : 'รีเฟรช';
  String get preview       => isEnglish ? 'Preview'         : 'ตัวอย่าง';
  String get copy          => isEnglish ? 'Copy'            : 'คัดลอก';
  String get yes           => isEnglish ? 'Yes'             : 'ใช่';
  String get no            => isEnglish ? 'No'              : 'ไม่';
  String get ok            => isEnglish ? 'OK'              : 'ตกลง';
  String get select        => isEnglish ? 'Select'          : 'เลือก';
  String get back          => isEnglish ? 'Back'            : 'ย้อนกลับ';
  String get reset         => isEnglish ? 'Reset'           : 'รีเซ็ต';
  String get run           => isEnglish ? 'Run'             : 'ประมวลผล';
  String get generate      => isEnglish ? 'Generate'        : 'สร้าง';
  String get upload        => isEnglish ? 'Upload'          : 'อัปโหลด';
  String get download      => isEnglish ? 'Download'        : 'ดาวน์โหลด';

  // ── Common field labels ───────────────────────────────────────────────────
  String get code          => isEnglish ? 'Code'            : 'รหัส';
  String get name          => isEnglish ? 'Name'            : 'ชื่อ';
  String get nameTh        => isEnglish ? 'Name (TH)'       : 'ชื่อภาษาไทย';
  String get nameEn        => isEnglish ? 'Name (EN)'       : 'ชื่อภาษาอังกฤษ';
  String get date          => isEnglish ? 'Date'            : 'วันที่';
  String get fromDate      => isEnglish ? 'From'            : 'ตั้งแต่วันที่';
  String get toDate        => isEnglish ? 'To'              : 'ถึงวันที่';
  String get amount        => isEnglish ? 'Amount'          : 'จำนวนเงิน';
  String get status        => isEnglish ? 'Status'          : 'สถานะ';
  String get note          => isEnglish ? 'Note'            : 'หมายเหตุ';
  String get remark        => isEnglish ? 'Remark'          : 'หมายเหตุ';
  String get reference     => isEnglish ? 'Reference'       : 'อ้างอิง';
  String get currency      => isEnglish ? 'Currency'        : 'สกุลเงิน';
  String get description   => isEnglish ? 'Description'     : 'คำอธิบาย';
  String get type          => isEnglish ? 'Type'            : 'ประเภท';
  String get group         => isEnglish ? 'Group'           : 'กลุ่ม';
  String get total         => isEnglish ? 'Total'           : 'รวม';
  String get docNo         => isEnglish ? 'Doc No.'         : 'เลขที่เอกสาร';
  String get branch        => isEnglish ? 'Branch'          : 'สาขา';
  String get project       => isEnglish ? 'Project'         : 'โปรเจกต์';
  String get rate          => isEnglish ? 'Rate'            : 'อัตรา';
  String get account       => isEnglish ? 'Account'         : 'บัญชี';
  String get period        => isEnglish ? 'Period'          : 'งวด';
  String get year          => isEnglish ? 'Year'            : 'ปี';
  String get month         => isEnglish ? 'Month'           : 'เดือน';
  String get number        => isEnglish ? 'No.'             : 'ลำดับ';
  String get details       => isEnglish ? 'Details'         : 'รายละเอียด';
  String get address       => isEnglish ? 'Address'         : 'ที่อยู่';
  String get phone         => isEnglish ? 'Phone'           : 'โทรศัพท์';
  String get email         => isEnglish ? 'Email'           : 'อีเมล';
  String get taxId         => isEnglish ? 'Tax ID'          : 'เลขประจำตัวผู้เสียภาษี';
  String get contactPerson => isEnglish ? 'Contact'         : 'ผู้ติดต่อ';
  String get creditLimit   => isEnglish ? 'Credit Limit'    : 'วงเงินเครดิต';
  String get creditDays    => isEnglish ? 'Credit Days'     : 'เครดิตเทอม (วัน)';
  String get debit         => isEnglish ? 'Debit'           : 'เดบิต';
  String get credit        => isEnglish ? 'Credit'          : 'เครดิต';
  String get balance       => isEnglish ? 'Balance'         : 'ยอดคงเหลือ';
  String get exchangeRate  => isEnglish ? 'Exchange Rate'   : 'อัตราแลกเปลี่ยน';
  String get vatRate       => isEnglish ? 'VAT Rate'        : 'อัตราภาษีมูลค่าเพิ่ม';
  String get discountRate  => isEnglish ? 'Discount %'      : 'ส่วนลด %';
  String get quantity      => isEnglish ? 'Qty'             : 'จำนวน';
  String get unitPrice     => isEnglish ? 'Unit Price'      : 'ราคาต่อหน่วย';

  // ── Status values ─────────────────────────────────────────────────────────
  String get all           => isEnglish ? 'All'             : 'ทั้งหมด';
  String get draft         => isEnglish ? 'Draft'           : 'ฉบับร่าง';
  String get posted        => isEnglish ? 'Posted'          : 'บันทึก';
  String get voided        => isEnglish ? 'Void'            : 'ยกเลิก';
  String get active        => isEnglish ? 'Active'          : 'ใช้งาน';
  String get inactive      => isEnglish ? 'Inactive'        : 'ไม่ใช้งาน';
  String get pending       => isEnglish ? 'Pending'         : 'รอดำเนินการ';
  String get approved      => isEnglish ? 'Approved'        : 'อนุมัติแล้ว';
  String get paid          => isEnglish ? 'Paid'            : 'ชำระแล้ว';
  String get unpaid        => isEnglish ? 'Unpaid'          : 'ยังไม่ชำระ';
  String get partial       => isEnglish ? 'Partial'         : 'ชำระบางส่วน';
  String get open          => isEnglish ? 'Open'            : 'เปิด';
  String get closed        => isEnglish ? 'Closed'          : 'ปิด';
  String get reconciled    => isEnglish ? 'Reconciled'      : 'กระทบยอดแล้ว';
  String get unreconciled  => isEnglish ? 'Unreconciled'    : 'ยังไม่กระทบยอด';

  // ── Common messages ───────────────────────────────────────────────────────
  String get confirmDelete  => isEnglish ? 'Confirm Delete'           : 'ยืนยันการลบ';
  String get confirmVoid    => isEnglish ? 'Confirm Void'             : 'ยืนยันการยกเลิก';
  String get confirmPost    => isEnglish ? 'Confirm Post'             : 'ยืนยันการผ่านรายการ';
  String get confirmApprove => isEnglish ? 'Confirm Approve'          : 'ยืนยันการอนุมัติ';
  String get noData         => isEnglish ? 'No data'                  : 'ไม่มีข้อมูล';
  String get loading        => isEnglish ? 'Loading...'               : 'กำลังโหลด...';
  String get pleaseSelect   => isEnglish ? 'Please select'            : 'กรุณาเลือก';
  String get required_      => isEnglish ? 'Required'                 : 'จำเป็น';
  String get errorOccurred  => isEnglish ? 'An error occurred'        : 'เกิดข้อผิดพลาด';
  String get savedSuccess   => isEnglish ? 'Saved successfully'       : 'บันทึกสำเร็จ';
  String get deletedSuccess => isEnglish ? 'Deleted successfully'     : 'ลบสำเร็จ';
  String get areYouSure     => isEnglish ? 'Are you sure?'            : 'คุณแน่ใจหรือไม่?';
  String get changesSaved   => isEnglish ? 'Changes saved'            : 'บันทึกการเปลี่ยนแปลงแล้ว';

  // ── Module-specific: GL ───────────────────────────────────────────────────
  String get glEntry        => isEnglish ? 'Journal Entry'            : 'รายการบัญชี';
  String get chartOfAccounts => isEnglish ? 'Chart of Accounts'       : 'ผังบัญชี';
  String get fiscalYear     => isEnglish ? 'Fiscal Year'              : 'ปีบัญชี';
  String get openingBalance => isEnglish ? 'Opening Balance'          : 'ยอดยกมา';
  String get closingBalance => isEnglish ? 'Closing Balance'          : 'ยอดยกไป';

  // ── Module-specific: AR ───────────────────────────────────────────────────
  String get customer       => isEnglish ? 'Customer'                 : 'ลูกหนี้';
  String get invoice        => isEnglish ? 'Invoice'                  : 'ใบแจ้งหนี้';
  String get receipt        => isEnglish ? 'Receipt'                  : 'ใบรับเงิน';
  String get aging          => isEnglish ? 'Aging'                    : 'การวิเคราะห์อายุหนี้';
  String get dueDate        => isEnglish ? 'Due Date'                 : 'วันครบกำหนด';

  // ── Module-specific: AP ───────────────────────────────────────────────────
  String get vendor         => isEnglish ? 'Vendor'                   : 'เจ้าหนี้';
  String get bill           => isEnglish ? 'Bill'                     : 'ใบวางบิล';
  String get payment        => isEnglish ? 'Payment'                  : 'การชำระเงิน';
  String get wht            => isEnglish ? 'WHT'                      : 'ภาษีหัก ณ ที่จ่าย';

  // ── Module-specific: CM ───────────────────────────────────────────────────
  String get bankAccount    => isEnglish ? 'Bank Account'             : 'บัญชีธนาคาร';
  String get bankStatement  => isEnglish ? 'Bank Statement'           : 'ใบแจ้งยอดธนาคาร';
  String get pettyCash      => isEnglish ? 'Petty Cash'               : 'เงินสดย่อย';
  String get reconcile      => isEnglish ? 'Reconcile'                : 'กระทบยอด';
  String get checkNo        => isEnglish ? 'Check No.'                : 'เลขที่เช็ค';
}

/// Convenience extension — uses [Provider.watch] so widget rebuilds on change.
/// Call only inside [build()].
extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n(watch<LanguageProvider>().isEnglish);
}
