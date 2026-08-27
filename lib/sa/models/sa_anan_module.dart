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
  '81': 'เงินสดและเช็ค - Cash & Cheque Management(CM)',
  // '86': 'เงินมัดจำ - Deposit Management (DS)',
  // '91': 'ภาษีซื้อ - VAT Purchase (VP)',
  // '96': 'ภาษีขาย - VAT Sales (VS)',
};
// '01': 'บัญชีแยกประเภท'
const Map<String, String> glSysDocType = {
  '10': 'ตั้งยอดบัญชียกมา - Opening Balance',
  '20': 'ใบสำคัญรับ - Receive Voucher',
  '30': 'ใบสำคัญจ่าย - Payment Voucher',
  '40': 'ใบสำคัญทั่วไป - Journal Voucher',
  '50': 'ปรับปรุงบัญชี - Adjusting Entry',
  '60': 'ยกเลิกบัญชี - Reversing Entry',
  '70': 'ปิดบัญชี - Closing Entry',
  '81': 'ลูกหนี้ - AR Posting',
  '82': 'เจ้าหนี้ - AP Posting',
  '83': 'เงินสด - CM Posting',
  '84': 'สินค้าคงคลัง - IM Posting',
};
// '11': 'บัญชีลูกหนี้'
const Map<String, String> arSysDocType = {
  '10': 'ตั้งหนี้ - Billing', // sale (+ar +income)
  '30': 'เพิ่มหนี้ - Debit Note to Customer', // dn (+ar +income)
  '35': 'เพิ่มหนี้ใบแจ้งหนี้ - Debit Note to Customer Billing',  // dn (+ar +income)
  '50': 'ลดหนี้ - Credit Note to Customer', // cn (-ar -income)
  '55': 'ลดหนี้ใบแจ้งหนี้ - Credit Note to Customer Billing',  // cn (-ar -income)
  '60': 'รับเงินมัดจำ - Deposit', // deposit (+cash +deposit)
  '65': 'คืนเงินมัดจำ - Return Deposit',  // return deposit (-cash -deposit)
  '70': 'วางบิล - Bill Collection',  // bill collection (no GL)
  '80': 'รับชำระ - Receipt',  // receipt (+cash -ar)
};
// '21': 'บัญชีเจ้าหนี้'
const Map<String, String> apSysDocType = {
  '10': 'ตั้งหนี้ - Billing', // buy (+ap +expense)
  '30': 'เพิ่มหนี้ - Debit Note from Supplier', // dn (+ap +expense)
  '35': 'เพิ่มหนี้ใบแจ้งหนี้ - Debit Note from Supplier Billing',  // dn (+ap +expense)
  '50': 'ลดหนี้ - Credit Note from Supplier', // cn (-ap -expense)
  '55': 'ลดหนี้ใบแจ้งหนี้ - Credit Note from Supplier Billing',  // cn (-ap -expense)
  '60': 'จ่ายเงินมัดจำ - Pay Deposit',  // pay deposit (-cash +deposit)
  '65': 'รับคืนเงินมัดจำ - Return Deposit',  // return deposit (+cash -deposit)
  '70': 'แจ้งชำระ - Remittance Advice', // remittance advice (no GL)
  '80': 'จ่ายชำระ - Payment', // pay (-cash -ap)
};
// '31': 'สินค้าคงคลัง'
const Map<String, String> imSysDocType = {
  '10': 'รับสินค้า - Good Receive Note', // receive(buy) (+stock +ap)
  '11': 'รับสินค้าใบแจ้งหนี้ - Good Receive Note Billing', // receive(buy) (+stock +ap)
  '12': 'รับสินค้า (รอตั้งหนี้) - GR Pending AP Billing', // receive(buy) (+stock only) ตั้งหนี้+GL ทีหลังเมื่อได้ invoice
  '15': 'คืนสินค้า - Return to Supplier', // return (-stock -ap)
  '20': 'ลดหนี้เจ้าหนี้ - Credit Note from Supplier', // cn (-stock -ap)
  '25': 'เพิ่มหนี้เจ้าหนี้ - Debit Note from Supplier', // dn (+stock +ap)
  '30': 'ส่งสินค้า - Delivery Note', // delivery(sale) (-stock +ar)
  '31': 'ส่งสินค้าใบแจ้งหนี้ - Delivery Note Billing', // delivery(sale) (-stock +ar)
  '35': 'รับคืนสินค้า - Return from Customer', // return (+stock -ar)
  '40': 'ลดหนี้ลูกหนี้ - Credit Note to Customer', // cn (+stock -ar)
  '45': 'เพิ่มหนี้ลูกหนี้ - Debit Note to Customer', // dn (-stock +ar)
  '60': 'เบิกสินค้า - Issue Stock', // issue (-stock) for project, ...
  '70': 'โอนสินค้า - Transfer in-out', // transfer between location (=stock)
  '80': 'ปรับยอดสินค้า - Adjust quantity', // adjust (+-stock) for Phys.Count, ...
};
// '81': 'เงินสดและเช็ค / Cash & Cheque Management (CM)'
const Map<String, String> cmSysDocType = {
  '10': 'รายรับ - Receipts',
  '15': 'รายรับจาก AR - Receipt from AR', // mirrors cm_receipt (created by AR posting) — read-only
  '20': 'รายจ่าย - Payments',
  '25': 'รายจ่ายจาก AP - Payment from AP', // mirrors cm_payment (created by AP posting) — read-only
  '30': 'เติมเงินสดย่อย - Petty Cash Replenishment',
  '40': 'เบิกเงินสดย่อย - Petty Cash Reimbursement',
  '50': 'โอนเงินระหว่างบัญชี - Inter Bank Transfers',
  '70': 'ค่าธรรมเนียมธนาคาร - Bank Charges',
  '90': 'ดอกเบี้ย - Interest',
};
// // '86': 'เงินมัดจำ'
// const Map<String, String> dsSysDocType = {
//   '': 'ไม่ระบุ',
// };
// // '91': 'ภาษีซื้อ'
// const Map<String, String> vpSysDocType = {
//   '': 'ไม่ระบุ',
// };
// // '96': 'ภาษีขาย'
// const Map<String, String> vsSysDocType = {
//   '': 'ไม่ระบุ',
// };

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
