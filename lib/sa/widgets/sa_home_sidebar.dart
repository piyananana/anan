// lib/sa/widgets/sa_home_sidebar.dart — แถบเมนูซ้ายของหน้าหลัก (แบบ A)
// โลโก้/บริษัท, ช่องค้นหาเมนู (Ctrl+K), เมนูโปรด, ต้นไม้เมนูตามโมดูล, ผู้ใช้ (เปลี่ยนรหัสผ่าน/ออกจากระบบ)
// mini = ย่อเหลือป้ายรหัสโมดูล (กว้าง 64) — กดป้ายแล้วขยายและเปิดโมดูลนั้น
import 'package:flutter/material.dart';
import '../models/sa_menu.dart';
import 'sa_home_theme.dart';
import '../utils/sa_menu_theme.dart';

class HomeSidebar extends StatefulWidget {
  final HomeMenuIndex index;
  final bool mini;
  final bool isEnglish;
  final String companyName;
  final String? logoUrl;
  final String userName;
  final String userRole;
  final Set<int> favoriteIds;
  final List<Menu> favorites;
  final int? selectedMenuId;
  final Map<int, bool> expandedState;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<Menu> onOpenMenu;
  final ValueChanged<Menu> onToggleFavorite;
  final VoidCallback onExpandRequest; // จาก mini → ขยาย
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const HomeSidebar({
    super.key,
    required this.index,
    required this.mini,
    required this.isEnglish,
    required this.companyName,
    required this.logoUrl,
    required this.userName,
    required this.userRole,
    required this.favoriteIds,
    required this.favorites,
    required this.selectedMenuId,
    required this.expandedState,
    required this.searchController,
    required this.searchFocus,
    required this.onOpenMenu,
    required this.onToggleFavorite,
    required this.onExpandRequest,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  String get _query => widget.searchController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onQuery);
  }

  @override
  void didUpdateWidget(HomeSidebar old) {
    super.didUpdateWidget(old);
    if (old.searchController != widget.searchController) {
      old.searchController.removeListener(_onQuery);
      widget.searchController.addListener(_onQuery);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onQuery);
    super.dispose();
  }

  void _onQuery() => setState(() {});

  String _name(Menu m) => m.localName(widget.isEnglish);

  @override
  Widget build(BuildContext context) {
    final mini = widget.mini;
    return Container(
      color: HomeColors.brand2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _brand(mini),
        if (!mini) _search(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            children: _query.isNotEmpty && !mini ? _searchResults() : _navigation(mini),
          ),
        ),
        _user(mini),
      ]),
    );
  }

  // ── โลโก้ + ชื่อบริษัท ─────────────────────────────────────────────────────
  Widget _brand(bool mini) {
    final initial = widget.companyName.trim().isEmpty ? 'A' : widget.companyName.trim().characters.first;
    final logo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: HomeColors.gold, borderRadius: BorderRadius.circular(9)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (widget.logoUrl ?? '').isNotEmpty
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(2),
              child: Image.network(widget.logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(initial,
                      style: const TextStyle(color: HomeColors.brand2, fontWeight: FontWeight.w700, fontSize: 16))),
            )
          : Text(initial, style: const TextStyle(color: HomeColors.brand2, fontWeight: FontWeight.w700, fontSize: 16)),
    );
    return SizedBox(
      height: 62,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mini ? 14 : 14),
        child: Row(children: [
          Tooltip(message: widget.companyName, child: logo),
          if (!mini) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: HomeColors.brandInk, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const Text('ANAN System', style: TextStyle(color: HomeColors.brandDim, fontSize: 11)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── ช่องค้นหาเมนู ─────────────────────────────────────────────────────────
  Widget _search() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: widget.searchController,
          focusNode: widget.searchFocus,
          style: const TextStyle(color: HomeColors.brandInk, fontSize: 13),
          cursorColor: HomeColors.gold,
          onSubmitted: (_) {
            final r = _matches();
            if (r.isNotEmpty) widget.onOpenMenu(r.first);
          },
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            hintText: widget.isEnglish ? 'Search menu' : 'ค้นหาเมนู',
            hintStyle: const TextStyle(color: HomeColors.brandDim, fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18, color: HomeColors.brandDim),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16, color: HomeColors.brandDim),
                    onPressed: () => widget.searchController.clear(),
                  )
                : const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Center(
                      widthFactor: 1,
                      child: Text('Ctrl K', style: TextStyle(color: HomeColors.brandDim, fontSize: 10.5)),
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  List<Menu> _matches() {
    final q = _query;
    if (q.isEmpty) return const [];
    final r = widget.index.leaves
        .where((m) => m.menuName.toLowerCase().contains(q) || m.menuNameEn.toLowerCase().contains(q))
        .toList();
    r.sort((a, b) => _name(a).compareTo(_name(b)));
    return r;
  }

  List<Widget> _searchResults() {
    final r = _matches();
    if (r.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(widget.isEnglish ? 'No menu found' : 'ไม่พบเมนู',
              style: const TextStyle(color: HomeColors.brandDim, fontSize: 12.5)),
        ),
      ];
    }
    return [
      _section(widget.isEnglish ? 'Results (${r.length})' : 'ผลการค้นหา (${r.length})'),
      for (final m in r)
        _NavRow(
          selected: m.id == widget.selectedMenuId,
          onTap: () => widget.onOpenMenu(m),
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          trailing: _star(m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name(m), style: const TextStyle(fontSize: 13)),
            Text(
              widget.index.pathOf(m).reversed.skip(1).toList().reversed.map(_name).join(' › '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HomeColors.brandGroup, fontSize: 11),
            ),
          ]),
        ),
    ];
  }

  // ── เมนูโปรด + โมดูล ─────────────────────────────────────────────────────
  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(color: HomeColors.brandDim, fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      );

  List<Widget> _navigation(bool mini) {
    final out = <Widget>[];
    if (widget.favorites.isNotEmpty) {
      if (!mini) out.add(_section(widget.isEnglish ? 'Favorites' : 'เมนูโปรด'));
      if (mini) out.add(const SizedBox(height: 6));
      for (final m in widget.favorites) {
        out.add(_NavRow(
          selected: m.id == widget.selectedMenuId,
          tooltip: mini ? _name(m) : null,
          onTap: () => widget.onOpenMenu(m),
          center: mini,
          trailing: mini ? null : _star(m),
          child: mini
              ? const Icon(Icons.star_rounded, size: 18, color: HomeColors.gold)
              : Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: HomeColors.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_name(m), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
        ));
      }
    }
    if (!mini) out.add(_section(widget.isEnglish ? 'Modules' : 'โมดูล'));
    if (mini) out.add(const Divider(color: Colors.white12, height: 14));
    for (final mod in widget.index.modules) {
      out.addAll(_moduleNode(mod, mini));
    }
    return out;
  }

  List<Widget> _moduleNode(Menu mod, bool mini) {
    final code = homeModuleCode(mod);
    final isFolder = mod.menuType == 'folder';
    final open = widget.expandedState[mod.id] ?? false;
    final selectedInside = widget.selectedMenuId != null &&
        widget.index.byId[widget.selectedMenuId] != null &&
        widget.index.moduleOf(widget.index.byId[widget.selectedMenuId]!)?.id == mod.id;
    final badge = Container(
      width: 28,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selectedInside ? HomeColors.gold.withOpacity(0.25) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(code,
          style: TextStyle(
              fontSize: code.length > 2 ? 9.5 : 10.5,
              fontWeight: FontWeight.w700,
              color: selectedInside ? HomeColors.selText : HomeColors.brandInk)),
    );
    if (mini) {
      return [
        _NavRow(
          center: true,
          tooltip: _name(mod),
          selected: false,
          onTap: () {
            if (isFolder) {
              widget.expandedState[mod.id] = true;
              widget.onExpandRequest();
            } else {
              widget.onOpenMenu(mod);
            }
          },
          child: badge,
        ),
      ];
    }
    return [
      _NavRow(
        selected: !isFolder && mod.id == widget.selectedMenuId,
        onTap: () {
          if (isFolder) {
            setState(() => widget.expandedState[mod.id] = !open);
          } else {
            widget.onOpenMenu(mod);
          }
        },
        child: Row(children: [
          badge,
          const SizedBox(width: 10),
          Expanded(child: Text(_name(mod), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isFolder)
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.chevron_right, size: 16, color: HomeColors.brandDim),
            ),
        ]),
      ),
      if (isFolder && open) ..._children(mod, 1),
    ];
  }

  List<Widget> _children(Menu parent, int level) {
    final out = <Widget>[];
    final indent = 30.0 + (level - 1) * 12.0;
    for (final m in widget.index.childrenOf(parent.id)) {
      if (m.menuType == 'folder') {
        final open = widget.expandedState[m.id] ?? false;
        out.add(_NavRow(
          selected: false,
          padding: EdgeInsets.fromLTRB(indent, 7, 6, 4),
          onTap: () => setState(() => widget.expandedState[m.id] = !open),
          child: Row(children: [
            Expanded(
              child: Text(_name(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: HomeColors.brandGroup, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Icon(open ? Icons.expand_less : Icons.expand_more, size: 15, color: HomeColors.brandGroup),
          ]),
        ));
        if (open) out.addAll(_children(m, level + 1));
      } else {
        final sel = m.id == widget.selectedMenuId;
        out.add(_NavRow(
          selected: sel,
          padding: EdgeInsets.fromLTRB(indent, 6, 6, 6),
          onTap: () => widget.onOpenMenu(m),
          trailing: _star(m),
          child: Row(children: [
            _bullet(m),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_name(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: sel ? HomeColors.selText : HomeColors.brandDim)),
            ),
          ]),
        ));
      }
    }
    return out;
  }

  // จุดสีหน้าเมนูที่เปิดหน้าจอได้ = สีธีมของเมนู (ตั้งที่หน้าจัดการเมนู / ตามเมนูแม่) ใช้สีแถบหัว (อ่อนกว่า) ให้เห็นบนพื้นเขียวเข้ม
  Widget _bullet(Menu m) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: ScreenTheme.effectiveFor(m).strip, borderRadius: BorderRadius.circular(2)),
      );

  // ดาวเมนูโปรด — แสดงตลอดถ้าเป็นเมนูโปรด ไม่งั้นแสดงตอนชี้
  Widget _star(Menu m) {
    final fav = widget.favoriteIds.contains(m.id);
    return _HoverStar(
      isFavorite: fav,
      tooltip: fav
          ? (widget.isEnglish ? 'Remove from favorites' : 'เอาออกจากเมนูโปรด')
          : (widget.isEnglish ? 'Add to favorites' : 'เพิ่มในเมนูโปรด'),
      onTap: () => widget.onToggleFavorite(m),
    );
  }

  // ── ผู้ใช้ ───────────────────────────────────────────────────────────────
  Widget _user(bool mini) {
    final initials = widget.userName.trim().isEmpty ? '?' : widget.userName.trim().characters.take(2).toString();
    final avatar = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: HomeColors.gold, shape: BoxShape.circle),
      child: Text(initials, style: const TextStyle(color: HomeColors.brand2, fontWeight: FontWeight.w700, fontSize: 12)),
    );
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
      child: PopupMenuButton<String>(
        tooltip: widget.isEnglish ? 'Account' : 'บัญชีผู้ใช้',
        position: PopupMenuPosition.over,
        offset: const Offset(0, -100),
        onSelected: (v) => v == 'pw' ? widget.onChangePassword() : widget.onLogout(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'pw',
            child: Row(children: [
              const Icon(Icons.password_outlined, size: 18, color: HomeColors.ink2),
              const SizedBox(width: 10),
              Text(widget.isEnglish ? 'Change password' : 'เปลี่ยนรหัสผ่าน'),
            ]),
          ),
          PopupMenuItem(
            value: 'out',
            child: Row(children: [
              const Icon(Icons.logout_outlined, size: 18, color: HomeColors.red),
              const SizedBox(width: 10),
              Text(widget.isEnglish ? 'Log out' : 'ออกจากระบบ', style: const TextStyle(color: HomeColors.red)),
            ]),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mini ? 16 : 12, vertical: 10),
          child: Row(children: [
            avatar,
            if (!mini) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: HomeColors.brandInk, fontSize: 12.5)),
                  Text(widget.userRole, style: const TextStyle(color: HomeColors.brandDim, fontSize: 11)),
                ]),
              ),
              const Icon(Icons.unfold_more, size: 16, color: HomeColors.brandDim),
            ],
          ]),
        ),
      ),
    );
  }
}

/// แถวเมนูบนแถบซ้าย (มีสถานะชี้/เลือก)
class _NavRow extends StatefulWidget {
  final Widget child;
  final Widget? trailing;
  final bool selected;
  final bool center;
  final String? tooltip;
  final EdgeInsets padding;
  final VoidCallback onTap;

  const _NavRow({
    required this.child,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.center = false,
    this.tooltip,
    this.padding = const EdgeInsets.fromLTRB(8, 7, 6, 7),
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? HomeColors.gold.withOpacity(0.16)
        : _hover
            ? Colors.white.withOpacity(0.07)
            : Colors.transparent;
    Widget row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: widget.center ? const EdgeInsets.symmetric(vertical: 7) : widget.padding,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: widget.selected ? HomeColors.selText : HomeColors.brandInk, fontSize: 13),
            child: widget.center
                ? Center(child: widget.child)
                : Row(children: [
                    Expanded(child: widget.child),
                    if (widget.trailing != null)
                      _HoverScope(hover: _hover, child: widget.trailing!),
                  ]),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) row = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 300), child: row);
    return row;
  }
}

/// ส่งสถานะ "กำลังชี้แถว" ลงไปให้ดาว
class _HoverScope extends InheritedWidget {
  final bool hover;
  const _HoverScope({required this.hover, required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_HoverScope>()?.hover ?? false;
  @override
  bool updateShouldNotify(_HoverScope old) => old.hover != hover;
}

class _HoverStar extends StatelessWidget {
  final bool isFavorite;
  final String tooltip;
  final VoidCallback onTap;
  const _HoverStar({required this.isFavorite, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final show = isFavorite || _HoverScope.of(context);
    return SizedBox(
      width: 24,
      height: 20,
      child: show
          ? Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onTap,
                child: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16, color: isFavorite ? HomeColors.gold : HomeColors.brandDim),
              ),
            )
          : null,
    );
  }
}
