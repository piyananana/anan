// lib/cd/widgets/cd_salesperson_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/cd_salesperson.dart';
import '../models/cd_sales_territory.dart';
import '../models/cd_business_unit.dart';
import '../models/cd_branch.dart';
import '../services/cd_sales_territory_service.dart';
import '../services/cd_business_unit_service.dart';
import '../services/cd_branch_service.dart';

class SalespersonDetailWidget extends StatefulWidget {
  final Mode mode;
  final Salesperson? selected;
  final Function(Salesperson) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const SalespersonDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<SalespersonDetailWidget> createState() =>
      SalespersonDetailWidgetState();
}

class SalespersonDetailWidgetState extends State<SalespersonDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThaCtrl;
  late TextEditingController _nameEngCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _commissionCtrl;

  String _salespersonType = 'EMPLOYEE';
  int? _branchId;
  String? _branchNameThai;
  int? _businessUnitId;
  String? _businessUnitName;
  DateTime? _effectiveDateFrom;
  DateTime? _effectiveDateTo;
  bool _isActive = true;
  bool _isSaving = false;

  // territories list
  List<SalespersonTerritory> _territories = [];

  @override
  void initState() {
    super.initState();
    _init(widget.selected);
  }

  void _init(Salesperson? d) {
    _codeCtrl = TextEditingController(text: d?.salespersonCode ?? '');
    _nameThaCtrl = TextEditingController(text: d?.salespersonNameThai ?? '');
    _nameEngCtrl = TextEditingController(text: d?.salespersonNameEng ?? '');
    _taxIdCtrl = TextEditingController(text: d?.taxId ?? '');
    _branchId = d?.branchId;
    _branchNameThai = d?.branchNameThai;
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _commissionCtrl =
        TextEditingController(text: (d?.commissionRate ?? 0).toString());
    _salespersonType = d?.salespersonType ?? 'EMPLOYEE';
    _businessUnitId = d?.businessUnitId;
    _businessUnitName = d?.businessUnitName;
    _effectiveDateFrom = d?.effectiveDateFrom;
    _effectiveDateTo = d?.effectiveDateTo;
    _isActive = d?.isActive ?? true;
    _territories = List.from(d?.territories ?? []);
  }

  @override
  void didUpdateWidget(covariant SalespersonDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        (widget.mode == Mode.add && oldWidget.mode != Mode.add)) {
      _codeCtrl.text = widget.selected?.salespersonCode ?? '';
      _nameThaCtrl.text = widget.selected?.salespersonNameThai ?? '';
      _nameEngCtrl.text = widget.selected?.salespersonNameEng ?? '';
      _taxIdCtrl.text = widget.selected?.taxId ?? '';
      _branchId = widget.selected?.branchId;
      _branchNameThai = widget.selected?.branchNameThai;
      _phoneCtrl.text = widget.selected?.phone ?? '';
      _emailCtrl.text = widget.selected?.email ?? '';
      _addressCtrl.text = widget.selected?.address ?? '';
      _commissionCtrl.text =
          (widget.selected?.commissionRate ?? 0).toString();
      _salespersonType = widget.selected?.salespersonType ?? 'EMPLOYEE';
      _businessUnitId = widget.selected?.businessUnitId;
      _businessUnitName = widget.selected?.businessUnitName;
      _effectiveDateFrom = widget.selected?.effectiveDateFrom;
      _effectiveDateTo = widget.selected?.effectiveDateTo;
      _isActive = widget.selected?.isActive ?? true;
      _territories = List.from(widget.selected?.territories ?? []);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThaCtrl.dispose();
    _nameEngCtrl.dispose();
    _taxIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_effectiveDateFrom ?? DateTime.now())
        : (_effectiveDateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveDateFrom = picked;
        } else {
          _effectiveDateTo = picked;
        }
      });
    }
  }

  Future<void> _pickBranch() async {
    final List<Branch> all;
    try {
      all = await Provider.of<BranchService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลสาขาล้มเหลว: $e')));
      }
      return;
    }
    final choices = all
        .where((b) => b.isActive)
        .toList()
      ..sort((a, b) => a.branchCode.compareTo(b.branchCode));

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('เลือกสาขา',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: choices.isEmpty
              ? const Center(child: Text('ไม่พบข้อมูลสาขา'))
              : ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (_, i) {
                    final b = choices[i];
                    return ListTile(
                      title: Text('${b.branchCode} — ${b.branchNameThai}'),
                      onTap: () {
                        setState(() {
                          _branchId = b.id;
                          _branchNameThai = b.branchNameThai;
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _pickBusinessUnit() async {
    final List<BusinessUnit> all;
    try {
      all = await Provider.of<BusinessUnitService>(context, listen: false)
          .fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลหน่วยงานล้มเหลว: $e')));
      }
      return;
    }
    final parentIds = all.map((bu) => bu.parentId).whereType<int>().toSet();
    final choices = all
        .where((bu) => bu.isActive && bu.parentId != null && !parentIds.contains(bu.id))
        .toList()
      ..sort((a, b) => a.buCode.compareTo(b.buCode));

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('เลือกหน่วยงาน',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: choices.isEmpty
              ? const Center(child: Text('ไม่พบข้อมูลหน่วยงาน'))
              : ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (_, i) {
                    final bu = choices[i];
                    return ListTile(
                      title: Text('${bu.buCode} — ${bu.buNameThai}'),
                      onTap: () {
                        setState(() {
                          _businessUnitId = bu.id;
                          _businessUnitName = bu.buNameThai;
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _addTerritory() async {
    final List<SalesTerritory> all;
    try {
      all =
          await Provider.of<SalesTerritoryService>(context, listen: false)
              .fetchActiveRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดเขตการขายล้มเหลว: $e')));
      }
      return;
    }
    // กรอง id ที่เลือกแล้ว
    final chosen = _territories.map((t) => t.territoryId).toSet();
    final available = all.where((t) => !chosen.contains(t.id)).toList()
      ..sort((a, b) => a.territoryCode.compareTo(b.territoryCode));

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('เพิ่มเขตการขาย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: available.isEmpty
              ? const Center(child: Text('ไม่มีเขตการขายให้เลือกเพิ่ม'))
              : ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final t = available[i];
                    return ListTile(
                      title: Text(
                          '${t.territoryCode} — ${t.territoryNameThai}'),
                      onTap: () {
                        setState(() {
                          _territories.add(SalespersonTerritory(
                            territoryId: t.id!,
                            territoryCode: t.territoryCode,
                            territoryNameThai: t.territoryNameThai,
                            isPrimary: _territories.isEmpty,
                          ));
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _removeTerritory(int index) {
    setState(() {
      final removed = _territories.removeAt(index);
      // ถ้าลบ primary และยังมีเขตอื่น → ตั้ง primary แรกใหม่
      if (removed.isPrimary && _territories.isNotEmpty) {
        _territories[0] = _territories[0].copyWith(isPrimary: true);
      }
    });
  }

  void _togglePrimary(int index) {
    setState(() {
      for (int i = 0; i < _territories.length; i++) {
        _territories[i] = _territories[i].copyWith(isPrimary: i == index);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = Salesperson(
        id: widget.selected?.id,
        salespersonCode: _codeCtrl.text.trim().toUpperCase(),
        salespersonNameThai: _nameThaCtrl.text.trim(),
        salespersonNameEng: _nameEngCtrl.text.trim().isEmpty
            ? null
            : _nameEngCtrl.text.trim(),
        salespersonType: _salespersonType,
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        branchId: _branchId,
        businessUnitId: _businessUnitId,
        phone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        commissionRate:
            double.tryParse(_commissionCtrl.text) ?? 0,
        effectiveDateFrom: _effectiveDateFrom,
        effectiveDateTo: _effectiveDateTo,
        isActive: _isActive,
        territories: _territories,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
          child: Text(
              'เลือกพนักงานขายเพื่อแก้ไข หรือ กดปุ่ม + เพื่อเพิ่มใหม่'));
    }

    final bool ro = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? 'ดูข้อมูลพนักงานขาย'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขพนักงานขาย'
                      : 'เพิ่มพนักงานขาย',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // รหัส
            TextFormField(
              controller: _codeCtrl,
              readOnly: widget.mode != Mode.add,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'รหัสพนักงานขาย *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัส' : null,
            ),
            const SizedBox(height: 12),

            // ชื่อไทย / อังกฤษ
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameThaCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ (ไทย) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'โปรดระบุชื่อภาษาไทย'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _nameEngCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ประเภทพนักงานขาย
            // ประเภท + เลขภาษี
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _salespersonType,
                    decoration: const InputDecoration(
                      labelText: 'ประเภท *',
                      border: OutlineInputBorder(),
                    ),
                    items: salespersonTypeOptions.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: ro
                        ? null
                        : (v) => setState(() => _salespersonType = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _taxIdCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'เลขภาษี/เลขบัตรประชาชน',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // สาขา + หน่วยงานที่สังกัด
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : _pickBranch,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'สาขา',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_branchId != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _branchId = null;
                                  _branchNameThai = null;
                                }),
                              ),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                      child: Text(_branchId == null
                          ? '— ไม่ระบุ —'
                          : _branchNameThai ?? ''),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : _pickBusinessUnit,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'หน่วยงานที่สังกัด',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_businessUnitId != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _businessUnitId = null;
                                  _businessUnitName = null;
                                }),
                              ),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                      child: Text(_businessUnitId == null
                          ? '— ไม่ระบุ —'
                          : _businessUnitName ?? ''),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // โทรศัพท์ / อีเมล
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'โทรศัพท์',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    readOnly: ro,
                    decoration: const InputDecoration(
                      labelText: 'อีเมล',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ที่อยู่
            TextFormField(
              controller: _addressCtrl,
              readOnly: ro,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // อัตราค่าคอมมิชชั่น
            TextFormField(
              controller: _commissionCtrl,
              readOnly: ro,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'อัตราค่าคอมมิชชั่น (%)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final d = double.tryParse(v);
                  if (d == null) return 'กรุณาใส่ตัวเลข';
                  if (d < 0 || d > 100) return 'ต้องอยู่ระหว่าง 0-100';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // วันที่เริ่ม / สิ้นสุด
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : () => _pickDate(true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'วันที่เริ่มใช้',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_effectiveDateFrom != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(
                                    () => _effectiveDateFrom = null),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(_formatDate(_effectiveDateFrom)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: ro ? null : () => _pickDate(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'วันที่สิ้นสุด',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_effectiveDateTo != null && !ro)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _effectiveDateTo = null),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(_formatDate(_effectiveDateTo)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // สถานะ
            Row(
              children: [
                Expanded(
                    child: Text(
                        'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
                Switch(
                  value: _isActive,
                  onChanged: ro
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── เขตการขาย ───────────────────────────────────────
            Row(
              children: [
                Text('เขตการขายที่รับผิดชอบ',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (!ro)
                  TextButton.icon(
                    onPressed: _addTerritory,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มเขต'),
                  ),
              ],
            ),
            const Divider(),
            if (_territories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('— ยังไม่มีเขตการขาย —',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _territories.length,
                itemBuilder: (ctx, i) {
                  final t = _territories[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: ro
                          ? Icon(
                              t.isPrimary ? Icons.star : Icons.star_border,
                              color: t.isPrimary
                                  ? Colors.amber
                                  : Colors.grey,
                            )
                          : IconButton(
                              icon: Icon(
                                t.isPrimary ? Icons.star : Icons.star_border,
                                color: t.isPrimary
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              tooltip: 'ตั้งเป็นหลัก',
                              onPressed: () => _togglePrimary(i),
                            ),
                      title: Text(
                          '${t.territoryCode ?? ''} — ${t.territoryNameThai ?? ''}'),
                      subtitle: t.isPrimary
                          ? const Text('เขตหลัก',
                              style: TextStyle(color: Colors.amber))
                          : null,
                      trailing: ro
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () => _removeTerritory(i),
                            ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // ปุ่ม
            Row(
              children: [
                if (widget.mode != Mode.view)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving
                          ? 'กำลังบันทึก...'
                          : widget.mode == Mode.edit
                              ? 'บันทึก'
                              : 'เพิ่ม'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (widget.mode != Mode.view) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: const Text('ยกเลิก'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
