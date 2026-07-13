import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';
import '../models/sa_doc_number_branch.dart';
import '../models/sa_module_document.dart';
import '../services/sa_doc_number_branch_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';

class DocNumberBranchSetupScreen extends StatefulWidget {
  const DocNumberBranchSetupScreen({super.key});

  @override
  State<DocNumberBranchSetupScreen> createState() => _DocNumberBranchSetupScreenState();
}

class _DocNumberBranchSetupScreenState extends State<DocNumberBranchSetupScreen> {
  final _service      = DocNumberBranchService();
  final _branchService = BranchService();

  // ---- Branch ----
  List<Branch> _branches = [];
  Branch? _selectedBranch;

  // ---- Tree data ----
  List<ModuleDocument> _treeRoots = [];       // root nodes (parentId=null)
  Map<int, List<ModuleDocument>> _children = {}; // parentId → children
  Map<int, DocNumberBranchConfig> _configMap = {}; // docId → config
  bool _loadingTree = false;

  // ---- Right panel ----
  ModuleDocument? _activeDoc;        // currently selected doc type (for config)
  DocNumberBranchConfig? _activeCfg; // existing config (null = creating new)
  bool _isEnabled    = false;        // switch: เลขที่เอกสารอัตโนมัติ?
  bool _savingConfig = false;

  // Form controllers (right panel)
  final _prefixCtrl    = TextEditingController();
  final _separatorCtrl = TextEditingController();
  final _nextCtrl      = TextEditingController(text: '1');
  final _previewCtrl   = TextEditingController();
  String _suffixDate   = '';
  int    _runningLen   = 4;

  // ---- Layout ----
  bool   _isLeftPanelExpanded = true;
  double _leftPanelWidth      = 360.0;
  bool   _isDraggingDivider   = false;

  @override
  void initState() {
    super.initState();
    _prefixCtrl.addListener(_updatePreview);
    _separatorCtrl.addListener(_updatePreview);
    _nextCtrl.addListener(_updatePreview);
    _loadBranches();
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _separatorCtrl.dispose();
    _nextCtrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────── Data loading ───────────────────────────

  Future<void> _loadBranches() async {
    try {
      final list = await _branchService.fetchRows();
      setState(() {
        _branches = list.where((b) => b.isActive).toList()
          ..sort((a, b) => a.branchCode.compareTo(b.branchCode));
      });
    } catch (e) {
      _snack('โหลดสาขาล้มเหลว: $e', error: true);
    }
  }

  Future<void> _loadTree(Branch branch) async {
    setState(() { _loadingTree = true; _treeRoots = []; _children = {}; _configMap = {}; _activeDoc = null; _activeCfg = null; });
    try {
      final docs    = await _service.fetchAllDocTypes();
      final configs = await _service.fetchByBranch(branch.id!);

      // Build config map — เฉพาะที่มีการตั้งค่าสาขาแล้ว (hasConfig=true)
      final cfgMap = <int, DocNumberBranchConfig>{
        for (final c in configs.where((c) => c.hasConfig)) c.docId: c,
      };

      // Build tree
      final childrenMap = <int, List<ModuleDocument>>{};
      final roots = <ModuleDocument>[];
      for (final d in docs) {
        if (d.parentId == null) {
          roots.add(d);
        } else {
          childrenMap.putIfAbsent(d.parentId!, () => []).add(d);
        }
      }
      // Sort by sortOrder
      roots.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final list in childrenMap.values) {
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }

      setState(() {
        _treeRoots  = roots;
        _children   = childrenMap;
        _configMap  = cfgMap;
        _loadingTree = false;
      });
    } catch (e) {
      if (mounted) _snack('โหลดข้อมูลล้มเหลว: $e', error: true);
      if (mounted) setState(() => _loadingTree = false);
    }
  }

  Future<void> _reloadConfigs() async {
    if (_selectedBranch == null) return;
    try {
      final configs = await _service.fetchByBranch(_selectedBranch!.id!);
      setState(() {
        _configMap = { for (final c in configs.where((c) => c.hasConfig)) c.docId: c };
      });
    } catch (_) {}
  }

  // ─────────────────────────── Branch picker dialog ───────────────────────────

  Future<void> _showBranchDialog() async {
    final searchCtrl = TextEditingController();
    List<Branch> filtered = List.from(_branches);

    final result = await showDialog<Branch>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            if (q.isEmpty) {
              filtered = List.from(_branches);
            } else {
              final lq = q.toLowerCase();
              filtered = _branches.where((b) =>
                b.branchCode.toLowerCase().contains(lq) ||
                b.branchNameThai.toLowerCase().contains(lq)).toList();
            }
          });
        }
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.business, size: 20, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('เลือกสาขา'),
          ]),
          content: SizedBox(
            width: 440, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อ',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final b = filtered[i];
                          final sel = _selectedBranch?.id == b.id;
                          return ListTile(
                            dense: true,
                            selected: sel,
                            selectedTileColor: Colors.deepOrange.shade50,
                            leading: sel
                                ? const Icon(Icons.check_circle, color: Colors.deepOrange, size: 18)
                                : const SizedBox(width: 18),
                            title: Text('${b.branchCode}  ${b.branchNameThai}',
                                style: const TextStyle(fontSize: 14)),
                            onTap: () => Navigator.of(ctx).pop(b),
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    if (result != null && mounted) {
      setState(() => _selectedBranch = result);
      _loadTree(result);
    }
  }

  // ─────────────────────────── Right panel ───────────────────────────

  void _openConfig(ModuleDocument doc, {bool isNew = false}) {
    final cfg = _configMap[doc.id];
    setState(() {
      _activeDoc  = doc;
      _activeCfg  = cfg;
      _isEnabled  = cfg != null;
      _prefixCtrl.text    = cfg?.formatPrefix    ?? '';
      _separatorCtrl.text = cfg?.formatSeparator ?? '';
      _suffixDate  = cfg?.formatSuffixDate ?? '';
      _runningLen  = cfg?.runningLength    ?? doc.runningLength;
      _nextCtrl.text = cfg?.nextRunningNumber.toString() ?? '1';
    });
    _updatePreview();
  }

  void _updatePreview() {
    if (_activeDoc == null || !_isEnabled) {
      _previewCtrl.text = '';
      return;
    }
    final prefix = _prefixCtrl.text.isEmpty
        ? (_activeCfg?.globalPrefix ?? _activeDoc!.formatPrefix)
        : _prefixCtrl.text;
    final sep = _separatorCtrl.text.isEmpty
        ? (_activeCfg?.globalSeparator ?? _activeDoc!.formatSeparator)
        : _separatorCtrl.text;
    final eff = _suffixDate.isEmpty
        ? (_activeCfg?.globalSuffixDate ?? _activeDoc!.formatSuffixDate)
        : _suffixDate;
    final now = DateTime.now();
    final y4  = now.year.toString();
    final y2  = y4.substring(2);
    final mm  = now.month.toString().padLeft(2, '0');
    final dd  = now.day.toString().padLeft(2, '0');
    String datePart = '';
    switch (eff) {
      case 'YY':       datePart = y2; break;
      case 'YYYY':     datePart = y4; break;
      case 'YYMM':     datePart = '$y2$mm'; break;
      case 'YYYYMM':   datePart = '$y4$mm'; break;
      case 'YYMMDD':   datePart = '$y2$mm$dd'; break;
    }
    final next = int.tryParse(_nextCtrl.text) ?? 1;
    _previewCtrl.text = '$prefix$datePart$sep${next.toString().padLeft(_runningLen, '0')}';
  }

  Future<void> _saveConfig() async {
    if (_activeDoc == null || _selectedBranch == null) return;
    setState(() => _savingConfig = true);
    try {
      if (!_isEnabled) {
        // Delete config (use global counter)
        if (_activeCfg != null) {
          await _service.deleteSingle(
              branchId: _selectedBranch!.id!, docId: _activeDoc!.id);
        }
      } else {
        // Upsert single config
        await _service.upsertSingle(
          branchId: _selectedBranch!.id!,
          docId: _activeDoc!.id,
          formatPrefix:      _prefixCtrl.text.isEmpty    ? null : _prefixCtrl.text,
          formatSeparator:   _separatorCtrl.text.isEmpty ? null : _separatorCtrl.text,
          formatSuffixDate:  _suffixDate.isEmpty         ? null : _suffixDate,
          runningLength:     _runningLen,
          nextRunningNumber: int.tryParse(_nextCtrl.text) ?? 1,
        );
      }
      await _reloadConfigs();
      // Re-open to refresh activeCfg
      if (_activeDoc != null) _openConfig(_activeDoc!);
      _snack('บันทึกสำเร็จ');
    } catch (e) {
      _snack('บันทึกล้มเหลว: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _deleteConfig(ModuleDocument doc) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_selectedBranch == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบการตั้งค่าสาขาสำหรับ "${doc.docCode} ${doc.docNameThai}" ?\n'
            'ระบบจะกลับไปใช้ counter ทั้งระบบแทน'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteSingle(branchId: _selectedBranch!.id!, docId: doc.id);
      await _reloadConfigs();
      if (_activeDoc?.id == doc.id) setState(() { _activeDoc = null; _activeCfg = null; });
      _snack('ลบสำเร็จ');
    } catch (e) {
      _snack('ลบล้มเหลว: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  // ─────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _selectedBranch == null ? null : () => _loadTree(_selectedBranch!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // ── Branch selector ──
        _buildBranchSelector(),
        const Divider(height: 1),
        // ── Main 2-panel layout ──
        Expanded(child: _buildMainPanels()),
      ]),
    );
  }

  Widget _buildBranchSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.business, size: 18, color: Colors.deepOrange),
        const SizedBox(width: 8),
        const Text('สาขา:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 12),
        InkWell(
          onTap: _showBranchDialog,
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.search, size: 18),
            ),
            child: SizedBox(
              width: 320,
              child: Text(
                _selectedBranch != null
                    ? '${_selectedBranch!.branchCode}  ${_selectedBranch!.branchNameThai}'
                    : '— คลิกเพื่อเลือกสาขา —',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedBranch == null ? Colors.grey[500] : null,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildMainPanels() {
    if (_selectedBranch == null) {
      return const Center(child: Text('เลือกสาขาเพื่อดูการตั้งค่า',
          style: TextStyle(color: Colors.grey)));
    }
    if (_loadingTree) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, constraints) {
      final maxLeft = (constraints.maxWidth - 36 - 5 - 280).clamp(100.0, double.infinity);
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Toggle button
        Container(
          width: 36,
          color: Colors.deepOrange[900],
          child: IconButton(
            icon: Icon(
              _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
              color: Colors.white, size: 20,
            ),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
            tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
          ),
        ),
        // Left panel
        AnimatedContainer(
          duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
          width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: _leftPanelWidth, minWidth: _leftPanelWidth,
              alignment: Alignment.topLeft,
              child: Container(
                color: Colors.blueGrey[50],
                child: _buildTree(),
              ),
            ),
          ),
        ),
        // Draggable divider
        if (_isLeftPanelExpanded)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
              onHorizontalDragUpdate: (d) => setState(() {
                _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft);
              }),
              onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
              child: Container(width: 5, color: Colors.grey[400]),
            ),
          ),
        // Right panel
        Expanded(child: _buildRightPanel()),
      ]);
    });
  }

  // ─────────────────────────── Tree ───────────────────────────

  Widget _buildTree() {
    if (_treeRoots.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _treeRoots.length,
      itemBuilder: (_, i) => _buildRootNode(_treeRoots[i]),
    );
  }

  Widget _buildRootNode(ModuleDocument root) {
    final kids = _children[root.id] ?? [];
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.folder, color: Colors.deepOrange, size: 20),
      title: Text(
        '${root.docCode}  ${root.docNameThai}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: kids.map((child) => _buildChildNode(child)).toList(),
    );
  }

  Widget _buildChildNode(ModuleDocument doc) {
    final kids = _children[doc.id] ?? [];
    if (kids.isNotEmpty) {
      // Has children → another level
      return ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.folder_open, color: Colors.blueGrey, size: 18),
        title: Text(
          '${doc.docCode}  ${doc.docNameThai}',
          style: const TextStyle(fontSize: 16),
        ),
        childrenPadding: const EdgeInsets.only(left: 16),
        children: kids.map((c) => _buildChildNode(c)).toList(),
      );
    }

    // Leaf node
    final isDocType      = doc.isDocType;
    final isAutoNumbering = doc.isAutoNumbering;
    final hasCfg = _configMap.containsKey(doc.id);
    final isSelected = _activeDoc?.id == doc.id;

    if (!isDocType || !isAutoNumbering) {
      // Non-configurable
      return ListTile(
        dense: true,
        selected: false,
        leading: Icon(
          isDocType ? Icons.description_outlined : Icons.label_outline,
          size: 16,
          color: Colors.grey[400],
        ),
        title: Text(
          '${doc.docCode}  ${doc.docNameThai}',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
        subtitle: isDocType && !isAutoNumbering
            ? Text('ไม่ใช้เลขอัตโนมัติ',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]))
            : null,
      );
    }

    // Configurable leaf
    return Container(
      color: isSelected ? Colors.deepOrange.shade50 : null,
      child: ListTile(
        dense: true,
        selected: isSelected,
        leading: Icon(
          Icons.description,
          size: 16,
          color: hasCfg ? Colors.deepOrange : Colors.teal,
        ),
        title: Text(
          '${doc.docCode}  ${doc.docNameThai}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: hasCfg ? Colors.deepOrange[800] : Colors.teal[800],
          ),
        ),
        subtitle: hasCfg
            ? Text(
                '${_configMap[doc.id]!.effectivePrefix}… counter: ${_configMap[doc.id]!.nextRunningNumber}',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange[400]),
              )
            : Text('ใช้ counter ทั้งระบบ',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!hasCfg)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.teal),
              tooltip: 'เพิ่มการตั้งค่าสาขา',
              onPressed: () => _openConfig(doc, isNew: true),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
              tooltip: 'แก้ไขการตั้งค่า',
              onPressed: () => _openConfig(doc),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              tooltip: 'ลบการตั้งค่าสาขา',
              onPressed: () => _deleteConfig(doc),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ],
        ]),
        onTap: () => _openConfig(doc),
      ),
    );
  }

  // ─────────────────────────── Right panel ───────────────────────────

  Widget _buildRightPanel() {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_activeDoc == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_list_numbered, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'คลิก + หรือ ไอคอนแก้ไข\nบนประเภทเอกสารทางซ้าย',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ]),
      );
    }

    final doc = _activeDoc!;
    final cfg = _configMap[doc.id]; // reload after save

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title
        Text(
          '${doc.docCode}  ${doc.docNameThai}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'สาขา: ${_selectedBranch!.branchCode} ${_selectedBranch!.branchNameThai}',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const Divider(height: 24),

        // Switch: เลขที่เอกสารอัตโนมัติสาขา?
        ListTile(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          title: Text(
            'เลขที่เอกสารอัตโนมัติสาขา: ${_isEnabled ? 'ใช่ (แยก counter ของสาขา)' : 'ไม่ (ใช้ counter ทั้งระบบ)'}',
          ),
          trailing: Switch(
            value: _isEnabled,
            activeColor: Colors.deepOrange[700],
            onChanged: (v) {
              setState(() {
                _isEnabled = v;
                if (v && cfg == null) {
                  // pre-fill with global defaults
                  _prefixCtrl.text    = doc.formatPrefix;
                  _separatorCtrl.text = doc.formatSeparator;
                  _suffixDate  = doc.formatSuffixDate;
                  _runningLen  = doc.runningLength;
                  _nextCtrl.text = '1';
                }
              });
              _updatePreview();
            },
          ),
        ),

        if (_isEnabled) ...[
          const SizedBox(height: 20),
          // Row 1: Prefix | Suffix date | Separator | Length
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextFormField(
              controller: _prefixCtrl,
              decoration: InputDecoration(
                labelText: 'คำนำหน้า',
                hintText: '(global: ${doc.formatPrefix})',
                border: const OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _suffixDate,
              decoration: const InputDecoration(
                labelText: 'คำต่อ(ปีเดือนวัน)',
                border: OutlineInputBorder(),
              ),
              items: ['', 'YY', 'YYYY', 'YYMM', 'YYYYMM', 'YYMMDD']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? '— ไม่ระบุ —' : v)))
                  .toList(),
              onChanged: (v) {
                setState(() => _suffixDate = v ?? '');
                _updatePreview();
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: _separatorCtrl,
              decoration: InputDecoration(
                labelText: 'อักษรคั่น',
                hintText: '(global: ${doc.formatSeparator})',
                border: const OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(
              isExpanded: true,
              value: _runningLen,
              decoration: const InputDecoration(
                labelText: 'ความยาวเลขที่',
                border: OutlineInputBorder(),
              ),
              items: [3, 4, 5, 6, 7, 8, 9]
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _runningLen = v);
                  _updatePreview();
                }
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: _nextCtrl,
              decoration: const InputDecoration(
                labelText: 'เลขที่ถัดไป',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
            )),
          ]),
          const SizedBox(height: 16),
          // Preview
          TextFormField(
            controller: _previewCtrl,
            enabled: false,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'ตัวอย่างเลขที่เอกสารอัตโนมัติ',
              border: OutlineInputBorder(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        // Action buttons
        Row(children: [
          ElevatedButton.icon(
            onPressed: _savingConfig ? null : _saveConfig,
            icon: _savingConfig
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: Text(l.save),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => setState(() { _activeDoc = null; _activeCfg = null; }),
            child: Text(l.cancel),
          ),
        ]),
      ]),
    );
  }
}
