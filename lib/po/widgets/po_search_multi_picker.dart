// lib/po/widgets/po_search_multi_picker.dart — dialog เลือกได้หลายรายการ (multi-select) พร้อมช่องค้นหา
// มิเรอร์ ApVendorGroupMultiPicker (InputDecorator + dialog + checkbox list + Select All) แต่เพิ่มช่องค้นหา
// เพราะรายการคลังสินค้า/หมวดหมู่สินค้าอาจยาวกว่ากลุ่มผู้ขาย — ใช้ได้กับ type T ใดก็ได้ผ่าน callback
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';

class SearchMultiPicker<T> extends StatelessWidget {
  final List<T> items;
  final List<int> selectedIds;
  final int Function(T item) idOf;
  final String Function(T item, bool isEnglish) labelOf;
  final String Function(T item) searchTextOf;
  final ValueChanged<List<int>> onChanged;
  final String labelTh;
  final String labelEn;
  final String allLabelTh;
  final String allLabelEn;

  const SearchMultiPicker({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.idOf,
    required this.labelOf,
    required this.searchTextOf,
    required this.onChanged,
    required this.labelTh,
    required this.labelEn,
    required this.allLabelTh,
    required this.allLabelEn,
  });

  Future<void> _pick(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _SearchMultiPickerDialog<T>(
        items: items,
        selected: selectedIds,
        idOf: idOf,
        labelOf: labelOf,
        searchTextOf: searchTextOf,
        titleTh: labelTh,
        titleEn: labelEn,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final hasValue = selectedIds.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: isEnglish ? labelEn : labelTh,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(
                onTap: () => onChanged([]),
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(
              onTap: () => _pick(context),
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.search, size: 18))),
        ]),
      ),
      child: InkWell(
        onTap: () => _pick(context),
        child: Text(
          hasValue
              ? (isEnglish ? 'Selected ${selectedIds.length} item(s)' : 'เลือก ${selectedIds.length} รายการ')
              : (isEnglish ? allLabelEn : allLabelTh),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SearchMultiPickerDialog<T> extends StatefulWidget {
  final List<T> items;
  final List<int> selected;
  final int Function(T item) idOf;
  final String Function(T item, bool isEnglish) labelOf;
  final String Function(T item) searchTextOf;
  final String titleTh;
  final String titleEn;

  const _SearchMultiPickerDialog({
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.searchTextOf,
    required this.titleTh,
    required this.titleEn,
  });

  @override
  State<_SearchMultiPickerDialog<T>> createState() => _SearchMultiPickerDialogState<T>();
}

class _SearchMultiPickerDialogState<T> extends State<_SearchMultiPickerDialog<T>> {
  late List<int> _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final q = _query.trim().toUpperCase();
    final display = q.isEmpty
        ? widget.items
        : widget.items.where((it) => widget.searchTextOf(it).toUpperCase().contains(q)).toList();
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(isEnglish ? widget.titleEn : widget.titleTh,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search by code or name' : 'ค้นหาจากรหัสหรือชื่อ',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: display.isEmpty
                ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                : ListView(
                    children: display.map((it) {
                      final id = widget.idOf(it);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(widget.labelOf(it, isEnglish), style: const TextStyle(fontSize: 13)),
                        value: _selected.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    final allIds = widget.items.map((it) => widget.idOf(it)).toList();
                    if (_selected.length == allIds.length) {
                      _selected = [];
                    } else {
                      _selected = allIds;
                    }
                  });
                },
                child: Text(_selected.length == widget.items.length
                    ? (isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                  child: Text(isEnglish ? 'OK' : 'ตกลง'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
