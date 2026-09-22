// lib/sa/widgets/sa_attachment_widget.dart — ปุ่มไฟล์แนบท้ายรายการแบบ generic ใช้ร่วมกันได้ทุกโมดูล ส่ง moduleCode
// ต่างกันไปตามจุดที่เรียกใช้ (เช่น 'pr_transaction_detail', 'po_transaction_detail') — จัดการ fetch/upload/delete
// ของตัวเองทั้งหมด ไม่ผูกกับ state ของ parent
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_attachment_service.dart';
import '../models/sa_attachment.dart';

class AttachmentButton extends StatefulWidget {
  final String moduleCode;
  final int? entityId; // null = บรรทัดยังไม่ถูกบันทึก ยังแนบไฟล์ไม่ได้
  final bool readOnly;

  const AttachmentButton({super.key, required this.moduleCode, required this.entityId, required this.readOnly});

  @override
  State<AttachmentButton> createState() => _AttachmentButtonState();
}

class _AttachmentButtonState extends State<AttachmentButton> {
  final _service = AttachmentService();
  List<SaAttachment> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.entityId != null) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _service.fetchByEntity(widget.moduleCode, widget.entityId!);
      if (mounted) setState(() { _items = rows; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _openDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _AttachmentDialog(
        moduleCode: widget.moduleCode,
        entityId: widget.entityId!,
        readOnly: widget.readOnly,
        initialItems: _items,
        onChanged: (rows) => setState(() => _items = rows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (widget.entityId == null) {
      return Tooltip(
        message: isEnglish ? 'Save first' : 'บันทึกก่อนจึงจะแนบไฟล์ได้',
        child: const IconButton(
          icon: Icon(Icons.attach_file, size: 18, color: Colors.grey),
          onPressed: null,
        ),
      );
    }
    return Tooltip(
      message: isEnglish ? 'Attachments' : 'ไฟล์แนบ',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openDialog,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.attach_file, size: 18, color: _items.isNotEmpty ? Colors.blue[700] : Colors.grey[600]),
            if (_loaded && _items.isNotEmpty)
              Positioned(
                right: -6, top: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text('${_items.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _AttachmentDialog extends StatefulWidget {
  final String moduleCode;
  final int entityId;
  final bool readOnly;
  final List<SaAttachment> initialItems;
  final ValueChanged<List<SaAttachment>> onChanged;

  const _AttachmentDialog({
    required this.moduleCode,
    required this.entityId,
    required this.readOnly,
    required this.initialItems,
    required this.onChanged,
  });

  @override
  State<_AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<_AttachmentDialog> {
  final _service = AttachmentService();
  late List<SaAttachment> _items;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initialItems);
  }

  Future<void> _add() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() { _busy = true; _err = null; });
    try {
      final uploaded = await _service.upload(widget.moduleCode, widget.entityId, result.files.first);
      setState(() => _items = [..._items, uploaded]);
      widget.onChanged(_items);
    } catch (e) {
      setState(() => _err = isEnglish ? 'Upload failed: $e' : 'อัปโหลดล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(SaAttachment item) async {
    setState(() { _busy = true; _err = null; });
    try {
      await _service.delete(item.id);
      setState(() => _items = _items.where((r) => r.id != item.id).toList());
      widget.onChanged(_items);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(SaAttachment item) async {
    if (item.isImage) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.network(item.fullUrl)),
        ),
      );
    } else {
      await launchUrl(Uri.parse(item.fullUrl), webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return AlertDialog(
      title: Text(isEnglish ? 'Attachments' : 'ไฟล์แนบ'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_err != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.red[50], border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(4)),
              child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(isEnglish ? 'No attachments' : 'ยังไม่มีไฟล์แนบ', style: const TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return ListTile(
                    dense: true,
                    leading: item.isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(item.fullUrl, width: 40, height: 40, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 32)),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 32, color: Colors.red),
                    title: Text(item.fileName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _view(item),
                    trailing: widget.readOnly
                        ? null
                        : IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: _busy ? null : () => _delete(item)),
                  );
                },
              ),
            ),
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()),
        ]),
      ),
      actions: [
        if (!widget.readOnly)
          TextButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add, size: 16),
            label: Text(isEnglish ? 'Add' : 'เพิ่มไฟล์'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Close' : 'ปิด')),
      ],
    );
  }
}
