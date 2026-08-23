import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/im_accounting_setting.dart';
import '../services/im_accounting_setting_service.dart';

// หน้าตั้งค่าโหมดบัญชีสินค้าระดับบริษัท (PERPETUAL/PERIODIC) — ดู pattern_im_periodic_accounting_mode:
// PERPETUAL = ธุรกรรม IM ทุกรายการ Post GL ทันที (ของเดิม), PERIODIC = ไม่ Post GL ต่อธุรกรรมเลย รอปิดงวด
// ครั้งเดียว (ดูหน้าจอ ImPeriodClosingScreen) — subledger (im_stock_balance/im_stock_layer) อัปเดตแบบเดียวกัน
// ทุกโหมดเสมอ ไม่ผูกกับการตั้งค่านี้
class ImAccountingSettingScreen extends StatefulWidget {
  const ImAccountingSettingScreen({super.key});

  @override
  State<ImAccountingSettingScreen> createState() => _ImAccountingSettingScreenState();
}

class _ImAccountingSettingScreenState extends State<ImAccountingSettingScreen> {
  final ImAccountingSettingService _svc = ImAccountingSettingService();
  final AccountService _acctSvc = AccountService();
  final PeriodService _periodSvc = PeriodService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Account> _accounts = [];
  List<PostingPeriod> _periods = [];
  List<ModuleDocument> _glDocs = [];

  String _mode = 'PERPETUAL';
  int? _effectivePeriodId;
  String? _effectivePeriodLabel;
  int? _inventoryAccountId; String? _inventoryAccountLabel;
  int? _cogsAccountId; String? _cogsAccountLabel;
  int? _purchasesAccountId; String? _purchasesAccountLabel;
  int? _closingGlDocId; String? _closingGlDocLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetting(),
        _acctSvc.fetchRows(),
        _periodSvc.fetchOpenGlPeriods(),
        _docSvc.fetchRows(),
      ]);
      final setting = results[0] as ImAccountingSetting?;
      _accounts = results[1] as List<Account>;
      _periods = results[2] as List<PostingPeriod>;
      _glDocs = (results[3] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList();

      if (setting != null) {
        _mode = setting.inventoryAccountingMode;
        _effectivePeriodId = setting.modeEffectivePeriodId;
        _effectivePeriodLabel = setting.modeEffectivePeriodName;
        _inventoryAccountId = setting.inventoryAccountId;
        _inventoryAccountLabel = _acctLabel(setting.inventoryAccountCode, setting.inventoryAccountName);
        _cogsAccountId = setting.cogsAccountId;
        _cogsAccountLabel = _acctLabel(setting.cogsAccountCode, setting.cogsAccountName);
        _purchasesAccountId = setting.purchasesAccountId;
        _purchasesAccountLabel = _acctLabel(setting.purchasesAccountCode, setting.purchasesAccountName);
        _closingGlDocId = setting.closingGlDocId;
        _closingGlDocLabel = setting.closingDocCode == null
            ? null
            : '${setting.closingDocCode} ${setting.closingDocNameThai ?? ''}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _acctLabel(String? code, String? name) => code == null ? null : '$code ${name ?? ''}';

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final result = await _svc.upsertSetting(ImAccountingSetting(
        inventoryAccountingMode: _mode,
        modeEffectivePeriodId: _effectivePeriodId,
        inventoryAccountId: _inventoryAccountId,
        cogsAccountId: _cogsAccountId,
        purchasesAccountId: _purchasesAccountId,
        closingGlDocId: _closingGlDocId,
      ));
      if (mounted) {
        setState(() {
          _mode = result.inventoryAccountingMode;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAccount(String title, void Function(Account) onPicked) async {
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
                : _accounts.where((a) => a.accountCode.toLowerCase().contains(lq) || a.accountNameThai.toLowerCase().contains(lq)).toList();
          });
        }
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480, height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'ค้นหา รหัส / ชื่อบัญชี', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
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
                      title: Text('${a.accountCode}  ${a.accountNameThai}', style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    if (picked != null) onPicked(picked!);
  }

  Future<void> _pickPeriod(void Function(PostingPeriod) onPicked) async {
    PostingPeriod? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลือกงวดบัญชี'),
        content: SizedBox(
          width: 420, height: 360,
          child: ListView.separated(
            itemCount: _periods.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = _periods[i];
              return ListTile(
                dense: true,
                title: Text(p.periodName),
                subtitle: Text('${p.periodStartDate.toLocal().toString().split(' ')[0]} - ${p.periodEndDate.toLocal().toString().split(' ')[0]}'),
                onTap: () { picked = p; Navigator.of(ctx).pop(); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก'))],
      ),
    );
    if (picked != null) onPicked(picked!);
  }

  Future<void> _pickGlDoc(void Function(ModuleDocument) onPicked) async {
    ModuleDocument? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลือกประเภทเอกสาร GL'),
        content: SizedBox(
          width: 420, height: 360,
          child: ListView.separated(
            itemCount: _glDocs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = _glDocs[i];
              return ListTile(
                dense: true,
                title: Text('${d.docCode}  ${d.docNameThai}'),
                onTap: () { picked = d; Navigator.of(ctx).pop(); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก'))],
      ),
    );
    if (picked != null) onPicked(picked!);
  }

  Widget _field({required String label, required String? value, required VoidCallback onSearch}) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      child: Row(children: [
        Expanded(child: Text(value ?? '— ไม่ระบุ —', style: TextStyle(color: value == null ? Colors.grey.shade600 : Colors.black87, fontWeight: value == null ? FontWeight.normal : FontWeight.bold))),
        IconButton(icon: const Icon(Icons.search, color: Colors.teal, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEnglish ? 'Inventory Accounting Mode' : 'โหมดบัญชีสินค้าคงคลัง', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          isEnglish
              ? 'Perpetual: post GL for every transaction (default). Periodic: post GL once at period-end closing only — quantity/cost tracking is unchanged either way.'
              : 'Perpetual: โพสต์บัญชีทุกธุรกรรมทันที (ค่าเริ่มต้น) ส่วน Periodic: ไม่โพสต์บัญชีต่อธุรกรรมเลย รอโพสต์ครั้งเดียวตอนปิดงวด — การติดตามจำนวน/ต้นทุนสินค้าคงเดิมไม่ว่าโหมดใด',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: InputDecoration(labelText: isEnglish ? 'Mode' : 'โหมด', border: const OutlineInputBorder(), isDense: true),
                items: [
                  DropdownMenuItem(value: 'PERPETUAL', child: Text(isEnglish ? 'Perpetual' : 'Perpetual (โพสต์บัญชีทันที)')),
                  DropdownMenuItem(value: 'PERIODIC', child: Text(isEnglish ? 'Periodic' : 'Periodic (ปิดงวดครั้งเดียว)')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'PERPETUAL'),
              ),
              const SizedBox(height: 12),
              _field(
                label: isEnglish ? 'Effective from period (required to switch mode)' : 'เริ่มใช้ตั้งแต่งวด (จำเป็นเมื่อสลับโหมด)',
                value: _effectivePeriodLabel,
                onSearch: () => _pickPeriod((p) => setState(() { _effectivePeriodId = p.id; _effectivePeriodLabel = p.periodName; })),
              ),
              const SizedBox(height: 16),
              Text(isEnglish ? 'Period-end closing accounts (used when Periodic)' : 'บัญชีสำหรับปิดงวด (ใช้เมื่อเลือก Periodic)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _field(
                label: isEnglish ? 'Inventory Account' : 'บัญชีสินค้าคงเหลือ',
                value: _inventoryAccountLabel,
                onSearch: () => _pickAccount(isEnglish ? 'Select Inventory Account' : 'เลือกบัญชีสินค้าคงเหลือ',
                    (a) => setState(() { _inventoryAccountId = a.id; _inventoryAccountLabel = '${a.accountCode} ${a.accountNameThai}'; })),
              ),
              const SizedBox(height: 8),
              _field(
                label: isEnglish ? 'COGS Account' : 'บัญชีต้นทุนขาย',
                value: _cogsAccountLabel,
                onSearch: () => _pickAccount(isEnglish ? 'Select COGS Account' : 'เลือกบัญชีต้นทุนขาย',
                    (a) => setState(() { _cogsAccountId = a.id; _cogsAccountLabel = '${a.accountCode} ${a.accountNameThai}'; })),
              ),
              const SizedBox(height: 8),
              _field(
                label: isEnglish ? 'Purchases Account (used once GRN posts here)' : 'บัญชีซื้อสินค้า (ใช้เมื่อ GRN โพสต์เข้ามาในอนาคต)',
                value: _purchasesAccountLabel,
                onSearch: () => _pickAccount(isEnglish ? 'Select Purchases Account' : 'เลือกบัญชีซื้อสินค้า',
                    (a) => setState(() { _purchasesAccountId = a.id; _purchasesAccountLabel = '${a.accountCode} ${a.accountNameThai}'; })),
              ),
              const SizedBox(height: 8),
              _field(
                label: isEnglish ? 'Closing GL Document Type' : 'ประเภทเอกสาร GL สำหรับปิดงวด',
                value: _closingGlDocLabel,
                onSearch: () => _pickGlDoc((d) => setState(() { _closingGlDocId = d.id; _closingGlDocLabel = '${d.docCode} ${d.docNameThai}'; })),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: _isSaving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEnglish ? 'Save' : 'บันทึก'),
          ),
        ),
      ]),
    );
  }
}
