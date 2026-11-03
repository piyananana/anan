import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_master_reset_view.dart';

// ล้างข้อมูลหลัก/การตั้งค่าของ IM และ MO — ธุรกรรม (เอกสาร IM, สต็อก, นับสต็อก, เปลี่ยนราคา, ใบสั่งผลิต)
// ล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen)
class ImResetScreen extends StatelessWidget {
  const ImResetScreen({super.key});

  static String _rows(Map<String, dynamic>? c, String key, bool en) =>
      '$key (${c?[key] ?? '-'} ${en ? 'rows' : 'รายการ'})';

  @override
  Widget build(BuildContext context) {
    return MasterResetView(
      countsUrl: '${AppConfig.apiIm}/im_reset_master/counts',
      resetUrl: '${AppConfig.apiIm}/im_reset_master',
      descriptionTh: 'ฟังก์ชันนี้จะลบข้อมูลหลักของสินค้าคงคลังและการผลิต (สินค้า, หมวดหมู่, หน่วยนับ, คลัง, ราคาขาย, '
          'สูตรการผลิต, ศูนย์งาน) และ/หรือคืนค่าการตั้งค่าตามที่เลือกไว้ด้านล่างอย่างถาวร',
      descriptionEn: 'Permanently deletes inventory and manufacturing master data (items, categories, units, warehouses, '
          'price lists, BOMs, work centers) and/or resets the settings selected below.',
      options: [
        MasterResetOption(
          bodyKey: 'resetBom',
          icon: Icons.account_tree,
          color: Colors.deepOrange[700]!,
          titleTh: 'สูตรการผลิต (BOM)',
          titleEn: 'Bills of materials (BOM)',
          subtitle: (c, en) => _rows(c, 'mo_bom_header', en),
          details: const [
            ('ลบสูตรการผลิตทั้งหมด รวมวัตถุดิบ ผลผลิต และขั้นตอนการผลิตของสูตร',
             'Deletes all BOMs incl. their components, outputs and operations'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetWorkCenters',
          icon: Icons.precision_manufacturing,
          color: Colors.brown[600]!,
          titleTh: 'ศูนย์งาน',
          titleEn: 'Work centers',
          subtitle: (c, en) => _rows(c, 'mo_work_center', en),
          details: const [
            ('ถ้าสูตรการผลิตยังใช้ศูนย์งานอยู่ ต้องเลือก "สูตรการผลิต" ด้วย',
             'If BOM operations still use a work center, select "Bills of materials" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetMoGlSetup',
          icon: Icons.factory,
          color: Colors.blueGrey[700]!,
          titleTh: 'ตั้งค่าเชื่อมต่อ GL ของการผลิต',
          titleEn: 'Manufacturing GL setup',
          subtitle: (c, en) => _rows(c, 'mo_gl_account_setup', en),
        ),
        MasterResetOption(
          bodyKey: 'resetPriceList',
          icon: Icons.sell,
          color: Colors.purple[700]!,
          titleTh: 'ราคาขาย (Price List)',
          titleEn: 'Price lists',
          subtitle: (c, en) => _rows(c, 'im_price_list', en),
          details: const [
            ('ลบราคาขายทั้งหมด รวมรายการราคา และล้างราคาขายที่ผูกไว้กับลูกค้า/ผู้ขายเป็นค่าว่าง',
             'Deletes all price lists incl. their lines and clears price lists linked to customers/vendors'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetPriceGroups',
          icon: Icons.label,
          color: Colors.pink[600]!,
          titleTh: 'กลุ่มราคา',
          titleEn: 'Price groups',
          subtitle: (c, en) => _rows(c, 'im_price_group', en),
        ),
        MasterResetOption(
          bodyKey: 'resetItems',
          icon: Icons.inventory_2,
          color: Colors.red[700]!,
          titleTh: 'สินค้า',
          titleEn: 'Items',
          subtitle: (c, en) => _rows(c, 'im_item', en),
          details: const [
            ('ลบสินค้าทั้งหมด รวมการตั้งค่ารายคลังและหน่วยนับทางเลือกของสินค้า',
             'Deletes all items incl. per-warehouse settings and alternate units'),
            ('ถ้ายังมีสูตรการผลิตหรือราคาขายอ้างอิงสินค้า ต้องเลือก "สูตรการผลิต" และ "ราคาขาย" ด้วย',
             'If BOMs or price lists still reference items, select "Bills of materials" and "Price lists" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetItemCategories',
          icon: Icons.category,
          color: Colors.blue[700]!,
          titleTh: 'หมวดหมู่สินค้า',
          titleEn: 'Item categories',
          subtitle: (c, en) => _rows(c, 'im_item_category', en),
          details: const [
            ('ถ้าไม่ได้ลบสินค้าด้วย หมวดหมู่ของสินค้าที่เหลือจะถูกล้างเป็นค่าว่าง',
             'If items are kept, their category is cleared'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetUom',
          icon: Icons.straighten,
          color: Colors.cyan[800]!,
          titleTh: 'หน่วยนับ',
          titleEn: 'Units of measure',
          subtitle: (c, en) => _rows(c, 'im_uom', en),
          details: const [
            ('สินค้าต้องมีหน่วยนับหลัก — ต้องเลือก "สินค้า" (และ "สูตรการผลิต"/"ราคาขาย" ถ้ามี) ด้วย',
             'Items require a base unit — select "Items" (and "Bills of materials"/"Price lists" if any) too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetWarehouses',
          icon: Icons.warehouse,
          color: Colors.green[700]!,
          titleTh: 'คลังสินค้า / ตำแหน่งจัดเก็บ',
          titleEn: 'Warehouses / locations',
          subtitle: (c, en) => en
              ? 'im_warehouse (${c?['im_warehouse'] ?? '-'}), im_location (${c?['im_location'] ?? '-'})'
              : 'im_warehouse (${c?['im_warehouse'] ?? '-'}), im_location (${c?['im_location'] ?? '-'})',
          details: const [
            ('ลบคลังและตำแหน่งจัดเก็บทั้งหมด การตั้งค่าสินค้ารายคลัง และล้างคลัง/ตำแหน่งเริ่มต้นของสินค้าเป็นค่าว่าง',
             'Deletes all warehouses and locations, per-warehouse item settings, and clears item default warehouse/location'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetGlAccountSetup',
          icon: Icons.account_balance,
          color: Colors.teal[700]!,
          titleTh: 'ตั้งค่าเชื่อมต่อ GL ของสินค้าคงคลัง',
          titleEn: 'Inventory GL setup',
          subtitle: (c, en) => _rows(c, 'im_gl_account_setup', en),
        ),
        MasterResetOption(
          bodyKey: 'resetAccountingSetting',
          icon: Icons.tune,
          color: Colors.indigo[700]!,
          titleTh: 'ตั้งค่าโหมดบัญชีสินค้าคงคลัง',
          titleEn: 'Inventory accounting mode',
          subtitle: (c, en) {
            final set = c?['im_accounting_setting_configured'] == true;
            return en ? (set ? 'Configured' : 'Default (perpetual)') : (set ? 'ตั้งค่าแล้ว' : 'ค่าเริ่มต้น (Perpetual)');
          },
          details: const [
            ('คืนค่าเป็น Perpetual และล้างบัญชี/งวดที่ตั้งไว้', 'Back to perpetual and clears the configured accounts/period'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetItemRunning',
          icon: Icons.tag,
          color: Colors.indigo[400]!,
          titleTh: 'ตั้งค่ารหัสสินค้าอัตโนมัติ',
          titleEn: 'Item code auto-numbering',
          subtitle: (c, en) {
            final r = c?['im_item_running'];
            final on = r?['is_auto_numbering'] == true;
            return en
                ? 'im_item_running — enabled: ${on ? 'yes' : 'no'}, next number: ${r?['next_running_number'] ?? '-'}'
                : 'im_item_running — เปิดใช้งาน: ${on ? 'ใช่' : 'ไม่ใช่'}, เลขที่ถัดไป: ${r?['next_running_number'] ?? '-'}';
          },
          details: const [
            ('คืนค่าเป็นค่าเริ่มต้น: ปิดใช้งาน, รูปแบบ ITEM-0001, เลขที่ถัดไป = 1',
             'Back to defaults: disabled, format ITEM-0001, next number = 1'),
          ],
        ),
      ],
    );
  }
}
