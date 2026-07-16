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
  List<ModuleDocument> _treeRoots = [];
  Map<int, List<ModuleDocument>> _children = {};
  Map<int, DocNumberBranchConfig> _configMap = {};
  bool _loadingTree = false;

  // ---- Right panel ----
  ModuleDocument? _activeDoc;
  DocNumberBranchConfig? _activeCfg;
  bool _isEnabled    = false;
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
      final isEnglish = mounted
          ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
          : false;
      _snack(isEnglish ? 'Cannot load branches: $e' : 'โหลดสาขาล้มเหลว: $e', error: true);
    }
  }

  Future<void> _loadTree(Branch branch) async {
    setState(() { _loadingTree = true; _treeRoots = []; _children = {}; _configMap = {}; _activeDoc = null; _activeCfg = null; });
    try {
      final docs    = await _service.fetchAllDocTypes();
      final configs = await _service.fetchByBranch(branch.id!);

      final cfgMap = <int, DocNumberBranchConfig>{
        for (final c in configs.where((c) => c.hasConfig)) c.docId: c,
      };

      final childrenMap = <int, List<ModuleDocument>>{};
      final roots = <ModuleDocument>[];
      for (final d in docs) {
        if (d.parentId == null) {
          roots.add(d);
        } else {
          childrenMap.putIfAbsent(d.parentId!, () => []).add(d);
        }
      }
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
      final isEnglish = mounted
          ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
          : false;
      if (mounted) _snack(isEnglish ? 'Cannot load data: $e' : 'โหลดข้อมูลล้มเหลว: $e', error: true);
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
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
                b.branchNameThai.toLowerCase().contains(lq) ||
                b.branchNameEng.toLowerCase().contains(lq)).toList();
            }
          });
        }
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.business, size: 20, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text(isEnglish ? 'Select Branch' : 'เลือกสาขา'),
          ]),
          content: SizedBox(
            width: 440, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                        style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final b = filtered[i];
                          final sel = _selectedBranch?.id == b.id;
                          final displayName = isEnglish && b.branchNameEng.isNotEmpty
                              ? b.branchNameEng
                              : b.branchNameThai;
                          return ListTile(
                            dense: true,
                            selected: sel,
                            selectedTileColor: Colors.deepOrange.shade50,
                            leading: sel
                                ? const Icon(Icons.check_circle, color: Colors.deepOrange, size: 18)
                                : const SizedBox(width: 18),
                            title: Text('${b.branchCode}  $displayName',
                                style: const TextStyle(fontSize: 14)),
                            onTap: () => Navigator.of(ctx).pop(b),
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isEnglish ? 'Close' : 'ปิด'),
            ),
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

  // ─────────────────────────── Right panel logic ───────────────────────────

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
    final isEnglish = mounted
        ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
        : false;
    try {
      if (!_isEnabled) {
        if (_activeCfg != null) {
          await _service.deleteSingle(
              branchId: _selectedBranch!.id!, docId: _activeDoc!.id);
        }
      } else {
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
      if (_activeDoc != null) _openConfig(_activeDoc!);
      _snack(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ');
    } catch (e) {
      _snack(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _deleteConfig(ModuleDocument doc) async {
    final isEnglish = mounted
        ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
        : false;
    final l = AppL10n(isEnglish);
    if (_selectedBranch == null) return;
    final docName = isEnglish && doc.docNameEng.isNotEmpty ? doc.docNameEng : doc.docNameThai;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(
          isEnglish
              ? 'Delete branch config for "$docName"?\nThe system will revert to using the global counter.'
              : 'ลบการตั้งค่าสาขาสำหรับ "$docName" ?\nระบบจะกลับไปใช้ counter ทั้งระบบแทน',
        ),
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
      _snack(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ');
    } catch (e) {
      _snack(isEnglish ? 'Delete failed: $e' : 'ลบล้มเหลว: $e', error: true);
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
            onPressed: _selectedBranch == null ? null : () => _loadTree(_selectedBranch!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        _buildBranchSelector(isEnglish),
        const Divider(height: 1),
        Expanded(child: _buildMainPanels(isEnglish, l)),
      ]),
    );
  }

  Widget _buildBranchSelector(bool isEnglish) {
    final branchDisplayName = _selectedBranch == null
        ? null
        : (isEnglish && _selectedBranch!.branchNameEng.isNotEmpty
            ? _selectedBranch!.branchNameEng
            : _selectedBranch!.branchNameThai);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.business, size: 18, color: Colors.deepOrange),
        const SizedBox(width: 8),
        Text(
          isEnglish ? 'Branch:' : 'สาขา:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
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
                branchDisplayName != null
                    ? '${_selectedBranch!.branchCode}  $branchDisplayName'
                    : (isEnglish ? '— Click to select branch —' : '— คลิกเพื่อเลือกสาขา —'),
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

  Widget _buildMainPanels(bool isEnglish, AppL10n l) {
    if (_selectedBranch == null) {
      return Center(
        child: Text(
          isEnglish ? 'Select a branch to view settings' : 'เลือกสาขาเพื่อดูการตั้งค่า',
          style: const TextStyle(color: Colors.grey),
        ),
      );
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
            tooltip: _isLeftPanelExpanded
                ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
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
                child: _buildTree(isEnglish),
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
        Expanded(child: _buildRightPanel(isEnglish, l)),
      ]);
    });
  }

  // ─────────────────────────── Tree ───────────────────────────

  Widget _buildTree(bool isEnglish) {
    if (_treeRoots.isEmpty) {
      return Center(
        child: Text(
          isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _treeRoots.length,
      itemBuilder: (_, i) => _buildRootNode(_treeRoots[i], isEnglish),
    );
  }

  Widget _buildRootNode(ModuleDocument root, bool isEnglish) {
    final kids = _children[root.id] ?? [];
    final displayName = isEnglish && root.docNameEng.isNotEmpty ? root.docNameEng : root.docNameThai;
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.folder, color: Colors.deepOrange, size: 20),
      title: Text(
        '${root.docCode}  $displayName',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: kids.map((child) => _buildChildNode(child, isEnglish)).toList(),
    );
  }

  Widget _buildChildNode(ModuleDocument doc, bool isEnglish) {
    final kids = _children[doc.id] ?? [];
    final displayName = isEnglish && doc.docNameEng.isNotEmpty ? doc.docNameEng : doc.docNameThai;

    if (kids.isNotEmpty) {
      return ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.folder_open, color: Colors.blueGrey, size: 18),
        title: Text(
          '${doc.docCode}  $displayName',
          style: const TextStyle(fontSize: 16),
        ),
        childrenPadding: const EdgeInsets.only(left: 16),
        children: kids.map((c) => _buildChildNode(c, isEnglish)).toList(),
      );
    }

    final isDocType       = doc.isDocType;
    final isAutoNumbering = doc.isAutoNumbering;
    final hasCfg    = _configMap.containsKey(doc.id);
    final isSelected = _activeDoc?.id == doc.id;

    if (!isDocType || !isAutoNumbering) {
      return ListTile(
        dense: true,
        selected: false,
        leading: Icon(
          isDocType ? Icons.description_outlined : Icons.label_outline,
          size: 16,
          color: Colors.grey[400],
        ),
        title: Text(
          '${doc.docCode}  $displayName',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
        subtitle: isDocType && !isAutoNumbering
            ? Text(
                isEnglish ? 'Not using auto numbering' : 'ไม่ใช้เลขอัตโนมัติ',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              )
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
          '${doc.docCode}  $displayName',
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
            : Text(
                isEnglish ? 'Using global counter' : 'ใช้ counter ทั้งระบบ',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!hasCfg)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.teal),
              tooltip: isEnglish ? 'Add branch config' : 'เพิ่มการตั้งค่าสาขา',
              onPressed: () => _openConfig(doc, isNew: true),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
              tooltip: isEnglish ? 'Edit config' : 'แก้ไขการตั้งค่า',
              onPressed: () => _openConfig(doc),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              tooltip: isEnglish ? 'Delete branch config' : 'ลบการตั้งค่าสาขา',
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

  Widget _buildRightPanel(bool isEnglish, AppL10n l) {
    if (_activeDoc == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_list_numbered, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            isEnglish
                ? 'Click + or the edit icon\non a document type on the left'
                : 'คลิก + หรือ ไอคอนแก้ไข\nบนประเภทเอกสารทางซ้าย',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ]),
      );
    }

    final doc = _activeDoc!;
    final cfg = _configMap[doc.id];
    final docDisplayName  = isEnglish && doc.docNameEng.isNotEmpty ? doc.docNameEng : doc.docNameThai;
    final branchDisplayName = isEnglish && _selectedBranch!.branchNameEng.isNotEmpty
        ? _selectedBranch!.branchNameEng
        : _selectedBranch!.branchNameThai;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title
        Text(
          '${doc.docCode}  $docDisplayName',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${isEnglish ? 'Branch' : 'สาขา'}: ${_selectedBranch!.branchCode} $branchDisplayName',
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
            isEnglish
                ? 'Branch auto document no.: ${_isEnabled ? 'Yes (separate branch counter)' : 'No (use global counter)'}'
                : 'เลขที่เอกสารอัตโนมัติสาขา: ${_isEnabled ? 'ใช่ (แยก counter ของสาขา)' : 'ไม่ (ใช้ counter ทั้งระบบ)'}',
          ),
          trailing: Switch(
            value: _isEnabled,
            activeColor: Colors.deepOrange[700],
            onChanged: (v) {
              setState(() {
                _isEnabled = v;
                if (v && cfg == null) {
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextFormField(
              controller: _prefixCtrl,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Prefix' : 'คำนำหน้า',
                hintText: '(global: ${doc.formatPrefix})',
                border: const OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _suffixDate,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Date suffix (YYYYMMDD)' : 'คำต่อ(ปีเดือนวัน)',
                border: const OutlineInputBorder(),
              ),
              items: ['', 'YY', 'YYYY', 'YYMM', 'YYYYMM', 'YYMMDD']
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.isEmpty ? (isEnglish ? '— None —' : '— ไม่ระบุ —') : v)))
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
                labelText: isEnglish ? 'Separator' : 'อักษรคั่น',
                hintText: '(global: ${doc.formatSeparator})',
                border: const OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(
              isExpanded: true,
              value: _runningLen,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Number length' : 'ความยาวเลขที่',
                border: const OutlineInputBorder(),
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
              decoration: InputDecoration(
                labelText: isEnglish ? 'Next number' : 'เลขที่ถัดไป',
                border: const OutlineInputBorder(),
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
            decoration: InputDecoration(
              labelText: isEnglish ? 'Sample auto document no.' : 'ตัวอย่างเลขที่เอกสารอัตโนมัติ',
              border: const OutlineInputBorder(),
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
            label: Text(_savingConfig ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : l.save),
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
