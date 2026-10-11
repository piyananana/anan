// lib/mo/widgets/mo_work_center_detail_widget.dart — มิเรอร์ im_price_group_detail_widget.dart เปลี่ยนฟีลด์
// description เป็น 3 อัตราค่าใช้จ่ายต่อชั่วโมง (labor/machine/overhead)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/mo_work_center.dart';

class MoWorkCenterDetailWidget extends StatefulWidget {
  final Mode mode;
  final MoWorkCenter? selected;
  final Function(MoWorkCenter) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มศูนย์งานซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const MoWorkCenterDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<MoWorkCenterDetailWidget> createState() => MoWorkCenterDetailWidgetState();
}

class MoWorkCenterDetailWidgetState extends State<MoWorkCenterDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _laborRateCtrl;
  late TextEditingController _machineRateCtrl;
  late TextEditingController _overheadRateCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.selected?.workCenterCode ?? '');
    _nameThCtrl = TextEditingController(text: widget.selected?.workCenterNameTh ?? '');
    _nameEnCtrl = TextEditingController(text: widget.selected?.workCenterNameEn ?? '');
    _laborRateCtrl = TextEditingController(text: '${widget.selected?.laborRatePerHour ?? 0}');
    _machineRateCtrl = TextEditingController(text: '${widget.selected?.machineRatePerHour ?? 0}');
    _overheadRateCtrl = TextEditingController(text: '${widget.selected?.overheadRatePerHour ?? 0}');
    _isActive = widget.selected?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant MoWorkCenterDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      final isAdd = widget.mode == Mode.add;
      _codeCtrl.text = isAdd ? '' : (widget.selected?.workCenterCode ?? '');
      _nameThCtrl.text = isAdd ? '' : (widget.selected?.workCenterNameTh ?? '');
      _nameEnCtrl.text = isAdd ? '' : (widget.selected?.workCenterNameEn ?? '');
      _laborRateCtrl.text = isAdd ? '0' : '${widget.selected?.laborRatePerHour ?? 0}';
      _machineRateCtrl.text = isAdd ? '0' : '${widget.selected?.machineRatePerHour ?? 0}';
      _overheadRateCtrl.text = isAdd ? '0' : '${widget.selected?.overheadRatePerHour ?? 0}';
      _isActive = isAdd ? true : (widget.selected?.isActive ?? true);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _laborRateCtrl.dispose();
    _machineRateCtrl.dispose();
    _overheadRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = MoWorkCenter(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        workCenterCode: _codeCtrl.text.trim().toUpperCase(),
        workCenterNameTh: _nameThCtrl.text.trim(),
        workCenterNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        laborRatePerHour: double.tryParse(_laborRateCtrl.text) ?? 0,
        machineRatePerHour: double.tryParse(_machineRateCtrl.text) ?? 0,
        overheadRatePerHour: double.tryParse(_overheadRateCtrl.text) ?? 0,
        isActive: _isActive,
      );
      await widget.onSubmit(row);
    } catch (e) {
      final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _rateField(TextEditingController ctrl, String labelEn, String labelTh, bool isEnglish) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          readOnly: _isReadOnly,
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(labelText: isEnglish ? labelEn : labelTh, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish ? 'Select a work center to view its data, or press + to add a new one' : 'เลือกศูนย์งานเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มศูนย์งานใหม่',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? (isEnglish ? 'View Data' : 'ดูข้อมูล')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Work Center' : 'แก้ไขศูนย์งาน')
                      : (isEnglish ? 'Add Work Center' : 'เพิ่มศูนย์งาน'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: isEnglish ? 'Work Center Code' : 'รหัสศูนย์งาน', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the work center code' : 'กรุณาป้อนรหัสศูนย์งาน') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameThCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Work Center Name (Thai)' : 'ชื่อศูนย์งาน (ไทย)', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the work center name (Thai)' : 'กรุณาป้อนชื่อศูนย์งาน (ไทย)') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _nameEnCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Work Center Name (English)' : 'ชื่อศูนย์งาน (อังกฤษ)', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // อัตราค่าใช้จ่ายต่อชั่วโมง — ข้อมูลการเงิน ควรจำกัดสิทธิ์แก้ไขไว้ที่กลุ่มผู้ใช้ Costing เท่านั้น
            // (ผ่านสิทธิ์ของเมนูนี้ ไม่ใช่ field-level — ดูแผนออกแบบโมดูล MO)
            _rateField(_laborRateCtrl, 'Labor Rate / Hour', 'อัตราค่าแรง / ชั่วโมง', isEnglish),
            _rateField(_machineRateCtrl, 'Machine Rate / Hour', 'อัตราค่าเครื่องจักร / ชั่วโมง', isEnglish),
            _rateField(_overheadRateCtrl, 'Overhead Rate / Hour', 'อัตราค่าโสหุ้ย (Overhead) / ชั่วโมง', isEnglish),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(value: _isActive, activeColor: Colors.teal, onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v)),
            ]),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container()
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : widget.mode == Mode.edit ? l.save : l.add),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: Text(l.cancel),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
