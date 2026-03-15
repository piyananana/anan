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
  '': 'ไม่ระบุ',
  '01': 'บัญชีแยกประเภท',
  '11': 'บัญชีลูกหนี้',
  '21': 'บัญชีเจ้าหนี้',
  '31': 'สินค้าคงคลัง',
  '81': 'เงินสดและเช็ค',
  '86': 'เงินมัดจำ',
  '91': 'ภาษีซื้อ',
  '96': 'ภาษีขาย',
};
// '01': 'บัญชีแยกประเภท'
const Map<String, String> glSysDocType = {
  '10': 'ตั้งยอดบัญชียกมา',
  '30': 'ใบสำคัญรับ',
  '50': 'ใบสำคัญจ่าย',
  '70': 'ใบสำคัญทั่วไป',
  '80': 'ปรับปรุงบัญชี',
  '90': 'ปิดบัญชี',
};
// '11': 'บัญชีลูกหนี้'
const Map<String, String> arSysDocType = {
  '10': 'ตั้งยอดลูกหนี้',
  '30': 'เพิ่มยอดลูกหนี้',
  '50': 'ลดยอดลูกหนี้',
  '70': 'รับชำระ',
};
// '21': 'บัญชีเจ้าหนี้'
const Map<String, String> apSysDocType = {
  '10': 'ตั้งยอดเจ้าหนี้',
  '30': 'เพิ่มยอดเจ้าหนี้',
  '50': 'ลดยอดเจ้าหนี้',
  '70': 'จ่ายชำระ',
};
// '31': 'สินค้าคงคลัง'
const Map<String, String> imSysDocType = {
  '10': 'Good Receive Note', // buy (stock+ ap+)
  '15': 'Return to Supplier', // return (stock- ap-)
  '20': 'Credit Note from Supplier', // cn (stock- ap-)
  '25': 'Debit Note from Supplier', // dn (stock+ ap+)
  '30': 'Sale', // sale (stock- ar+)
  '35': 'Return from Customer', // return (stock+ ar-)
  '40': 'Credit Note to Customer', // cn (stock+ ar-)
  '45': 'Debit Note to Customer', // dn (stock- ar+)
  '60': 'Issue Stock', // issue (stock-) for project, ...
  '70': 'Transfer in-out', // transfer between location (stock=)
  '80': 'Adjust quantity', // adjust (stock+-) for Phys.Count, ...
};
// '81': 'เงินสดและเช็ค'
const Map<String, String> cqSysDocType = {
  '': 'ไม่ระบุ',
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

const Map<int, String> periodNameThai = {
  1: 'มกราคม',
  2: 'กุมภาพันธ์',
  3: 'มีนาคม',
  4: 'เมษายน',
  5: 'พฤษภาคม',
  6: 'มิถุนายน',
  7: 'กรกฎาคม',
  8: 'สิงหาคม',
  9: 'กันยายน',
  10: 'ตุลาคม',
  11: 'พฤศจิกายน',
  12: 'ธันวาคม',
};

const Map<int, String> periodNameEng = {
  1: 'January',
  2: 'February',
  3: 'March',
  4: 'April',
  5: 'May',
  6: 'June',
  7: 'July',
  8: 'August',
  9: 'September',
  10: 'October',
  11: 'November',
  12: 'December',
};

const Map<int, String> periodShortNameThai = {
  1: 'ม.ค.',
  2: 'ก.พ.',
  3: 'มี.ค.',
  4: 'เม.ย.',
  5: 'พ.ค.',
  6: 'มิ.ย.',
  7: 'ก.ค.',
  8: 'ส.ค.',
  9: 'ก.ย.',
  10: 'ต.ค.',
  11: 'พ.ย.',
  12: 'ธ.ค.',
};

const Map<int, String> periodShortNameEng = {
  1: 'Jan',
  2: 'Feb',
  3: 'Mar',
  4: 'Apr',
  5: 'May',
  6: 'Jun',
  7: 'Jul',
  8: 'Aug',
  9: 'Sep',
  10: 'Oct',
  11: 'Nov',
  12: 'Dec',
};
