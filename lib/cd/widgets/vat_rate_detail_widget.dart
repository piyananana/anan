import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/models/anan_module.dart';
import '../models/vat_rate.dart';

class VatRateDetailWidget extends StatefulWidget {
  final Mode mode;
  final VatRate? selected;
  final Function(VatRate) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const VatRateDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<VatRateDetailWidget> createState() => VatRateDetailWidgetState();
}

class VatRateDetailWidgetState extends State<VatRateDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vatCodeController;
  late TextEditingController _vatNameThController;
  late TextEditingController _vatNameEnController;
  late TextEditingController _rateController;
  late TextEditingController _remarkController;
  DateTime? _effectiveDate;
  DateTime? _endDate;
  late bool _isActive;
  bool _isSaving = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _initFields(widget.selected);
  }

  void _initFields(VatRate? row) {
    _vatCodeController = TextEditingController(text: row?.vatCode ?? '');
    _vatNameThController = TextEditingController(text: row?.vatNameTh ?? '');
    _vatNameEnController = TextEditingController(text: row?.vatNameEn ?? '');
    _rateController =
        TextEditingController(text: row != null ? row.rate.toString() : '');
    _remarkController = TextEditingController(text: row?.remark ?? '');
    _effectiveDate = row?.effectiveDate;
    _endDate = row?.endDate;
    _isActive = row?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant VatRateDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _disposeControllers();
      _initFields(widget.selected);
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _disposeControllers();
      _initFields(null);
    }
  }

  void _disposeControllers() {
    _vatCodeController.dispose();
    _vatNameThController.dispose();
    _vatNameEnController.dispose();
    _rateController.dispose();
    _remarkController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _pickDate(bool isEffective) async {
    final initial = isEffective
        ? (_effectiveDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isEffective) {
          _effectiveDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_effectiveDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาระบุวันที่มีผลบังคับใช้')),
        );
        return;
      }
      setState(() => _isSaving = true);
      try {
        final row = VatRate(
          id: widget.selected?.id,
          vatCode: _vatCodeController.text.toUpperCase().trim(),
          vatNameTh: _vatNameThController.text.trim(),
          vatNameEn: _vatNameEnController.text.trim().isEmpty
              ? null
              : _vatNameEnController.text.trim(),
          rate: double.tryParse(_rateController.text) ?? 0.0,
          effectiveDate: _effectiveDate!,
          endDate: _endDate,
          isActive: _isActive,
          remark: _remarkController.text.trim().isEmpty
              ? null
              : _remarkController.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกอัตราภาษีเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มอัตราใหม่'),
      );
    }

    final readOnly = widget.mode == Mode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? 'ดูข้อมูลอัตราภาษี'
                  : widget.mode == Mode.edit
                      ? 'แก้ไขอัตราภาษี'
                      : 'เพิ่มอัตราภาษีใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // รหัส VAT + อัตรา %
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vatCodeController,
                    readOnly: readOnly,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'รหัสภาษี (VAT Code) *',
                      border: OutlineInputBorder(),
                      hintText: 'เช่น VAT7, VAT0, EXEMPT',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัสภาษี' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    readOnly: readOnly,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'อัตรา (%) *',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'โปรดระบุอัตรา';
                      if (double.tryParse(v) == null) return 'ตัวเลขไม่ถูกต้อง';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ชื่อภาษาไทย
            TextFormField(
              controller: _vatNameThController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษี (ไทย) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อภาษาไทย' : null,
            ),
            const SizedBox(height: 12),

            // ชื่อภาษาอังกฤษ
            TextFormField(
              controller: _vatNameEnController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษี (อังกฤษ)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // วันที่มีผลบังคับใช้
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: readOnly ? null : () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่มีผลบังคับใช้ *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _effectiveDate != null
                            ? _dateFmt.format(_effectiveDate!)
                            : 'เลือกวันที่',
                        style: TextStyle(
                          color: _effectiveDate != null
                              ? null
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: readOnly ? null : () => _pickDate(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'วันสิ้นสุด (ว่าง = ปัจจุบัน)',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_endDate != null && !readOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _endDate = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                      child: Text(
                        _endDate != null
                            ? _dateFmt.format(_endDate!)
                            : 'ปัจจุบัน',
                        style: TextStyle(
                          color: _endDate != null ? null : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // หมายเหตุ
            TextFormField(
              controller: _remarkController,
              readOnly: readOnly,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // สถานะ
            Row(
              children: [
                Expanded(
                  child: Text(
                      'สถานะการใช้งาน: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.mode != Mode.view)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
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
                if (widget.mode != Mode.view) const SizedBox(width: 16),
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
