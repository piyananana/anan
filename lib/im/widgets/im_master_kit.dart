// lib/im/widgets/im_master_kit.dart — หน้าตาร่วมของหน้าจอข้อมูลหลัก IM แบบ B (user 2026-11-25)
// ใช้กับ หน่วยนับ / คลังสินค้า / กลุ่มราคา / ตารางราคา (หน้าจอสินค้ามีชุดของตัวเองใน im_item_detail_widget.dart)
//   - ImMasterShell: AppBar สี IM + แถบย่อ/ขยาย + แผงซ้ายลากปรับกว้างได้ + แผงขวา
//   - ImMasterList*: การ์ดรายการ, ปุ่มกรอง, ช่องค้นหา
//   - ImMasterKit (mixin ของ State ฝั่งรายละเอียด): ช่องกรอก 40px สีพื้นตามที่มา, กลุ่มสี, การ์ด, ตาราง 36px,
//     ตัวเลขสรุป, แถบหัว (ชื่อ+ป้ายชิดซ้าย ปุ่มชิดขวา), แถบลิงก์ข้ามส่วน + เลื่อนหน้าเดียว
// สี AppBar / แถบหัว / พื้นอ่อน / สีหลัก มาจากสีธีมของเมนู (ScreenTheme.of(context), 2026-11-27) — ไม่ได้ตั้ง = teal เดิม
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/utils/sa_menu_theme.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';

class ImKit {
  static const bar = Color(0xFF0F6E6E);
  static const rhd = Color(0xFF4DA3A3);
  static const listBg = Color(0xFFCFD8DC);
  static const pageBg = Color(0xFFF3F5F4);
  static const im = Color(0xFF0F5C5C);
  static const imSoft = Color(0xFFE8F3F2);
  static const line = Color(0xFFE1E6E3);
  static const ink2 = Color(0xFF55625B);
  static const ink3 = Color(0xFF8B968F);
  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDECEA);
  static const ok = Color(0xFF1E6B3A);
  static const okSoft = Color(0xFFE6F4EA);
  static const gold = Color(0xFFE0A526);
  static const goldSoft = Color(0xFFFFF4DA);
  static const amber = Color(0xFF8A5A00);
  static const auto = Color(0xFFE3EEFA);
  static const ro = Color(0xFFEEF0F2);
  static const gDoc = Color(0xFF1E5AA8);
  static const gParty = Color(0xFF1F7A4D);
  static const gFin = Color(0xFFB45309);
  static const gMore = Color(0xFF5B6B7C);
  static const blueSoft = Color(0xFFE3EEFA);
  static const blue = Color(0xFF1E4F8F);
  static const purSoft = Color(0xFFEFE8FB);
  static const pur = Color(0xFF5B3B9A);
  static const double fieldH = 40;
  static const double font = 13;

  static Widget chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      );

  static Widget activeChip(bool active, bool isEnglish) => active
      ? chip(isEnglish ? 'Active' : 'ใช้งาน', okSoft, ok)
      : chip(isEnglish ? 'Inactive' : 'หยุดใช้', redSoft, red);

  /// ปุ่มบน AppBar ของหน้าจอ (นำเข้า/เพิ่ม) — ฟอนต์ตามระบบ
  static Widget barButton(BuildContext context, String label, IconData icon, VoidCallback onPressed, {bool primary = false}) {
    final style = TextStyle(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily, fontWeight: FontWeight.w600, fontSize: 13);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(7));
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: primary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF0B3A2A), textStyle: style,
                  padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 34), shape: shape),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), textStyle: style,
                  padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 34), shape: shape),
            ),
    );
  }

  /// เปิดเมนูอื่นเป็นแท็บ (สิทธิ์จริงของผู้ใช้) — ไม่มีเมนู → แจ้ง
  static void openMenu(BuildContext context, String targetPath, String nameTh, String nameEn, bool isEnglish) {
    if (!MenuOpener.open(targetPath)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'You do not have access to the $nameEn menu' : 'ไม่มีสิทธิ์เข้าถึงเมนู$nameTh'),
        backgroundColor: red,
      ));
    }
  }
}

/// ตารางกว้างกว่าพื้นที่ → เลื่อนแนวนอน พร้อมแถบเลื่อนที่เห็นตลอด (เว็บ: ล้อเมาส์เลื่อนแนวนอนไม่ได้ ต้องมีแถบให้ลาก)
class ImHScroll extends StatefulWidget {
  final double width;
  final Widget child;
  const ImHScroll({super.key, required this.width, required this.child});

  @override
  State<ImHScroll> createState() => _ImHScrollState();
}

class _ImHScrollState extends State<ImHScroll> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _ctrl,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12), // เว้นที่ให้แถบเลื่อนไม่ทับแถวสุดท้าย
          child: SizedBox(width: widget.width, child: widget.child),
        ),
      );
}

// ---------------------------------------------------------------------------
// โครงหน้าจอ
// ---------------------------------------------------------------------------
/// สถานะย่อ/ขยายรายการซ้ายของ ImMasterShell — แถบหัวแผงขวา (kHeaderBar) / หน้าว่าง (kPlaceholder)
/// อ่านจากตรงนี้แล้ววางปุ่มไว้หน้ารหัส/ชื่อ (แบบเดียวกับปุ่มย่อแถบเมนู) แทนแถบปุ่มแนวตั้งกว้าง 36 เดิม
class ImListToggle extends InheritedWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final bool isEnglish;

  const ImListToggle({super.key, required this.expanded, required this.onToggle, required this.isEnglish, required super.child});

  @override
  bool updateShouldNotify(ImListToggle oldWidget) => oldWidget.expanded != expanded || oldWidget.isEnglish != isEnglish;

  /// ปุ่มย่อ/ขยายรายการ — null เมื่อไม่ได้อยู่ใน ImMasterShell
  static Widget? button(BuildContext context, {bool onHeader = true}) {
    final s = context.dependOnInheritedWidgetOfExactType<ImListToggle>();
    if (s == null) return null;
    final e = s.isEnglish;
    return IconButton(
      icon: Icon(s.expanded ? Icons.menu_open_rounded : Icons.menu_rounded, color: onHeader ? Colors.white : Colors.blueGrey.shade700),
      tooltip: s.expanded ? (e ? 'Collapse list' : 'ย่อรายการ') : (e ? 'Expand list' : 'ขยายรายการ'),
      onPressed: s.onToggle,
    );
  }

  /// หน้าว่างของแผงขวา (ยังไม่เลือกรายการ) — มีปุ่มย่อ/ขยายรายการที่มุมซ้ายบน
  static Widget placeholder(BuildContext context, IconData? icon, String text) {
    final toggle = button(context, onHeader: false);
    return Container(
      color: ImKit.pageBg,
      child: Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8)],
            Text(text, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ]),
        ),
        if (toggle != null) Positioned(left: 4, top: 4, child: toggle),
      ]),
    );
  }
}

class ImMasterShell extends StatefulWidget {
  final List<Widget> barActions;
  final Widget list;
  final Widget detail;
  final bool isEnglish;
  final double initialListWidth;

  const ImMasterShell({super.key, required this.barActions, required this.list, required this.detail, required this.isEnglish,
      this.initialListWidth = 300});

  @override
  State<ImMasterShell> createState() => _ImMasterShellState();
}

class _ImMasterShellState extends State<ImMasterShell> {
  bool _expanded = true;
  late double _width = widget.initialListWidth;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isEnglish = widget.isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: ScreenTheme.of(context).bar,
        foregroundColor: Colors.white,
        actions: [...widget.barActions, const SizedBox(width: 4)],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxLeft = (constraints.maxWidth - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
            width: _expanded ? _width : 0.0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _width,
                minWidth: _width,
                alignment: Alignment.topLeft,
                child: ColoredBox(color: ImKit.listBg, child: widget.list),
              ),
            ),
          ),
          if (_expanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (d) => setState(() => _width = (_width + d.delta.dx).clamp(220.0, maxLeft)),
                onHorizontalDragEnd: (_) => setState(() => _dragging = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          Expanded(
            child: ImListToggle(
              expanded: _expanded,
              isEnglish: isEnglish,
              onToggle: () => setState(() => _expanded = !_expanded),
              child: widget.detail,
            ),
          ),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// แผงรายการซ้าย
// ---------------------------------------------------------------------------
class ImMasterFilterChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? fg;
  const ImMasterFilterChip({super.key, required this.label, required this.on, required this.onTap, this.fg});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: on ? ScreenTheme.of(context).ink : Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(999)),
          child: Text(label,
              style: TextStyle(fontSize: 12, color: on ? Colors.white : (fg ?? ImKit.ink2), fontWeight: on ? FontWeight.w600 : null)),
        ),
      );
}

/// ปุ่มกรองแบบเลือกจากรายการ (เช่น สาขา/กลุ่ม) — value null = ทั้งหมด
class ImMasterPopupFilter extends StatelessWidget {
  final String label;
  final String? value;
  final String? valueLabel;
  final List<(String, String)> options; // (value, label)
  final String allLabel;
  final ValueChanged<String?> onChanged;
  const ImMasterPopupFilter({super.key, required this.label, required this.value, this.valueLabel, required this.options,
      required this.allLabel, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(allLabel)),
        for (final o in options) PopupMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: on ? ScreenTheme.of(context).ink : Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(on ? (valueLabel ?? value!) : label,
              style: TextStyle(fontSize: 12, color: on ? Colors.white : ImKit.ink2, fontWeight: on ? FontWeight.w600 : null)),
          Icon(Icons.arrow_drop_down, size: 16, color: on ? Colors.white : ImKit.ink2),
        ]),
      ),
    );
  }
}

/// ส่วนบนของแผงรายการ: ช่องค้นหา + ปุ่มกรอง + จำนวนรายการ
class ImMasterListHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String hint;
  final ValueChanged<String> onSearch;
  final List<Widget> filters;
  final String countText;
  final Widget? trailing;
  const ImMasterListHeader({super.key, required this.searchCtrl, required this.hint, required this.onSearch, required this.filters,
      required this.countText, this.trailing});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: onSearch,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
        if (filters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Wrap(spacing: 4, runSpacing: 4, children: filters),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(countText, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
        ),
      ]);
}

/// การ์ดรายการ 1 ใบ: รหัส + ป้าย, ชื่อ, บรรทัดข้อมูลย่อ; selected = ขอบทอง
class ImMasterListCard extends StatelessWidget {
  final String code;
  final List<Widget> chips;
  final String name;
  final InlineSpan? meta;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  const ImMasterListCard({super.key, required this.code, this.chips = const [], required this.name, this.meta,
      required this.selected, this.active = true, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? ImKit.gold : Colors.transparent, width: selected ? 1.5 : 1),
                boxShadow: selected ? [BoxShadow(color: ImKit.gold.withOpacity(0.25), spreadRadius: 2)] : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? ScreenTheme.of(context).ink : ImKit.ink3,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                  for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 4), chips[i]],
                ]),
                const SizedBox(height: 2),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: active ? null : ImKit.ink3)),
                if (meta != null) ...[
                  const SizedBox(height: 3),
                  Text.rich(TextSpan(style: const TextStyle(fontSize: 11.5, color: ImKit.ink3), children: [meta!]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// ชิ้นส่วนฝั่งรายละเอียด
// ---------------------------------------------------------------------------
class KCol {
  final String label;
  final int flex;
  final bool num;
  const KCol(this.label, this.flex, {this.num = false});
}

class ImKpi {
  final String label;
  final String value;
  final String sub;
  final bool warn;
  final VoidCallback? onTap;
  const ImKpi(this.label, this.value, this.sub, {this.warn = false, this.onTap});
}

mixin ImMasterKit<T extends StatefulWidget> on State<T> {
  bool get kitEnglish;
  bool get kitReadOnly;

  /// สีหลักของหน้าจอตามสีธีมของเมนู (ปุ่ม/ตัวอักษรเน้นบนพื้นขาว)
  Color get kInk => ScreenTheme.of(context).ink;
  ScreenThemeColors get kTheme => ScreenTheme.of(context);

  // แถบลิงก์ข้ามส่วน
  final ScrollController kScroll = ScrollController();
  final GlobalKey _kBodyKey = GlobalKey();
  final Map<int, GlobalKey> _kSecKeys = {};
  int kActiveSec = 0;
  bool _kActiveScheduled = false;
  List<int> _kPresent = const [];

  GlobalKey _secKey(int i) => _kSecKeys.putIfAbsent(i, () => GlobalKey());

  @override
  void dispose() {
    kScroll.dispose();
    super.dispose();
  }

  /// เลื่อนกลับบนสุด (หลังเฟรม) — เรียกเมื่อเปลี่ยนรายการ
  void kScrollTop() {
    kActiveSec = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && kScroll.hasClients) kScroll.jumpTo(0);
    });
  }

  void kJumpTo(int i) {
    setState(() => kActiveSec = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _kSecKeys[i]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _kUpdateActive() {
    final root = _kBodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || !kScroll.hasClients || _kPresent.isEmpty) return;
    var active = _kPresent.first;
    final pos = kScroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 2 && pos.maxScrollExtent > 0) {
      active = _kPresent.last;
    } else {
      for (final i in _kPresent) {
        final b = _kSecKeys[i]?.currentContext?.findRenderObject() as RenderBox?;
        if (b == null || !b.attached) continue;
        if (b.localToGlobal(Offset.zero, ancestor: root).dy <= 60) active = i;
      }
    }
    if (active != kActiveSec) setState(() => kActiveSec = active);
  }

  Widget _kAnchors(List<(int, String)> sections) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in sections)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => kJumpTo(s.$1),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: kActiveSec == s.$1 ? ScreenTheme.of(context).soft : null,
                      border: Border.all(color: kActiveSec == s.$1 ? Color.lerp(ScreenTheme.of(context).soft, ScreenTheme.of(context).ink, 0.25)! : ImKit.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(s.$2,
                        style: TextStyle(fontSize: 12.5, color: kActiveSec == s.$1 ? ScreenTheme.of(context).ink : ImKit.ink2,
                            fontWeight: kActiveSec == s.$1 ? FontWeight.w600 : null)),
                  ),
                ),
              ),
          ]),
        ),
      );

  /// หน้ารายละเอียดทั้งหน้า: แถบหัว + ลิงก์ข้ามส่วน + เนื้อหาเลื่อนหน้าเดียว
  /// sections = (id, ชื่อลิงก์, เนื้อหา) — id คงที่ต่อส่วน, top = เนื้อหาเหนือส่วนแรก (ตัวเลขสรุป)
  Widget kPage({required Widget header, required List<(int, String, Widget)> sections, Widget? top}) {
    _kPresent = sections.map((s) => s.$1).toList();
    if (!_kPresent.contains(kActiveSec) && _kPresent.isNotEmpty) kActiveSec = _kPresent.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      if (sections.length > 1) ...[_kAnchors([for (final s in sections) (s.$1, s.$2)]), const Divider(height: 1, color: ImKit.line)],
      Expanded(
        child: ColoredBox(
          color: ImKit.pageBg,
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              if (!_kActiveScheduled) {
                _kActiveScheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _kActiveScheduled = false;
                  if (mounted) _kUpdateActive();
                });
              }
              return false;
            },
            child: SingleChildScrollView(
              key: _kBodyKey,
              controller: kScroll,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (top != null) ...[top, const SizedBox(height: 12)],
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  KeyedSubtree(key: _secKey(sections[i].$1), child: sections[i].$3),
                ],
                const SizedBox(height: 240),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  /// แถบหัว: รหัส + ชื่อ + ป้าย ชิดซ้าย (ชื่อยาวขึ้นบรรทัดใหม่) / ปุ่มชิดขวา
  Widget kHeaderBar({String? code, required String title, List<Widget> badges = const [], required List<DocBarAction> acts, bool busy = false}) {
    final toggle = ImListToggle.button(context, onHeader: true);
    return Container(
      color: ScreenTheme.of(context).strip,
      padding: EdgeInsets.fromLTRB(toggle != null ? 4 : 14, 6, 14, 6),
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        if (toggle != null) toggle,
        Expanded(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
            if (code != null && code.isNotEmpty)
              Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()])),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ...badges,
          ]),
        ),
        const SizedBox(width: 8),
        buildDocBarActions(context, acts, busy: busy, isEnglish: kitEnglish),
      ]),
    );
  }

  /// ปุ่มมาตรฐานของแถบหัว: ดู = [extra..] ลบ ปิด แก้ไข / แก้ไข,เพิ่ม = ยกเลิก บันทึก
  List<DocBarAction> kStdActs({required bool saving, VoidCallback? onEdit, VoidCallback? onDelete, required VoidCallback onClose,
      required VoidCallback onCancel, required VoidCallback onSave, List<DocBarAction> extra = const []}) {
    final e = kitEnglish;
    if (kitReadOnly) {
      return [
        ...extra,
        if (onDelete != null) DocBarAction(e ? 'Delete' : 'ลบ', onDelete, fg: ImKit.red),
        DocBarAction(e ? 'Close' : 'ปิด', onClose, fg: kInk),
        if (onEdit != null) DocBarAction(e ? 'Edit' : 'แก้ไข', onEdit, fg: Colors.white, bg: kInk, primary: true),
      ];
    }
    return [
      DocBarAction(e ? 'Cancel' : 'ยกเลิก', saving ? null : onCancel, fg: kInk),
      DocBarAction(saving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), saving ? null : onSave,
          fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
    ];
  }

  Widget kEditingBadge() => ImKit.chip(kitEnglish ? 'Editing' : 'กำลังแก้ไข', ImKit.goldSoft, ImKit.amber);

  Widget kPlaceholder(IconData icon, String text) => ImListToggle.placeholder(context, icon, text);

  // ── ช่องกรอก ──
  InputDecoration kDec(String label, {bool auto = false, bool editable = true, Widget? suffixIcon}) {
    final req = label.endsWith(' *');
    final text = req ? label.substring(0, label.length - 2) : label;
    return InputDecoration(
      label: req
          ? Text.rich(TextSpan(text: text, children: const [TextSpan(text: ' *', style: TextStyle(color: ImKit.red))]))
          : Text(text),
      labelStyle: const TextStyle(fontSize: ImKit.font),
      floatingLabelStyle: const TextStyle(fontSize: 16),
      border: const OutlineInputBorder(),
      isDense: false,
      constraints: const BoxConstraints.tightFor(height: ImKit.fieldH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
      filled: !editable || auto,
      fillColor: !editable ? ImKit.ro : ImKit.auto,
      suffixIcon: suffixIcon,
    );
  }

  Widget kTxt(String label, TextEditingController c,
      {bool auto = false, bool? editable, bool numeric = false, bool digitsOnly = false, TextCapitalization cap = TextCapitalization.none}) {
    final ed = editable ?? !kitReadOnly;
    return TextField(
      controller: c,
      readOnly: !ed,
      textCapitalization: cap,
      textAlign: numeric ? TextAlign.right : TextAlign.start,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
      style: const TextStyle(fontSize: ImKit.font),
      decoration: kDec(label, auto: auto, editable: ed),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget kDd<V>(String label, V? value, List<DropdownMenuItem<V>> items, ValueChanged<V?>? onChanged, {bool auto = true}) =>
      DropdownButtonFormField<V>(
        value: value,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: ImKit.font, color: Colors.black87),
        decoration: kDec(label, auto: auto, editable: onChanged != null),
        items: items,
        onChanged: onChanged,
      );

  /// ช่องเลือกจากรายการค้นหา (กดทั้งช่อง = ค้นหา)
  Widget kFk({required String label, required String? text, required bool hasValue, VoidCallback? onSearch, VoidCallback? onClear,
      bool auto = false, bool locked = false, String? lockedTip}) {
    final ed = !kitReadOnly && !locked && onSearch != null;
    return InkWell(
      onTap: ed ? onSearch : null,
      child: InputDecorator(
        decoration: kDec(label, auto: auto, editable: ed),
        child: Row(children: [
          Expanded(
            child: hasValue
                ? Text(text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font))
                : Text(kitEnglish ? '— Not specified —' : '— ไม่ระบุ —', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: ImKit.font, color: Colors.grey.shade600)),
          ),
          if (locked && !kitReadOnly)
            Tooltip(message: lockedTip ?? '', child: Icon(Icons.lock, color: Colors.grey.shade500, size: 16))
          else if (ed) ...[
            if (hasValue && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red, size: 16),
                tooltip: kitEnglish ? 'Clear' : 'ล้าง',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onClear,
              ),
            const Icon(Icons.search, color: Colors.teal, size: 18),
          ],
        ]),
      ),
    );
  }

  /// ช่องวันที่ (กดเพื่อเลือก) — null = ว่าง
  Widget kDate(String label, DateTime? value, ValueChanged<DateTime?>? onChanged, {String Function(DateTime)? fmt}) {
    final ed = !kitReadOnly && onChanged != null;
    String f(DateTime d) => fmt != null ? fmt(d) : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return InkWell(
      onTap: !ed
          ? null
          : () async {
              final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) onChanged(d);
            },
      child: InputDecorator(
        decoration: kDec(label, editable: ed),
        child: Row(children: [
          Expanded(child: Text(value == null ? '' : f(value), style: const TextStyle(fontSize: ImKit.font))),
          if (ed && value != null)
            IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.red), padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24), onPressed: () => onChanged(null)),
          if (ed) const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
        ]),
      ),
    );
  }

  Widget kCk(String label, bool value, ValueChanged<bool>? onChanged, {String? tooltip}) {
    final w = InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFEFF7F1) : Colors.white,
          border: Border.all(color: value ? const Color(0xFFB9DCC4) : ImKit.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 16,
              color: onChanged == null ? Colors.grey : (value ? ImKit.gParty : Colors.grey.shade600)),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12.5, color: onChanged == null && !value ? Colors.grey : null))),
        ]),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip, child: w);
  }

  Widget kChecks(List<Widget> checks) => Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 6, children: checks));

  Widget kRow(List<Widget> children, [List<int>? flex]) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(Expanded(flex: flex != null && i < flex.length ? flex[i] : 1, child: children[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  Widget kNote(String text, {Color color = ImKit.ink3}) => Text(text, style: TextStyle(fontSize: 12, color: color));

  Widget kGroup(int no, String title, Color color, List<Widget> rows) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFD),
            border: Border.all(color: const Color(0xFFDDE3EA)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 18, height: 18, alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                    child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 10),
                for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
              ]),
            ),
          ]),
        ),
      );

  /// กลุ่มเรียง 2 คอลัมน์ (จอกว้าง) / คอลัมน์เดียว (จอแคบ)
  Widget kGroups(List<Widget> groups) => LayoutBuilder(builder: (c, cons) {
        if (cons.maxWidth < 860 || groups.length == 1) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < groups.length; i++) ...[if (i > 0) const SizedBox(height: 12), groups[i]],
          ]);
        }
        final rows = <Widget>[];
        for (var i = 0; i < groups.length; i += 2) {
          if (i > 0) rows.add(const SizedBox(height: 12));
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: groups[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < groups.length ? groups[i + 1] : const SizedBox.shrink()),
          ]));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      });

  Widget kLegend({bool withAuto = true}) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 10, decoration: BoxDecoration(color: c, border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
        ]);
    return Wrap(spacing: 12, children: [
      item(Colors.white, kitEnglish ? 'Entered' : 'กรอกเอง'),
      if (withAuto) item(ImKit.auto, kitEnglish ? 'System default, editable' : 'ค่าตั้งต้นจากระบบ แก้ได้'),
      item(ImKit.ro, kitEnglish ? 'Read-only' : 'อ่านอย่างเดียว'),
    ]);
  }

  Widget kCard({required String title, String? count, Widget? trailing, required Widget child,
      bool collapsed = false, VoidCallback? onToggle, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ImKit.line), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Row(children: [
                if (onToggle != null) ...[
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20, color: ImKit.ink3),
                  const SizedBox(width: 4),
                ],
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: count == null
                      ? const SizedBox.shrink()
                      : Text(count, style: const TextStyle(fontSize: 12, color: ImKit.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (trailing != null) trailing,
              ]),
            ),
          ),
        ),
        if (!collapsed) ...[
          const Divider(height: 1, color: ImKit.line),
          Padding(padding: padding, child: child),
        ],
      ]),
    );
  }

  /// ตาราง 36px; แคบกว่า minWidth → เลื่อนแนวนอน; rowColors = พื้นแถว (เช่น แถวกำลังแก้)
  Widget kTable(List<KCol> cols, List<List<Widget>> rows,
      {double minWidth = 600, List<VoidCallback?>? onTap, List<Color?>? rowColors, String? empty, double rowMinHeight = 36}) {
    Widget row(List<Widget> cells, {bool head = false, VoidCallback? tap, Color? bg}) => InkWell(
          onTap: tap,
          child: Container(
            constraints: BoxConstraints(minHeight: head ? 36 : rowMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: head ? const Color(0xFFF6F8FA) : bg,
              border: Border(bottom: BorderSide(color: head ? const Color(0xFFDDE3EA) : const Color(0xFFEEF1F4))),
            ),
            child: Row(children: [
              for (var i = 0; i < cols.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  flex: cols[i].flex,
                  child: Align(alignment: cols[i].num ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                ),
              ],
            ]),
          ),
        );
    final head = [
      for (final c in cols)
        Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ImKit.ink2)),
    ];
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row(head, head: true),
      for (var i = 0; i < rows.length; i++)
        row(rows[i],
            tap: onTap != null && i < onTap.length ? onTap[i] : null,
            bg: rowColors != null && i < rowColors.length ? rowColors[i] : null),
      if (rows.isEmpty && empty != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(empty, style: const TextStyle(color: ImKit.ink3, fontSize: 12.5)),
        ),
    ]);
    return LayoutBuilder(
      builder: (c, cons) => cons.maxWidth >= minWidth
          ? body
          : ImHScroll(width: minWidth, child: body),
    );
  }

  Widget kCell(String text, {bool bold = false, Color? color, bool mono = false}) => Text(
        text.isEmpty ? '—' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w600 : null,
          color: color ?? (text.isEmpty ? ImKit.ink3 : null),
          fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
        ),
      );

  Widget kGhost(String label, IconData icon, VoidCallback? onPressed) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: TextStyle(fontSize: 12.5, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily)),
        style: TextButton.styleFrom(
          foregroundColor: kInk,
          side: const BorderSide(color: ImKit.line),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget kIconBtn(IconData icon, String tip, VoidCallback onPressed, {Color? color}) => IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );

  Widget kKpis(List<ImKpi> tiles, {bool loading = false}) {
    if (tiles.isEmpty) {
      return SizedBox(
        height: 64,
        child: Center(child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
      );
    }
    Widget tile(ImKpi k) => InkWell(
          onTap: k.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: k.warn ? const Color(0xFFFFF8F7) : ScreenTheme.of(context).soft,
              border: Border.all(color: k.warn ? const Color(0xFFF3C0BB) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.label, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(k.value, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: k.warn ? ImKit.red : null,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              Text(k.sub, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
    return LayoutBuilder(builder: (c, cons) {
      final cols = cons.maxWidth >= 760 ? tiles.length.clamp(1, 4) : 2;
      final w = (cons.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tiles) SizedBox(width: w, child: tile(t))]);
    });
  }
}
