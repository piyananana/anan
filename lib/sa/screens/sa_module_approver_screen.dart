// lib/sa/screens/sa_module_approver_screen.dart
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sa_module_approver.dart';
import '../models/user.dart';
import '../services/sa_module_approver_service.dart';
import '../services/user_service.dart';

// ── constants ─────────────────────────────────────────────────────────────────
const _modules = [
  _Option('AP', 'บัญชีเจ้าหนี้ (AP)'),
  _Option('AR', 'บัญชีลูกหนี้ (AR)'),
];
const _categories = [
  _Option('payment_run', 'Payment Run (ชำระเงิน)'),
];

class _Option {
  final String value;
  final String label;
  const _Option(this.value, this.label);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class SaModuleApproverScreen extends StatefulWidget {
  const SaModuleApproverScreen({super.key});
  @override
  State<SaModuleApproverScreen> createState() => _SaModuleApproverScreenState();
}

class _SaModuleApproverScreenState extends State<SaModuleApproverScreen>
    with AutomaticKeepAliveClientMixin {
  final _svc    = SaModuleApproverService();
  final _userSvc = UserService();

  List<SaModuleApprover> _rows = [];
  List<User> _users = [];
  bool _loading = true;

  // filter
  String _filterModule   = 'AP';
  String _filterCategory = 'payment_run';

  // panel state
  SaModuleApprover? _selected;
  bool _isAdding = false;
  double _leftWidth = 420;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(moduleCode: _filterModule, docCategory: _filterCategory),
        _userSvc.fetchUsers(),
      ]);
      if (mounted) setState(() {
        _rows    = results[0] as List<SaModuleApprover>;
        _users   = results[1] as List<User>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onFilterChange() async {
    setState(() { _selected = null; _isAdding = false; });
    await _load();
  }

  void _onAdd() => setState(() { _selected = null; _isAdding = true; });

  void _onSelect(SaModuleApprover row) =>
      setState(() { _selected = row; _isAdding = false; });

  Future<void> _onDelete(SaModuleApprover row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบผู้อนุมัติ "${row.approverFullName}" ลำดับที่ ${row.approvalLevel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row.id!);
      if (_selected?.id == row.id) setState(() { _selected = null; _isAdding = false; });
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _onSave(SaModuleApprover row) async {
    try {
      if (row.id == null) {
        await _svc.addRow(row);
      } else {
        await _svc.updateRow(row);
      }
      setState(() { _selected = null; _isAdding = false; });
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  void _onCancel() => setState(() { _selected = null; _isAdding = false; });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.approval, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ตั้งค่าผู้อนุมัติ'),
        ]),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'รีเฟรช', onPressed: _load),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 300).clamp(200.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Left panel ──────────────────────────────────────────────────────
          SizedBox(
            width: _leftWidth,
            child: Column(children: [
              // Filter bar
              Container(
                color: Colors.blueGrey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _filterModule,
                    decoration: const InputDecoration(labelText: 'โมดูล', isDense: true,
                        border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: _modules.map((m) => DropdownMenuItem(value: m.value, child: Text(m.label, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) { if (v != null) { _filterModule = v; _onFilterChange(); } },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _filterCategory,
                    decoration: const InputDecoration(labelText: 'ประเภทงาน', isDense: true,
                        border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: _categories.map((c) => DropdownMenuItem(value: c.value, child: Text(c.label, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) { if (v != null) { _filterCategory = v; _onFilterChange(); } },
                  )),
                ]),
              ),
              // Add button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('เพิ่มผู้อนุมัติ'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white),
                    onPressed: _onAdd,
                  ),
                ]),
              ),
              // List
              Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                  ? const Center(child: Text('ยังไม่มีผู้อนุมัติ', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) => _ApproverTile(
                        row: _rows[i],
                        isSelected: _selected?.id == _rows[i].id,
                        onTap: () => _onSelect(_rows[i]),
                        onDelete: () => _onDelete(_rows[i]),
                      ),
                    )),
            ]),
          ),
          // ── Resizable divider ────────────────────────────────────────────────
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => setState(() =>
                  _leftWidth = (_leftWidth + d.delta.dx).clamp(280.0, maxLeft)),
              child: Container(width: 5, color: Colors.grey[300]),
            ),
          ),
          // ── Right panel ──────────────────────────────────────────────────────
          Expanded(child: _isAdding
            ? _ApproverForm(
                key: ValueKey('add'),
                initial: SaModuleApprover(
                  moduleCode: _filterModule, docCategory: _filterCategory,
                  approvalLevel: _rows.isEmpty ? 1 : _rows.last.approvalLevel + 1,
                  approverUserId: 0,
                ),
                users: _users,
                onSave: _onSave,
                onCancel: _onCancel,
              )
            : _selected != null
              ? _ApproverForm(
                  key: ValueKey(_selected!.id),
                  initial: _selected!,
                  users: _users,
                  onSave: _onSave,
                  onCancel: _onCancel,
                )
              : const Center(child: Text('เลือกรายการหรือกด "เพิ่มผู้อนุมัติ"',
                  style: TextStyle(color: Colors.grey)))),
        ]);
      }),
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────
class _ApproverTile extends StatelessWidget {
  final SaModuleApprover row;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ApproverTile({required this.row, required this.isSelected, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blueGrey.shade100 : Colors.white,
        border: Border.all(color: isSelected ? Colors.blueGrey.shade400 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blueGrey.shade600,
          child: Text('${row.approvalLevel}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        title: Text(row.approverFullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text('${row.moduleName} › ${row.docCategoryName}', style: const TextStyle(fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!row.isActive)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
              child: const Text('หยุดใช้', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          if (row.signatureImage != null)
            const Icon(Icons.draw, size: 14, color: Colors.blueGrey),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}

// ── Form (add / edit) ─────────────────────────────────────────────────────────
class _ApproverForm extends StatefulWidget {
  final SaModuleApprover initial;
  final List<User> users;
  final Future<void> Function(SaModuleApprover) onSave;
  final VoidCallback onCancel;
  const _ApproverForm({super.key, required this.initial, required this.users, required this.onSave, required this.onCancel});
  @override
  State<_ApproverForm> createState() => _ApproverFormState();
}

class _ApproverFormState extends State<_ApproverForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late String _moduleCode;
  late String _docCategory;
  late int    _approvalLevel;
  int?        _approverUserId;
  String?     _signatureImage;
  late bool   _isActive;

  final _levelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _moduleCode    = r.moduleCode;
    _docCategory   = r.docCategory;
    _approvalLevel = r.approvalLevel;
    _approverUserId = r.approverUserId == 0 ? null : r.approverUserId;
    _signatureImage = r.signatureImage;
    _isActive       = r.isActive;
    _levelCtrl.text = '${r.approvalLevel}';
  }

  @override
  void dispose() { _levelCtrl.dispose(); super.dispose(); }

  User? get _selectedUser =>
      _approverUserId == null ? null : widget.users.where((u) => u.id == _approverUserId).firstOrNull;

  Future<void> _pickSignature() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('การอัพโหลดลายเซ็นรองรับเฉพาะ Web')));
      return;
    }
    final upload = html.FileUploadInputElement()..accept = 'image/*';
    upload.click();
    upload.onChange.listen((e) {
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoad.listen((_) {
        if (mounted) setState(() => _signatureImage = reader.result as String);
      });
    });
  }

  Future<void> _pickUser() async {
    final picked = await showDialog<User>(
      context: context,
      builder: (ctx) => _UserPickerDialog(users: widget.users),
    );
    if (picked != null) setState(() => _approverUserId = picked.id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final row = SaModuleApprover(
        id: widget.initial.id,
        moduleCode: _moduleCode,
        docCategory: _docCategory,
        approvalLevel: int.tryParse(_levelCtrl.text) ?? _approvalLevel,
        approverUserId: _approverUserId!,
        approverUsername: _selectedUser?.userName,
        approverFirstName: _selectedUser?.firstName,
        approverLastName: _selectedUser?.lastName,
        approverEmail: _selectedUser?.email,
        signatureImage: _signatureImage,
        isActive: _isActive,
      );
      await widget.onSave(row);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial.id == null;
    return Form(
      key: _formKey,
      child: Column(children: [
        // Header bar
        Container(
          color: Colors.blueGrey[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.approval, color: Colors.blueGrey[900], size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isNew ? 'เพิ่มผู้อนุมัติ' : 'แก้ไขผู้อนุมัติ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
            )),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, size: 16),
              label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onCancel,
              child: Text('ปิด', style: TextStyle(color: Colors.blueGrey[900])),
            ),
          ]),
        ),
        // Form body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Module + Category
            Row(children: [
              Expanded(child: _buildDropdown<String>(
                label: 'โมดูล *',
                value: _moduleCode,
                items: _modules.map((m) => DropdownMenuItem(value: m.value, child: Text(m.label))).toList(),
                onChanged: (v) => setState(() => _moduleCode = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown<String>(
                label: 'ประเภทงาน *',
                value: _docCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c.value, child: Text(c.label))).toList(),
                onChanged: (v) => setState(() => _docCategory = v!),
              )),
            ]),
            const SizedBox(height: 12),
            // Level
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: _levelCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'ลำดับที่ *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณาระบุ' : null,
              ),
            ),
            const SizedBox(height: 12),
            // Approver user picker
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'ผู้อนุมัติ *',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                errorText: _approverUserId == null && _saving ? 'กรุณาเลือกผู้อนุมัติ' : null,
              ),
              child: Row(children: [
                Expanded(child: _approverUserId == null
                  ? const Text('— ยังไม่ได้เลือก —', style: TextStyle(color: Colors.grey, fontSize: 13))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selectedUser?.firstName != null
                          ? '${_selectedUser!.firstName} ${_selectedUser!.lastName ?? ''}'.trim()
                          : _selectedUser?.userName ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      if (_selectedUser?.email != null)
                        Text(_selectedUser!.email!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                IconButton(
                  icon: const Icon(Icons.person_search, color: Colors.blueGrey, size: 18),
                  tooltip: 'เลือกผู้ใช้',
                  onPressed: _pickUser,
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
                if (_approverUserId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    onPressed: () => setState(() => _approverUserId = null),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            // Status
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}',
                  style: const TextStyle(fontSize: 13)),
              value: _isActive,
              activeColor: Colors.blueGrey[700],
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const Divider(height: 24),
            // Signature section
            _buildSectionHeader('ลายเซ็นผู้อนุมัติ'),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Preview
              Container(
                width: 220, height: 110,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade50,
                ),
                child: _signatureImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.memory(
                        base64Decode(_signatureImage!.contains(',')
                            ? _signatureImage!.split(',').last
                            : _signatureImage!),
                        fit: BoxFit.contain,
                      ))
                  : const Center(child: Text('ยังไม่มีลายเซ็น',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload, size: 15),
                  label: const Text('อัพโหลดลายเซ็น', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[600], foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  onPressed: _pickSignature,
                ),
                const SizedBox(height: 6),
                if (_signatureImage != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                    label: const Text('ลบลายเซ็น', style: TextStyle(fontSize: 12, color: Colors.red)),
                    onPressed: () => setState(() => _signatureImage = null),
                  ),
                const SizedBox(height: 8),
                Text('รองรับไฟล์ PNG, JPG', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text('แนะนำพื้นหลังโปร่งใส (PNG)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _buildDropdown<T>({
    required String label, required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) => DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label, border: const OutlineInputBorder(),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    ),
    items: items,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 13, color: Colors.black87),
  );

  Widget _buildSectionHeader(String title) => Row(children: [
    Container(width: 3, height: 16, color: Colors.blueGrey[700], margin: const EdgeInsets.only(right: 8)),
    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[700])),
  ]);
}

// ── User Picker Dialog ────────────────────────────────────────────────────────
class _UserPickerDialog extends StatefulWidget {
  final List<User> users;
  const _UserPickerDialog({required this.users});
  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users.where((u) {
      final q = _search.toLowerCase();
      return q.isEmpty ||
          (u.userName).toLowerCase().contains(q) ||
          ('${u.firstName ?? ''} ${u.lastName ?? ''}').toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: const Text('เลือกผู้อนุมัติ'),
      content: SizedBox(width: 420, height: 380, child: Column(children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ค้นหา ชื่อ / username / email',
            prefixIcon: Icon(Icons.search), border: OutlineInputBorder(),
            isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 8),
        Expanded(child: filtered.isEmpty
          ? const Center(child: Text('ไม่พบผู้ใช้'))
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final u = filtered[i];
                final name = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person, size: 20, color: Colors.blueGrey),
                  title: Text(name.isNotEmpty ? name : u.userName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(u.email ?? u.userName, style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.of(context).pop(u),
                );
              })),
      ])),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก'))],
    );
  }
}
