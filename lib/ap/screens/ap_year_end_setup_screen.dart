import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/ap_year_end.dart';
import '../services/ap_year_end_service.dart';

class ApYearEndSetupScreen extends StatefulWidget {
  const ApYearEndSetupScreen({super.key});

  @override
  State<ApYearEndSetupScreen> createState() => _ApYearEndSetupScreenState();
}

class _ApYearEndSetupScreenState extends State<ApYearEndSetupScreen>
    with AutomaticKeepAliveClientMixin {
  final ApYearEndService      _svc     = ApYearEndService();
  final AccountService        _acctSvc = AccountService();
  final ModuleDocumentService _docSvc  = ModuleDocumentService();

  static const _kIndigo = Color(0xFF3949AB);

  List<Account>        _accounts = [];
  List<ModuleDocument> _glDocs   = [];

  bool _isEnglish = false;

  int? _fxGainId, _fxLossId, _ufxGainId, _ufxLossId;
  int? _fxRevalDocId;

  bool _isLoading = true;
  bool _isSaving  = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetup(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      final setup = results[0] as ApYearEndSetup?;
      setState(() {
        _accounts = (results[1] as List<Account>)
            .where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _glDocs   = (results[2] as List<ModuleDocument>)
            .where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        if (setup != null) {
          _fxGainId    = setup.fxGainAccountId;
          _fxLossId    = setup.fxLossAccountId;
          _ufxGainId   = setup.unrealizedFxGainAccountId;
          _ufxLossId   = setup.unrealizedFxLossAccountId;
          _fxRevalDocId = setup.fxRevalGlDocId;
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

  String _accountLabel(Account a) =>
      _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  String _docLabel(ModuleDocument d) =>
      _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  Future<Account?> _pickAccount(String title) async {
    final isEnglish = _isEnglish;
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
                    a.accountNameThai.toLowerCase().contains(lq) ||
                    a.accountNameEng.toLowerCase().contains(lq)).toList();
          });
        }
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                      title: Text('${a.accountCode}  ${_accountLabel(a)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<ModuleDocument?> _pickGlDoc() async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(_glDocs);
    ModuleDocument? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) {
                  setDlg(() {
                    final lq = q.toLowerCase();
                    filtered = q.isEmpty
                        ? List.from(_glDocs)
                        : _glDocs.where((d) =>
                            d.docCode.toLowerCase().contains(lq) ||
                            d.docNameThai.toLowerCase().contains(lq) ||
                            d.docNameEng.toLowerCase().contains(lq)).toList();
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
                      title: Text('${d.docCode}  ${_docLabel(d)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    setState(() => _isSaving = true);
    try {
      final s = ApYearEndSetup(
        fxGainAccountId:            _fxGainId   == 0 ? null : _fxGainId,
        fxLossAccountId:            _fxLossId   == 0 ? null : _fxLossId,
        unrealizedFxGainAccountId:  _ufxGainId  == 0 ? null : _ufxGainId,
        unrealizedFxLossAccountId:  _ufxLossId  == 0 ? null : _ufxLossId,
        fxRevalGlDocId:             _fxRevalDocId == 0 ? null : _fxRevalDocId,
      );
      await _svc.saveSetup(s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ'), backgroundColor: Colors.indigo));
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
    final isEnglish = _isEnglish;
    final acc = _findAccount(selectedId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 280, child: Text(label, style: const TextStyle(fontSize: 14))),
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
                    acc != null ? '${acc.accountCode}  ${_accountLabel(acc)}' : (isEnglish ? '-- Not configured --' : '-- ไม่ได้ตั้งค่า --'),
                    style: TextStyle(fontSize: 14,
                        color: acc != null ? Colors.black87 : Colors.grey[500]),
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
    final isEnglish = _isEnglish;
    final doc = _findDoc(selectedId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 280, child: Text(label, style: const TextStyle(fontSize: 14))),
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
                    doc != null ? '${doc.docCode}  ${_docLabel(doc)}' : (isEnglish ? '-- Not configured --' : '-- ไม่ได้ตั้งค่า --'),
                    style: TextStyle(fontSize: 14,
                        color: doc != null ? Colors.black87 : Colors.grey[500]),
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

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kIndigo)),
      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const Divider(height: 16),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kIndigo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeader(
                  isEnglish ? 'Realized FX Revaluation' : 'ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยนแบบ Realized',
                  isEnglish ? 'Realized FX gain/loss accounts' : 'บัญชีกำไร/ขาดทุนจากอัตราแลกเปลี่ยนที่ปรับจริง',
                ),
                _accountPickerField(isEnglish ? 'FX Gain Account' : 'บัญชีกำไรอัตราแลกเปลี่ยน', _fxGainId,
                    dialogTitle: isEnglish ? 'FX Gain Account' : 'บัญชีกำไรอัตราแลกเปลี่ยน',
                    onChanged: (v) => setState(() => _fxGainId = v)),
                _accountPickerField(isEnglish ? 'FX Loss Account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยน', _fxLossId,
                    dialogTitle: isEnglish ? 'FX Loss Account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยน',
                    onChanged: (v) => setState(() => _fxLossId = v)),
                const SizedBox(height: 8),
                _sectionHeader(
                  isEnglish ? 'Reversing FX Revaluation' : 'ปรับมูลค่าหนี้จากอัตราแลกเปลี่ยนแบบ Reversing',
                  isEnglish
                      ? 'Unrealized FX gain/loss accounts (reversed at the start of the new period)'
                      : 'บัญชีกำไร/ขาดทุนจากอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง (กลับรายการต้นงวดใหม่)',
                ),
                _accountPickerField(
                  isEnglish ? 'Unrealized FX Gain Account' : 'บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง', _ufxGainId,
                  dialogTitle: isEnglish ? 'Unrealized FX Gain Account' : 'บัญชีกำไรอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง',
                  onChanged: (v) => setState(() => _ufxGainId = v),
                ),
                _accountPickerField(
                  isEnglish ? 'Unrealized FX Loss Account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง', _ufxLossId,
                  dialogTitle: isEnglish ? 'Unrealized FX Loss Account' : 'บัญชีขาดทุนอัตราแลกเปลี่ยนที่ยังไม่ได้ปรับจริง',
                  onChanged: (v) => setState(() => _ufxLossId = v),
                ),
                const SizedBox(height: 8),
                _sectionHeader(
                  isEnglish ? 'GL Document Types' : 'ประเภทเอกสารบัญชีแยกประเภท',
                  isEnglish ? 'GL document types used to create adjustment entries' : 'ประเภทเอกสาร GL ที่ใช้สร้างรายการปรับปรุงในบัญชีแยกประเภท',
                ),
                _docPickerField(
                  isEnglish ? 'FX Revaluation Document Type' : 'ประเภทเอกสารปรับมูลค่าหนี้จากอัตราแลกเปลี่ยน',
                  _fxRevalDocId,
                  (v) => setState(() => _fxRevalDocId = v),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: (_isSaving || !(MenuScope.of(context)?.canEdit ?? true)) ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: _kIndigo),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEnglish ? 'Save' : 'บันทึก'),
                  ),
                ),
              ]),
            ),
    );
  }
}
