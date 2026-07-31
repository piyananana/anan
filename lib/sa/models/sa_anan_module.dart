enum Mode {
  none,
  add,
  addHeader, // for document with header and detail
  addDetail, // for document with header and detail
  addRoot, // for tree views
  addChild, // for tree views
  edit,
  view,
  delete,
}

const Map<String, String> sysModules = {
  '': 'ไม่ระบุ (Unspecified)',
  '01': 'บัญชีแยกประเภท - General Ledger (GL)',
  '11': 'บัญชีลูกหนี้ - Accounts Receivable (AR)',
  '21': 'บัญชีเจ้าหนี้ - Accounts Payable (AP)',
  '31': 'สินค้าคงคลัง - Inventory Management (IM)',
  '81': 'เงินสดและเช็ค - Cash and Check (CQ)',
  '86': 'เงินมัดจำ - Deposit Management (DS)',
  '91': 'ภาษีซื้อ - VAT Purchase (VP)',
  '96': 'ภาษีขาย - VAT Sales (VS)',
};
// '01': 'บัญชีแยกประเภท'
const Map<String, String> glSysDocType = {
  '10': 'ตั้งยอดบัญชียกมา - Opening Balance (OB)',
  '30': 'ใบสำคัญรับ - Receive Voucher (RV)',
  '50': 'ใบสำคัญจ่าย - Payment Voucher (PV)',
  '70': 'ใบสำคัญทั่วไป - Journal Voucher (JV)',
  '80': 'ปรับปรุงบัญชี - Adjusting Entry (ADJ)',
  '90': 'ปิดบัญชี - Closing Entry (CL) ',
};
// '11': 'บัญชีลูกหนี้'
const Map<String, String> arSysDocType = {
  '10': 'ตั้งหนี้ - Billing (BL)',
  '30': 'เพิ่มหนี้ - Debit Note to Customer (DN)',
  '35': 'เพิ่มหนี้ใบแจ้งหนี้ - Debit Note to Customer Billing (DN)',
  '50': 'ลดหนี้ - Credit Note to Customer (CN)',
  '55': 'ลดหนี้ใบแจ้งหนี้ - Credit Note to Customer Billing (CN)',
  '60': 'รับเงินมัดจำ - Deposit (DP)',
  '65': 'คืนเงินมัดจำ - Return Deposit (RDP)',
  '70': 'วางบิล - Bill Collection (BC)',
  '80': 'รับชำระ - Receipt (RC)',
};
// '21': 'บัญชีเจ้าหนี้'
const Map<String, String> apSysDocType = {
  '10': 'ตั้งหนี้ - Billing (BL)',
  '30': 'เพิ่มหนี้ - Debit Note from Supplier (DN)',
  '35': 'เพิ่มหนี้ใบแจ้งหนี้ - Debit Note from Supplier Billing (DN)',
  '50': 'ลดหนี้ - Credit Note from Supplier (CN)',
  '55': 'ลดหนี้ใบแจ้งหนี้ - Credit Note from Supplier Billing (CN)',
  '60': 'จ่ายเงินมัดจำ - Pay Deposit (DP)',
  '65': 'รับคืนเงินมัดจำ - Return Deposit (RDP)',
  '70': 'แจ้งโอนเงิน - Remittance Advice (RA)',
  '80': 'จ่ายชำระ - Payment (PY)',
};
// '31': 'สินค้าคงคลัง'
const Map<String, String> imSysDocType = {
  '10': 'รับสินค้า - Good Receive Note', // buy (stock+ ap+)
  '15': 'คืนสินค้า - Return to Supplier', // return (stock- ap-)
  '20': 'ลดหนี้เจ้าหนี้ -Credit Note from Supplier', // cn (stock- ap-)
  '25': 'เพิ่มหนี้เจ้าหนี้ - Debit Note from Supplier', // dn (stock+ ap+)
  '30': 'ขาย - Sale', // sale (stock- ar+)
  '35': 'รับคืนสินค้า - Return from Customer', // return (stock+ ar-)
  '40': 'ลดหนี้ลูกหนี้ - Credit Note to Customer', // cn (stock+ ar-)
  '45': 'เพิ่มหนี้ลูกหนี้ - Debit Note to Customer', // dn (stock- ar+)
  '60': 'เบิกสินค้า - Issue Stock', // issue (stock-) for project, ...
  '70': 'โอนสินค้า - Transfer in-out', // transfer between location (stock=)
  '80': 'ปรับยอดสินค้า - Adjust quantity', // adjust (stock+-) for Phys.Count, ...
};
// '81': 'เงินสดและเช็ค / Cash & Cheque Management (CM)'
const Map<String, String> cmSysDocType = {
  '10': 'รายรับ - Receipts',
  '20': 'รายจ่าย - Payments',
  '30': 'เติมเงินสดย่อย - Petty Cash Replenishment',
  '40': 'เบิกเงินสดย่อย - Petty Cash Reimbursement',
  '50': 'โอนเงินระหว่างบัญชี - Inter Bank Transfers',
  '70': 'ค่าธรรมเนียมธนาคาร - Bank Charges',
  '90': 'ดอกเบี้ย - Interest',
};
// '86': 'เงินมัดจำ'
const Map<String, String> dsSysDocType = {
  '': 'ไม่ระบุ',
};
// '91': 'ภาษีซื้อ'
const Map<String, String> vpSysDocType = {
  '': 'ไม่ระบุ',
};
// '96': 'ภาษีขาย'
const Map<String, String> vsSysDocType = {
  '': 'ไม่ระบุ',
};

// const Map<int, String> periodNameThai = {
//   1: 'มกราคม',
//   2: 'กุมภาพันธ์',
//   3: 'มีนาคม',
//   4: 'เมษายน',
//   5: 'พฤษภาคม',
//   6: 'มิถุนายน',
//   7: 'กรกฎาคม',
//   8: 'สิงหาคม',
//   9: 'กันยายน',
//   10: 'ตุลาคม',
//   11: 'พฤศจิกายน',
//   12: 'ธันวาคม',
// };

// const Map<int, String> periodNameEng = {
//   1: 'January',
//   2: 'February',
//   3: 'March',
//   4: 'April',
//   5: 'May',
//   6: 'June',
//   7: 'July',
//   8: 'August',
//   9: 'September',
//   10: 'October',
//   11: 'November',
//   12: 'December',
// };

// const Map<int, String> periodShortNameThai = {
//   1: 'ม.ค.',
//   2: 'ก.พ.',
//   3: 'มี.ค.',
//   4: 'เม.ย.',
//   5: 'พ.ค.',
//   6: 'มิ.ย.',
//   7: 'ก.ค.',
//   8: 'ส.ค.',
//   9: 'ก.ย.',
//   10: 'ต.ค.',
//   11: 'พ.ย.',
//   12: 'ธ.ค.',
// };

// const Map<int, String> periodShortNameEng = {
//   1: 'Jan',
//   2: 'Feb',
//   3: 'Mar',
//   4: 'Apr',
//   5: 'May',
//   6: 'Jun',
//   7: 'Jul',
//   8: 'Aug',
//   9: 'Sep',
//   10: 'Oct',
//   11: 'Nov',
//   12: 'Dec',
// };
