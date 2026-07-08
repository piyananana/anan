import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/auth_service.dart';
import '../services/sa_dashboard_service.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  final _svc            = SaDashboardService();
  late final PageController _pageCtrl;
  Timer? _scrollTimer;
  Timer? _refreshTimer;

  bool         _isHovered   = false;
  int          _currentPage = 0;
  UserStats?   _stats;
  DbSizeInfo?  _sizeInfo;
  bool         _loading     = true;
  String       _error       = '';

  static const _scrollIntervalSec  = 6;
  static const _refreshIntervalSec = 30;

  int get _cardCount => 3;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _load();
    _startScrollTimer();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSec),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _refreshTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(
      const Duration(seconds: _scrollIntervalSec),
      (_) {
        if (_isHovered || !mounted || !_pageCtrl.hasClients) return;
        final next = (_currentPage + 1) % _cardCount;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = ''; });
    try {
      final results = await Future.wait([
        _svc.fetchUserStats(),
        _svc.fetchDbSize(),
      ]);
      if (mounted) {
        setState(() {
          _stats    = results[0] as UserStats;
          _sizeInfo = results[1] as DbSizeInfo;
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade50,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          if (!_loading && _error.isEmpty) _buildIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.dashboard_rounded,
              color: Color(0xFF455A64), size: 20),
          const SizedBox(width: 8),
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF37474F),
                  letterSpacing: 0.5,
                ),
          ),
          const Spacer(),
          // show pause icon when hovered
          AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Tooltip(
              message: 'หยุด auto scroll',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.pause_circle_outline_rounded,
                    size: 18, color: Color(0xFF90A4AE)),
              ),
            ),
          ),
          const Tooltip(
            message: 'อัปเดตอัตโนมัติทุก $_refreshIntervalSec วินาที',
            child: Icon(Icons.sync_rounded,
                size: 16, color: Color(0xFFB0BEC5)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => _load(),
            tooltip: 'รีเฟรชทันที',
            color: const Color(0xFF78909C),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final cardSz = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        Widget page(Widget card) => Center(
              child: SizedBox.square(dimension: cardSz, child: card),
            );

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit:  (_) => setState(() => _isHovered = false),
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _currentPage = p),
            children: [
              page(_UserStatsCard(stats: _stats!)),
              page(_DbSizeCard(info: _sizeInfo!)),
              page(const _SessionTimerCard()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_cardCount, (i) {
          final active = i == _currentPage;
          return GestureDetector(
            onTap: () => _pageCtrl.animateToPage(
              i,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 28.0 : 8.0,
              height: 8.0,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF455A64)
                    : const Color(0xFFB0BEC5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Shared card frame ────────────────────────────────────────────────────────

class _CardFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _CardFrame({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        elevation: 2,
        shadowColor: const Color(0x26607D8B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // card title
              Row(children: [
                Icon(icon, size: 20, color: Colors.blueGrey.shade500),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card 1: User Stats ───────────────────────────────────────────────────────

class _UserStatsCard extends StatelessWidget {
  final UserStats stats;
  const _UserStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      title: 'ผู้ใช้งาน',
      icon: Icons.people_alt_rounded,
      child: Column(
        children: [
          // donut chart — takes majority of height
          Expanded(
            flex: 6,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _DonutPainter(
                    online:        stats.online,
                    activeOffline: stats.activeOffline,
                    inactive:      stats.inactive,
                    total:         stats.total,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // summary totals row
          _summaryRow(stats.total, stats.active, stats.inactive),
          const SizedBox(height: 16),
          // legend
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(const Color(0xFF00C853),
                    'กำลัง Login', stats.online),
                const SizedBox(height: 8),
                _legendItem(const Color(0xFF2979FF),
                    'Active (ยังไม่ได้ Login)', stats.activeOffline),
                const SizedBox(height: 8),
                _legendItem(const Color(0xFF90A4AE),
                    'Inactive', stats.inactive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(int total, int active, int inactive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statChip('ทั้งหมด',  total,    const Color(0xFF37474F)),
        _divider(),
        _statChip('Active',   active,   const Color(0xFF2979FF)),
        _divider(),
        _statChip('Inactive', inactive, const Color(0xFF78909C)),
      ],
    );
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: const Color(0xFFE0E0E0));

  Widget _statChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF90A4AE))),
      ],
    );
  }

  Widget _legendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF455A64))),
        ),
        Text('$count',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF263238))),
        const SizedBox(width: 3),
        const Text('คน',
            style: TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
      ],
    );
  }
}

// Donut chart painter
class _DonutPainter extends CustomPainter {
  final int online, activeOffline, inactive, total;

  static const Color _cOnline   = Color(0xFF00C853); // vivid green
  static const Color _cActive   = Color(0xFF2979FF); // vivid blue
  static const Color _cInactive = Color(0xFF90A4AE); // blue-grey
  static const Color _cEmpty    = Color(0xFFE0E0E0);

  const _DonutPainter({
    required this.online,
    required this.activeOffline,
    required this.inactive,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius  = math.min(cx, cy) * 0.80;
    final strokeW = radius * 0.28;
    final arcRect = Rect.fromCircle(
        center: Offset(cx, cy), radius: radius - strokeW / 2);

    if (total == 0) {
      canvas.drawArc(arcRect, 0, 2 * math.pi, false,
          Paint()
            ..color = _cEmpty
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW);
    } else {
      // gap ระหว่าง segment — clamp ไม่เกิน 20% ของ sweep
      // เพื่อให้ segment เล็ก (เช่น online 1 คน) ยังแสดงได้
      // ใช้ StrokeCap.butt เพื่อป้องกัน cap โผล่ทับ segment ข้างๆ
      const maxGap = 0.04;
      double angle = -math.pi / 2;

      void seg(int count, Color color) {
        if (count <= 0) return;
        final sweep = 2 * math.pi * count / total;
        final gapEach = math.min(maxGap, sweep * 0.20);
        canvas.drawArc(
          arcRect,
          angle + gapEach / 2,
          math.max(sweep - gapEach, 0.001),
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.butt,
        );
        angle += sweep;
      }

      seg(online,        _cOnline);
      seg(activeOffline, _cActive);
      seg(inactive,      _cInactive);
    }

    // subtle inner shadow ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius - strokeW - 1,
      Paint()
        ..color = const Color(0x0A000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // center: total count
    _drawText(canvas, '$total', 40, FontWeight.w800,
        Offset(cx, cy - 14), const Color(0xFF212121));
    _drawText(canvas, 'คน', 15, FontWeight.w500,
        Offset(cx, cy + 20), const Color(0xFF607D8B));
  }

  void _drawText(Canvas canvas, String text, double size,
      FontWeight weight, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.online != online ||
      o.activeOffline != activeOffline ||
      o.inactive != inactive;
}

// ─── Card 2: DB Size by Module ────────────────────────────────────────────────

class _DbSizeCard extends StatelessWidget {
  final DbSizeInfo info;

  static const List<Color> _palette = [
    Color(0xFF2196F3), Color(0xFF009688), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFFF44336),
    Color(0xFF607D8B), Color(0xFF00BCD4), Color(0xFF8BC34A),
  ];

  static const Map<String, String> _moduleNames = {
    'sa': 'System Admin',
    'cd': 'Common Data',
    'gl': 'General Ledger',
    'ar': 'Accounts Receivable',
    'ap': 'Accounts Payable',
    'cm': 'Cash & Check',
    'vt': 'VAT',
    'im': 'Inventory',
  };

  static String _moduleName(String code) =>
      _moduleNames[code.toLowerCase()] ?? code.toUpperCase();

  const _DbSizeCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      title: 'ขนาดข้อมูล (ตามโมดูล)',
      icon: Icons.storage_rounded,
      child: info.modules.isEmpty
          ? const Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey)))
          : Column(
              children: [
                Expanded(child: _buildBars()),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildBars() {
    final sizes   = info.modules;
    final maxBytes = sizes.first.sizeBytes.toDouble();
    return Column(
      children: sizes.asMap().entries.map((e) {
        final i     = e.key;
        final item  = e.value;
        final frac  = maxBytes > 0 ? item.sizeBytes / maxBytes : 0.0;
        final color = _palette[i % _palette.length];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    _moduleName(item.module),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: LayoutBuilder(
                    builder: (_, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: math.max(c.maxWidth * frac, frac > 0 ? 6.0 : 0.0),
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 66,
                  child: Text(
                    _fmt(item.sizeBytes),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    final modTotal = info.modulesTotalBytes;
    final dbTotal  = info.dbTotalBytes;
    // fraction of DB space used by public-schema tables (0..1)
    final usedFrac = dbTotal > 0
        ? (modTotal / dbTotal).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 14, thickness: 0.8, color: Color(0xFFE0E0E0)),
        // summary numbers
        Row(
          children: [
            _footerStat(Icons.table_rows_rounded, 'ยอดรวมข้อมูล',   modTotal, const Color(0xFF455A64)),
            const SizedBox(width: 12),
            _footerStat(Icons.dns_rounded,        'ขนาด Database', dbTotal,  const Color(0xFF1565C0)),
          ],
        ),
        const SizedBox(height: 8),
        // utilisation bar: modTotal vs dbTotal
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // background = DB total
              Container(height: 8, color: const Color(0xFFBBDEFB)),
              // foreground = module tables
              FractionallySizedBox(
                widthFactor: usedFrac,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ข้อมูล tables ใช้ ${(usedFrac * 100).toStringAsFixed(1)}% ของ Database',
          style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
        ),
      ],
    );
  }

  Widget _footerStat(IconData icon, String label, int bytes, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                Text(_fmt(bytes),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int b) {
    if (b >= 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    if (b >= 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }
}

// ─── Card 3: Session Timer ────────────────────────────────────────────────────

class _SessionTimerCard extends StatefulWidget {
  const _SessionTimerCard();

  @override
  State<_SessionTimerCard> createState() => _SessionTimerCardState();
}

class _SessionTimerCardState extends State<_SessionTimerCard> {
  Timer?    _ticker;
  DateTime? _loginAt;
  DateTime? _expiresAt;
  bool      _loaded   = false;
  bool      _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFromJwt();
  }

  Future<void> _loadFromJwt() async {
    final token = await AuthService().getAuthToken();
    if (token == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException('invalid jwt');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final iat = (payload['iat'] as num?)?.toInt();
      final exp = (payload['exp'] as num?)?.toInt();
      if (iat == null || exp == null) throw const FormatException('missing iat/exp');

      if (mounted) {
        setState(() {
          _loginAt   = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
          _expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          _loaded    = true;
        });
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _hms(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return _CardFrame(
        title: 'Session ปัจจุบัน',
        icon: Icons.timer_rounded,
        child: Center(
          child: _hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade300, size: 32),
                    const SizedBox(height: 8),
                    const Text('ไม่สามารถอ่านข้อมูล Session',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final now       = DateTime.now();
    final elapsed   = now.difference(_loginAt!);
    final remaining = _expiresAt!.difference(now);
    final total     = _expiresAt!.difference(_loginAt!);
    final remFrac   = total.inSeconds > 0
        ? (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final isExpired = remaining.isNegative;

    final remColor = isExpired
        ? Colors.red[700]!
        : remaining.inHours < 1
            ? Colors.orange[700]!
            : const Color(0xFF2E7D32);
    final barColor = isExpired
        ? Colors.red.shade400
        : remaining.inHours < 1
            ? Colors.orange.shade400
            : const Color(0xFF43A047);

    return _CardFrame(
      title: 'Session ปัจจุบัน',
      icon: Icons.timer_rounded,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Session duration (large clock) ──
          Text('เวลาที่ใช้งาน',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400)),
          const SizedBox(height: 6),
          Text(
            _hms(elapsed),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
              letterSpacing: 2,
            ),
          ),
          Text(
            'Login เมื่อ ${DateFormat('HH:mm:ss').format(_loginAt!)}',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          // ── Remaining session time ──
          Text('เวลาคงเหลือก่อน Session หมดอายุ',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
          const SizedBox(height: 6),
          Text(
            isExpired ? 'หมดอายุแล้ว' : _hms(remaining),
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w600, color: remColor),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: remFrac.toDouble(),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isExpired
                ? 'Session หมดอายุ — กรุณา Login ใหม่'
                : 'หมดอายุ ${DateFormat('HH:mm').format(_expiresAt!)} น.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400),
          ),
        ],
      ),
    );
  }
}
