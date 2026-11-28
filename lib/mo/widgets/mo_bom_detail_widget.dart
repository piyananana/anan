// lib/mo/widgets/mo_bom_detail_widget.dart — สูตรการผลิต แบบ B ของ IM (user 2026-11-29)
//   แถบหัว + ตัวเลขสรุป (ต้นทุนต่อหน่วยตามสูตร ไล่ลึกทุกชั้น, วัตถุดิบ/แปรรูป, เทียบต้นทุนมาตรฐาน, ใบสั่งผลิต) + ลิงก์ข้ามส่วน
//   ส่วน: ข้อมูลสูตร / ส่วนประกอบ / ขั้นตอนผลิต / ผลิตภัณฑ์ร่วม เป็นตาราง (กดแถว = หน้าต่างแก้ไขเดิม) / การใช้งานสูตร
//   เตือน: เวอร์ชันที่จะถูกปิด, ตีมูลค่ามาตรฐานแต่สินค้ายังไม่ตั้งต้นทุนมาตรฐาน, ศูนย์งานยังไม่ตั้งอัตรา
//   backend ตรวจสูตรอ้างอิงกันเป็นวงตอนบันทึก และบอกเหตุผลเมื่อลบไม่ได้
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/mo_bom.dart';
import '../models/mo_header.dart';
import '../models/mo_master_summary.dart';
import '../models/mo_work_center.dart';
import '../services/mo_bom_service.dart';
import '../services/mo_work_center_service.dart';
import '../widgets/mo_work_center_list_widget.dart';
import 'mo_uom_picker.dart';
import '../../im/models/im_item.dart';
import '../../im/widgets/im_item_list_widget.dart';

// ---------------------------------------------------------------------------
// Add/Edit component dialog
// ---------------------------------------------------------------------------
Future<MoBomDetail?> _showComponentDialog(BuildContext context, MoBomDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? componentItemId = existing?.componentItemId;
  String? componentItemCode = existing?.componentItemCode;
  String? componentItemName = isEnglish && (existing?.componentItemNameEn ?? '').isNotEmpty
      ? existing?.componentItemNameEn
      : existing?.componentItemNameTh;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final qtyCtrl = TextEditingController(text: existing != null ? '${existing.quantityPer}' : '1');
  final scrapCtrl = TextEditingController(text: existing != null ? '${existing.scrapPercent}' : '0');

  // ลิงก์ไปสูตรของตัวเอง ถ้าส่วนประกอบนี้ผลิตเองได้ (มี BOM active) — opt-in เสมอ ไม่ auto-link ให้ (ดูแผนออกแบบ
  // โมดูล MO ข้อ "BOM scope ให้มี recursive"): componentBomHeaderId = ลิงก์จริงที่จะบันทึก, suggestedBomHeaderId
  // = แค่คำแนะนำที่เจอจากการเช็คสินค้าที่เลือก (เช็คใหม่ทุกครั้งที่เปลี่ยนสินค้า ไม่เชื่อค่าเดิมที่ค้างมา)
  int? componentBomHeaderId = existing?.componentBomHeaderId;
  String? componentBomVersion = existing?.componentBomVersion;
  int? suggestedBomHeaderId = existing?.componentActiveBomId;
  String? suggestedBomVersion;
  bool checkingSubBom = false;

  return showDialog<MoBomDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      Future<void> checkSubBom(int itemId) async {
        setDlg(() => checkingSubBom = true);
        try {
          final boms = await MoBomService().fetchRows(parentItemId: itemId);
          final active = boms.where((b) => b.isActive).toList();
          setDlg(() {
            suggestedBomHeaderId = active.isNotEmpty ? active.first.id : null;
            suggestedBomVersion = active.isNotEmpty ? active.first.bomVersion : null;
          });
        } catch (_) {
        } finally {
          setDlg(() => checkingSubBom = false);
        }
      }

      Widget buildSubBomBanner() {
        if (componentBomHeaderId != null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
            child: Row(children: [
              const Icon(Icons.precision_manufacturing, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isEnglish ? 'Linked to this component\'s own BOM (v$componentBomVersion) — can be exploded into a sub Manufacturing Order' : 'เชื่อมกับสูตรของส่วนประกอบนี้เอง (v$componentBomVersion) — สร้างใบสั่งผลิตย่อยได้',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: isEnglish ? 'Unlink' : 'ยกเลิกลิงก์',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setDlg(() { componentBomHeaderId = null; componentBomVersion = null; }),
              ),
            ]),
          );
        }
        if (checkingSubBom) {
          return const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator());
        }
        if (suggestedBomHeaderId != null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade300)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isEnglish ? 'This item is manufactured too (BOM v$suggestedBomVersion found)' : 'สินค้านี้ผลิตเองได้เหมือนกัน (พบสูตร v$suggestedBomVersion)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => setDlg(() { componentBomHeaderId = suggestedBomHeaderId; componentBomVersion = suggestedBomVersion; }),
                child: Text(isEnglish ? 'Link' : 'เชื่อมสูตรนี้', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          );
        }
        return const SizedBox.shrink();
      }

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Component' : 'เพิ่มส่วนประกอบ') : (isEnglish ? 'Edit Component' : 'แก้ไขส่วนประกอบ')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFkField(
                label: isEnglish ? 'Component Item *' : 'สินค้าส่วนประกอบ *',
                hasValue: componentItemId != null,
                displayText: '$componentItemCode — $componentItemName',
                onSearch: () => ImItemListWidget.search(ctx, onSelected: (ImItem i) {
                  setDlg(() {
                    componentItemId = i.id; componentItemCode = i.itemCode;
                    componentItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                    // เปลี่ยนสินค้าแล้ว ลิงก์สูตรเดิม (ถ้ามี) ใช้กับสินค้าใหม่ไม่ได้ ต้องเช็คใหม่เสมอ
                    componentBomHeaderId = null; componentBomVersion = null;
                    suggestedBomHeaderId = null; suggestedBomVersion = null;
                    // เปลี่ยนสินค้าแล้วหน่วยเดิมอาจไม่ใช่หน่วยของสินค้าใหม่ — ตั้งเป็นหน่วยหลักของสินค้าใหม่
                    uomId = i.baseUomId; uomCode = i.baseUomCode;
                    uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                  });
                  if (i.id != null) checkSubBom(i.id!);
                }),
              ),
              buildSubBomBanner(),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Qty per unit *' : 'จำนวนต่อหน่วย *', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildFkField(
                    label: isEnglish ? 'UOM' : 'หน่วยนับ',
                    hasValue: uomId != null,
                    displayText: '$uomCode — $uomName',
                    onSearch: () async {
                      final o = await pickProductionUom(ctx, componentItemId, isEnglish);
                      if (o != null) {
                        setDlg(() { uomId = o.uomId; uomCode = o.uomCode; uomName = o.displayName(isEnglish); });
                      }
                    },
                  ),
                ),
              ]),
              TextField(
                controller: scrapCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(labelText: isEnglish ? 'Scrap %' : 'เปอร์เซ็นต์ของเสีย (%)', border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (componentItemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a component item' : 'กรุณาเลือกสินค้าส่วนประกอบ')));
                return;
              }
              Navigator.of(ctx).pop(MoBomDetail(
                id: existing?.id,
                bomHeaderId: existing?.bomHeaderId,
                lineNo: existing?.lineNo ?? 1,
                componentItemId: componentItemId!,
                componentItemCode: componentItemCode,
                componentItemNameTh: isEnglish ? null : componentItemName,
                componentItemNameEn: isEnglish ? componentItemName : null,
                quantityPer: double.tryParse(qtyCtrl.text) ?? 0,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: isEnglish ? null : uomName,
                uomNameEn: isEnglish ? uomName : null,
                scrapPercent: double.tryParse(scrapCtrl.text) ?? 0,
                componentBomHeaderId: componentBomHeaderId,
                componentBomVersion: componentBomVersion,
                componentActiveBomId: componentBomHeaderId ?? suggestedBomHeaderId,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Add/Edit co-product (output) dialog
// ---------------------------------------------------------------------------
Future<MoBomOutputDetail?> _showOutputDialog(BuildContext context, MoBomOutputDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? outputItemId = existing?.outputItemId;
  String? outputItemCode = existing?.outputItemCode;
  String? outputItemName = isEnglish && (existing?.outputItemNameEn ?? '').isNotEmpty ? existing?.outputItemNameEn : existing?.outputItemNameTh;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final qtyCtrl = TextEditingController(text: existing != null ? '${existing.outputQtyPer}' : '1');

  return showDialog<MoBomOutputDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Co-product' : 'เพิ่มผลิตภัณฑ์ร่วม') : (isEnglish ? 'Edit Co-product' : 'แก้ไขผลิตภัณฑ์ร่วม')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFkField(
                label: isEnglish ? 'Output Item *' : 'สินค้าผลผลิต *',
                hasValue: outputItemId != null,
                displayText: '$outputItemCode — $outputItemName',
                onSearch: () => ImItemListWidget.search(ctx, onSelected: (ImItem i) {
                  setDlg(() {
                    outputItemId = i.id; outputItemCode = i.itemCode;
                    outputItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                    // เปลี่ยนสินค้าแล้วหน่วยเดิมอาจไม่ใช่หน่วยของสินค้าใหม่ — ตั้งเป็นหน่วยหลักของสินค้าใหม่
                    uomId = i.baseUomId; uomCode = i.baseUomCode;
                    uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                  });
                }),
              ),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Qty per batch *' : 'จำนวนต่อรอบผลิต *', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildFkField(
                    label: isEnglish ? 'UOM' : 'หน่วยนับ',
                    hasValue: uomId != null,
                    displayText: '$uomCode — $uomName',
                    onSearch: () async {
                      final o = await pickProductionUom(ctx, outputItemId, isEnglish);
                      if (o != null) {
                        setDlg(() { uomId = o.uomId; uomCode = o.uomCode; uomName = o.displayName(isEnglish); });
                      }
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (outputItemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select an output item' : 'กรุณาเลือกสินค้าผลผลิต')));
                return;
              }
              Navigator.of(ctx).pop(MoBomOutputDetail(
                id: existing?.id,
                bomHeaderId: existing?.bomHeaderId,
                lineNo: existing?.lineNo ?? 1,
                outputItemId: outputItemId!,
                outputItemCode: outputItemCode,
                outputItemNameTh: isEnglish ? null : outputItemName,
                outputItemNameEn: isEnglish ? outputItemName : null,
                outputQtyPer: double.tryParse(qtyCtrl.text) ?? 0,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: isEnglish ? null : uomName,
                uomNameEn: isEnglish ? uomName : null,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Add/Edit operation (routing step) dialog
// ---------------------------------------------------------------------------
Future<MoBomOperationDetail?> _showOperationDialog(BuildContext context, MoBomOperationDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? workCenterId = existing?.workCenterId;
  String? workCenterCode = existing?.workCenterCode;
  String? workCenterName = isEnglish && (existing?.workCenterNameEn ?? '').isNotEmpty ? existing?.workCenterNameEn : existing?.workCenterNameTh;
  final nameCtrl = TextEditingController(text: existing?.operationName ?? '');
  final laborCtrl = TextEditingController(text: existing != null ? '${existing.standardLaborHours}' : '0');
  final machineCtrl = TextEditingController(text: existing != null ? '${existing.standardMachineHours}' : '0');
  final setupCtrl = TextEditingController(text: existing != null ? '${existing.setupHours}' : '0');

  return showDialog<MoBomOperationDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Operation' : 'เพิ่มขั้นตอนการผลิต') : (isEnglish ? 'Edit Operation' : 'แก้ไขขั้นตอนการผลิต')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFkField(
                label: isEnglish ? 'Work Center *' : 'ศูนย์งาน *',
                hasValue: workCenterId != null,
                displayText: '$workCenterCode — $workCenterName',
                onSearch: () => MoWorkCenterListWidget.search(ctx, onSelected: (MoWorkCenter w) {
                  setDlg(() {
                    workCenterId = w.id; workCenterCode = w.workCenterCode;
                    workCenterName = isEnglish && (w.workCenterNameEn ?? '').isNotEmpty ? w.workCenterNameEn : w.workCenterNameTh;
                  });
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Operation Name' : 'ชื่อขั้นตอน', border: const OutlineInputBorder()),
                ),
              ),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: laborCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Labor Hrs' : 'ชม. แรงงาน', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: machineCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Machine Hrs' : 'ชม. เครื่องจักร', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
              ]),
              TextField(
                controller: setupCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(labelText: isEnglish ? 'Setup Hrs (fixed per order)' : 'ชม. ติดตั้ง (คงที่ต่อใบสั่งผลิต)', border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (workCenterId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a work center' : 'กรุณาเลือกศูนย์งาน')));
                return;
              }
              Navigator.of(ctx).pop(MoBomOperationDetail(
                id: existing?.id,
                bomHeaderId: existing?.bomHeaderId,
                lineNo: existing?.lineNo ?? 1,
                workCenterId: workCenterId!,
                workCenterCode: workCenterCode,
                workCenterNameTh: isEnglish ? null : workCenterName,
                workCenterNameEn: isEnglish ? workCenterName : null,
                operationName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                standardLaborHours: double.tryParse(laborCtrl.text) ?? 0,
                standardMachineHours: double.tryParse(machineCtrl.text) ?? 0,
                setupHours: double.tryParse(setupCtrl.text) ?? 0,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

class MoBomDetailWidget extends StatefulWidget {
  final Mode mode;
  final MoBomHeader? selected;
  // สร้างเวอร์ชันใหม่: สำเนาสูตรนี้ทั้งหมด เลขเวอร์ชันถัดไป และยังไม่ใช้งาน (user 2026-11-29)
  final MoBomHeader? newVersionOf;
  final String? nextVersion;
  // สูตรทั้งหมดจากรายการ — ใช้เตือนว่าติ๊กใช้งานแล้วเวอร์ชันไหนจะถูกปิด
  final List<MoBomHeader> allRows;
  final Future<void> Function(MoBomHeader) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onNewVersion;

  const MoBomDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    this.newVersionOf,
    this.nextVersion,
    this.allRows = const [],
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.onEdit,
    this.onDelete,
    this.onNewVersion,
  });

  @override
  State<MoBomDetailWidget> createState() => MoBomDetailWidgetState();
}

class MoBomDetailWidgetState extends State<MoBomDetailWidget> with ImMasterKit {
  bool _isSaving = false;
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  final _versionCtrl = TextEditingController(text: '1');
  final _bomQtyCtrl = TextEditingController(text: '1');
  final _overheadPercentCtrl = TextEditingController(text: '0');

  bool _isActive = true;
  DateTime? _effectiveDate;
  String _issueMethod = 'EXPLICIT';
  String _costingMethod = 'ACTUAL';
  String _costingMode = 'OVERHEAD_PERCENT';

  int? _parentItemId;
  String? _parentItemCode;
  String? _parentItemName;
  double? _parentStdCost; // ต้นทุนมาตรฐานของสินค้าที่ผลิต (จากสินค้าที่เลือก หรือจากข้อมูลสรุป)
  int? _outputUomId;
  String? _outputUomCode;
  String? _outputUomName;

  List<MoBomDetail> _details = [];
  List<MoBomOutputDetail> _outputs = [];
  List<MoBomOperationDetail> _operations = [];

  String _snapshot = '';
  MoBomSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;
  Map<int, MoWorkCenter> _workCenters = {};

  static final _money = NumberFormat('#,##0.00');
  static final _money4 = NumberFormat('#,##0.00##');
  static final _qty = NumberFormat('#,##0.####');

  bool get _isReadOnly => kitReadOnly;
  bool get _isNewVersion => widget.mode == Mode.add && widget.newVersionOf != null;
  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadWorkCenters();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant MoBomDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected &&
        widget.mode == oldWidget.mode &&
        widget.requestSeq == oldWidget.requestSeq &&
        widget.newVersionOf == oldWidget.newVersionOf) {
      return;
    }
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _applyCurrent();
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: !onlyFullLoad && sameRecord && widget.mode == Mode.view);
    if (!onlyFullLoad) kScrollTop();
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _bomQtyCtrl.dispose();
    _overheadPercentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkCenters() async {
    try {
      final list = await MoWorkCenterService().fetchRows();
      if (mounted) setState(() => _workCenters = {for (final w in list) w.id: w});
    } catch (_) {}
  }

  Future<void> _loadSummary({bool force = false}) async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null) {
      _summary = null;
      _summaryFor = null;
      return;
    }
    if (!force && _summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    try {
      final s = await MoBomService().fetchSummary(id);
      if (mounted && _summaryFor == id) {
        setState(() {
          _summary = s;
          _parentStdCost = s.standardCost;
        });
      }
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    }
    if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
  }

  void _applyCurrent() {
    if (widget.mode == Mode.add && widget.newVersionOf != null) {
      _populate(widget.newVersionOf!, asNewVersion: true);
      _snapshot = '';
    } else if (widget.selected != null && widget.mode != Mode.add) {
      _populate(widget.selected!);
      _snapshot = _fingerprint();
    } else {
      _clear();
      _snapshot = '';
    }
  }

  void _populate(MoBomHeader h, {bool asNewVersion = false}) {
    _versionCtrl.text = asNewVersion ? (widget.nextVersion ?? '${h.bomVersion}-2') : h.bomVersion;
    _bomQtyCtrl.text = _qty.format(h.bomQty).replaceAll(',', '');
    _overheadPercentCtrl.text = _qty.format(h.overheadPercent).replaceAll(',', '');
    _isActive = asNewVersion ? false : h.isActive;
    _effectiveDate = asNewVersion ? null : h.effectiveDate;
    _issueMethod = h.issueMethod;
    _costingMethod = h.costingMethod;
    _costingMode = h.costingMode;
    _parentItemId = h.parentItemId;
    _parentItemCode = h.parentItemCode;
    _parentItemName = _isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn : h.parentItemNameTh;
    _outputUomId = h.outputUomId;
    _outputUomCode = h.outputUomCode;
    _outputUomName = _isEnglish && (h.outputUomNameEn ?? '').isNotEmpty ? h.outputUomNameEn : h.outputUomNameTh;
    // สำเนาเป็นเวอร์ชันใหม่: toJson ของบรรทัดไม่ส่ง id จึงคัดลอกรายการเดิมได้ตรง ๆ (backend สร้างบรรทัดใหม่)
    _details = List.from(h.details);
    _outputs = List.from(h.outputs);
    _operations = List.from(h.operations);
  }

  void _clear() {
    _versionCtrl.text = '1';
    _bomQtyCtrl.text = '1';
    _overheadPercentCtrl.text = '0';
    _isActive = true;
    _effectiveDate = null;
    _issueMethod = 'EXPLICIT';
    _costingMethod = 'ACTUAL';
    _costingMode = 'OVERHEAD_PERCENT';
    _parentItemId = null;
    _parentItemCode = null;
    _parentItemName = null;
    _parentStdCost = null;
    _outputUomId = null;
    _outputUomCode = null;
    _outputUomName = null;
    _details = [];
    _outputs = [];
    _operations = [];
  }

  MoBomHeader _build() => MoBomHeader(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        parentItemId: _parentItemId ?? 0,
        bomVersion: _versionCtrl.text.trim().isEmpty ? '1' : _versionCtrl.text.trim(),
        bomQty: double.tryParse(_bomQtyCtrl.text) ?? 1,
        outputUomId: _outputUomId,
        isActive: _isActive,
        effectiveDate: _effectiveDate,
        issueMethod: _issueMethod,
        costingMethod: _costingMethod,
        costingMode: _costingMode,
        overheadPercent: double.tryParse(_overheadPercentCtrl.text) ?? 0,
        details: _details,
        outputs: _outputs,
        operations: _operations,
      );

  String _fingerprint() {
    try {
      return jsonEncode(_build().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    String? err;
    if (_parentItemId == null) {
      err = isEnglish ? 'Please select the item to produce' : 'กรุณาเลือกสินค้าที่ผลิต';
    } else if (_details.isEmpty) {
      err = isEnglish ? 'Please add at least one component' : 'กรุณาเพิ่มส่วนประกอบอย่างน้อย 1 รายการ';
    } else if (_details.any((d) => d.componentItemId == _parentItemId)) {
      err = isEnglish ? 'A component cannot be the item being produced' : 'ส่วนประกอบเป็นสินค้าตัวเดียวกับสินค้าที่ผลิตไม่ได้';
    } else if ((double.tryParse(_bomQtyCtrl.text) ?? 0) <= 0) {
      err = isEnglish ? 'Output qty must be greater than 0' : 'จำนวนผลผลิตต่อรอบต้องมากกว่า 0';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${isEnglish ? 'Error' : 'เกิดข้อผิดพลาด'}: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickParentItem() async {
    final isEnglish = _isEnglish;
    await ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
      setState(() {
        _parentItemId = i.id;
        _parentItemCode = i.itemCode;
        _parentItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
        _parentStdCost = i.standardCost;
        // เปลี่ยนสินค้าที่ผลิตแล้ว หน่วยผลผลิตเดิมอาจไม่ใช่หน่วยของสินค้าใหม่ — ตั้งเป็นหน่วยหลักของสินค้าใหม่
        _outputUomId = i.baseUomId;
        _outputUomCode = i.baseUomCode;
        _outputUomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
      });
    });
  }

  Future<void> _pickOutputUom() async {
    final isEnglish = _isEnglish;
    final o = await pickProductionUom(context, _parentItemId, isEnglish);
    if (o == null || !mounted) return;
    setState(() {
      _outputUomId = o.uomId;
      _outputUomCode = o.uomCode;
      _outputUomName = o.displayName(isEnglish);
    });
  }

  Future<void> _addComponent() async {
    final result = await _showComponentDialog(context, null);
    if (result != null) setState(() => _details.add(result));
  }

  Future<void> _addOutput() async {
    final result = await _showOutputDialog(context, null);
    if (result != null) setState(() => _outputs.add(result));
  }

  Future<void> _addOperation() async {
    final result = await _showOperationDialog(context, null);
    if (result != null) setState(() => _operations.add(result));
  }

  // กดแถวในโหมดแก้ไข: แก้ / ลบ / เลื่อน
  Future<void> _rowMenu<T>(List<T> list, int i, Future<T?> Function(T) edit) async {
    final e = _isEnglish;
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(e ? 'Edit' : 'แก้ไข'), onTap: () => Navigator.pop(ctx, 'edit')),
          if (i > 0) ListTile(leading: const Icon(Icons.arrow_upward), title: Text(e ? 'Move up' : 'เลื่อนขึ้น'), onTap: () => Navigator.pop(ctx, 'up')),
          if (i < list.length - 1) ListTile(leading: const Icon(Icons.arrow_downward), title: Text(e ? 'Move down' : 'เลื่อนลง'), onTap: () => Navigator.pop(ctx, 'down')),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (r == 'edit') {
      final v = await edit(list[i]);
      if (v != null) setState(() => list[i] = v);
    } else if (r == 'delete') {
      setState(() => list.removeAt(i));
    } else if (r == 'up') {
      setState(() => list.insert(i - 1, list.removeAt(i)));
    } else if (r == 'down') {
      setState(() => list.insert(i + 1, list.removeAt(i)));
    }
  }

  // ─── ค่าที่คำนวณในหน้า ──────────────────────────────────────────────────────────
  double _opCost(MoBomOperationDetail op) {
    final w = _workCenters[op.workCenterId];
    if (w == null) return 0;
    return op.standardLaborHours * w.laborRatePerHour + op.standardMachineHours * (w.machineRatePerHour + w.overheadRatePerHour) + op.setupHours * w.laborRatePerHour;
  }

  bool _opZeroRate(MoBomOperationDetail op) {
    final w = _workCenters[op.workCenterId];
    return w != null && w.laborRatePerHour + w.machineRatePerHour + w.overheadRatePerHour == 0;
  }

  // เวอร์ชันที่ใช้งานอยู่ของสินค้าเดียวกัน ที่จะถูกปิดเมื่อบันทึกสูตรนี้เป็น "ใช้งาน"
  List<MoBomHeader> get _willDeactivate => _parentItemId == null || !_isActive
      ? const []
      : widget.allRows.where((b) => b.parentItemId == _parentItemId && b.id != widget.selected?.id && b.isActive && widget.mode != Mode.view).toList();

  String _uomName(String? code, String? th, String? en) {
    final n = _isEnglish && (en ?? '').isNotEmpty ? en : th;
    return (n ?? '').isNotEmpty ? n! : (code ?? '');
  }

  // ─── การ์ด ───────────────────────────────────────────────────────────────────
  Widget _mainCard() {
    final e = _isEnglish;
    final ro = _isReadOnly;
    final itemLocked = widget.mode == Mode.edit || _isNewVersion;
    final deact = _willDeactivate;
    final stdMissing = _costingMethod == 'STANDARD' && _parentItemId != null && (_parentStdCost ?? 0) <= 0 && _parentStdCost != null;
    return kCard(
      title: e ? 'BOM details' : 'ข้อมูลสูตร',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kFk(
            label: e ? 'Item to produce *' : 'สินค้าที่ผลิต *',
            text: '${_parentItemCode ?? ''} ${_parentItemName ?? ''}'.trim(),
            hasValue: _parentItemId != null,
            onSearch: _pickParentItem,
            onClear: () => setState(() {
              _parentItemId = null;
              _parentItemCode = null;
              _parentItemName = null;
              _parentStdCost = null;
            }),
            locked: itemLocked,
            lockedTip: e ? 'The item cannot change after the BOM is created' : 'เปลี่ยนสินค้าที่ผลิตหลังสร้างสูตรแล้วไม่ได้',
          ),
          kRow([
            kTxt(e ? 'Version' : 'เวอร์ชัน', _versionCtrl),
            kDate(e ? 'Effective date' : 'วันที่มีผล', _effectiveDate, ro ? null : (d) => setState(() => _effectiveDate = d)),
          ]),
          kRow([
            kTxt(e ? 'Output qty per batch' : 'จำนวนผลผลิตต่อรอบ', _bomQtyCtrl, numeric: true),
            kFk(
              label: e ? 'Output UOM' : 'หน่วยนับผลผลิต',
              text: '${_outputUomCode ?? ''} ${_outputUomName ?? ''}'.trim(),
              hasValue: _outputUomId != null,
              onSearch: _pickOutputUom,
              onClear: () => setState(() {
                _outputUomId = null;
                _outputUomCode = null;
                _outputUomName = null;
              }),
            ),
          ]),
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v))]),
          if (deact.isNotEmpty)
            kNote(
                e
                    ? 'Only one active version per item — saving will deactivate version ${deact.map((b) => b.bomVersion).join(', ')}'
                    : 'สินค้าหนึ่งตัวมีสูตรที่ใช้งานได้ทีละเวอร์ชัน — บันทึกแล้วเวอร์ชัน ${deact.map((b) => b.bomVersion).join(', ')} จะถูกปิดใช้งาน',
                color: ImKit.amber)
          else
            kNote(e ? 'Only one active version per item' : 'สินค้าหนึ่งตัวมีสูตรที่ใช้งานได้ทีละเวอร์ชัน'),
        ]),
        kGroup(2, e ? 'Costing policy' : 'นโยบายต้นทุน', ImKit.gFin, [
          kDd<String>(e ? 'Material issue' : 'วิธีเบิกวัตถุดิบ', _issueMethod,
              [for (final m in moIssueMethods) DropdownMenuItem(value: m, child: Text(moIssueMethodLabel(m, e), overflow: TextOverflow.ellipsis))],
              ro ? null : (v) => setState(() => _issueMethod = v ?? 'EXPLICIT'), auto: false),
          kRow([
            kDd<String>(e ? 'Output costing' : 'วิธีตีมูลค่าผลผลิต', _costingMethod,
                [for (final m in moCostingMethods) DropdownMenuItem(value: m, child: Text(moCostingMethodLabel(m, e), overflow: TextOverflow.ellipsis))],
                ro ? null : (v) => setState(() => _costingMethod = v ?? 'ACTUAL'), auto: false),
            kDd<String>(e ? 'Conversion cost' : 'ต้นทุนแปรรูป', _costingMode,
                [for (final m in moCostingModes) DropdownMenuItem(value: m, child: Text(moCostingModeLabel(m, e), overflow: TextOverflow.ellipsis))],
                ro ? null : (v) => setState(() => _costingMode = v ?? 'OVERHEAD_PERCENT'), auto: false),
          ]),
          if (_costingMode == 'OVERHEAD_PERCENT') kTxt(e ? 'Overhead %' : 'เปอร์เซ็นต์ Overhead', _overheadPercentCtrl, numeric: true),
          if (stdMissing)
            kNote(
                e
                    ? 'Standard costing: item ${_parentItemCode ?? ''} has no standard cost yet — receiving from production will be blocked until it is set'
                    : 'ตีมูลค่าแบบต้นทุนมาตรฐาน แต่สินค้า ${_parentItemCode ?? ''} ยังไม่ได้ตั้งต้นทุนมาตรฐาน จะรับเข้าจากการผลิตไม่ได้จนกว่าจะตั้ง',
                color: ImKit.red),
          kNote(e ? 'Defaults for MOs created from this BOM; each MO can override them' : 'ค่าตั้งต้นของใบสั่งผลิตที่สร้างจากสูตรนี้ แก้เป็นรายใบได้'),
        ]),
      ]),
    );
  }

  Widget _componentsCard() {
    final e = _isEnglish;
    final ro = _isReadOnly;
    final bd = ro ? (_summary?.breakdown ?? const <MoBomLineCost>[]) : const <MoBomLineCost>[];
    final showCost = bd.length == _details.length && bd.isNotEmpty;
    final batch = double.tryParse(_bomQtyCtrl.text) ?? 1;
    return kCard(
      title: e ? 'Components (${_details.length})' : 'ส่วนประกอบ (${_details.length})',
      count: ro
          ? (e ? 'Per batch of ${_qty.format(batch)} ${_outputUomCode ?? ''}' : 'ต่อรอบผลิต ${_qty.format(batch)} ${_outputUomName ?? _outputUomCode ?? ''}')
          : (e ? 'Tap a row to edit, move or delete' : 'กดที่แถวเพื่อแก้ไข เลื่อน หรือลบ'),
      trailing: ro ? null : kGhost(e ? 'Component' : 'ส่วนประกอบ', Icons.add, _addComponent),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol('#', 1),
          KCol(e ? 'Item' : 'สินค้า', 8),
          KCol(e ? 'Qty' : 'จำนวน', 2, num: true),
          KCol(e ? 'UOM' : 'หน่วย', 2),
          KCol(e ? 'Scrap' : 'ของเสีย', 2, num: true),
          KCol(e ? 'Sub BOM' : 'สูตรย่อย', 3),
          KCol(e ? 'Unit cost' : 'ต้นทุน/หน่วย', 3, num: true),
          KCol(e ? 'Total' : 'รวม', 3, num: true),
        ],
        [
          for (var i = 0; i < _details.length; i++)
            () {
              final d = _details[i];
              final name = e && (d.componentItemNameEn ?? '').isNotEmpty ? d.componentItemNameEn : d.componentItemNameTh;
              return [
                kCell('${i + 1}', mono: true),
                kCell('${d.componentItemCode ?? ''} ${name ?? ''}'.trim()),
                kCell(_qty.format(d.quantityPer), mono: true),
                kCell(_uomName(d.uomCode, d.uomNameTh, d.uomNameEn)),
                kCell(d.scrapPercent == 0 ? '0%' : '${_qty.format(d.scrapPercent)}%', mono: true),
                d.componentBomHeaderId != null
                    ? ImKit.chip(e ? 'v${d.componentBomVersion ?? ''} pinned' : 'v${d.componentBomVersion ?? ''} ปักหมุด', ImKit.blueSoft, ImKit.blue)
                    : (showCost && bd[i].isSubAssembly)
                        ? ImKit.chip(e ? 'active BOM' : 'สูตรที่ใช้งาน', ImKit.ro, ImKit.ink2)
                        : d.hasOwnBom
                            ? ImKit.chip(e ? 'has BOM' : 'มีสูตร', ImKit.goldSoft, ImKit.amber)
                            : kCell(''),
                kCell(showCost ? _money4.format(bd[i].unitCost) : '', mono: true),
                kCell(showCost ? _money.format(bd[i].lineTotal) : '', mono: true),
              ];
            }(),
        ],
        onTap: ro ? null : [for (var i = 0; i < _details.length; i++) () => _rowMenu<MoBomDetail>(_details, i, (d) => _showComponentDialog(context, d))],
        rowColors: [for (final d in _details) d.componentBomHeaderId != null ? const Color(0xFFFFFCF2) : null],
        minWidth: 860,
        empty: ro ? (e ? 'No components' : 'ยังไม่มีส่วนประกอบ') : (e ? 'No components yet — press "+ Component"' : 'ยังไม่มีส่วนประกอบ — กด "+ ส่วนประกอบ"'),
      ),
    );
  }

  Widget _operationsCard() {
    final e = _isEnglish;
    final ro = _isReadOnly;
    return kCard(
      title: e ? 'Routing (${_operations.length})' : 'ขั้นตอนการผลิต (${_operations.length})',
      count: e ? 'Cost at current work center rates' : 'ต้นทุนตามอัตราศูนย์งานปัจจุบัน',
      trailing: ro ? null : kGhost(e ? 'Operation' : 'ขั้นตอน', Icons.add, _addOperation),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol('#', 1),
          KCol(e ? 'Work center' : 'ศูนย์งาน', 6),
          KCol(e ? 'Operation' : 'ขั้นตอน', 5),
          KCol(e ? 'Labor' : 'แรงงาน', 2, num: true),
          KCol(e ? 'Machine' : 'เครื่องจักร', 2, num: true),
          KCol(e ? 'Setup' : 'ติดตั้ง', 2, num: true),
          KCol(e ? 'Cost' : 'ต้นทุน', 4, num: true),
        ],
        [
          for (var i = 0; i < _operations.length; i++)
            () {
              final op = _operations[i];
              final wc = e && (op.workCenterNameEn ?? '').isNotEmpty ? op.workCenterNameEn : op.workCenterNameTh;
              final zero = _opZeroRate(op);
              return [
                kCell('${i + 1}', mono: true),
                kCell('${op.workCenterCode ?? ''} ${wc ?? ''}'.trim()),
                kCell(op.operationName ?? ''),
                kCell(_qty.format(op.standardLaborHours), mono: true),
                kCell(_qty.format(op.standardMachineHours), mono: true),
                kCell(_qty.format(op.setupHours), mono: true),
                kCell(zero ? (e ? '0.00 · no rates' : '0.00 · ยังไม่ตั้งอัตรา') : _money.format(_opCost(op)), mono: true, color: zero ? ImKit.red : null),
              ];
            }(),
        ],
        onTap: ro ? null : [for (var i = 0; i < _operations.length; i++) () => _rowMenu<MoBomOperationDetail>(_operations, i, (o) => _showOperationDialog(context, o))],
        minWidth: 800,
        empty: ro ? (e ? 'No operations' : 'ยังไม่มีขั้นตอนการผลิต') : (e ? 'No operations yet — press "+ Operation"' : 'ยังไม่มีขั้นตอน — กด "+ ขั้นตอน"'),
      ),
    );
  }

  Widget _outputsCard() {
    final e = _isEnglish;
    final ro = _isReadOnly;
    return kCard(
      title: e ? 'Co-products (${_outputs.length})' : 'ผลิตภัณฑ์ร่วม (${_outputs.length})',
      count: e ? 'Extra outputs produced with the main item · may be empty' : 'ผลผลิตอื่นที่ได้พร้อมสินค้าหลัก · เว้นว่างได้',
      trailing: ro ? null : kGhost(e ? 'Co-product' : 'ผลิตภัณฑ์ร่วม', Icons.add, _addOutput),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol('#', 1),
          KCol(e ? 'Item' : 'สินค้า', 9),
          KCol(e ? 'Qty per batch' : 'จำนวนต่อรอบ', 3, num: true),
          KCol(e ? 'UOM' : 'หน่วย', 3),
        ],
        [
          for (var i = 0; i < _outputs.length; i++)
            () {
              final o = _outputs[i];
              final name = e && (o.outputItemNameEn ?? '').isNotEmpty ? o.outputItemNameEn : o.outputItemNameTh;
              return [
                kCell('${i + 1}', mono: true),
                kCell('${o.outputItemCode ?? ''} ${name ?? ''}'.trim()),
                kCell(_qty.format(o.outputQtyPer), mono: true),
                kCell(_uomName(o.uomCode, o.uomNameTh, o.uomNameEn)),
              ];
            }(),
        ],
        onTap: ro ? null : [for (var i = 0; i < _outputs.length; i++) () => _rowMenu<MoBomOutputDetail>(_outputs, i, (o) => _showOutputDialog(context, o))],
        minWidth: 560,
        empty: e ? 'No co-products' : 'ไม่มีผลิตภัณฑ์ร่วม',
      ),
    );
  }

  Widget _usageCard() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) {
      return kCard(
        title: e ? 'BOM usage' : 'การใช้งานสูตร',
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(e ? 'Could not load' : 'โหลดข้อมูลไม่ได้'),
      );
    }
    final rows = <List<Widget>>[];
    for (final v in s.otherVersions) {
      rows.add([
        kCell(e ? 'Other version' : 'เวอร์ชันอื่นของสินค้านี้'),
        kCell(e
            ? 'v${v.version} · ${v.componentCount} component(s)${v.unitCost == null ? '' : ' · ${_money4.format(v.unitCost)} / unit'}'
            : 'v${v.version} · ${v.componentCount} ส่วนประกอบ${v.unitCost == null ? '' : ' · ${_money4.format(v.unitCost)} / หน่วย'}'),
        v.isActive ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'ไม่ใช้งาน', ImKit.ro, ImKit.ink2),
      ]);
    }
    for (final p in s.parents) {
      rows.add([
        kCell(e ? 'Parent BOM using this item' : 'สูตรแม่ที่ใช้สินค้านี้'),
        kCell('${p.itemCode ?? ''} ${p.itemName(e)} v${p.version} · ${e ? 'uses' : 'ใช้'} ${_qty.format(p.quantityPer)}${p.pinnedHere ? (e ? ' · pinned to this BOM' : ' · ปักหมุดสูตรนี้') : ''}'),
        p.isActive ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'ไม่ใช้งาน', ImKit.ro, ImKit.ink2),
      ]);
    }
    if (s.moTotal > 0) {
      rows.add([
        kCell(e ? 'Manufacturing orders' : 'ใบสั่งผลิต'),
        kCell(s.openMos.isEmpty
            ? (e ? '${s.moTotal} MO(s), all closed' : '${s.moTotal} ใบ ปิดแล้วทั้งหมด')
            : s.openMos.map((m) => '${m.docNo ?? ''} (${moHeaderStatusLabel(m.status, e)})').join(' · ')),
        kCell(e ? '${s.moOpenCount} open' : 'ยังไม่ปิด ${s.moOpenCount}', color: ImKit.ink3),
      ]);
    }
    return kCard(
      title: e ? 'BOM usage' : 'การใช้งานสูตร',
      count: e ? 'Read-only' : 'อ่านอย่างเดียว',
      trailing: kGhost(e ? 'Manufacturing orders' : 'ไปหน้าใบสั่งผลิต', Icons.open_in_new,
          () => ImKit.openMenu(context, 'MoHeaderScreen', 'ใบสั่งผลิต', 'Manufacturing Order', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Type' : 'ประเภท', 4), KCol(e ? 'Details' : 'รายการ', 10), KCol(e ? 'Status' : 'สถานะ', 3)],
        rows,
        minWidth: 640,
        empty: e ? 'No other versions, parent BOMs or MOs' : 'ไม่มีเวอร์ชันอื่น สูตรแม่ หรือใบสั่งผลิตที่ใช้สูตรนี้',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    final uom = _outputUomName ?? _outputUomCode ?? '';
    final batch = double.tryParse(_bomQtyCtrl.text) ?? 1;
    final std = s.standardCost;
    final unit = s.unitCost;
    final diff = (unit != null && std != null && std > 0) ? (unit - std) / std * 100 : null;
    return kKpis([
      ImKpi(e ? 'Unit cost by BOM' : 'ต้นทุนต่อหน่วยตามสูตร', unit == null ? '—' : _money4.format(unit),
          s.costError != null ? (e ? 'cannot cost: ${s.costError}' : 'คิดต้นทุนไม่ได้: ${s.costError}') : (e ? 'per $uom · all sub-levels' : 'ต่อ $uom · ไล่ลึกทุกชั้น'),
          warn: s.costError != null,
          onTap: () => ImKit.openMenu(context, 'MoBomCostReportScreen', 'รายงานต้นทุนสูตรการผลิตที่ใช้', 'BOM Cost Report', e)),
      ImKpi(e ? 'Material / conversion' : 'วัตถุดิบ / แปรรูป',
          s.materialCost == null ? '—' : '${_money.format(s.materialCost)} / ${_money.format(s.conversionCost ?? 0)}',
          e ? 'per batch of ${_qty.format(batch)} $uom' : 'ต่อรอบผลิต ${_qty.format(batch)} $uom'),
      ImKpi(
          e ? 'vs item standard cost' : 'เทียบต้นทุนมาตรฐานของสินค้า',
          diff == null ? '—' : '${diff >= 0 ? '+' : ''}${NumberFormat('0.0').format(diff)}%',
          std == null || std <= 0 ? (e ? 'no standard cost set' : 'ยังไม่ได้ตั้งต้นทุนมาตรฐาน') : (e ? 'standard ${_money4.format(std)}' : 'ต้นทุนมาตรฐาน ${_money4.format(std)}'),
          warn: (std == null || std <= 0) ? _costingMethod == 'STANDARD' : (diff != null && diff.abs() >= 5)),
      ImKpi(e ? 'MOs using this BOM' : 'ใบสั่งผลิตที่ใช้สูตรนี้', '${s.moOpenCount}',
          e ? 'open · ${s.moTotal} in total' : 'ยังไม่ปิด · ทั้งหมด ${s.moTotal}',
          onTap: () => ImKit.openMenu(context, 'MoHeaderScreen', 'ใบสั่งผลิต', 'Manufacturing Order', e)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.precision_manufacturing_outlined,
          e ? 'Select a BOM on the left, or press "Add BOM"' : 'เลือกสูตรการผลิตจากรายการด้านซ้าย หรือกด "เพิ่มสูตร"');
    }
    final ro = _isReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final uom = _outputUomName ?? _outputUomCode ?? '';
    return kPage(
      header: kHeaderBar(
        code: _parentItemCode,
        title: isAdd && _parentItemId == null ? (e ? 'New BOM' : 'สูตรการผลิตใหม่') : (_parentItemName ?? ''),
        badges: [
          ImKit.chip(e ? 'Version ${_versionCtrl.text}' : 'เวอร์ชัน ${_versionCtrl.text}', ImKit.ro, ImKit.ink2),
          if (_isNewVersion) ImKit.chip(e ? 'New version' : 'เวอร์ชันใหม่', ImKit.goldSoft, ImKit.amber),
          _isActive ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'ไม่ใช้งาน', ImKit.ro, ImKit.ink2),
          Text(
              [
                e ? 'batch ${_bomQtyCtrl.text} $uom' : 'รอบละ ${_bomQtyCtrl.text} $uom',
                if (_effectiveDate != null)
                  '${e ? 'effective' : 'มีผล'} ${_effectiveDate!.day.toString().padLeft(2, '0')}/${_effectiveDate!.month.toString().padLeft(2, '0')}/${_effectiveDate!.year}',
              ].join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (!ro) kEditingBadge(),
        ],
        busy: _isSaving,
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _save,
          extra: [if (widget.onNewVersion != null) DocBarAction(e ? 'New version' : 'สร้างเวอร์ชันใหม่', widget.onNewVersion, fg: kInk)],
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'Components' : 'ส่วนประกอบ', _componentsCard()),
        if (_costingMode == 'ROUTING' || _operations.isNotEmpty) (2, e ? 'Routing' : 'ขั้นตอนผลิต', _operationsCard()),
        (3, e ? 'Co-products' : 'ผลิตภัณฑ์ร่วม', _outputsCard()),
        if (saved) (4, e ? 'Usage' : 'การใช้งาน', _usageCard()),
      ],
    );
  }
}
