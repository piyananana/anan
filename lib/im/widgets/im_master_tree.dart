// lib/im/widgets/im_master_tree.dart — ต้นไม้ของแผงซ้าย (หมวดหมู่สินค้า / ตำแหน่งจัดเก็บ, user 2026-11-25)
// เส้นแสดงระดับ, ลูกศรพับ/กาง, ป้ายชนิด (H/C, G/B), ตัวเลขท้ายแถว, ปุ่ม ＋ เพิ่มลูก (ชี้เมาส์/แถวที่เลือก),
// กาง/พับทั้งหมด, ค้นหา/กรอง (แสดงแถวที่ตรง + แม่ทุกระดับ กางให้อัตโนมัติ), ลากแถววางบนแถวอื่นเพื่อย้าย (ยืนยันก่อน)
// onReorder (หน้าจัดการเมนู 2026-11-27): วางที่ขอบบน/ล่างของแถว = เรียงก่อน/หลังแถวนั้น, กลางแถวที่มีลูกได้ = ย้ายเข้าไป
import 'package:flutter/material.dart';
import 'im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

class ImTreeNode {
  final int id;
  final int? parentId;
  final String code;
  final String name;
  final String kind; // ตัวอักษรในป้ายชนิด
  final Color kindBg;
  final Color kindFg;
  final String? count; // ข้อความท้ายแถว (เช่น 382, 24 ช่อง, ว่าง)
  final bool active;
  final bool canHaveChildren; // วางแถวอื่นลงบนแถวนี้ได้ / มีปุ่ม ＋
  final int? order; // ลำดับในระดับเดียวกัน (null = เรียงตามรหัส)
  final Widget? lead; // ต่อท้ายป้ายชนิด (เช่น จุดสีธีม)
  final Widget? trail; // ก่อนตัวเลขท้ายแถว (เช่น ป้าย SYS)
  final String? search; // ข้อความเพิ่มสำหรับค้นหา (เช่น ชื่ออังกฤษ / ชื่อหน้าจอ)
  const ImTreeNode({required this.id, this.parentId, required this.code, required this.name, required this.kind,
      required this.kindBg, required this.kindFg, this.count, this.active = true, this.canHaveChildren = true,
      this.order, this.lead, this.trail, this.search});
}

class ImMasterTree extends StatefulWidget {
  final List<ImTreeNode> nodes;
  final int? selectedId;
  final String query;
  final bool Function(ImTreeNode)? filter;
  final ValueChanged<ImTreeNode> onTap;
  final ValueChanged<ImTreeNode>? onAddChild;
  /// ย้าย node ไปอยู่ใต้ newParent (null = ระดับบนสุด) — null = ลากไม่ได้
  final Future<void> Function(ImTreeNode node, ImTreeNode? newParent)? onMove;
  /// ลากเพื่อย้าย + เรียงลำดับ: newParent (null = บนสุด), before = วางก่อนแถวนี้ (null = ท้ายสุด) — ใช้แทน onMove
  final Future<void> Function(ImTreeNode node, ImTreeNode? newParent, ImTreeNode? before)? onReorder;
  final bool isEnglish;
  final String emptyText;
  final List<(String, String, Color, Color)> legend; // (ตัวอักษร, ชื่อชนิด, พื้น, ตัวอักษร)

  const ImMasterTree({super.key, required this.nodes, this.selectedId, this.query = '', this.filter, required this.onTap,
      this.onAddChild, this.onMove, this.onReorder, required this.isEnglish, required this.emptyText, this.legend = const []});

  @override
  State<ImMasterTree> createState() => _ImMasterTreeState();
}

class _ImMasterTreeState extends State<ImMasterTree> {
  final Set<int> _expanded = {};
  int? _hover;
  int? _dropTarget; // แถวที่กำลังลากผ่าน (-1 = โซนระดับบนสุด)
  int _dropPos = 1; // onReorder: 0 = ก่อนแถว, 1 = เข้าไปในแถว, 2 = หลังแถว

  bool get _draggable => widget.onMove != null || widget.onReorder != null;

  Map<int?, List<ImTreeNode>> get _byParent {
    final m = <int?, List<ImTreeNode>>{};
    final ids = widget.nodes.map((n) => n.id).toSet();
    for (final n in widget.nodes) {
      // แม่ที่ไม่อยู่ในชุดข้อมูล (เช่น ถูกกรองฝั่ง backend) → แสดงเป็นระดับบนสุด
      m.putIfAbsent(ids.contains(n.parentId) ? n.parentId : null, () => []).add(n);
    }
    for (final l in m.values) {
      l.sort((a, b) => a.order != null && b.order != null && a.order != b.order ? a.order!.compareTo(b.order!) : a.code.compareTo(b.code));
    }
    return m;
  }

  @override
  void didUpdateWidget(covariant ImMasterTree old) {
    super.didUpdateWidget(old);
    // เลือกแถวใหม่จากที่อื่น (เช่น หลังบันทึก/เพิ่มลูก) → กางแม่ทุกระดับให้เห็นแถวนั้น
    if (widget.selectedId != null && widget.selectedId != old.selectedId) {
      final byId = {for (final n in widget.nodes) n.id: n};
      var p = byId[widget.selectedId]?.parentId;
      while (p != null && byId.containsKey(p)) {
        _expanded.add(p);
        p = byId[p]?.parentId;
      }
    }
  }

  Set<int> _descendants(int id, Map<int?, List<ImTreeNode>> byParent) {
    final out = <int>{};
    void walk(int x) {
      for (final c in byParent[x] ?? const <ImTreeNode>[]) {
        if (out.add(c.id)) walk(c.id);
      }
    }
    walk(id);
    return out;
  }

  /// แถวที่แสดง (ตามลำดับ) พร้อมระดับ
  List<(ImTreeNode, int, bool)> _rows() {
    final byParent = _byParent;
    final q = widget.query.trim().toUpperCase();
    final filtering = q.isNotEmpty || widget.filter != null;
    Set<int>? keep;
    if (filtering) {
      final byId = {for (final n in widget.nodes) n.id: n};
      keep = {};
      for (final n in widget.nodes) {
        final hit = (q.isEmpty || n.code.toUpperCase().contains(q) || n.name.toUpperCase().contains(q) ||
                (n.search ?? '').toUpperCase().contains(q)) &&
            (widget.filter == null || widget.filter!(n));
        if (!hit) continue;
        keep.add(n.id);
        var p = n.parentId;
        while (p != null && byId.containsKey(p)) {
          keep.add(p);
          p = byId[p]?.parentId;
        }
      }
    }
    final out = <(ImTreeNode, int, bool)>[];
    void add(int? parent, int level) {
      for (final n in byParent[parent] ?? const <ImTreeNode>[]) {
        if (keep != null && !keep.contains(n.id)) continue;
        final hasKids = (byParent[n.id] ?? const []).isNotEmpty;
        out.add((n, level, hasKids));
        if (hasKids && (keep != null || _expanded.contains(n.id))) add(n.id, level + 1);
      }
    }
    add(null, 0);
    return out;
  }

  Future<void> _drop(ImTreeNode node, ImTreeNode? target) async {
    setState(() => _dropTarget = null);
    if (widget.onMove == null || node.parentId == target?.id) return;
    final e = widget.isEnglish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Move' : 'ย้ายตำแหน่งในผัง'),
        content: Text(target == null
            ? (e ? 'Move "${node.code} ${node.name}" to the top level?' : 'ย้าย "${node.code} ${node.name}" ไปเป็นระดับบนสุด?')
            : (e
                ? 'Move "${node.code} ${node.name}" under "${target.code} ${target.name}"?'
                : 'ย้าย "${node.code} ${node.name}" ไปอยู่ใต้ "${target.code} ${target.name}"?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(e ? 'Move' : 'ย้าย')),
        ],
      ),
    );
    if (ok != true) return;
    if (target != null) _expanded.add(target.id);
    await widget.onMove!(node, target);
  }

  String _label(ImTreeNode n) => n.code.isEmpty ? n.name : '${n.code} ${n.name}';

  /// onReorder: วาง node ที่ target ตามตำแหน่ง pos — ย้ายข้ามโฟลเดอร์ถามยืนยันก่อน, เรียงในระดับเดิมไม่ถาม
  Future<void> _dropReorder(ImTreeNode node, ImTreeNode? target, int pos, Map<int?, List<ImTreeNode>> byParent) async {
    setState(() => _dropTarget = null);
    final byId = {for (final n in widget.nodes) n.id: n};
    ImTreeNode? parent;
    ImTreeNode? before;
    if (target == null) {
      parent = null; // โซนท้ายรายการ = ท้ายสุดของระดับบนสุด
    } else if (pos == 1) {
      parent = target;
    } else {
      parent = target.parentId == null ? null : byId[target.parentId];
      final sibs = (byParent[parent?.id] ?? const <ImTreeNode>[]).where((x) => x.id != node.id).toList();
      if (pos == 0) {
        before = target;
      } else {
        final i = sibs.indexWhere((x) => x.id == target.id);
        before = i >= 0 && i + 1 < sibs.length ? sibs[i + 1] : null;
      }
    }
    if (before?.id == node.id) return;
    final e = widget.isEnglish;
    if (node.parentId != parent?.id) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(e ? 'Move' : 'ย้ายตำแหน่งในผัง'),
          content: Text(parent == null
              ? (e ? 'Move "${_label(node)}" to the top level?' : 'ย้าย "${_label(node)}" ไปเป็นระดับบนสุด?')
              : (e ? 'Move "${_label(node)}" under "${_label(parent)}"?' : 'ย้าย "${_label(node)}" ไปอยู่ใต้ "${_label(parent)}"?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(e ? 'Move' : 'ย้าย')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (parent != null) _expanded.add(parent.id);
    await widget.onReorder!(node, parent, before);
  }

  Widget _kindBadge(ImTreeNode n, {double size = 20}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: n.kindBg, borderRadius: BorderRadius.circular(5)),
        child: Text(n.kind, style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.bold, color: n.kindFg)),
      );

  Widget _row(ImTreeNode n, int level, bool hasKids, Map<int?, List<ImTreeNode>> byParent) {
    final selected = widget.selectedId == n.id;
    final hover = _hover == n.id;
    final expanded = _expanded.contains(n.id) || widget.query.trim().isNotEmpty || widget.filter != null;
    final dropOn = _dropTarget == n.id && (widget.onReorder == null || _dropPos == 1);
    final lineAt = _dropTarget == n.id && widget.onReorder != null && _dropPos != 1 ? _dropPos : null;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.only(left: 4, right: 6),
      decoration: BoxDecoration(
        color: dropOn ? ScreenTheme.of(context).soft : (selected || hover ? Colors.white : Colors.white.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: dropOn ? ScreenTheme.of(context).ink : (selected ? ImKit.gold : Colors.transparent), width: 1.5),
        boxShadow: selected ? [BoxShadow(color: ImKit.gold.withOpacity(0.25), spreadRadius: 2)] : null,
      ),
      child: Row(children: [
        for (var i = 0; i < level; i++)
          Container(width: 14, height: 34, margin: const EdgeInsets.only(left: 2),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF9FB0B6))))),
        SizedBox(
          width: 22,
          child: hasKids
              ? InkWell(
                  onTap: () => setState(() => expanded ? _expanded.remove(n.id) : _expanded.add(n.id)),
                  child: Icon(expanded ? Icons.arrow_drop_down : Icons.arrow_right, size: 20, color: ImKit.ink2),
                )
              : null,
        ),
        _kindBadge(n),
        if (n.lead != null) ...[const SizedBox(width: 6), n.lead!],
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              if (n.code.isNotEmpty)
                TextSpan(text: '${n.code}  ', style: TextStyle(fontWeight: FontWeight.w600, color: n.active ? ScreenTheme.of(context).ink : ImKit.ink3)),
              TextSpan(text: n.name),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: n.active ? null : ImKit.ink3, decoration: n.active ? null : TextDecoration.lineThrough),
          ),
        ),
        if (n.trail != null) ...[const SizedBox(width: 4), n.trail!],
        if ((n.count ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFEEF1F4), borderRadius: BorderRadius.circular(999)),
            child: Text(n.count!, style: const TextStyle(fontSize: 11, color: ImKit.ink2, fontFeatures: [FontFeature.tabularFigures()])),
          ),
        if (widget.onAddChild != null && n.canHaveChildren)
          Opacity(
            opacity: hover || selected ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: widget.isEnglish ? 'Add child' : 'เพิ่มลูก',
                child: InkWell(
                  onTap: () => widget.onAddChild!(n),
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ImKit.line), borderRadius: BorderRadius.circular(5)),
                    child: Icon(Icons.add, size: 15, color: ScreenTheme.of(context).ink),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
    final Widget base = MouseRegion(
      onEnter: (_) => setState(() => _hover = n.id),
      onExit: (_) => setState(() => _hover = _hover == n.id ? null : _hover),
      child: GestureDetector(onTap: () => widget.onTap(n), child: content),
    );
    final Widget shown = lineAt == null
        ? base
        : Stack(clipBehavior: Clip.none, children: [
            base,
            Positioned(
              left: 4.0 + level * 16,
              right: 4,
              top: lineAt == 0 ? -2 : null,
              bottom: lineAt == 2 ? -2 : null,
              child: Container(height: 3, decoration: BoxDecoration(color: ImKit.gold, borderRadius: BorderRadius.circular(2))),
            ),
          ]);
    Widget row = shown;
    if (widget.onReorder != null) {
      row = Draggable<ImTreeNode>(
        data: n,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _kindBadge(n, size: 18),
              const SizedBox(width: 6),
              Text(_label(n), style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: base),
        child: Builder(
          builder: (rowCtx) => DragTarget<ImTreeNode>(
            // วางบนตัวเอง หรือบนลูกหลานของตัวที่ลากอยู่ไม่ได้ (กันวนรอบ)
            onWillAcceptWithDetails: (d) => d.data.id != n.id && !_descendants(d.data.id, byParent).contains(n.id),
            onMove: (d) {
              final box = rowCtx.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              final y = box.globalToLocal(d.offset).dy / (box.size.height == 0 ? 1 : box.size.height);
              final pos = n.canHaveChildren ? (y < 0.28 ? 0 : (y > 0.72 ? 2 : 1)) : (y < 0.5 ? 0 : 2);
              if (_dropTarget != n.id || _dropPos != pos) {
                setState(() {
                  _dropTarget = n.id;
                  _dropPos = pos;
                });
              }
            },
            onLeave: (_) => setState(() => _dropTarget = _dropTarget == n.id ? null : _dropTarget),
            onAcceptWithDetails: (d) => _dropReorder(d.data, n, _dropPos, byParent),
            builder: (c, _, __) => shown,
          ),
        ),
      );
    } else if (widget.onMove != null) {
      final blocked = {n.id, ..._descendants(n.id, byParent)};
      row = Draggable<ImTreeNode>(
        data: n,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _kindBadge(n, size: 18),
              const SizedBox(width: 6),
              Text('${n.code}  ${n.name}', style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: base),
        child: DragTarget<ImTreeNode>(
          onWillAcceptWithDetails: (d) {
            final ok = n.canHaveChildren && !blocked.contains(d.data.id) && d.data.parentId != n.id &&
                !_descendants(d.data.id, byParent).contains(n.id);
            if (ok && _dropTarget != n.id) setState(() => _dropTarget = n.id);
            return ok;
          },
          onLeave: (_) => setState(() => _dropTarget = _dropTarget == n.id ? null : _dropTarget),
          onAcceptWithDetails: (d) => _drop(d.data, n),
          builder: (c, _, __) => base,
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 2), child: row);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.isEnglish;
    final rows = _rows();
    final byParent = _byParent;
    final allParents = widget.nodes.where((n) => (byParent[n.id] ?? const []).isNotEmpty).map((n) => n.id).toSet();
    Widget tool(String label, IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: ImKit.ink2),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          tool(e ? 'Expand all' : 'กางทั้งหมด', Icons.unfold_more, () => setState(() => _expanded.addAll(allParents))),
          tool(e ? 'Collapse all' : 'พับทั้งหมด', Icons.unfold_less, () => setState(() => _expanded.clear())),
        ]),
      ),
      if (_draggable)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Text(
              widget.onReorder != null
                  ? (e ? 'Drag a row onto a folder to move it, or onto a row edge to reorder' : 'ลากแถววางบนโฟลเดอร์เพื่อย้าย หรือวางที่ขอบแถวเพื่อเรียงลำดับ')
                  : (e ? 'Drag a row onto another row to move it' : 'ลากแถววางบนแถวอื่นเพื่อย้าย'),
              style: const TextStyle(fontSize: 11, color: ImKit.ink3)),
        ),
      Expanded(
        child: rows.isEmpty
            ? Center(child: Text(widget.emptyText, style: const TextStyle(color: ImKit.ink2)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: rows.length,
                itemBuilder: (_, i) => _row(rows[i].$1, rows[i].$2, rows[i].$3, byParent),
              ),
      ),
      if (_draggable)
        DragTarget<ImTreeNode>(
          onWillAcceptWithDetails: (d) {
            final ok = widget.onReorder != null || d.data.parentId != null;
            if (ok && _dropTarget != -1) setState(() => _dropTarget = -1);
            return ok;
          },
          onLeave: (_) => setState(() => _dropTarget = _dropTarget == -1 ? null : _dropTarget),
          onAcceptWithDetails: (d) => widget.onReorder != null ? _dropReorder(d.data, null, 2, byParent) : _drop(d.data, null),
          builder: (c, cand, _) => cand.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _dropTarget == -1 ? ScreenTheme.of(context).soft : Colors.white.withOpacity(0.6),
                    border: Border.all(color: ScreenTheme.of(context).ink),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                      widget.onReorder != null
                          ? (e ? 'Drop here to put it last at the top level' : 'วางที่นี่เพื่อย้ายไปท้ายสุดของระดับบนสุด')
                          : (e ? 'Drop here to move to the top level' : 'วางที่นี่เพื่อย้ายไปเป็นระดับบนสุด'),
                      style: TextStyle(fontSize: 12, color: ScreenTheme.of(context).ink)),
                ),
        ),
      if (widget.legend.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Wrap(spacing: 10, children: [
            for (final l in widget.legend)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 14, height: 14, alignment: Alignment.center,
                  decoration: BoxDecoration(color: l.$3, borderRadius: BorderRadius.circular(4)),
                  child: Text(l.$1, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: l.$4)),
                ),
                const SizedBox(width: 4),
                Text(l.$2, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
              ]),
          ]),
        ),
    ]);
  }
}
