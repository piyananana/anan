import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

class GlDimensionTypeScreen extends StatefulWidget {
  const GlDimensionTypeScreen({super.key});

  @override
  State<GlDimensionTypeScreen> createState() => _GlDimensionTypeScreenState();
}

class _GlDimensionTypeScreenState extends State<GlDimensionTypeScreen> {
  final _service = GlDimensionService();
  List<GlDimensionType> _types = [];
  bool _isLoading = false;
  bool _isEnglish = false;

  // edit state
  final Map<int, TextEditingController> _codeCtrl = {};
  final Map<int, TextEditingController> _nameCtrl = {};
  final Map<int, TextEditingController> _nameEngCtrl = {};
  final Map<int, bool> _active = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _codeCtrl.values) c.dispose();
    for (final c in _nameCtrl.values) c.dispose();
    for (final c in _nameEngCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchAllTypes();
      // ensure all 5 slots exist (with defaults)
      final Map<int, GlDimensionType> bySlot = {for (final r in rows) r.slotNo: r};
      final all = List.generate(5, (i) {
        final s = i + 1;
        return bySlot[s] ?? GlDimensionType(slotNo: s, typeCode: 'DIM$s', nameThai: 'Dimension $s', isActive: false);
      });
      setState(() {
        _types = all;
        for (final t in _types) {
          _codeCtrl[t.slotNo] = TextEditingController(text: t.typeCode);
          _nameCtrl[t.slotNo] = TextEditingController(text: t.nameThai);
          _nameEngCtrl[t.slotNo] = TextEditingController(text: t.nameEng ?? '');
          _active[t.slotNo] = t.isActive;
        }
      });
    } catch (e) {
      final isEnglish = _isEnglish;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save(int slotNo) async {
    final isEnglish = _isEnglish;
    final type = GlDimensionType(
      slotNo:    slotNo,
      typeCode:  _codeCtrl[slotNo]!.text.trim().toUpperCase(),
      nameThai:  _nameCtrl[slotNo]!.text.trim(),
      nameEng:   _nameEngCtrl[slotNo]!.text.trim().isEmpty ? null : _nameEngCtrl[slotNo]!.text.trim(),
      isActive:  _active[slotNo] ?? false,
      sortOrder: slotNo,
    );
    try {
      await _service.upsertType(type);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกเรียบร้อย')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'ข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEnglish ? 'Configure Dimension Slot 1–5' : 'กำหนด Dimension Slot 1–5', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              isEnglish
                                  ? 'Each slot is an analysis dimension attached to a GL line, e.g. department, cost center, project'
                                  : 'แต่ละ Slot คือมิติการวิเคราะห์ที่แนบกับบรรทัด GL เช่น แผนก, ศูนย์ต้นทุน, โครงการ',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 16),
                          ...List.generate(5, (i) => _buildSlotCard(i + 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSlotCard(int slotNo) {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final isActive = _active[slotNo] ?? false;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? null : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isActive ? Colors.teal : Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text('$slotNo', style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 8),
            Text('Slot $slotNo', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(
              value: isActive,
              onChanged: !canEdit
                  ? null
                  : (v) async {
                      setState(() => _active[slotNo] = v);
                      await _save(slotNo);
                    },
            ),
            Text(isEnglish ? 'Enabled' : 'เปิดใช้งาน'),
          ]),
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: 160, child: TextFormField(
                controller: _codeCtrl[slotNo],
                enabled: canEdit,
                decoration: InputDecoration(labelText: isEnglish ? 'Code (type_code)' : 'รหัส (type_code)', isDense: true, border: const OutlineInputBorder()),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _nameCtrl[slotNo],
                enabled: canEdit,
                decoration: InputDecoration(labelText: isEnglish ? 'Thai Name *' : 'ชื่อภาษาไทย *', isDense: true, border: const OutlineInputBorder()),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _nameEngCtrl[slotNo],
                enabled: canEdit,
                decoration: InputDecoration(labelText: isEnglish ? 'English Name' : 'ชื่อภาษาอังกฤษ', isDense: true, border: const OutlineInputBorder()),
              )),
              const SizedBox(width: 12),
              if (canEdit)
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(l.save),
                  onPressed: () => _save(slotNo),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
