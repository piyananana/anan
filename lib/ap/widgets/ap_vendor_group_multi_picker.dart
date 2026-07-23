import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/ap_vendor_group.dart';

class ApVendorGroupMultiPicker extends StatelessWidget {
  final List<ApVendorGroup> groups;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final String? label;

  const ApVendorGroupMultiPicker({
    super.key,
    required this.groups,
    required this.selectedIds,
    required this.onChanged,
    this.label,
  });

  Future<void> _pick(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ApVendorGroupMultiPickerDialog(
        groups: groups,
        selected: selectedIds,
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
        labelText: label ?? (isEnglish ? 'Vendor Group' : 'กลุ่มผู้ขาย'),
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
                  child: Icon(Icons.arrow_drop_down, size: 20))),
        ]),
      ),
      child: InkWell(
        onTap: () => _pick(context),
        child: Text(
          hasValue
              ? (isEnglish
                  ? 'Selected ${selectedIds.length} item(s)'
                  : 'เลือก ${selectedIds.length} รายการ')
              : (isEnglish ? '— All groups —' : '— ทุกกลุ่ม —'),
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ApVendorGroupMultiPickerDialog extends StatefulWidget {
  final List<ApVendorGroup> groups;
  final List<int> selected;

  const _ApVendorGroupMultiPickerDialog({
    required this.groups,
    required this.selected,
  });

  @override
  State<_ApVendorGroupMultiPickerDialog> createState() =>
      _ApVendorGroupMultiPickerDialogState();
}

class _ApVendorGroupMultiPickerDialogState
    extends State<_ApVendorGroupMultiPickerDialog> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 400, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blueGrey[700],
            child: Text(isEnglish ? 'Select Vendor Group' : 'เลือกกลุ่มผู้ขาย',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.groups.where((g) => g.isActive).map((g) {
                final id = g.id!;
                final groupName = isEnglish && g.groupNameEng.isNotEmpty
                    ? g.groupNameEng
                    : g.groupNameThai;
                return CheckboxListTile(
                  dense: true,
                  title: Text('${g.groupCode}  $groupName',
                      style: const TextStyle(fontSize: 13)),
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
                    if (_selected.length == widget.groups.length) {
                      _selected = [];
                    } else {
                      _selected = widget.groups.map((g) => g.id!).toList();
                    }
                  });
                },
                child: Text(_selected.length == widget.groups.length
                    ? (isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      foregroundColor: Colors.white),
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
