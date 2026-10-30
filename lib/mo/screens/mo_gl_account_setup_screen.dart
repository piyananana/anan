import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/mo_gl_account_setup.dart';
import '../services/mo_gl_account_setup_service.dart';

// ตั้งค่าบัญชีของประเภทเอกสารใบสั่งผลิต — WIP / ผลต่าง / ค่าแรงและโสหุ้ยที่ปันเข้างาน + เอกสาร GL
// (ชุดเดียวต่อใบสั่งผลิต ใช้กับ MOI/MOR ที่อ้างอิงใบสั่งผลิต บันทึกเวลา และปิดใบสั่งผลิต)
class MoGlAccountSetupScreen extends StatefulWidget {
  const MoGlAccountSetupScreen({super.key});

  @override
  State<MoGlAccountSetupScreen> createState() => _MoGlAccountSetupScreenState();
}

class _MoGlAccountSetupScreenState extends State<MoGlAccountSetupScreen> with AutomaticKeepAliveClientMixin {
  final _svc = MoGlAccountSetupService();
  final _acctSvc = AccountService();
  final _docSvc = ModuleDocumentService();

  List<MoGlAccountSetup> _rows = [];
  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];
  bool _isEnglish = false;
  bool _isLoading = true;
  String _selectedDocCode = '';
  bool _isLeftPanelExpanded = true;
  bool _isDraggingDivider = false;
  double _leftPanelWidth = 320.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([_svc.fetchRows(), _acctSvc.fetchRows(), _docSvc.fetchRows()]);
      setState(() {
        _rows = results[0] as List<MoGlAccountSetup>;
        _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _glDocs = (results[2] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        _isLoading = false;
        if (_rows.isNotEmpty && _selectedDocCode.isEmpty) _selectedDocCode = _rows.first.docCode;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  MoGlAccountSetup? get _selected => _rows.where((r) => r.docCode == _selectedDocCode).firstOrNull;

  Future<T?> _pickFromList<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
  }) async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<T> filtered = List.from(items);
    T? picked;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty ? List.from(items) : items.where((x) => label(x).toLowerCase().contains(lq)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(label(filtered[i]), style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      picked = filtered[i];
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  String _acctLabel(Account a) => '${a.accountCode}  ${_isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai}';
  String _docLabel(ModuleDocument d) => '${d.docCode}  ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  Future<void> _onSave(MoGlAccountSetup updated) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.upsertRow(updated.docCode, updated);
      setState(() {
        final idx = _rows.indexWhere((r) => r.docCode == saved.docCode);
        if (idx >= 0) _rows[idx] = saved;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), tooltip: isEnglish ? 'Reload' : 'โหลดใหม่', onPressed: _loadAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (ctx, constraints) {
              final maxLeft = (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 36,
                  color: Colors.blue[700],
                  child: IconButton(
                    icon: Icon(_isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse list' : 'ย่อรายการ') : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                  ),
                ),
                AnimatedContainer(
                  duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                  width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftPanelWidth,
                      minWidth: _leftPanelWidth,
                      alignment: Alignment.topLeft,
                      child: Container(color: Colors.blueGrey.shade100, child: _buildLeftPanel()),
                    ),
                  ),
                ),
                if (_isLeftPanelExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() => _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft)),
                      onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                Expanded(
                  child: _selected == null
                      ? Center(child: Text(isEnglish ? 'Select a manufacturing order document type on the left' : 'เลือกประเภทเอกสารใบสั่งผลิตด้านซ้าย'))
                      : _MoGlSetupForm(
                          key: ValueKey(_selected!.docCode),
                          setup: _selected!,
                          pickAccount: (title) => _pickFromList<Account>(title: title, items: _accounts, label: _acctLabel),
                          pickGlDoc: () => _pickFromList<ModuleDocument>(
                              title: isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL', items: _glDocs, label: _docLabel),
                          onSave: _onSave,
                        ),
                ),
              ]);
            }),
    );
  }

  Widget _buildLeftPanel() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _rows.length,
      itemBuilder: (ctx, i) {
        final row = _rows[i];
        final isSelected = row.docCode == _selectedDocCode;
        final docName = _isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? '—');
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isSelected ? Colors.blue.shade50 : null,
          shape: isSelected
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.blue.shade400, width: 1.5))
              : null,
          child: ListTile(
            dense: true,
            onTap: () => setState(() => _selectedDocCode = row.docCode),
            leading: Icon(row.isConfigured ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18, color: row.isConfigured ? Colors.green : Colors.grey),
            title: Text(row.docCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.blue[800] : null)),
            subtitle: Text(docName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
          ),
        );
      },
    );
  }
}

class _MoGlSetupForm extends StatefulWidget {
  final MoGlAccountSetup setup;
  final Future<Account?> Function(String title) pickAccount;
  final Future<ModuleDocument?> Function() pickGlDoc;
  final Future<void> Function(MoGlAccountSetup) onSave;

  const _MoGlSetupForm({super.key, required this.setup, required this.pickAccount, required this.pickGlDoc, required this.onSave});

  @override
  State<_MoGlSetupForm> createState() => _MoGlSetupFormState();
}

class _MoGlSetupFormState extends State<_MoGlSetupForm> {
  late Map<String, ({int? id, String? code, String? name})> _accts;
  int? _glDocId;
  String? _glDocCode;
  String? _glDocName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accts = Map.of(widget.setup.accounts);
    _glDocId = widget.setup.glDocId;
    _glDocCode = widget.setup.glDocCode;
    _glDocName = widget.setup.glDocName;
  }

  // ป้ายช่องบัญชี + คำอธิบายว่าใช้ตอนไหน
  static const _labels = {
    'wip_account_id': ('งานระหว่างผลิต (WIP)', 'Work in process (WIP)',
        'Dr ตอนเบิกวัตถุดิบ (MOI) และบันทึกเวลา / Cr ตอนรับสินค้าจากการผลิต (MOR)',
        'Debited by material issue (MOI) and time logs; credited by production receipt (MOR)'),
    'variance_account_id': ('ผลต่างต้นทุนการผลิต', 'Manufacturing cost variance',
        'ผลต่างต้นทุนมาตรฐานกับต้นทุนจริงตอน MOR และ WIP คงเหลือตอนปิดใบสั่งผลิต',
        'Standard vs actual cost at MOR, and the WIP left over when the order is closed'),
    'applied_labor_account_id': ('ค่าแรงที่ปันเข้างาน', 'Applied labor',
        'Cr ตอนบันทึกเวลา (ชั่วโมงแรงงาน x อัตราค่าแรงของศูนย์งาน)',
        'Credited by time logs (labor hours x work center labor rate)'),
    'applied_overhead_account_id': ('โสหุ้ยการผลิตที่ปันเข้างาน', 'Applied manufacturing overhead',
        'Cr ตอนบันทึกเวลา (ชั่วโมงเครื่องจักร x อัตราเครื่องจักร+โสหุ้ย) หรือตอน MOR สำหรับโสหุ้ยแบบ %',
        'Credited by time logs (machine hours x machine + overhead rate), or at MOR for percentage overhead'),
  };

  Widget _field({required String label, required String hint, required String? value, required VoidCallback onTap, VoidCallback? onClear}) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (onClear != null)
                IconButton(icon: const Icon(Icons.clear, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
              const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.account_tree_outlined, size: 18)),
            ]),
          ),
          child: Text(value ?? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: TextStyle(fontSize: 13, color: value != null ? null : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(MoGlAccountSetup(
        docCode: widget.setup.docCode,
        docNameThai: widget.setup.docNameThai,
        docNameEng: widget.setup.docNameEng,
        glDocId: _glDocId,
        glDocCode: _glDocCode,
        glDocName: _glDocName,
        accounts: _accts,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final s = widget.setup;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.docCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(isEnglish && (s.docNameEng ?? '').isNotEmpty ? s.docNameEng! : (s.docNameThai ?? ''),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text(
          isEnglish
              ? 'One account set per manufacturing order: material issues (MOI) and production receipts (MOR) that reference the order, time logs and order closing all use these accounts.'
              : 'ชุดบัญชีเดียวต่อใบสั่งผลิต: เบิกวัตถุดิบ (MOI) และรับสินค้าจากการผลิต (MOR) ที่อ้างอิงใบสั่งผลิต การบันทึกเวลา และการปิดใบสั่งผลิต ใช้บัญชีเหล่านี้ทั้งหมด',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
        ),
        const SizedBox(height: 16),
        _field(
          label: isEnglish ? 'GL Document Type (time logs and order closing)' : 'ประเภทเอกสาร GL (บันทึกเวลาและปิดใบสั่งผลิต)',
          hint: isEnglish ? 'MOI/MOR use the GL document type of their IM document type' : 'MOI/MOR ใช้ประเภทเอกสาร GL ของประเภทเอกสาร IM ของตัวเอง',
          value: _glDocId != null ? '$_glDocCode  ${_glDocName ?? ''}' : null,
          onTap: () async {
            final d = await widget.pickGlDoc();
            if (d != null) setState(() { _glDocId = d.id; _glDocCode = d.docCode; _glDocName = isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai; });
          },
          onClear: _glDocId == null ? null : () => setState(() { _glDocId = null; _glDocCode = null; _glDocName = null; }),
        ),
        for (final k in MoGlAccountSetup.accountKeys)
          _field(
            label: isEnglish ? _labels[k]!.$2 : _labels[k]!.$1,
            hint: isEnglish ? _labels[k]!.$4 : _labels[k]!.$3,
            value: _accts[k]!.id != null ? '${_accts[k]!.code}  ${_accts[k]!.name ?? ''}' : null,
            onTap: () async {
              final a = await widget.pickAccount(isEnglish ? _labels[k]!.$2 : _labels[k]!.$1);
              if (a != null) {
                setState(() => _accts[k] = (id: a.id, code: a.accountCode,
                    name: isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai));
              }
            },
            onClear: _accts[k]!.id == null ? null : () => setState(() => _accts[k] = (id: null, code: null, name: null)),
          ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || !(MenuScope.of(context)?.canEdit ?? true)) ? null : _submit,
            icon: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ]),
    );
  }
}
