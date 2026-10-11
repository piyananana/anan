import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/mo_bom.dart';
import '../models/mo_work_center.dart';
import '../services/mo_bom_service.dart';
import '../widgets/mo_work_center_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_uom.dart';
import '../../im/widgets/im_item_list_widget.dart';
import '../../im/widgets/im_uom_list_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section — same look used across the other IM detail widgets
// ---------------------------------------------------------------------------
class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, this.initiallyExpanded = true, required this.children, this.trailing});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.blueGrey.shade600),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800))),
              if (widget.trailing != null) widget.trailing!,
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

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
                    if (uomId == null && i.baseUomId != null) {
                      uomId = i.baseUomId; uomCode = i.baseUomCode;
                      uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                    }
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
                    onSearch: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                      setDlg(() {
                        uomId = u.id; uomCode = u.uomCode;
                        uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                      });
                    }),
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
                    if (uomId == null && i.baseUomId != null) {
                      uomId = i.baseUomId; uomCode = i.baseUomCode;
                      uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                    }
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
                    onSearch: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                      setDlg(() {
                        uomId = u.id; uomCode = u.uomCode;
                        uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                      });
                    }),
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
  final Future<void> Function(MoBomHeader) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มสูตรการผลิตซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const MoBomDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<MoBomDetailWidget> createState() => MoBomDetailWidgetState();
}

class MoBomDetailWidgetState extends State<MoBomDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEnglish = false;

  late TextEditingController _versionCtrl;
  late TextEditingController _bomQtyCtrl;
  late TextEditingController _overheadPercentCtrl;

  bool _isActive = true;
  DateTime? _effectiveDate;
  String _issueMethod = 'EXPLICIT';
  String _costingMethod = 'ACTUAL';
  String _costingMode = 'OVERHEAD_PERCENT';

  int? _parentItemId; String? _parentItemCode; String? _parentItemName;
  int? _outputUomId; String? _outputUomCode; String? _outputUomName;

  List<MoBomDetail> _details = [];
  List<MoBomOutputDetail> _outputs = [];
  List<MoBomOperationDetail> _operations = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _versionCtrl = TextEditingController(text: '1');
    _bomQtyCtrl = TextEditingController(text: '1');
    _overheadPercentCtrl = TextEditingController(text: '0');
    if (widget.selected != null) _populate(widget.selected!);
  }

  @override
  void didUpdateWidget(covariant MoBomDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      if (widget.selected != null) {
        _populate(widget.selected!);
      } else {
        _clear();
      }
    }
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _bomQtyCtrl.dispose();
    _overheadPercentCtrl.dispose();
    super.dispose();
  }

  void _populate(MoBomHeader h) {
    _versionCtrl.text = h.bomVersion;
    _bomQtyCtrl.text = '${h.bomQty}';
    _overheadPercentCtrl.text = '${h.overheadPercent}';
    _isActive = h.isActive;
    _effectiveDate = h.effectiveDate;
    _issueMethod = h.issueMethod;
    _costingMethod = h.costingMethod;
    _costingMode = h.costingMode;
    _parentItemId = h.parentItemId; _parentItemCode = h.parentItemCode;
    _parentItemName = _isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn : h.parentItemNameTh;
    _outputUomId = h.outputUomId; _outputUomCode = h.outputUomCode;
    _outputUomName = _isEnglish && (h.outputUomNameEn ?? '').isNotEmpty ? h.outputUomNameEn : h.outputUomNameTh;
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
    _parentItemId = null; _parentItemCode = null; _parentItemName = null;
    _outputUomId = null; _outputUomCode = null; _outputUomName = null;
    _details = [];
    _outputs = [];
    _operations = [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = _isEnglish;
    if (_parentItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select the item to produce' : 'กรุณาเลือกสินค้าที่ผลิต')));
      return;
    }
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please add at least one component' : 'กรุณาเพิ่มส่วนประกอบอย่างน้อย 1 รายการ')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final header = MoBomHeader(
        id: widget.selected?.id,
        parentItemId: _parentItemId!,
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
      await widget.onSubmit(header);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickParentItem() async {
    final isEnglish = _isEnglish;
    await ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
      setState(() {
        _parentItemId = i.id; _parentItemCode = i.itemCode;
        _parentItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
        if (_outputUomId == null && i.baseUomId != null) {
          _outputUomId = i.baseUomId; _outputUomCode = i.baseUomCode;
          _outputUomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
        }
      });
    });
  }

  Future<void> _pickOutputUom() async {
    final isEnglish = _isEnglish;
    await ImUomListWidget.search(context, onSelected: (ImUom u) {
      setState(() {
        _outputUomId = u.id; _outputUomCode = u.uomCode;
        _outputUomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
      });
    });
  }

  Future<void> _addComponent() async {
    final result = await _showComponentDialog(context, null);
    if (result != null) setState(() => _details.add(result));
  }

  Future<void> _editComponent(int index) async {
    final result = await _showComponentDialog(context, _details[index]);
    if (result != null) setState(() => _details[index] = result);
  }

  void _removeComponent(int index) => setState(() => _details.removeAt(index));

  Future<void> _addOutput() async {
    final result = await _showOutputDialog(context, null);
    if (result != null) setState(() => _outputs.add(result));
  }

  Future<void> _editOutput(int index) async {
    final result = await _showOutputDialog(context, _outputs[index]);
    if (result != null) setState(() => _outputs[index] = result);
  }

  void _removeOutput(int index) => setState(() => _outputs.removeAt(index));

  Future<void> _addOperation() async {
    final result = await _showOperationDialog(context, null);
    if (result != null) setState(() => _operations.add(result));
  }

  Future<void> _editOperation(int index) async {
    final result = await _showOperationDialog(context, _operations[index]);
    if (result != null) setState(() => _operations[index] = result);
  }

  void _removeOperation(int index) => setState(() => _operations.removeAt(index));

  Widget _buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch, VoidCallback? onClear, bool locked = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Row(children: [
            Expanded(
              child: hasValue
                  ? Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ])
                  : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
            ),
            if (!_isReadOnly && !locked) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.teal), tooltip: _isEnglish ? 'Search $label' : 'ค้นหา$label', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              if (hasValue && onClear != null)
                IconButton(icon: const Icon(Icons.clear, color: Colors.red, size: 18), tooltip: _isEnglish ? 'Clear' : 'ล้าง', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
            ],
          ]),
        ),
      );

  Widget _buildBasicSection() {
    final isEnglish = _isEnglish;
    final isLocked = _isReadOnly || widget.mode == Mode.edit;
    return _Section(title: isEnglish ? 'Basic Information' : 'ข้อมูลพื้นฐาน', children: [
      _buildFkField(
        label: isEnglish ? 'Item to Produce *' : 'สินค้าที่ผลิต *',
        hasValue: _parentItemId != null,
        displayText: '$_parentItemCode — $_parentItemName',
        onSearch: _pickParentItem,
        onClear: () => setState(() { _parentItemId = null; _parentItemCode = null; _parentItemName = null; }),
        locked: isLocked,
      ),
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              readOnly: _isReadOnly,
              controller: _versionCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Version' : 'เวอร์ชัน', border: const OutlineInputBorder()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              readOnly: _isReadOnly,
              controller: _bomQtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(labelText: isEnglish ? 'Output Qty (batch size)' : 'จำนวนผลผลิตต่อรอบ', border: const OutlineInputBorder()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Output UOM' : 'หน่วยนับผลผลิต',
          hasValue: _outputUomId != null,
          displayText: '$_outputUomCode — $_outputUomName',
          onSearch: _pickOutputUom,
          onClear: () => setState(() { _outputUomId = null; _outputUomCode = null; _outputUomName = null; }),
        )),
      ]),
      InkWell(
        onTap: _isReadOnly ? null : () async {
          final picked = await showDatePicker(
            context: context, initialDate: _effectiveDate ?? DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _effectiveDate = picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: isEnglish ? 'Effective Date' : 'วันที่มีผล', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          child: Text(_effectiveDate != null ? '${_effectiveDate!.day}/${_effectiveDate!.month}/${_effectiveDate!.year}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
        ),
      ),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(isEnglish ? 'Active (only one active version per item)' : 'ใช้งาน (แต่ละสินค้ามีสูตรที่ active ได้ทีละเวอร์ชัน)'),
        value: _isActive,
        activeColor: Colors.teal,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
      ),
    ]);
  }

  // นโยบายต้นทุน — ตั้งเป็นค่า default ของสูตรนี้ ใบสั่งผลิตที่สร้างจากสูตรนี้ override เป็นรายใบได้ (ควรจำกัดสิทธิ์
  // แก้ไข section นี้ไว้ที่กลุ่มผู้ใช้ Costing เท่านั้น — ดูแผนออกแบบโมดูล MO)
  Widget _buildCostingSection() {
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Costing Policy' : 'นโยบายต้นทุน', children: [
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              value: _issueMethod,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Material Issue' : 'วิธีเบิกวัตถุดิบ', border: const OutlineInputBorder()),
              items: moIssueMethods.map((m) => DropdownMenuItem(value: m, child: Text(moIssueMethodLabel(m, isEnglish)))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _issueMethod = v ?? 'EXPLICIT'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              value: _costingMethod,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Output Costing' : 'วิธีตีมูลค่าผลผลิต', border: const OutlineInputBorder()),
              items: moCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(moCostingMethodLabel(m, isEnglish)))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _costingMethod = v ?? 'ACTUAL'),
            ),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              value: _costingMode,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Conversion Cost' : 'ต้นทุนแปรรูป', border: const OutlineInputBorder()),
              items: moCostingModes.map((m) => DropdownMenuItem(value: m, child: Text(moCostingModeLabel(m, isEnglish)))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _costingMode = v ?? 'OVERHEAD_PERCENT'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (_costingMode == 'OVERHEAD_PERCENT')
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                readOnly: _isReadOnly,
                controller: _overheadPercentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(labelText: isEnglish ? 'Overhead %' : 'เปอร์เซ็นต์ Overhead', border: const OutlineInputBorder()),
              ),
            ),
          )
        else
          const Expanded(child: SizedBox.shrink()),
      ]),
    ]);
  }

  Widget _buildComponentsSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Components (${_details.length})' : 'ส่วนประกอบ (${_details.length})',
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add component' : 'เพิ่มส่วนประกอบ', onPressed: _addComponent),
      children: [
        if (_details.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No components yet' : 'ยังไม่มีส่วนประกอบ', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._details.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final name = isEnglish && (d.componentItemNameEn ?? '').isNotEmpty ? d.componentItemNameEn : d.componentItemNameTh;
            final uomName = isEnglish && (d.uomNameEn ?? '').isNotEmpty ? d.uomNameEn : (d.uomNameTh ?? d.uomCode ?? '');
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: Colors.teal.shade50, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.teal))),
                title: Row(children: [
                  Expanded(child: Text('${d.componentItemCode}  $name')),
                  if (d.componentBomHeaderId != null)
                    Icon(Icons.precision_manufacturing, size: 14, color: Colors.teal.shade700)
                  else if (d.hasOwnBom)
                    Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                ]),
                subtitle: Text(
                  isEnglish
                      ? 'Qty per unit: ${d.quantityPer} $uomName${d.scrapPercent > 0 ? '  ·  Scrap ${d.scrapPercent}%' : ''}'
                      : 'จำนวนต่อหน่วย: ${d.quantityPer} $uomName${d.scrapPercent > 0 ? '  ·  ของเสีย ${d.scrapPercent}%' : ''}',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editComponent(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeComponent(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildOutputsSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Co-products (${_outputs.length})' : 'ผลิตภัณฑ์ร่วม (${_outputs.length})',
      initiallyExpanded: false,
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add co-product' : 'เพิ่มผลิตภัณฑ์ร่วม', onPressed: _addOutput),
      children: [
        Text(
          isEnglish
              ? 'Extra outputs produced alongside the main item above (e.g. by-products) — leave empty for a single-output BOM'
              : 'ผลผลิตอื่นที่ได้พร้อมกับสินค้าหลักด้านบน (เช่น ผลพลอยได้) — เว้นว่างได้ถ้าสูตรนี้มีผลผลิตเดียว',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        if (_outputs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(isEnglish ? 'No co-products' : 'ไม่มีผลิตภัณฑ์ร่วม', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._outputs.asMap().entries.map((entry) {
            final i = entry.key;
            final o = entry.value;
            final name = isEnglish && (o.outputItemNameEn ?? '').isNotEmpty ? o.outputItemNameEn : o.outputItemNameTh;
            final uomName = isEnglish && (o.uomNameEn ?? '').isNotEmpty ? o.uomNameEn : (o.uomNameTh ?? o.uomCode ?? '');
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: Colors.indigo.shade50, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.indigo))),
                title: Text('${o.outputItemCode}  $name'),
                subtitle: Text(isEnglish ? 'Qty per batch: ${o.outputQtyPer} $uomName' : 'จำนวนต่อรอบผลิต: ${o.outputQtyPer} $uomName'),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editOutput(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeOutput(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildOperationsSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Routing (${_operations.length})' : 'ขั้นตอนการผลิต (${_operations.length})',
      initiallyExpanded: false,
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add operation' : 'เพิ่มขั้นตอนการผลิต', onPressed: _addOperation),
      children: [
        if (_operations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(isEnglish ? 'No operations yet' : 'ยังไม่มีขั้นตอนการผลิต', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._operations.asMap().entries.map((entry) {
            final i = entry.key;
            final op = entry.value;
            final wcName = isEnglish && (op.workCenterNameEn ?? '').isNotEmpty ? op.workCenterNameEn : op.workCenterNameTh;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: Colors.brown.shade50, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.brown))),
                title: Text('${op.workCenterCode}  $wcName${(op.operationName ?? '').isNotEmpty ? ' — ${op.operationName}' : ''}'),
                subtitle: Text(
                  isEnglish
                      ? 'Labor ${op.standardLaborHours} hr · Machine ${op.standardMachineHours} hr${op.setupHours > 0 ? ' · Setup ${op.setupHours} hr' : ''}'
                      : 'แรงงาน ${op.standardLaborHours} ชม. · เครื่องจักร ${op.standardMachineHours} ชม.${op.setupHours > 0 ? ' · ติดตั้ง ${op.setupHours} ชม.' : ''}',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editOperation(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeOperation(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    _isEnglish = isEnglish;
    if (widget.isPlaceholder) {
      return Center(child: Text(isEnglish ? 'Select a BOM to view its data' : 'เลือกสูตรการผลิตเพื่อดูข้อมูล', style: const TextStyle(color: Colors.grey)));
    }

    return Form(
      key: _formKey,
      child: Column(children: [
        Container(
          color: Colors.teal[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.precision_manufacturing, color: Colors.teal[900], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.mode == Mode.add
                    ? (isEnglish ? 'Add BOM' : 'เพิ่มสูตรการผลิต')
                    : widget.mode == Mode.edit
                        ? (isEnglish ? 'Edit BOM' : 'แก้ไขสูตรการผลิต')
                        : (isEnglish ? 'BOM Information' : 'ข้อมูลสูตรการผลิต'),
                style: TextStyle(color: Colors.teal[900], fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (!_isReadOnly) ...[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 16),
                label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด', style: TextStyle(color: Colors.teal[900]))),
          ]),
        ),
        Expanded(
          child: ListView(children: [
            _buildBasicSection(),
            _buildCostingSection(),
            _buildComponentsSection(),
            _buildOutputsSection(),
            if (_costingMode == 'ROUTING') _buildOperationsSection(),
          ]),
        ),
      ]),
    );
  }
}
