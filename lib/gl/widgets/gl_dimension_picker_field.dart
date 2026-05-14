import 'package:flutter/material.dart';
import '../models/gl_dimension.dart';

/// Reusable dimension picker field with searchable dialog.
/// ใช้แทน DropdownButtonFormField สำหรับ GL/AR dimension ทุกหน้าจอ
class GlDimensionPickerField extends StatelessWidget {
  final GlDimensionType dimType;
  final List<GlDimensionValue> values;
  final GlDimensionValue? selected;
  final ValueChanged<GlDimensionValue?> onSelected;
  final bool readOnly;
  final bool isDense;         // true = ใน table row / false = ใน card header

  const GlDimensionPickerField({
    super.key,
    required this.dimType,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.readOnly = false,
    this.isDense = false,
  });

  Future<void> _openDialog(BuildContext context) async {
    final searchCtrl = TextEditingController();
    // แสดงเฉพาะ leaf nodes (ไม่มีลูก) — parent ไม่สามารถเลือกลงรายการได้
    final parentIds = values.map((v) => v.parentId).whereType<int>().toSet();
    final sorted = values.where((v) => !parentIds.contains(v.id)).toList()
      ..sort((a, b) => a.valueCode.compareTo(b.valueCode));
    List<GlDimensionValue> filtered = List.from(sorted);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(sorted);
            } else {
              final lq = q.toLowerCase();
              filtered = sorted.where((v) =>
                  v.valueCode.toLowerCase().contains(lq) ||
                  v.valueNameThai.toLowerCase().contains(lq) ||
                  (v.valueNameEng?.toLowerCase().contains(lq) ?? false)).toList();
            }
          });
        }

        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.tune, size: 20, color: Colors.teal),
            const SizedBox(width: 8),
            Text('เลือก${dimType.nameThai}'),
          ]),
          content: SizedBox(
            width: 480,
            height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อ',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              // Clear selection option
              if (selected != null)
                InkWell(
                  onTap: () {
                    onSelected(null);
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.clear, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('— ล้างค่า —', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ]),
                  ),
                ),
              Expanded(
                child: values.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final v = filtered[i];
                              final isSelected = selected?.id == v.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.teal.shade50,
                                leading: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.teal, size: 18)
                                    : const SizedBox(width: 18),
                                title: Text(
                                  '${v.valueCode}  ${v.valueNameThai}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () {
                                  onSelected(v);
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null;

    // ใน DataTable (isDense=true): ไม่แสดง label เพราะ column header แสดงอยู่แล้ว
    // ใน card header (isDense=false): แสดง label ตามปกติ

    if (readOnly) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: isDense ? null : dimType.nameThai,
          border: isDense ? InputBorder.none : const OutlineInputBorder(),
          isDense: true,
          contentPadding: isDense
              ? const EdgeInsets.symmetric(horizontal: 0, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: isDense && hasValue
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected!.valueCode,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                  Text(selected!.valueNameThai,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ],
              )
            : Text(
                hasValue ? '${selected!.valueCode} — ${selected!.valueNameThai}' : '—',
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? Colors.teal[700] : Colors.grey,
                ),
              ),
      );
    }

    // Editable
    return InputDecorator(
      decoration: InputDecoration(
        labelText: isDense ? null : dimType.nameThai,
        border: isDense ? const UnderlineInputBorder() : const OutlineInputBorder(),
        enabledBorder: isDense
            ? const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.teal, width: 1))
            : const OutlineInputBorder(),
        isDense: true,
        filled: isDense,
        fillColor: Colors.white,
        contentPadding: isDense
            ? const EdgeInsets.symmetric(horizontal: 0, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: isDense && hasValue
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selected!.valueCode,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                      Text(selected!.valueNameThai,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )
                : Text(
                    hasValue ? '${selected!.valueCode} — ${selected!.valueNameThai}' : '— ไม่ระบุ —',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasValue ? Colors.teal[700] : Colors.grey[500],
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (hasValue)
            InkWell(
              onTap: () => onSelected(null),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.clear, size: 14, color: Colors.grey),
              ),
            ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => _openDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.search, size: 16, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
