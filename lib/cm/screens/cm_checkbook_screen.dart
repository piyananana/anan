import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../sa/utils/app_l10n.dart';
import '../../sa/services/language_provider.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_checkbook.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_checkbook_service.dart';

class CmCheckbookScreen extends StatefulWidget {
  const CmCheckbookScreen({super.key});

  @override
  State<CmCheckbookScreen> createState() => _CmCheckbookScreenState();
}

class _CmCheckbookScreenState extends State<CmCheckbookScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  static const _kColor = Color(0xFF1565C0); // indigo[800]

  final CmBankAccountService _acctSvc = CmBankAccountService();
  final CmCheckbookService   _svc     = CmCheckbookService();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  late TabController _tabCtrl;

  // Bank account selector (left panel)
  List<CmBankAccount> _bankAccounts = [];
  CmBankAccount?      _selectedBank;
  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth    = 280.0;
  bool _isDragging          = false;

  // Checkbook tab
  List<CmCheckbook> _checkbooks = [];
  bool _cbLoading = false;
  CmCheckbook? _editingCb;   // null = new

  // Print config tab
  List<CmCheckPrintConfig> _configs = [];
  bool _cfgLoading = false;
  CmCheckPrintConfig? _editingCfg; // null = new

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final list = await _acctSvc.fetchRows();
      setState(() => _bankAccounts = list.where((b) => b.isCheckAccount).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode)));
    } catch (e) { _showErr(e.toString()); }
  }

  void _selectBank(CmBankAccount b) {
    setState(() { _selectedBank = b; _checkbooks = []; _configs = []; _editingCb = null; _editingCfg = null; });
    _loadCheckbooks();
    _loadPrintConfigs();
  }

  Future<void> _loadCheckbooks() async {
    if (_selectedBank == null) return;
    setState(() => _cbLoading = true);
    try {
      final list = await _svc.fetchCheckbooks(bankAccountId: _selectedBank!.id);
      setState(() { _checkbooks = list; _cbLoading = false; });
    } catch (e) {
      setState(() => _cbLoading = false);
      _showErr(e.toString());
    }
  }

  Future<void> _loadPrintConfigs() async {
    if (_selectedBank == null) return;
    setState(() => _cfgLoading = true);
    try {
      final list = await _svc.fetchPrintConfigs(bankAccountId: _selectedBank!.id);
      setState(() { _configs = list; _cfgLoading = false; });
    } catch (e) {
      setState(() => _cfgLoading = false);
      _showErr(e.toString());
    }
  }

  void _showErr(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showOk(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _kColor));
  }

  // ── Checkbook CRUD ────────────────────────────────────────────────────────

  Future<void> _saveCb(CmCheckbook cb) async {
    try {
      if (cb.id == null) {
        await _svc.addCheckbook(cb);
        _showOk('เพิ่มสมุดเช็คสำเร็จ');
      } else {
        await _svc.updateCheckbook(cb);
        _showOk('บันทึกสำเร็จ');
      }
      setState(() => _editingCb = null);
      await _loadCheckbooks();
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _deleteCb(CmCheckbook cb) async {
    final ok = await _confirm('ลบสมุดเช็ค "${cb.checkbookCode}" ?');
    if (!ok) return;
    try {
      await _svc.deleteCheckbook(cb.id!);
      _showOk('ลบสำเร็จ');
      await _loadCheckbooks();
    } catch (e) { _showErr(e.toString()); }
  }

  // ── Print Config CRUD ─────────────────────────────────────────────────────

  Future<void> _saveCfg(CmCheckPrintConfig cfg) async {
    try {
      if (cfg.id == null) {
        await _svc.addPrintConfig(cfg);
        _showOk('เพิ่มรูปแบบพิมพ์สำเร็จ');
      } else {
        await _svc.updatePrintConfig(cfg);
        _showOk('บันทึกสำเร็จ');
      }
      setState(() => _editingCfg = null);
      await _loadPrintConfigs();
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _deleteCfg(CmCheckPrintConfig cfg) async {
    final ok = await _confirm('ลบรูปแบบพิมพ์ "${cfg.configName}" ?');
    if (!ok) return;
    try {
      await _svc.deletePrintConfig(cfg.id!);
      _showOk('ลบสำเร็จ');
      await _loadPrintConfigs();
    } catch (e) { _showErr(e.toString()); }
  }

  Future<bool> _confirm(String msg) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยัน'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.confirm, style: const TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.book, size: 18), text: 'สมุดเช็ค'),
            Tab(icon: Icon(Icons.print, size: 18), text: 'ตำแหน่งพิมพ์'),
          ],
        ),
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Toggle strip
          Container(
            width: 36, color: _kColor,
            child: IconButton(
              icon: Icon(_isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
              tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
            ),
          ),
          // Left panel — bank account list
          AnimatedContainer(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _leftPanelWidth, minWidth: _leftPanelWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: _buildBankList(),
                ),
              ),
            ),
          ),
          if (_isLeftPanelExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (d) => setState(() {
                  _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(180.0, maxLeft);
                }),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          // Right panel — tabs
          Expanded(
            child: _selectedBank == null
                ? const Center(child: Text('เลือกบัญชีธนาคารที่รองรับเช็คทางซ้าย',
                    style: TextStyle(color: Colors.grey)))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildCheckbookTab(),
                      _buildPrintConfigTab(),
                    ],
                  ),
          ),
        ]);
      }),
    );
  }

  // ── Left panel ────────────────────────────────────────────────────────────

  Widget _buildBankList() => Column(children: [
    Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blueGrey.shade200,
      child: const Row(children: [
        Icon(Icons.savings, size: 16, color: Colors.black54),
        SizedBox(width: 6),
        Text('บัญชีที่รองรับเช็ค', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    ),
    Expanded(
      child: _bankAccounts.isEmpty
          ? const Center(child: Text('ไม่พบบัญชีที่รองรับเช็ค\n(ตั้งค่าใน "ตั้งค่าบัญชีธนาคาร")',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)))
          : ListView.builder(
              itemCount: _bankAccounts.length,
              itemBuilder: (_, i) {
                final b = _bankAccounts[i];
                final selected = _selectedBank?.id == b.id;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: const Color(0xFFE3F2FD),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: selected ? _kColor : Colors.blueGrey.shade300,
                    child: Text(b.currencyCode.isNotEmpty ? b.currencyCode.substring(0, 1) : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(b.accountCode,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                          color: selected ? _kColor : null)),
                  subtitle: Text(b.accountNameTh,
                      style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  onTap: () => _selectBank(b),
                );
              },
            ),
    ),
  ]);

  // ── Checkbook Tab ─────────────────────────────────────────────────────────

  Widget _buildCheckbookTab() => Column(children: [
    // Header bar
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(children: [
        Text('สมุดเช็ค — ${_selectedBank!.accountCode} ${_selectedBank!.accountNameTh}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('เพิ่มสมุดเช็ค'),
          style: FilledButton.styleFrom(backgroundColor: _kColor),
          onPressed: () => setState(() => _editingCb = CmCheckbook(
            bankAccountId: _selectedBank!.id!, checkbookCode: '', startCheckNo: '', endCheckNo: '')),
        ),
      ]),
    ),
    const Divider(height: 1),
    // Form (when editing)
    if (_editingCb != null)
      _CheckbookForm(
        key: ValueKey(_editingCb.hashCode),
        initial: _editingCb!,
        bankAccountId: _selectedBank!.id!,
        onSave: _saveCb,
        onCancel: () => setState(() => _editingCb = null),
        kColor: _kColor,
      ),
    if (_editingCb != null) const Divider(height: 1),
    // List
    Expanded(
      child: _cbLoading
          ? const Center(child: CircularProgressIndicator())
          : _checkbooks.isEmpty
              ? const Center(child: Text('ไม่มีสมุดเช็ค', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _checkbooks.length,
                  itemBuilder: (_, i) => _CheckbookCard(
                    item: _checkbooks[i],
                    dateFmt: _dateFmt,
                    onEdit: (cb) => setState(() => _editingCb = cb),
                    onDelete: _deleteCb,
                  ),
                ),
    ),
  ]);

  // ── Print Config Tab ──────────────────────────────────────────────────────

  Widget _buildPrintConfigTab() => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(children: [
        Text('ตำแหน่งพิมพ์เช็ค — ${_selectedBank!.accountCode}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('เพิ่มรูปแบบ'),
          style: FilledButton.styleFrom(backgroundColor: _kColor),
          onPressed: () => setState(() => _editingCfg = CmCheckPrintConfig(
            bankAccountId: _selectedBank!.id!, configName: '')),
        ),
      ]),
    ),
    const Divider(height: 1),
    Expanded(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Config list
        SizedBox(
          width: 280,
          child: _cfgLoading
              ? const Center(child: CircularProgressIndicator())
              : _configs.isEmpty
                  ? const Center(child: Text('ไม่มีรูปแบบ', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _configs.length,
                      itemBuilder: (_, i) {
                        final cfg = _configs[i];
                        final sel = _editingCfg?.id == cfg.id;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: sel ? const Color(0xFFE3F2FD) : null,
                          shape: sel ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: _kColor, width: 1.5)) : null,
                          child: ListTile(
                            dense: true,
                            title: Row(children: [
                              Expanded(child: Text(cfg.configName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              if (cfg.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Default', style: TextStyle(fontSize: 10, color: _kColor)),
                                ),
                            ]),
                            subtitle: Text('${cfg.paperWidthMm}×${cfg.paperHeightMm} mm',
                                style: const TextStyle(fontSize: 11)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                onPressed: () => setState(() => _editingCfg = cfg),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                onPressed: () => _deleteCfg(cfg),
                              ),
                            ]),
                            onTap: () => setState(() => _editingCfg = cfg),
                          ),
                        );
                      },
                    ),
        ),
        const VerticalDivider(width: 1),
        // Config form + preview
        Expanded(
          child: _editingCfg == null
              ? const Center(child: Text('เลือกหรือเพิ่มรูปแบบพิมพ์', style: TextStyle(color: Colors.grey)))
              : _PrintConfigForm(
                  key: ValueKey(_editingCfg.hashCode),
                  initial: _editingCfg!,
                  bankAccountId: _selectedBank!.id!,
                  onSave: _saveCfg,
                  onCancel: () => setState(() => _editingCfg = null),
                  kColor: _kColor,
                ),
        ),
      ]),
    ),
  ]);
}

// ── Checkbook Form ────────────────────────────────────────────────────────────

class _CheckbookForm extends StatefulWidget {
  final CmCheckbook initial;
  final int bankAccountId;
  final Future<void> Function(CmCheckbook) onSave;
  final VoidCallback onCancel;
  final Color kColor;
  const _CheckbookForm({super.key, required this.initial, required this.bankAccountId,
      required this.onSave, required this.onCancel, required this.kColor});
  @override
  State<_CheckbookForm> createState() => _CheckbookFormState();
}

class _CheckbookFormState extends State<_CheckbookForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl, _startCtrl, _endCtrl, _nextCtrl, _noteCtrl;
  late String _status;
  DateTime? _receivedDate;
  bool _saving = false;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _codeCtrl  = TextEditingController(text: d.checkbookCode);
    _startCtrl = TextEditingController(text: d.startCheckNo);
    _endCtrl   = TextEditingController(text: d.endCheckNo);
    _nextCtrl  = TextEditingController(text: d.nextCheckNo ?? d.startCheckNo);
    _noteCtrl  = TextEditingController(text: d.note ?? '');
    _status       = d.status;
    _receivedDate = d.receivedDate;
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _startCtrl, _endCtrl, _nextCtrl, _noteCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(CmCheckbook(
        id: widget.initial.id,
        bankAccountId: widget.bankAccountId,
        checkbookCode: _codeCtrl.text.trim(),
        startCheckNo:  _startCtrl.text.trim(),
        endCheckNo:    _endCtrl.text.trim(),
        nextCheckNo:   _nextCtrl.text.trim().isEmpty ? _startCtrl.text.trim() : _nextCtrl.text.trim(),
        receivedDate:  _receivedDate,
        status:        _status,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'รหัสสมุดเช็ค *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ' : null,
            )),
            const SizedBox(width: 8),
            Expanded(child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _receivedDate ?? DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _receivedDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'วันที่รับสมุดเช็ค', border: OutlineInputBorder(), isDense: true),
                child: Text(_receivedDate != null ? _dateFmt.format(_receivedDate!) : '—',
                    style: const TextStyle(fontSize: 14)),
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _startCtrl,
              decoration: const InputDecoration(labelText: 'เลขเช็คแรก *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ' : null,
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: _endCtrl,
              decoration: const InputDecoration(labelText: 'เลขเช็คสุดท้าย *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ' : null,
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: _nextCtrl,
              decoration: const InputDecoration(labelText: 'เลขถัดไป', border: OutlineInputBorder(), isDense: true),
            )),
            if (widget.initial.id != null) ...[
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true),
                items: cmCheckbookStatusOptions.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              )),
            ],
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder(), isDense: true),
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: widget.onCancel, child: Text(l.cancel)),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.kColor),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.initial.id == null ? l.add : l.save),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Checkbook Card ────────────────────────────────────────────────────────────

class _CheckbookCard extends StatelessWidget {
  final CmCheckbook item;
  final DateFormat dateFmt;
  final void Function(CmCheckbook) onEdit;
  final Future<void> Function(CmCheckbook) onDelete;
  const _CheckbookCard({required this.item, required this.dateFmt, required this.onEdit, required this.onDelete});

  Color _statusColor(String s) =>
      s == 'Active' ? Colors.green : s == 'Used' ? Colors.grey : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: _statusColor(item.status).withOpacity(0.15),
          child: Icon(Icons.book, color: _statusColor(item.status), size: 18),
        ),
        title: Row(children: [
          Text(item.checkbookCode, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(item.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(cmCheckbookStatusOptions[item.status] ?? item.status,
                style: TextStyle(fontSize: 11, color: _statusColor(item.status))),
          ),
        ]),
        subtitle: Text(
          'เช็ค ${item.startCheckNo}–${item.endCheckNo}'
          '${item.nextCheckNo != null ? '  |  ถัดไป: ${item.nextCheckNo}' : ''}'
          '${item.receivedDate != null ? '  |  รับ: ${dateFmt.format(item.receivedDate!)}' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (item.status != 'Used')
            IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                onPressed: () => onEdit(item)),
          IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              onPressed: () => onDelete(item)),
        ]),
      ),
    );
  }
}

// ── Print Config Form + Preview ───────────────────────────────────────────────

class _PrintConfigForm extends StatefulWidget {
  final CmCheckPrintConfig initial;
  final int bankAccountId;
  final Future<void> Function(CmCheckPrintConfig) onSave;
  final VoidCallback onCancel;
  final Color kColor;
  const _PrintConfigForm({super.key, required this.initial, required this.bankAccountId,
      required this.onSave, required this.onCancel, required this.kColor});
  @override
  State<_PrintConfigForm> createState() => _PrintConfigFormState();
}

class _PrintConfigFormState extends State<_PrintConfigForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _wCtrl, _hCtrl;
  late TextEditingController _dateXCtrl, _dateYCtrl, _dateFmtCtrl;
  late TextEditingController _payeeXCtrl, _payeeYCtrl;
  late TextEditingController _amtNumXCtrl, _amtNumYCtrl;
  late TextEditingController _amtTxtXCtrl, _amtTxtYCtrl;
  late TextEditingController _stubWCtrl;
  late bool _hasStub, _isDefault;
  bool _saving = false;

  double _n(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _nameCtrl   = TextEditingController(text: d.configName);
    _wCtrl      = TextEditingController(text: d.paperWidthMm.toStringAsFixed(1));
    _hCtrl      = TextEditingController(text: d.paperHeightMm.toStringAsFixed(1));
    _dateXCtrl  = TextEditingController(text: (d.dateX ?? 150).toStringAsFixed(1));
    _dateYCtrl  = TextEditingController(text: (d.dateY ?? 18).toStringAsFixed(1));
    _dateFmtCtrl = TextEditingController(text: d.dateFormat);
    _payeeXCtrl = TextEditingController(text: (d.payeeX ?? 35).toStringAsFixed(1));
    _payeeYCtrl = TextEditingController(text: (d.payeeY ?? 38).toStringAsFixed(1));
    _amtNumXCtrl = TextEditingController(text: (d.amountNumX ?? 155).toStringAsFixed(1));
    _amtNumYCtrl = TextEditingController(text: (d.amountNumY ?? 38).toStringAsFixed(1));
    _amtTxtXCtrl = TextEditingController(text: (d.amountTextX ?? 20).toStringAsFixed(1));
    _amtTxtYCtrl = TextEditingController(text: (d.amountTextY ?? 55).toStringAsFixed(1));
    _stubWCtrl  = TextEditingController(text: (d.stubWidthMm ?? 50).toStringAsFixed(1));
    _hasStub    = d.hasStub;
    _isDefault  = d.isDefault;
    for (final c in [_wCtrl,_hCtrl,_dateXCtrl,_dateYCtrl,_payeeXCtrl,_payeeYCtrl,
        _amtNumXCtrl,_amtNumYCtrl,_amtTxtXCtrl,_amtTxtYCtrl,_stubWCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl,_wCtrl,_hCtrl,_dateXCtrl,_dateYCtrl,_dateFmtCtrl,
        _payeeXCtrl,_payeeYCtrl,_amtNumXCtrl,_amtNumYCtrl,_amtTxtXCtrl,_amtTxtYCtrl,_stubWCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(CmCheckPrintConfig(
        id: widget.initial.id,
        bankAccountId: widget.bankAccountId,
        configName:    _nameCtrl.text.trim(),
        paperWidthMm:  _n(_wCtrl),
        paperHeightMm: _n(_hCtrl),
        dateX:  _n(_dateXCtrl), dateY:  _n(_dateYCtrl),
        dateFormat: _dateFmtCtrl.text.trim(),
        payeeX: _n(_payeeXCtrl), payeeY: _n(_payeeYCtrl),
        amountNumX:  _n(_amtNumXCtrl), amountNumY:  _n(_amtNumYCtrl),
        amountTextX: _n(_amtTxtXCtrl), amountTextY: _n(_amtTxtYCtrl),
        hasStub:    _hasStub,
        stubWidthMm: _hasStub ? _n(_stubWCtrl) : null,
        isDefault:  _isDefault,
      ));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _numField(String label, TextEditingController ctrl, {double w = 90}) => SizedBox(
    width: w,
    child: TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(),
          isDense: true, suffixText: 'mm',
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 13),
    ),
  );

  Widget _row(String label, TextEditingController xCtrl, TextEditingController yCtrl) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13))),
        _numField('X', xCtrl),
        const SizedBox(width: 8),
        _numField('Y', yCtrl),
      ]),
    );

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final pw = _n(_wCtrl);
    final ph = _n(_hCtrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + paper size
          Row(children: [
            Expanded(child: TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'ชื่อรูปแบบ *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ' : null,
            )),
            const SizedBox(width: 8),
            _numField('กว้าง', _wCtrl, w: 100),
            const SizedBox(width: 6),
            const Text('×', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            _numField('สูง', _hCtrl, w: 100),
          ]),
          const SizedBox(height: 12),

          // Field positions
          const Text('ตำแหน่งฟิลด์ (mm จากมุมบนซ้าย)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Divider(height: 16),
          _row('วันที่เช็ค', _dateXCtrl, _dateYCtrl),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 130),
            child: SizedBox(
              width: 200,
              child: TextFormField(
                controller: _dateFmtCtrl,
                decoration: const InputDecoration(labelText: 'รูปแบบวันที่', border: OutlineInputBorder(),
                    isDense: true, hintText: 'dd/MM/yyyy',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          _row('ชื่อผู้รับเงิน', _payeeXCtrl, _payeeYCtrl),
          _row('จำนวนเงิน (ตัวเลข)', _amtNumXCtrl, _amtNumYCtrl),
          _row('จำนวนเงิน (ตัวอักษร)', _amtTxtXCtrl, _amtTxtYCtrl),
          const SizedBox(height: 8),

          // Stub
          Row(children: [
            Checkbox(value: _hasStub, onChanged: (v) => setState(() => _hasStub = v!)),
            const Text('มีสเตาบ์ (Stub)'),
            if (_hasStub) ...[const SizedBox(width: 12), _numField('ความกว้าง Stub', _stubWCtrl, w: 130)],
          ]),
          const SizedBox(height: 4),

          // Default
          Row(children: [
            Checkbox(value: _isDefault, onChanged: (v) => setState(() => _isDefault = v!)),
            const Text('ใช้เป็น Default'),
          ]),
          const SizedBox(height: 16),

          // Buttons
          Row(children: [
            TextButton(onPressed: widget.onCancel, child: Text(l.cancel)),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.kColor),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.initial.id == null ? 'เพิ่ม' : 'บันทึก'),
            ),
          ]),
          const SizedBox(height: 20),

          // Preview
          if (pw > 0 && ph > 0) ...[
            const Text('Preview ตำแหน่ง (มาตราส่วน 1:2)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _CheckPreview(
              widthMm: pw, heightMm: ph,
              dateX: _n(_dateXCtrl), dateY: _n(_dateYCtrl),
              payeeX: _n(_payeeXCtrl), payeeY: _n(_payeeYCtrl),
              amountNumX: _n(_amtNumXCtrl), amountNumY: _n(_amtNumYCtrl),
              amountTextX: _n(_amtTxtXCtrl), amountTextY: _n(_amtTxtYCtrl),
              hasStub: _hasStub, stubWidth: _hasStub ? _n(_stubWCtrl) : 0,
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Check Preview Canvas ──────────────────────────────────────────────────────

class _CheckPreview extends StatelessWidget {
  final double widthMm, heightMm;
  final double dateX, dateY, payeeX, payeeY;
  final double amountNumX, amountNumY, amountTextX, amountTextY;
  final bool hasStub;
  final double stubWidth;

  const _CheckPreview({
    required this.widthMm, required this.heightMm,
    required this.dateX, required this.dateY,
    required this.payeeX, required this.payeeY,
    required this.amountNumX, required this.amountNumY,
    required this.amountTextX, required this.amountTextY,
    required this.hasStub, required this.stubWidth,
  });

  @override
  Widget build(BuildContext context) {
    const scale = 2.0; // 1 mm = 2 px in preview
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        color: Colors.white,
      ),
      width: widthMm * scale,
      height: heightMm * scale,
      child: CustomPaint(
        painter: _CheckPainter(
          widthMm: widthMm, heightMm: heightMm, scale: scale,
          dateX: dateX, dateY: dateY,
          payeeX: payeeX, payeeY: payeeY,
          amountNumX: amountNumX, amountNumY: amountNumY,
          amountTextX: amountTextX, amountTextY: amountTextY,
          hasStub: hasStub, stubWidth: stubWidth,
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double widthMm, heightMm, scale;
  final double dateX, dateY, payeeX, payeeY;
  final double amountNumX, amountNumY, amountTextX, amountTextY;
  final bool hasStub;
  final double stubWidth;

  const _CheckPainter({
    required this.widthMm, required this.heightMm, required this.scale,
    required this.dateX, required this.dateY,
    required this.payeeX, required this.payeeY,
    required this.amountNumX, required this.amountNumY,
    required this.amountTextX, required this.amountTextY,
    required this.hasStub, required this.stubWidth,
  });

  void _label(Canvas c, String text, double xMm, double yMm, {Color color = const Color(0xFF1565C0)}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    // Draw crosshair
    final x = xMm * scale;
    final y = yMm * scale;
    final paint = Paint()..color = color.withOpacity(0.5)..strokeWidth = 0.8;
    c.drawLine(Offset(x - 6, y), Offset(x + 6, y), paint);
    c.drawLine(Offset(x, y - 6), Offset(x, y + 6), paint);
    // Draw label
    tp.paint(c, Offset(x + 4, y - 10));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()..color = Colors.grey.shade300..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // Stub line
    if (hasStub && stubWidth > 0) {
      final stubPaint = Paint()..color = Colors.grey.shade400..strokeWidth = 1..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(stubWidth * scale, 0), Offset(stubWidth * scale, size.height), stubPaint);
      final tp = TextPainter(
        text: const TextSpan(text: 'Stub', style: TextStyle(fontSize: 9, color: Colors.grey)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, size.height / 2 - 6));
    }

    _label(canvas, 'วันที่', dateX, dateY);
    _label(canvas, 'ชื่อผู้รับ', payeeX, payeeY, color: const Color(0xFF2E7D32));
    _label(canvas, 'จำนวน (ตัวเลข)', amountNumX, amountNumY, color: const Color(0xFF6A1B9A));
    _label(canvas, 'จำนวน (ตัวอักษร)', amountTextX, amountTextY, color: const Color(0xFFE65100));
  }

  @override
  bool shouldRepaint(_CheckPainter old) => true;
}
