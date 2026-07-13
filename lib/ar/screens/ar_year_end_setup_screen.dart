import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/ar_year_end.dart';
import '../services/ar_year_end_service.dart';

class ArYearEndSetupScreen extends StatefulWidget {
  const ArYearEndSetupScreen({super.key});

  @override
  State<ArYearEndSetupScreen> createState() => _ArYearEndSetupScreenState();
}

class _ArYearEndSetupScreenState extends State<ArYearEndSetupScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ArYearEndService    _svc     = ArYearEndService();
  final AccountService      _acctSvc = AccountService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();

  late TabController _tabController;
  List<Account>        _accounts = [];
  List<ModuleDocument> _glDocs   = [];

  // Setup fields
  int? _fxGainId, _fxLossId, _ufxGainId, _ufxLossId;
  int? _allowExpId, _allowContraId, _fxRevalDocId, _allowDocId;

  // Allowance rules
  List<ArAllowanceRule> _rules = [];

  bool _isLoading = true;
  bool _isSaving  = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetup(),
        _svc.fetchAllowanceRules(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      final setup = results[0] as ArYearEndSetup?;
      setState(() {
        _rules   = List<ArAllowanceRule>.from(results[1] as List);
        _accounts = (results[2] as List<Account>)
            .where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _glDocs  = (results[3] as List<ModuleDocument>)
            .where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        if (setup != null) {
          _fxGainId    = setup.fxGainAccountId;
          _fxLossId    = setup.fxLossAccountId;
          _ufxGainId   = setup.unrealizedFxGainAccountId;
          _ufxLossId   = setup.unrealizedFxLossAccountId;
          _allowExpId  = setup.allowanceExpenseAccountId;
          _allowContraId = setup.allowanceContraAccountId;
          _fxRevalDocId  = setup.fxRevalGlDocId;
          _allowDocId    = setup.allowanceGlDocId;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError(e.toString());
    }
  }

  Account? _findAccount(int? id) => id == null || id == 0
      ? null
      : _accounts.cast<Account?>().firstWhere((a) => a?.id == id, orElse: () => null);

  ModuleDocument? _findDoc(int? id) => id == null || id == 0
      ? null
      : _glDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == id, orElse: () => null);

  // ── Account picker dialog ─────────────────────────────────────────────────
  Future<Account?> _pickAccount(String title) async {
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    Account? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            final lq = q.toLowerCase();
            filtered = q.isEmpty
                ? List.from(_accounts)
                : _accounts.where((a) =>
                    a.accountCode.toLowerCase().contains(lq) ||
                    a.accountNameThai.toLowerCase().contains(lq)).toList();
          });
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${a.accountCode}  ${a.accountNameThai}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ── GL Doc picker dialog ──────────────────────────────────────────────────
  Future<ModuleDocument?> _pickGlDoc() async {
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(_glDocs);
    ModuleDocument? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: const Text('เลือกประเภทเอกสาร GL'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) {
                  setDlg(() {
                    final lq = q.toLowerCase();
                    filtered = q.isEmpty
                        ? List.from(_glDocs)
                        : _glDocs.where((d) =>
                            d.docCode.toLowerCase().contains(lq) ||
                            d.docNameThai.toLowerCase().contains(lq)).toList();
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${d.docCode}  ${d.docNameThai}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _saveSetup() async {
    setState(() => _isSaving = true);
    try {
      final s = ArYearEndSetup(
        fxGainAccountId:           _fxGainId   == 0 ? null : _fxGainId,
        fxLossAccountId:           _fxLossId   == 0 ? null : _fxLossId,
        unrealizedFxGainAccountId: _ufxGainId  == 0 ? null : _ufxGainId,
        unrealizedFxLossAccountId: _ufxLossId  == 0 ? null : _ufxLossId,
        allowanceExpenseAccountId: _allowExpId   == 0 ? null : _allowExpId,
        allowanceContraAccountId:  _allowContraId == 0 ? null : _allowContraId,
        fxRevalGlDocId:            _fxRevalDocId == 0 ? null : _fxRevalDocId,
        allowanceGlDocId:          _allowDocId   == 0 ? null : _allowDocId,
      );
      await _svc.saveSetup(s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ'), backgroundColor: Colors.teal));
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveRules() async {
    setState(() => _isSaving = true);
    try {
      await _svc.saveAllowanceRules(_rules);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ'), backgroundColor: Colors.teal));
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Widget _accountPickerField(String label, int? selectedId, {
    required String dialogTitle,
    required void Function(int?) onChanged,
  }) {
    final acc = _findAccount(selectedId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 260, child: Text(label, style: const TextStyle(fontSize: 14))),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await _pickAccount(dialogTitle);
              if (picked != null) onChanged(picked.id);
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    acc != null ? '${acc.accountCode}  ${acc.accountNameThai}' : '-- ไม่ได้ตั้งค่า --',
                    style: TextStyle(
                      fontSize: 14,
                      color: acc != null ? Colors.black87 : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (acc != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
                  )
                else
                  Icon(Icons.search, size: 16, color: Colors.grey[500]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _docPickerField(String label, int? selectedId, void Function(int?) onChanged) {
    final doc = _findDoc(selectedId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 260, child: Text(label, style: const TextStyle(fontSize: 14))),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await _pickGlDoc();
              if (picked != null) onChanged(picked.id);
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    doc != null ? '${doc.docCode}  ${doc.docNameThai}' : '-- ไม่ได้ตั้งค่า --',
                    style: TextStyle(
                      fontSize: 14,
                      color: doc != null ? Colors.black87 : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (doc != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
                  )
                else
                  Icon(Icons.search, size: 16, color: Colors.grey[500]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSetupTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยนแบบ Realized', 'บัญชีกำไร/ขาดทุนจากอัตราแลกเปลี่ยนที่ปรับจริง'),
      _accountPickerField('บัญชีกำไรอัตราแลกเปลี่ยน', _fxGainId,
          dialogTitle: 'บัญชีกำไรอัตราแลกเปลี่ยน',
          onChanged: (v) => setState(() => _fxGainId = v)),
      _accountPickerField('บัญชีขาดทุนอัตราแลกเปลี่ยน', _fxLossId,
          dialogTitle: 'บัญชีขาดทุนอัตราแลกเปลี่ยน',
          onChanged: (v) => setState(() => _fxLossId = v)),
      const SizedBox(height: 8),
      _sectionHeader('ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยนแบบ Reversing', 'บัญชีกำไร/ขาดทุนจากอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง (กลับรายการต้นงวดใหม่)'),
      _accountPickerField('บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง', _ufxGainId,
          dialogTitle: 'บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง',
          onChanged: (v) => setState(() => _ufxGainId = v)),
      _accountPickerField('บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง', _ufxLossId,
          dialogTitle: 'บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง',
          onChanged: (v) => setState(() => _ufxLossId = v)),
      const SizedBox(height: 8),
      _sectionHeader('ค่าเผื่อหนี้สงสัยจะสูญ', 'บัญชีค่าเผื่อหนี้สงสัยจะสูญ'),
      _accountPickerField('บัญชีค่าเผื่อหนี้สงสัยจะสูญ (ค่าใช้จ่าย)', _allowExpId,
          dialogTitle: 'บัญชีค่าเผื่อหนี้สงสัยจะสูญ (ค่าใช้จ่าย)',
          onChanged: (v) => setState(() => _allowExpId = v)),
      _accountPickerField('บัญชีค่าเผื่อหนี้สงสัยจะสูญสะสม (contra)', _allowContraId,
          dialogTitle: 'บัญชีค่าเผื่อหนี้สงสัยจะสูญสะสม',
          onChanged: (v) => setState(() => _allowContraId = v)),
      const SizedBox(height: 8),
      _sectionHeader('ประเภทเอกสารบัญชีแยกประเภท', 'ประเภทเอกสาร GL ที่ใช้สร้างรายการปรับปรุงในบัญชีแยกประเภท'),
      _docPickerField('ประเภทเอกสารปรับมูลค่าหนี้จากอัตราแลกเปลี่ยน', _fxRevalDocId, (v) => setState(() => _fxRevalDocId = v)),
      _docPickerField('ประเภทเอกสารปรับปรุงค่าเผื่อหนี้สงสัยจะสูญ', _allowDocId, (v) => setState(() => _allowDocId = v)),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _isSaving ? null : _saveSetup,
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('บันทึก'),
        ),
      ),
    ]),
  );

  Widget _buildRulesTab() {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
              columns: const [
                DataColumn(label: Text('อายุหนี้ตั้งแต่ (วัน)')),
                DataColumn(label: Text('อายุหนี้ถึง (วัน)')),
                DataColumn(label: Text('% สำรอง')),
                DataColumn(label: Text('ใช้งาน')),
                DataColumn(label: SizedBox()),
              ],
              rows: _rules.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return DataRow(cells: [
                  DataCell(_numField(r.ageFromDays.toString(), (v) {
                    setState(() => _rules[i] = r.copyWith(ageFromDays: int.tryParse(v) ?? r.ageFromDays));
                  })),
                  DataCell(_numField(r.ageToDays?.toString() ?? '', (v) {
                    setState(() => _rules[i] = ArAllowanceRule(
                      id: r.id, ageFromDays: r.ageFromDays,
                      ageToDays: v.isEmpty ? null : int.tryParse(v),
                      rate: r.rate, sortOrder: r.sortOrder, isActive: r.isActive,
                    ));
                  }, hint: 'ไม่จำกัด')),
                  DataCell(_numField(fmt.format(r.rate), (v) {
                    setState(() => _rules[i] = r.copyWith(rate: double.tryParse(v.replaceAll(',', '')) ?? r.rate));
                  })),
                  DataCell(Checkbox(
                    value: r.isActive,
                    onChanged: (v) => setState(() => _rules[i] = r.copyWith(isActive: v ?? true)),
                  )),
                  DataCell(IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                    onPressed: () => setState(() => _rules.removeAt(i)),
                  )),
                ]);
              }).toList(),
            ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('เพิ่มแถว'),
            onPressed: () => setState(() => _rules.add(ArAllowanceRule(
              ageFromDays: 0, rate: 0, sortOrder: _rules.length,
            ))),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSaving ? null : _saveRules,
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('บันทึก'),
          ),
        ]),
      ),
    ]);
  }

  Widget _numField(String initial, void Function(String) onChanged, {String? hint}) =>
      SizedBox(
        width: 100,
        child: TextFormField(
          initialValue: initial,
          decoration: InputDecoration(isDense: true, border: const UnderlineInputBorder(), hintText: hint),
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.right,
          onChanged: onChanged,
        ),
      );

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const Divider(height: 16),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal[100],
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ตั้งค่าบัญชี'),
            Tab(text: 'ตั้งกฎเกณฑ์สำรองหนี้'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : TabBarView(
              controller: _tabController,
              children: [_buildSetupTab(), _buildRulesTab()],
            ),
    );
  }
}
