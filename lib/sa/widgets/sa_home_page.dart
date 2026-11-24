// lib/sa/widgets/sa_home_page.dart — หน้าแรก (แท็บ "หน้าแรก") ของหน้าหลักแบบ A
// ทักทาย + งานรออนุมัติ + เมนูโปรด + Dashboard เดิม (ผู้ใช้งาน/ขนาดข้อมูล/Session — ทุกคนเห็น)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sa_menu.dart';
import '../models/sa_pending_approval.dart';
import '../services/sa_dashboard_service.dart';
import 'sa_dashboard_widget.dart';
import 'sa_home_theme.dart';

class HomePage extends StatefulWidget {
  final bool isEnglish;
  final String firstName;
  final List<PendingApprovalItem> approvals;
  final ValueChanged<PendingApprovalItem> onOpenApproval;
  final VoidCallback onShowAllApprovals;
  final List<Menu> favorites;
  final String Function(Menu) moduleCodeOf;
  final ValueChanged<Menu> onOpenMenu;
  final ValueChanged<Menu> onRemoveFavorite;
  /// เปิดหน้าจอตาม Menu.targetPath (การ์ดตัวเลขสรุป) — canOpenTarget = มีสิทธิ์เมนูนั้น
  final ValueChanged<String> onOpenTarget;
  final bool Function(String targetPath) canOpenTarget;

  const HomePage({
    super.key,
    required this.isEnglish,
    required this.firstName,
    required this.approvals,
    required this.onOpenApproval,
    required this.onShowAllApprovals,
    required this.favorites,
    required this.moduleCodeOf,
    required this.onOpenMenu,
    required this.onRemoveFavorite,
    required this.onOpenTarget,
    required this.canOpenTarget,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _editFav = false;
  HomeKpi? _kpi;

  @override
  void initState() {
    super.initState();
    _loadKpi(); // หน้าแรกสร้างใหม่ทุกครั้งที่กลับมาดู → ตัวเลขล่าสุดเสมอ
  }

  Future<void> _loadKpi() async {
    try {
      final k = await SaDashboardService().fetchHomeKpi();
      if (mounted) setState(() => _kpi = k);
    } catch (_) {}
  }

  static const _thDays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  static const _thMonths = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];

  String _today() {
    final d = DateTime.now();
    if (widget.isEnglish) return DateFormat('EEEE, d MMMM y').format(d);
    return 'วัน${_thDays[d.weekday - 1]}ที่ ${d.day} ${_thMonths[d.month - 1]} ${d.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.isEnglish;
    return Container(
      color: HomeColors.appBg,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final approvals = _approvalsCard();
        final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _favoritesCard(),
          const SizedBox(height: 16),
          _dashboardCard(),
        ]);
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          children: [
            Text(en ? 'Hello, ${widget.firstName}' : 'สวัสดี คุณ${widget.firstName}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: HomeColors.ink)),
            const SizedBox(height: 2),
            Text(_today(), style: const TextStyle(color: HomeColors.ink2, fontSize: 13)),
            const SizedBox(height: 16),
            _kpiRow(c.maxWidth),
            const SizedBox(height: 16),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 135, child: approvals),
                const SizedBox(width: 16),
                Expanded(flex: 100, child: right),
              ])
            else ...[
              approvals,
              const SizedBox(height: 16),
              right,
            ],
          ],
        );
      }),
    );
  }

  // ── แถวตัวเลขสรุป 5 ช่อง ─────────────────────────────────────────────────
  Widget _kpiRow(double maxWidth) {
    final en = widget.isEnglish;
    final k = _kpi;
    String v(int? n) => k == null ? '–' : NumberFormat('#,##0').format(n ?? 0);
    final approvals = widget.approvals;
    final approvalModules = approvals.map((a) => _codeOfTarget(a.targetPath)).toSet().length;
    final draftParts = k == null
        ? ''
        : (k.myDraftsByModule.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => '${e.key} ${e.value}')
            .join(' · ');

    final tiles = <_KpiData>[
      _KpiData(
        icon: Icons.task_alt_rounded,
        label: en ? 'Pending approvals' : 'งานรออนุมัติ',
        value: NumberFormat('#,##0').format(approvals.length),
        sub: approvals.isEmpty
            ? (en ? 'Nothing waiting' : 'ไม่มีงานค้าง')
            : (en ? 'from $approvalModules module(s)' : 'จาก $approvalModules โมดูล'),
        alert: approvals.isNotEmpty,
        onTap: approvals.isEmpty ? null : widget.onShowAllApprovals,
      ),
      _KpiData(
        icon: Icons.edit_note_rounded,
        label: en ? 'My drafts' : 'เอกสารร่างของฉัน',
        value: v(k?.myDrafts),
        sub: k == null ? '' : (draftParts.isEmpty ? (en ? 'No drafts' : 'ไม่มีเอกสารร่าง') : draftParts),
      ),
      _KpiData(
        icon: Icons.local_shipping_outlined,
        label: en ? 'Awaiting delivery' : 'ค้างส่งสินค้า',
        value: v(k?.soPending),
        sub: k == null ? '' : (en ? 'sales orders · ${k.soPartial} partly delivered' : 'ใบสั่งขาย · ส่งบางส่วน ${k.soPartial} ใบ'),
        target: 'SoTransactionScreen',
      ),
      _KpiData(
        icon: Icons.inventory_2_outlined,
        label: en ? 'Awaiting receipt' : 'ค้างรับสินค้า',
        value: v(k?.poPending),
        sub: k == null ? '' : (en ? 'purchase orders · ${k.poPartial} partly received' : 'ใบสั่งซื้อ · รับบางส่วน ${k.poPartial} ใบ'),
        target: 'PoTransactionScreen',
      ),
      _KpiData(
        icon: Icons.precision_manufacturing_outlined,
        label: en ? 'In production' : 'กำลังผลิต',
        value: v(k?.moActive),
        sub: k == null
            ? ''
            : (en
                ? 'in progress ${k.moInProgress} · released ${k.moReleased}'
                : 'เริ่มผลิตแล้ว ${k.moInProgress} · ปล่อยแล้ว ${k.moReleased}'),
        target: 'MoHeaderScreen',
      ),
    ];

    Widget tile(_KpiData d) {
      final canOpen = d.onTap != null || (d.target != null && widget.canOpenTarget(d.target!));
      return _KpiTile(
        data: d,
        onTap: !canOpen ? null : (d.onTap ?? () => widget.onOpenTarget(d.target!)),
      );
    }

    // กว้างพอ: 5 ช่องแถวเดียว, แคบ: ห่อเป็นหลายแถว
    if (maxWidth >= 1000) {
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tile(tiles[i])),
          ],
        ]),
      );
    }
    final cols = maxWidth >= 640 ? 3 : 2;
    final w = (maxWidth - 44 - (cols - 1) * 12) / cols;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final d in tiles) SizedBox(width: w, child: tile(d)),
    ]);
  }

  Widget _card({required Widget title, Widget? action, required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: HomeColors.card,
        border: Border.all(color: HomeColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.ink), child: title)),
          if (action != null) action,
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _link(String text, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            foregroundColor: HomeColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
            textStyle: const TextStyle(fontSize: 12.5)),
        child: Text(text),
      );

  // ── งานรออนุมัติ ─────────────────────────────────────────────────────────
  static String _codeOfTarget(String targetPath) {
    final p = targetPath.toLowerCase();
    if (p.startsWith('ap')) return 'AP';
    if (p.startsWith('ar')) return 'AR';
    if (p.startsWith('im')) return 'IM';
    if (p.startsWith('pr') || p.startsWith('po')) return 'PO';
    if (p.startsWith('so') || p.startsWith('quote')) return 'SO';
    if (p.startsWith('mo')) return 'MO';
    if (p.startsWith('cm')) return 'CM';
    if (p.startsWith('period') || p.startsWith('gl')) return 'GL';
    return 'SA';
  }

  Widget _approvalsCard() {
    final en = widget.isEnglish;
    final items = widget.approvals;
    const maxShow = 8;
    final money = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');
    return _card(
      title: Row(children: [
        const Icon(Icons.task_alt_rounded, size: 18, color: HomeColors.brand),
        const SizedBox(width: 8),
        Text(en ? 'Pending approvals' : 'งานรออนุมัติ'),
        const SizedBox(width: 8),
        if (items.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(color: HomeColors.amberSoft, borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length}', style: const TextStyle(fontSize: 12, color: HomeColors.amber, fontWeight: FontWeight.w700)),
          ),
      ]),
      action: items.length > maxShow ? _link(en ? 'View all' : 'ดูทั้งหมด', widget.onShowAllApprovals) : null,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                const Icon(Icons.inbox_outlined, size: 32, color: HomeColors.ink3),
                const SizedBox(height: 6),
                Text(en ? 'Nothing waiting for your approval' : 'ไม่มีงานรออนุมัติ',
                    style: const TextStyle(color: HomeColors.ink3, fontSize: 13)),
              ]),
            )
          : Column(children: [
              for (int i = 0; i < items.length && i < maxShow; i++)
                _ApprovalRow(
                  first: i == 0,
                  code: _codeOfTarget(items[i].targetPath),
                  docNo: items[i].docNo,
                  title: [
                    en ? items[i].titleEn : items[i].titleTh,
                    if ((items[i].submittedBy ?? '').isNotEmpty) '${en ? 'by' : 'โดย'} ${items[i].submittedBy}',
                  ].join(' · '),
                  amount: items[i].amount != 0 ? money.format(items[i].amount) : '',
                  date: items[i].date != null ? dateFmt.format(items[i].date!) : '',
                  onTap: () => widget.onOpenApproval(items[i]),
                ),
            ]),
    );
  }

  // ── เมนูโปรด ─────────────────────────────────────────────────────────────
  Widget _favoritesCard() {
    final en = widget.isEnglish;
    final favs = widget.favorites;
    return _card(
      title: Row(children: [
        const Icon(Icons.star_rounded, size: 18, color: HomeColors.gold),
        const SizedBox(width: 8),
        Text(en ? 'Favorites' : 'เมนูโปรด'),
      ]),
      action: favs.isEmpty ? null : _link(_editFav ? (en ? 'Done' : 'เสร็จ') : (en ? 'Edit' : 'แก้ไข'), () => setState(() => _editFav = !_editFav)),
      child: favs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                en
                    ? 'Point at a menu in the left panel and click ☆ to add it here.'
                    : 'ชี้ที่เมนูในแถบซ้าย แล้วกด ☆ เพื่อเพิ่มเป็นเมนูโปรด',
                style: const TextStyle(color: HomeColors.ink3, fontSize: 12.5),
              ),
            )
          : LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 520 ? 3 : (c.maxWidth >= 300 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in favs)
                  SizedBox(
                    width: w,
                    child: _FavButton(
                      code: widget.moduleCodeOf(m),
                      label: m.localName(en),
                      editing: _editFav,
                      onTap: () => _editFav ? widget.onRemoveFavorite(m) : widget.onOpenMenu(m),
                    ),
                  ),
              ]);
            }),
    );
  }

  // ── Dashboard เดิม (ผู้ใช้งาน / ขนาดข้อมูล / Session) ─────────────────────
  Widget _dashboardCard() {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: HomeColors.card,
        border: Border.all(color: HomeColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: const DashboardWidget(),
    );
  }
}

class _ApprovalRow extends StatefulWidget {
  final bool first;
  final String code;
  final String docNo;
  final String title;
  final String amount;
  final String date;
  final VoidCallback onTap;
  const _ApprovalRow({
    required this.first,
    required this.code,
    required this.docNo,
    required this.title,
    required this.amount,
    required this.date,
    required this.onTap,
  });

  @override
  State<_ApprovalRow> createState() => _ApprovalRowState();
}

class _ApprovalRowState extends State<_ApprovalRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: _hover ? HomeColors.hover : Colors.transparent,
            border: widget.first ? null : const Border(top: BorderSide(color: HomeColors.line)),
          ),
          child: Row(children: [
            HomeModuleBadge(widget.code),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.docNo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: HomeColors.ink)),
                Text(widget.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: HomeColors.ink3)),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (widget.amount.isNotEmpty)
                Text(widget.amount,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: HomeColors.ink, fontFeatures: [FontFeature.tabularFigures()])),
              Text(widget.date, style: const TextStyle(fontSize: 11.5, color: HomeColors.ink3)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: HomeColors.ink3),
          ]),
        ),
      ),
    );
  }
}

class _FavButton extends StatefulWidget {
  final String code;
  final String label;
  final bool editing;
  final VoidCallback onTap;
  const _FavButton({required this.code, required this.label, required this.editing, required this.onTap});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? HomeColors.hover : HomeColors.card,
            border: Border.all(color: _hover ? HomeColors.brand : HomeColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            HomeModuleBadge(widget.code, width: 26, height: 22, fontSize: 10),
            const SizedBox(width: 9),
            Expanded(
              child: Text(widget.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: HomeColors.ink)),
            ),
            if (widget.editing) const Icon(Icons.close, size: 16, color: HomeColors.red),
          ]),
        ),
      ),
    );
  }
}

class _KpiData {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool alert; // มีงานที่ต้องทำ → ตัวเลขสีเหลืองอำพัน
  final String? target; // Menu.targetPath ที่เปิดเมื่อกด
  final VoidCallback? onTap;
  const _KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.alert = false,
    this.target,
    this.onTap,
  });
}

class _KpiTile extends StatefulWidget {
  final _KpiData data;
  final VoidCallback? onTap;
  const _KpiTile({required this.data, required this.onTap});

  @override
  State<_KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<_KpiTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final clickable = widget.onTap != null;
    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: HomeColors.card,
            border: Border.all(color: clickable && _hover ? HomeColors.brand : HomeColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(d.icon, size: 16, color: HomeColors.ink3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(d.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: HomeColors.ink2)),
              ),
              if (clickable) Icon(Icons.chevron_right, size: 16, color: _hover ? HomeColors.brand : HomeColors.line),
            ]),
            const SizedBox(height: 4),
            Text(d.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: d.alert ? HomeColors.amber : HomeColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            const SizedBox(height: 2),
            Text(d.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: HomeColors.ink3)),
          ]),
        ),
      ),
    );
  }
}
