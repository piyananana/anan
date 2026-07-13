// lib/gl/screens/gl_year_end_closing_config_screen.dart
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/gl_account.dart';
import '../models/gl_year_end_closing.dart';
import '../services/gl_account_service.dart';
import '../services/gl_year_end_closing_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';

class YearEndClosingConfigScreen extends StatefulWidget {
  const YearEndClosingConfigScreen({super.key});

  @override
  State<YearEndClosingConfigScreen> createState() =>
      _YearEndClosingConfigScreenState();
}

class _YearEndClosingConfigScreenState
    extends State<YearEndClosingConfigScreen> {
  final YearEndClosingService _service = YearEndClosingService();
  final AccountService _accountService = AccountService();
  final ModuleDocumentService _docService = ModuleDocumentService();

  List<Account> _allAccounts = [];
  List<ModuleDocument> _docTypes = [];
  ClosingConfig? _existingConfig;

  Account? _selectedIncomeSummary;
  Account? _selectedRetainedEarnings;
  ModuleDocument? _selectedClosingDoc;
  ModuleDocument? _selectedCarryForwardDoc;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _accountService.fetchRowsControlAccount();
      final docs = await _docService.fetchRows();
      // เฉพาะ isDocType=true, isActive=true และ sysModule=01 (GL บัญชีแยกประเภท)
      final activeDocTypes = docs
          .where((d) => d.isDocType && d.isActive && d.sysModule == '01')
          .toList()
        ..sort((a, b) => a.docCode.compareTo(b.docCode));

      ClosingConfig? cfg;
      try {
        cfg = await _service.fetchConfig();
      } catch (_) {}

      setState(() {
        _allAccounts = accounts;
        _docTypes = activeDocTypes;
        _existingConfig = cfg;
        if (cfg != null) {
          _selectedIncomeSummary = accounts.cast<Account?>().firstWhere(
                (a) => a?.id == cfg!.incomeSummaryAccountId,
                orElse: () => null,
              );
          _selectedRetainedEarnings = accounts.cast<Account?>().firstWhere(
                (a) => a?.id == cfg!.retainedEarningsAccountId,
                orElse: () => null,
              );
          if (cfg.closingDocId != null) {
            _selectedClosingDoc =
                activeDocTypes.cast<ModuleDocument?>().firstWhere(
                      (d) => d?.id == cfg!.closingDocId,
                      orElse: () => null,
                    );
          }
          if (cfg.carryForwardDocId != null) {
            _selectedCarryForwardDoc =
                activeDocTypes.cast<ModuleDocument?>().firstWhere(
                      (d) => d?.id == cfg!.carryForwardDocId,
                      orElse: () => null,
                    );
          }
        }
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedIncomeSummary == null) {
      setState(() => _errorMsg = 'กรุณาเลือกบัญชีสรุปกำไรขาดทุน');
      return;
    }
    if (_selectedRetainedEarnings == null) {
      setState(() => _errorMsg = 'กรุณาเลือกบัญชีกำไรสะสม');
      return;
    }
    if (_selectedClosingDoc == null) {
      setState(() => _errorMsg = 'กรุณาเลือกประเภทเอกสารปิดบัญชี');
      return;
    }
    if (_selectedCarryForwardDoc == null) {
      setState(() => _errorMsg = 'กรุณาเลือกประเภทเอกสารยกยอด');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
      _successMsg = null;
    });
    try {
      final config = ClosingConfig(
        id: _existingConfig?.id,
        incomeSummaryAccountId: _selectedIncomeSummary!.id,
        retainedEarningsAccountId: _selectedRetainedEarnings!.id,
        closingDocId: _selectedClosingDoc!.id,
        carryForwardDocId: _selectedCarryForwardDoc!.id,
      );
      await _service.saveConfig(config);
      setState(() {
        _existingConfig = config;
        _successMsg = 'บันทึกการตั้งค่าเรียบร้อยแล้ว';
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Banner ────────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.info_outline, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text(
                                'การตั้งค่าการปิดบัญชีสิ้นปี',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo),
                              ),
                            ]),
                            SizedBox(height: 8),
                            Text(
                              'กำหนดบัญชีและประเภทเอกสารที่ใช้ในกระบวนการปิดบัญชีสิ้นปี'
                              ' ระบบจะใช้ข้อมูลเหล่านี้ในการสร้างรายการโอนโดยอัตโนมัติ',
                              style: TextStyle(color: Colors.indigo),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Alerts ────────────────────────────────────────────
                      if (_errorMsg != null)
                        _Alert(
                          message: _errorMsg!,
                          color: Colors.red,
                          icon: Icons.error,
                          onClose: () => setState(() => _errorMsg = null),
                        ),
                      if (_successMsg != null)
                        _Alert(
                          message: _successMsg!,
                          color: Colors.green,
                          icon: Icons.check_circle,
                          onClose: () => setState(() => _successMsg = null),
                        ),

                      // ── Section: บัญชี ────────────────────────────────────
                      _SectionCard(
                        title: 'บัญชีที่ใช้ในการปิดบัญชี',
                        children: [
                          _AccountSearchField(
                            label: 'บัญชีสรุปกำไรขาดทุน (Income Summary)',
                            helperText:
                                'บัญชีกลางที่รับโอนยอดรายได้และค่าใช้จ่ายทั้งหมด (เช่น 3-1000)',
                            accounts: _allAccounts,
                            selected: _selectedIncomeSummary,
                            onSelected: (acc) =>
                                setState(() => _selectedIncomeSummary = acc),
                          ),
                          const SizedBox(height: 24),
                          _AccountSearchField(
                            label: 'บัญชีกำไรสะสม (Retained Earnings)',
                            helperText:
                                'บัญชีที่รับโอนกำไร/ขาดทุนสุทธิเข้าส่วนของผู้ถือหุ้น (เช่น 3-2000)',
                            accounts: _allAccounts,
                            selected: _selectedRetainedEarnings,
                            onSelected: (acc) => setState(
                                () => _selectedRetainedEarnings = acc),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Section: ประเภทเอกสาร ─────────────────────────────
                      _SectionCard(
                        title: 'ประเภทเอกสารสำหรับรายการที่สร้างอัตโนมัติ',
                        children: [
                          _DocTypePickerField(
                            label: 'เอกสารปิดบัญชีรายได้/ค่าใช้จ่าย (ขั้นตอน 3 & 4)',
                            helperText:
                                'ใช้สร้างรายการโอนบัญชีรายได้/ค่าใช้จ่าย และโอนกำไรสุทธิ',
                            docTypes: _docTypes,
                            selected: _selectedClosingDoc,
                            onChanged: (d) =>
                                setState(() => _selectedClosingDoc = d),
                          ),
                          const SizedBox(height: 20),
                          _DocTypePickerField(
                            label: 'เอกสารยกยอดงบดุล (ขั้นตอน 5)',
                            helperText:
                                'ใช้สร้างรายการยกยอดสินทรัพย์/หนี้สิน/ทุนไปปีถัดไป',
                            docTypes: _docTypes,
                            selected: _selectedCarryForwardDoc,
                            onChanged: (d) =>
                                setState(() => _selectedCarryForwardDoc = d),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Save Button ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving
                              ? 'กำลังบันทึก...'
                              : 'บันทึกการตั้งค่า'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Doc Type Picker Field ─────────────────────────────────────────────────────

class _DocTypePickerField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<ModuleDocument> docTypes;
  final ModuleDocument? selected;
  final ValueChanged<ModuleDocument?> onChanged;

  const _DocTypePickerField({
    required this.label,
    required this.helperText,
    required this.docTypes,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _openDialog(BuildContext context) async {
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(docTypes);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(docTypes);
            } else {
              final lq = q.toLowerCase();
              filtered = docTypes
                  .where((d) =>
                      d.docCode.toLowerCase().contains(lq) ||
                      d.docNameThai.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text('เลือก$label'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา รหัส / ชื่อประเภทเอกสาร',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: docTypes.isEmpty
                      ? const Center(child: Text('ไม่พบประเภทเอกสาร GL'))
                      : filtered.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final d = filtered[i];
                                final isSelected = selected?.id == d.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          d.docCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(child: Text(d.docNameThai)),
                                    ],
                                  ),
                                  onTap: () {
                                    onChanged(d);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            helperText: helperText,
            helperMaxLines: 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: selected != null
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${selected!.docCode} — ${selected!.docNameThai}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    : const Text('— ไม่ระบุ —',
                        style: TextStyle(color: Colors.grey)),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.blue),
                tooltip: 'ค้นหาประเภทเอกสาร',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _openDialog(context),
              ),
              if (selected != null)
                IconButton(
                  icon:
                      const Icon(Icons.clear, color: Colors.red, size: 18),
                  tooltip: 'ล้างการเลือก',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Account Search Field ──────────────────────────────────────────────────────

class _AccountSearchField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<Account> accounts;
  final Account? selected;
  final ValueChanged<Account?> onSelected;

  const _AccountSearchField({
    required this.label,
    required this.helperText,
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  Future<void> _openDialog(BuildContext context) async {
    final searchCtrl = TextEditingController();
    final sorted = List<Account>.from(accounts)
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    List<Account> filtered = List.from(sorted);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(sorted);
            } else {
              final lq = q.toLowerCase();
              filtered = sorted
                  .where((a) =>
                      a.accountCode.toLowerCase().contains(lq) ||
                      a.accountNameThai.toLowerCase().contains(lq) ||
                      a.accountNameEng.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text('เลือก$label'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: accounts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? const Center(child: Text('ไม่พบบัญชี'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final a = filtered[i];
                                final isSelected = selected?.id == a.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor:
                                      Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          a.accountCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(
                                          child: Text(a.accountNameThai)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          accountTypeOptions[a.accountType] ??
                                              a.accountType,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    onSelected(a);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            helperText: helperText,
            helperMaxLines: 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: selected != null
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${selected!.accountCode} — ${selected!.accountNameThai}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              accountTypeOptions[selected!.accountType] ??
                                  selected!.accountType,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : const Text('— ไม่ระบุ —',
                        style: TextStyle(color: Colors.grey)),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.blue),
                tooltip: 'ค้นหาบัญชี',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _openDialog(context),
              ),
              if (selected != null)
                IconButton(
                  icon:
                      const Icon(Icons.clear, color: Colors.red, size: 18),
                  tooltip: 'ล้างการเลือก',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onSelected(null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Alert Banner ──────────────────────────────────────────────────────────────

class _Alert extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;

  const _Alert({
    required this.message,
    required this.color,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: TextStyle(color: color))),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: color),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
