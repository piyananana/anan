// lib/sa/screens/sa_module_approver_screen.dart
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_anan_module.dart' show sysModules;
import '../models/sa_menu.dart';
import '../models/sa_menu_doc_type.dart';
import '../models/sa_module_approver.dart';
import '../models/sa_module_document.dart';
import '../services/sa_menu_service.dart';
import '../services/sa_module_approver_service.dart';
import '../services/sa_module_document_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_menu_scope.dart';

// หน้าจอนี้เป็นจุดตั้งค่าการอนุมัติทั้งหมดในระดับ admin/user (ไม่ใช่ developer):
// - เลือกเมนูที่เปิดใช้การอนุมัติไว้ (requires_approval, ตั้งค่าที่ sa_menu_screen) จาก panel ซ้าย
// - panel ขวา: รูปแบบการอนุมัติ (ALL/ANY), ข้อความอธิบายการอนุมัติ ไทย/อังกฤษ, ลำดับผู้อนุมัติ,
//   และสวิตช์ "ใช้ประเภทเอกสาร" — ถ้าเปิด จะแสดงการ์ดประเภทเอกสารที่เพิ่มได้ผ่าน dialog ค้นหาจาก
//   ตาราง sa_module_document โดยแต่ละการ์ดมีคิวผู้อนุมัติเป็นของตัวเอง
// ผู้มีสิทธิ์อนุมัติแต่ละคนมาจากสิทธิ์ "อนุมัติ" (can_approve) ที่ให้ไว้แล้วในหน้าจอสิทธิ์เมนูผู้ใช้
// โดยอัตโนมัติ ไม่มีการเพิ่ม/ลบคนที่นี่ — ปรับได้แค่ลำดับและงด/ใช้งาน
class SaModuleApproverScreen extends StatefulWidget {
  const SaModuleApproverScreen({super.key});

  @override
  State<SaModuleApproverScreen> createState() => _SaModuleApproverScreenState();
}

class _SaModuleApproverScreenState extends State<SaModuleApproverScreen>
    with AutomaticKeepAliveClientMixin {
  final _menuSvc = MenuService();
  final _approverSvc = SaModuleApproverService();
  final _docSvc = ModuleDocumentService();

  List<Menu> _allMenus = [];
  bool _loadingMenus = true;

  Menu? _selectedMenu;

  // ── Settings buffer (mode / description TH-EN / uses_doc_type) ──
  String _approvalMode = 'ALL';
  final _descThCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();
  bool _usesDocType = false;
  bool _settingsDirty = false;
  bool _savingSettings = false;

  // ── Doc-type cards (when _usesDocType == true) ──
  List<SaMenuDocType> _docTypeCards = [];
  bool _loadingDocTypes = false;
  String? _selectedDocTypeCard; // doc_type ของการ์ดที่เลือกดูคิวผู้อนุมัติ

  // ── Approver queue ──
  List<SaModuleApprover> _approvers = [];
  bool _loadingApprovers = false;
  bool _savingOrder = false;
  bool _orderDirty = false;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 380.0;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  @override
  void dispose() {
    _descThCtrl.dispose();
    _descEnCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenus() async {
    setState(() => _loadingMenus = true);
    try {
      final menus = await _menuSvc.fetchMenus();
      if (!mounted) return;
      setState(() {
        _allMenus = menus;
        _loadingMenus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMenus = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  // เมนูที่ "ไม่มีลูก" (leaf) และเปิดใช้การอนุมัติไว้ (ตั้งค่าจากหน้าจอจัดการเมนู)
  List<Menu> get _approvableMenus {
    final parentIds = _allMenus.map((m) => m.parentId).whereType<int>().toSet();
    final list = _allMenus
        .where((m) => m.requiresApproval && !parentIds.contains(m.id))
        .toList();
    list.sort((a, b) => a.menuName.compareTo(b.menuName));
    return list;
  }

  Future<void> _selectMenu(Menu menu) async {
    setState(() {
      _selectedMenu = menu;
      _approvalMode = menu.approvalMode;
      _descThCtrl.text = menu.approvalDescription ?? '';
      _descEnCtrl.text = menu.approvalDescriptionEn ?? '';
      _usesDocType = menu.usesDocType;
      _settingsDirty = false;
      _selectedDocTypeCard = null;
      _docTypeCards = [];
      _approvers = [];
      _orderDirty = false;
    });
    if (_usesDocType) {
      await _loadDocTypeCards();
    } else {
      await _loadApprovers();
    }
  }

  Future<void> _loadDocTypeCards() async {
    if (_selectedMenu == null) return;
    setState(() => _loadingDocTypes = true);
    try {
      final rows = await _menuSvc.fetchDocTypesForMenu(_selectedMenu!.id);
      if (!mounted) return;
      setState(() {
        _docTypeCards = rows;
        _loadingDocTypes = false;
      });
      // เลือกการ์ดแรกให้อัตโนมัติ เพื่อไม่ให้ section ผู้อนุมัติว่างเปล่าโดยไม่จำเป็น
      if (_selectedDocTypeCard == null && rows.isNotEmpty) {
        await _selectDocTypeCard(rows.first.docType);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDocTypes = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _selectDocTypeCard(String docType) async {
    setState(() {
      _selectedDocTypeCard = docType;
      _approvers = [];
      _orderDirty = false;
    });
    await _loadApprovers();
  }

  Future<void> _loadApprovers() async {
    if (_selectedMenu == null) return;
    setState(() => _loadingApprovers = true);
    try {
      final rows = await _approverSvc.fetchByMenu(_selectedMenu!.id, docType: _selectedDocTypeCard);
      if (!mounted) return;
      setState(() {
        _approvers = rows;
        _loadingApprovers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingApprovers = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedMenu == null) return;
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    setState(() => _savingSettings = true);
    try {
      final updated = await _menuSvc.updateApprovalConfig(
        _selectedMenu!.id,
        approvalMode: _approvalMode,
        approvalDescription: _descThCtrl.text.trim().isEmpty ? null : _descThCtrl.text.trim(),
        approvalDescriptionEn: _descEnCtrl.text.trim().isEmpty ? null : _descEnCtrl.text.trim(),
        usesDocType: _usesDocType,
      );
      if (!mounted) return;
      setState(() {
        // อัปเดต snapshot ใน list เมนูซ้าย ให้ตรงกับค่าที่เพิ่งบันทึก
        final idx = _allMenus.indexWhere((m) => m.id == updated.id);
        if (idx != -1) _allMenus[idx] = updated;
        _selectedMenu = updated;
        _settingsDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Approval settings saved' : 'บันทึกการตั้งค่าการอนุมัติสำเร็จ')));
      if (_usesDocType) {
        await _loadDocTypeCards();
      } else {
        _selectedDocTypeCard = null;
        await _loadApprovers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _addDocTypeCard() async {
    if (_selectedMenu == null) return;
    final picked = await showDialog<ModuleDocument>(
      context: context,
      builder: (ctx) => _DocTypeSearchDialog(docSvc: _docSvc),
    );
    if (picked == null || !mounted) return;
    try {
      await _menuSvc.addDocTypeToMenu(
        _selectedMenu!.id,
        docType: picked.docCode,
        docNameThai: picked.docNameThai,
        docNameEng: picked.docNameEng,
        sysModule: picked.sysModule,
      );
      await _loadDocTypeCards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeDocTypeCard(SaMenuDocType card) async {
    if (_selectedMenu == null) return;
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Remove document type' : 'ลบประเภทเอกสาร'),
        content: Text(isEnglish
            ? 'Remove "${card.localName(true)}" and its approval queue from this menu?'
            : 'ลบประเภทเอกสาร "${card.localName(false)}" และคิวผู้อนุมัติของประเภทนี้ออกจากเมนู?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isEnglish ? 'Remove' : 'ลบ', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _menuSvc.removeDocTypeFromMenu(_selectedMenu!.id, card.docType);
      if (!mounted) return;
      if (_selectedDocTypeCard == card.docType) {
        setState(() {
          _selectedDocTypeCard = null;
          _approvers = [];
        });
      }
      await _loadDocTypeCards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  void _toggleActive(int index, bool value) {
    setState(() {
      _approvers[index] = _approvers[index].copyWith(isActive: value);
      _orderDirty = true;
    });
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _approvers.removeAt(index);
      _approvers.insert(index - 1, item);
      _orderDirty = true;
    });
  }

  void _moveDown(int index) {
    if (index >= _approvers.length - 1) return;
    setState(() {
      final item = _approvers.removeAt(index);
      _approvers.insert(index + 1, item);
      _orderDirty = true;
    });
  }

  void _setApprovalLimit(int index, double value) {
    setState(() {
      _approvers[index] = _approvers[index].copyWith(approvalLimit: value);
      _orderDirty = true;
    });
  }

  Future<void> _pickSignature(int index) async {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    input.onChange.listen((e) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoad.listen((_) {
        if (!mounted) return;
        setState(() {
          _approvers[index] =
              _approvers[index].copyWith(signatureImage: reader.result as String);
          _orderDirty = true;
        });
      });
    });
  }

  Uint8List _decodeSignature(String dataUrl) {
    final data = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return base64Decode(data);
  }

  Future<void> _saveOrder() async {
    if (_selectedMenu == null) return;
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    setState(() => _savingOrder = true);
    try {
      await _approverSvc.reorder(_selectedMenu!.id, _approvers, docType: _selectedDocTypeCard);
      if (!mounted) return;
      setState(() => _orderDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Approval order saved' : 'บันทึกลำดับผู้อนุมัติสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
            onPressed: _loadMenus,
          ),
        ],
      ),
      body: _loadingMenus
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxLeft =
                  (constraints.maxWidth - 36 - 5 - 300).clamp(200.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 36,
                  color: Colors.blueGrey[700],
                  child: IconButton(
                    icon: Icon(
                        _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                        color: Colors.white,
                        size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded
                        ? (isEnglish ? 'Collapse' : 'ย่อรายการ')
                        : (isEnglish ? 'Expand' : 'ขยายรายการ'),
                  ),
                ),
                AnimatedContainer(
                  duration:
                      _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                  width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftPanelWidth,
                      minWidth: _leftPanelWidth,
                      alignment: Alignment.topLeft,
                      child: Container(
                        color: Colors.blueGrey.shade50,
                        child: _approvableMenus.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    isEnglish
                                        ? 'No menu currently has approval enabled.\nGo to Menu Management and turn on "Can have an approver".'
                                        : 'ยังไม่มีเมนูใดเปิดใช้การอนุมัติ\nไปที่จัดการเมนู แล้วเปิดสวิตช์ "มีผู้อนุมัติได้"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _approvableMenus.length,
                                itemBuilder: (ctx, i) {
                                  final m = _approvableMenus[i];
                                  final selected = _selectedMenu?.id == m.id;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    color: selected ? Colors.blueGrey.shade100 : Colors.white,
                                    child: ListTile(
                                      dense: true,
                                      selected: selected,
                                      title: Text(m.localName(isEnglish),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: (m.localApprovalDescription(isEnglish) ?? '').isNotEmpty
                                          ? Text(m.localApprovalDescription(isEnglish)!,
                                              style: const TextStyle(fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis)
                                          : null,
                                      onTap: () => _selectMenu(m),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ),
                if (_isLeftPanelExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() => _leftPanelWidth =
                          (_leftPanelWidth + d.delta.dx).clamp(280.0, maxLeft)),
                      onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[300]),
                    ),
                  ),
                Expanded(child: _buildRightPanel(isEnglish)),
              ]);
            }),
    );
  }

  // ── Right panel ──────────────────────────────────────────────────────────

  Widget _buildRightPanel(bool isEnglish) {
    if (_selectedMenu == null) {
      return Center(
        child: Text(
          isEnglish ? 'Select a menu from the left panel' : 'เลือกเมนูจาก panel ด้านซ้าย',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    final menu = _selectedMenu!;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Colors.blueGrey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(menu.localName(isEnglish),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 1) รูปแบบการอนุมัติ
            Text(isEnglish ? 'Approval mode' : 'รูปแบบการอนุมัติ',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'All approvers must approve, in order' : 'ต้องอนุมัติครบทุกคนตามลำดับ'),
              value: 'ALL',
              groupValue: _approvalMode,
              onChanged: (v) => setState(() {
                _approvalMode = v!;
                _settingsDirty = true;
              }),
            ),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'Any one approver is enough' : 'คนใดคนหนึ่งอนุมัติก็พอ'),
              value: 'ANY',
              groupValue: _approvalMode,
              onChanged: (v) => setState(() {
                _approvalMode = v!;
                _settingsDirty = true;
              }),
            ),
            const SizedBox(height: 12),
            // 2) ข้อความอธิบายการอนุมัติ ไทย/อังกฤษ
            Text(isEnglish ? 'Approval description' : 'ข้อความอธิบายการอนุมัติ',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descThCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Description (Thai)' : 'ข้อความอธิบาย (ไทย)',
                hintText: 'เช่น "ขั้นตอนนี้ต้องการผู้อนุมัติ 2 ท่าน คือ"',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _settingsDirty = true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descEnCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Description (English)' : 'ข้อความอธิบาย (อังกฤษ)',
                hintText: 'e.g. "This step requires 2 approvers:"',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _settingsDirty = true),
            ),
            const SizedBox(height: 12),
            // 4) ใช้ประเภทเอกสาร
            Row(children: [
              Text(isEnglish ? 'Uses document type: ' : 'ใช้ประเภทเอกสาร: ',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Switch(
                value: _usesDocType,
                onChanged: (v) {
                  setState(() {
                    _usesDocType = v;
                    _settingsDirty = true;
                    _selectedDocTypeCard = null;
                    _approvers = [];
                  });
                  if (v) {
                    _loadDocTypeCards();
                  } else {
                    _loadApprovers();
                  }
                },
              ),
              Text(_usesDocType
                  ? (isEnglish ? 'Yes — can add multiple document types below' : 'ใช้ — เพิ่มประเภทเอกสารได้ด้านล่าง')
                  : (isEnglish ? 'No — one approval queue for this menu' : 'ไม่ใช้ — คิวผู้อนุมัติเดียวสำหรับเมนูนี้')),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_settingsDirty && !_savingSettings) ? _saveSettings : null,
                icon: _savingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(isEnglish ? 'Save approval settings' : 'บันทึกการตั้งค่าการอนุมัติ'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (_usesDocType) _buildDocTypeCardSection(isEnglish),
        const Divider(height: 1),
        _buildApproverQueueSection(isEnglish),
      ]),
    );
  }

  Widget _buildDocTypeCardSection(bool isEnglish) {
    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(isEnglish ? 'Document types' : 'ประเภทเอกสาร',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TextButton.icon(
            onPressed: _addDocTypeCard,
            icon: const Icon(Icons.add, size: 18),
            label: Text(isEnglish ? 'Add document type' : 'เพิ่มประเภทเอกสาร'),
          ),
        ]),
        if (_loadingDocTypes)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_docTypeCards.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              isEnglish
                  ? 'No document type added yet. Press "Add document type" to search from the document type table.'
                  : 'ยังไม่มีประเภทเอกสารที่เพิ่มไว้ กดปุ่ม "เพิ่มประเภทเอกสาร" เพื่อค้นหาจากตารางประเภทเอกสาร',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _docTypeCards.map((card) {
              final selected = _selectedDocTypeCard == card.docType;
              return InkWell(
                onTap: () => _selectDocTypeCard(card.docType),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepOrange.shade100 : Colors.white,
                    border: Border.all(
                        color: selected ? Colors.deepOrange : Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined,
                        size: 16, color: selected ? Colors.deepOrange : Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(card.localName(isEnglish), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _removeDocTypeCard(card),
                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
      ]),
    );
  }

  Widget _buildApproverQueueSection(bool isEnglish) {
    if (_usesDocType && _selectedDocTypeCard == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            isEnglish
                ? 'Select a document type card above to view/edit its approval queue'
                : 'เลือกการ์ดประเภทเอกสารด้านบนเพื่อดู/แก้ไขคิวผู้อนุมัติ',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    if (_loadingApprovers) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(isEnglish ? 'Approval queue' : 'ลำดับผู้อนุมัติ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      _approvers.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isEnglish
                    ? 'No user has been granted "Approve" permission for this menu yet.\nGo to User Menu Rights and grant it there.'
                    : 'ยังไม่มีผู้ใช้คนใดได้รับสิทธิ์ "อนุมัติ" สำหรับเมนูนี้\nไปที่สิทธิ์เมนูผู้ใช้ แล้วให้สิทธิ์ก่อน',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _approvers.length,
              itemBuilder: (ctx, i) {
                final a = _approvers[i];
                return Card(
                  key: ValueKey(a.id ?? 'row_$i'),
                  margin: const EdgeInsets.only(bottom: 6),
                  color: a.isActive ? null : Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: a.isActive ? Colors.blueGrey.shade600 : Colors.grey.shade400,
                          child: Text('${i + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(a.approverFullName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: a.isActive ? null : Colors.grey,
                                      decoration: a.isActive ? null : TextDecoration.lineThrough)),
                              if (a.approverEmail != null)
                                Text(a.approverEmail!, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ปุ่มลายเซ็น — คลิกเพื่ออัปโหลด, ถ้ายังไม่มีให้แสดงไอคอนแทน
                        Tooltip(
                          message: isEnglish ? 'Upload signature' : 'อัปโหลดลายเซ็น',
                          child: InkWell(
                            onTap: () => _pickSignature(i),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 52,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: (a.signatureImage ?? '').isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.memory(
                                        _decodeSignature(a.signatureImage!),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.broken_image_outlined,
                                            size: 18,
                                            color: Colors.grey),
                                      ),
                                    )
                                  : Icon(Icons.draw_outlined, size: 18, color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // วงเงินอนุมัติ (0 = ไม่ต้องเช็ควงเงิน) — แสดงด้านขวาของรูปลายเซ็น
                        SizedBox(
                          width: 96,
                          child: TextFormField(
                            key: ValueKey('limit_${a.id ?? i}'),
                            initialValue:
                                a.approvalLimit == 0 ? '' : a.approvalLimit.toStringAsFixed(0),
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              labelText: isEnglish ? 'Limit' : 'วงเงิน',
                              hintText: '0',
                              helperText: isEnglish ? '0 = no check' : '0=ไม่เช็ค',
                              helperStyle: const TextStyle(fontSize: 10),
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (v) => _setApprovalLimit(i, double.tryParse(v) ?? 0),
                          ),
                        ),
                        Tooltip(
                          message: a.isActive
                              ? (isEnglish ? 'Suspend (skip in approval queue)' : 'งดอนุมัติ')
                              : (isEnglish ? 'Reinstate' : 'กลับมาใช้งาน'),
                          child: Switch(value: a.isActive, onChanged: (v) => _toggleActive(i, v)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          tooltip: isEnglish ? 'Move up' : 'เลื่อนขึ้น',
                          onPressed: i == 0 ? null : () => _moveUp(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          tooltip: isEnglish ? 'Move down' : 'เลื่อนลง',
                          onPressed: i == _approvers.length - 1 ? null : () => _moveDown(i),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_orderDirty && !_savingOrder) ? _saveOrder : null,
            icon: _savingOrder
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(isEnglish ? 'Save Order' : 'บันทึกลำดับ'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white),
          ),
        ),
      ),
    ]);
  }
}

// ── Document type search dialog (ค้นหาจากตาราง sa_module_document) ──────────

class _DocTypeSearchDialog extends StatefulWidget {
  final ModuleDocumentService docSvc;
  const _DocTypeSearchDialog({required this.docSvc});

  @override
  State<_DocTypeSearchDialog> createState() => _DocTypeSearchDialogState();
}

class _DocTypeSearchDialogState extends State<_DocTypeSearchDialog> {
  List<ModuleDocument> _allDocs = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.docSvc.fetchRows();
      if (!mounted) return;
      setState(() {
        _allDocs = rows.where((d) => d.isDocType).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final filtered = _allDocs.where((d) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return d.docCode.toLowerCase().contains(q) ||
          d.docNameThai.toLowerCase().contains(q) ||
          d.docNameEng.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          children: [
            Container(
              color: Colors.blueGrey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.search, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEnglish ? 'Search document type' : 'ค้นหาประเภทเอกสาร',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Search by code or name' : 'ค้นหาด้วยรหัสหรือชื่อ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(isEnglish ? 'No document type found' : 'ไม่พบประเภทเอกสาร',
                              style: const TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final d = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(isEnglish
                                  ? (d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai)
                                  : d.docNameThai),
                              subtitle: Text(
                                  '${d.docCode}${d.sysModule.isNotEmpty ? ' · ${sysModules[d.sysModule] ?? d.sysModule}' : ''}'),
                              onTap: () => Navigator.of(context).pop(d),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
