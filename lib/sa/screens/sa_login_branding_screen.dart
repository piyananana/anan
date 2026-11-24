// lib/sa/screens/sa_login_branding_screen.dart — ตั้งค่าหน้าล็อกอิน (เมนูจัดการระบบ, เฉพาะผู้พัฒนาระบบ)
// เลือกแบบหน้าล็อกอิน A/B, โลโก้ระบบ (PNG/JPG ≤ 1MB), ชื่อระบบ/คำโปรย ไทย-อังกฤษ,
// รูปพื้นหลังของแบบ B (PNG/JPG ≤ 3MB; ไม่มี = ไล่สีเขียว-ทอง), ตัวอย่างหน้าล็อกอิน, ประวัติการแก้ไข
// ใช้ร่วมทุกฐานข้อมูล (หน้าล็อกอินแสดงก่อนเลือกฐานข้อมูล) — user-approved 2026-11-24
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_login_branding_service.dart';

class LoginBrandingScreen extends StatefulWidget {
  const LoginBrandingScreen({super.key});

  @override
  State<LoginBrandingScreen> createState() => _LoginBrandingScreenState();
}

class _C {
  static const brand = Color(0xFF0F4A36);
  static const brand2 = Color(0xFF0B3A2A);
  static const gold = Color(0xFFE0A526);
  static const bg = Color(0xFFF3F5F4);
  static const line = Color(0xFFE1E6E3);
  static const ink = Color(0xFF1B2420);
  static const ink2 = Color(0xFF55625B);
  static const ink3 = Color(0xFF8B968F);
  static const hover = Color(0xFFEAF2ED);
  static const red = Color(0xFFC62828);
}

class _LoginBrandingScreenState extends State<LoginBrandingScreen> {
  final _svc = LoginBrandingService();
  LoginBranding? _saved;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _layout = 'A';
  final _nameTh = TextEditingController();
  final _nameEn = TextEditingController();
  final _tagTh = TextEditingController();
  final _tagEn = TextEditingController();
  BrandingImage? _newLogo;
  BrandingImage? _newBg;
  bool _removeLogo = false;
  bool _removeBg = false;

  bool get _isDeveloper => AuthService().currentUser?.isDeveloper ?? false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameTh, _nameEn, _tagTh, _tagEn]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameTh, _nameEn, _tagTh, _tagEn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _apply(await _svc.fetch());
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(LoginBranding b) {
    _saved = b;
    _layout = b.layout;
    _nameTh.text = b.nameTh;
    _nameEn.text = b.nameEn;
    _tagTh.text = b.taglineTh;
    _tagEn.text = b.taglineEn;
    _newLogo = null;
    _newBg = null;
    _removeLogo = false;
    _removeBg = false;
  }

  bool get _dirty {
    final s = _saved;
    if (s == null) return false;
    return _layout != s.layout ||
        _nameTh.text.trim() != s.nameTh ||
        _nameEn.text.trim() != s.nameEn ||
        _tagTh.text.trim() != s.taglineTh ||
        _tagEn.text.trim() != s.taglineEn ||
        _newLogo != null ||
        _newBg != null ||
        _removeLogo ||
        _removeBg;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? _C.red : _C.brand));
  }

  Future<void> _pick({required bool logo, required bool isEnglish}) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg'], withData: true);
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    final limitMb = logo ? 1 : 3;
    if (f.size > limitMb * 1024 * 1024) {
      _snack(isEnglish ? 'File is larger than $limitMb MB' : 'ไฟล์ใหญ่เกิน $limitMb MB', error: true);
      return;
    }
    setState(() {
      if (logo) {
        _newLogo = BrandingImage(f.bytes!, f.name);
        _removeLogo = false;
      } else {
        _newBg = BrandingImage(f.bytes!, f.name);
        _removeBg = false;
      }
    });
  }

  Future<void> _save(bool isEnglish) async {
    setState(() => _saving = true);
    try {
      final b = await _svc.save(
        layout: _layout,
        nameTh: _nameTh.text.trim(),
        nameEn: _nameEn.text.trim(),
        taglineTh: _tagTh.text.trim(),
        taglineEn: _tagEn.text.trim(),
        logo: _newLogo,
        background: _newBg,
        removeLogo: _removeLogo,
        removeBackground: _removeBg,
      );
      if (!mounted) return;
      setState(() => _apply(b));
      _snack(isEnglish ? 'Saved. The login screen uses these settings now.' : 'บันทึกแล้ว หน้าล็อกอินใช้ค่าใหม่ทันที');
    } catch (e) {
      if (mounted) _snack('${isEnglish ? 'Save failed' : 'บันทึกไม่สำเร็จ'}: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset(bool isEnglish) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Restore defaults?' : 'คืนค่าเริ่มต้น?'),
        content: Text(isEnglish
            ? 'Layout A, the standard name and tagline, and the app logo will be used. The uploaded logo and background will be deleted.'
            : 'จะกลับไปใช้แบบ A ชื่อระบบและคำโปรยมาตรฐาน และโลโก้ของแอป โลโก้และรูปพื้นหลังที่อัปโหลดไว้จะถูกลบ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEnglish ? 'Restore defaults' : 'คืนค่าเริ่มต้น'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final b = await _svc.save(layout: 'A', nameTh: '', nameEn: '', taglineTh: '', taglineEn: '', reset: true);
      if (!mounted) return;
      setState(() => _apply(b));
      _snack(isEnglish ? 'Defaults restored' : 'คืนค่าเริ่มต้นแล้ว');
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // รูปที่จะแสดง (ไฟล์ใหม่ที่ยังไม่บันทึก > ของเดิม, ลบ = ไม่มี)
  ImageProvider? get _logoImage => _newLogo != null
      ? MemoryImage(_newLogo!.bytes)
      : (!_removeLogo && _saved?.logoUrl != null ? NetworkImage(_saved!.logoUrl!) : null);
  ImageProvider? get _bgImage => _newBg != null
      ? MemoryImage(_newBg!.bytes)
      : (!_removeBg && _saved?.backgroundUrl != null ? NetworkImage(_saved!.backgroundUrl!) : null);

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (!_isDeveloper) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 40, color: _C.ink3),
          const SizedBox(height: 8),
          Text(isEnglish ? 'Only developers can change the login screen.' : 'เฉพาะผู้พัฒนาระบบเท่านั้นที่แก้ไขหน้าล็อกอินได้',
              style: const TextStyle(color: _C.ink2)),
        ]),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: _C.red)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: Text(isEnglish ? 'Retry' : 'ลองใหม่')),
        ]),
      );
    }

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _layoutCard(isEnglish),
      const SizedBox(height: 16),
      _imageCard(
        isEnglish: isEnglish,
        title: isEnglish ? 'System logo' : 'โลโก้ระบบ',
        note: isEnglish ? 'Shown on the login screen for every database' : 'แสดงบนหน้าล็อกอิน ใช้ร่วมทุกฐานข้อมูล',
        rule: isEnglish
            ? 'PNG or JPG up to 1 MB. A square image with a transparent background, at least 512×512 px, works best. Also used in the home screen side panel when the company has no logo.'
            : 'PNG หรือ JPG ไม่เกิน 1 MB · แนะนำภาพสี่เหลี่ยมจัตุรัสพื้นโปร่งใส อย่างน้อย 512×512 px · ใช้ที่แถบเมนูซ้ายของหน้าหลักด้วย เมื่อบริษัทไม่มีโลโก้',
        image: _logoImage,
        square: true,
        hasImage: _logoImage != null,
        onPick: () => _pick(logo: true, isEnglish: isEnglish),
        onRemove: () => setState(() {
          _newLogo = null;
          _removeLogo = _saved?.logoUrl != null;
        }),
      ),
      const SizedBox(height: 16),
      _textCard(isEnglish),
      const SizedBox(height: 16),
      _imageCard(
        isEnglish: isEnglish,
        title: isEnglish ? 'Background image' : 'รูปพื้นหลัง',
        note: isEnglish ? 'Layout B only · none = green-to-gold gradient' : 'เฉพาะแบบ B · ไม่ใส่ = พื้นไล่สีเขียว-ทอง',
        rule: isEnglish
            ? 'Landscape PNG or JPG up to 3 MB, 1920×1080 px or larger. The image is darkened slightly so the card stays readable.'
            : 'รูปแนวนอน PNG หรือ JPG ไม่เกิน 3 MB แนะนำ 1920×1080 px ขึ้นไป ระบบจะทำให้มืดลงเล็กน้อยเพื่อให้การ์ดอ่านง่าย',
        image: _bgImage,
        square: false,
        hasImage: _bgImage != null,
        onPick: () => _pick(logo: false, isEnglish: isEnglish),
        onRemove: () => setState(() {
          _newBg = null;
          _removeBg = _saved?.backgroundUrl != null;
        }),
      ),
      const SizedBox(height: 16),
      _historyCard(isEnglish),
    ]);

    return Container(
      color: _C.bg,
      child: Column(children: [
        // แถบปุ่ม
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _C.line))),
          child: Row(children: [
            Text(isEnglish ? 'Login screen settings' : 'ตั้งค่าหน้าล็อกอิน',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _C.ink)),
            const SizedBox(width: 10),
            if (_dirty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(10)),
                child: Text(isEnglish ? 'Unsaved changes' : 'ยังไม่ได้บันทึก',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A00))),
              ),
            const Spacer(),
            OutlinedButton(
              onPressed: _saving ? null : () => _reset(isEnglish),
              child: Text(isEnglish ? 'Restore defaults' : 'คืนค่าเริ่มต้น'),
            ),
            const SizedBox(width: 8),
            if (_dirty) ...[
              TextButton(
                onPressed: _saving ? null : () => setState(() => _apply(_saved!)),
                child: Text(isEnglish ? 'Discard' : 'ยกเลิกการแก้ไข'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _C.brand),
              onPressed: _saving || !_dirty ? null : () => _save(isEnglish),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1100;
            final preview = _previewCard(isEnglish);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: left),
                      const SizedBox(width: 18),
                      SizedBox(width: 520, child: preview),
                    ])
                  : Column(children: [preview, const SizedBox(height: 16), left]),
            );
          }),
        ),
      ]),
    );
  }

  Widget _card({required String title, String? note, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _C.line), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _C.ink)),
          if (note != null) TextSpan(text: '   $note', style: const TextStyle(fontSize: 12, color: _C.ink3)),
        ])),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  // ── เลือกแบบหน้าล็อกอิน ─────────────────────────────────────────────────
  Widget _layoutCard(bool isEnglish) {
    Widget option(String v, String title, String desc) {
      final on = _layout == v;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _layout = v),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: on ? _C.hover : Colors.white,
              border: Border.all(color: on ? _C.brand : _C.line, width: on ? 1.6 : 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              _LayoutThumb(layout: v),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: on ? _C.brand : _C.ink3),
                    const SizedBox(width: 6),
                    Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _C.ink))),
                  ]),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: _C.ink2)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }

    return _card(
      title: isEnglish ? 'Login screen layout' : 'แบบหน้าล็อกอิน',
      child: Row(children: [
        option('A', isEnglish ? 'A · Split' : 'A · แบ่งซ้าย-ขวา',
            isEnglish ? 'Large logo on green at left, form on white at right' : 'โลโก้ใหญ่บนพื้นเขียวด้านซ้าย ฟอร์มพื้นขาวด้านขวา'),
        const SizedBox(width: 12),
        option('B', isEnglish ? 'B · Centered card' : 'B · การ์ดกลางจอ',
            isEnglish ? 'Form card over a full-screen background' : 'การ์ดฟอร์มบนพื้นหลังเต็มจอ ใส่รูปพื้นหลังได้'),
      ]),
    );
  }

  // ── รูป (โลโก้ / พื้นหลัง) ──────────────────────────────────────────────
  Widget _imageCard({
    required bool isEnglish,
    required String title,
    required String note,
    required String rule,
    required ImageProvider? image,
    required bool square,
    required bool hasImage,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final w = square ? 110.0 : 180.0;
    return _card(
      title: title,
      note: note,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCFB),
          border: Border.all(color: const Color(0xFFB9C8BF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: w,
            height: 110,
            padding: square ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _C.line),
              borderRadius: BorderRadius.circular(12),
              gradient: !square && image == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1D6A4D), _C.brand2, Color(0xFF5C4A12)],
                      stops: [0, 0.6, 1])
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: image != null
                ? Image(image: image, fit: square ? BoxFit.contain : BoxFit.cover)
                : (square ? const Image(image: AssetImage('assets/images/ANAN.png'), fit: BoxFit.contain) : null),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasImage
                    ? (isEnglish ? 'Current image' : 'รูปปัจจุบัน')
                    : (square ? (isEnglish ? 'Using the app logo' : 'ใช้โลโก้มาตรฐานของแอป') : (isEnglish ? 'Using the gradient' : 'ใช้พื้นไล่สี')),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _C.ink),
              ),
              const SizedBox(height: 4),
              Text(rule, style: const TextStyle(fontSize: 12.5, color: _C.ink2)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _C.brand),
                  onPressed: _saving ? null : onPick,
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: Text(isEnglish ? 'Choose file' : 'เลือกไฟล์'),
                ),
                if (hasImage)
                  OutlinedButton.icon(
                    onPressed: _saving ? null : onRemove,
                    icon: const Icon(Icons.delete_outline, size: 18, color: _C.red),
                    label: Text(isEnglish ? 'Remove' : 'ลบรูป', style: const TextStyle(color: _C.red)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── ชื่อระบบและคำโปรย ───────────────────────────────────────────────────
  Widget _textCard(bool isEnglish) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );
    return _card(
      title: isEnglish ? 'System name and tagline' : 'ชื่อระบบและคำโปรย',
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _nameTh, maxLength: 80, decoration: deco(isEnglish ? 'System name (Thai)' : 'ชื่อระบบ (ไทย)'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _nameEn, maxLength: 80, decoration: deco(isEnglish ? 'System name (English)' : 'ชื่อระบบ (อังกฤษ)'))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: TextField(controller: _tagTh, maxLength: 200, decoration: deco(isEnglish ? 'Tagline (Thai)' : 'คำโปรย (ไทย)'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _tagEn, maxLength: 200, decoration: deco(isEnglish ? 'Tagline (English)' : 'คำโปรย (อังกฤษ)'))),
        ]),
      ]),
    );
  }

  Widget _historyCard(bool isEnglish) {
    final h = _saved?.history ?? const [];
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return _card(
      title: isEnglish ? 'Change history' : 'ประวัติการแก้ไข',
      child: h.isEmpty
          ? Text(isEnglish ? 'No changes yet' : 'ยังไม่มีการแก้ไข', style: const TextStyle(fontSize: 12.5, color: _C.ink3))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in h.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 120,
                        child: Text(e.at == null ? '' : fmt.format(e.at!), style: const TextStyle(fontSize: 12, color: _C.ink3))),
                    SizedBox(width: 90, child: Text(e.by, style: const TextStyle(fontSize: 12, color: _C.ink3))),
                    Expanded(child: Text(e.action, style: const TextStyle(fontSize: 12.5, color: _C.ink2))),
                  ]),
                ),
            ]),
    );
  }

  // ── ตัวอย่างหน้าล็อกอิน (ย่อส่วน) ──────────────────────────────────────
  Widget _previewCard(bool isEnglish) {
    final name = isEnglish ? _nameEn.text : _nameTh.text;
    final tag = isEnglish ? _tagEn.text : _tagTh.text;
    return _card(
      title: isEnglish ? 'Preview' : 'ตัวอย่างหน้าล็อกอิน',
      note: isEnglish ? 'Layout $_layout' : 'แบบ $_layout',
      child: AspectRatio(
        aspectRatio: 1280 / 760,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: _C.line), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1280,
              height: 760,
              child: _LoginPreview(
                layout: _layout,
                name: name.trim().isEmpty ? 'ANAN System' : name,
                tagline: tag,
                logo: _logoImage,
                background: _bgImage,
                isEnglish: isEnglish,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ภาพย่อแบบ A/B ในตัวเลือก
class _LayoutThumb extends StatelessWidget {
  final String layout;
  const _LayoutThumb({required this.layout});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(width: w, height: 4, margin: const EdgeInsets.only(top: 3), color: _C.line);
    final form = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [bar(26), bar(26), bar(26), Container(width: 26, height: 5, margin: const EdgeInsets.only(top: 3), color: _C.brand)]),
    );
    return Container(
      width: 84,
      height: 54,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: _C.line)),
      clipBehavior: Clip.antiAlias,
      child: layout == 'A'
          ? Row(children: [
              Expanded(
                  child: Container(
                      color: _C.brand2,
                      alignment: Alignment.center,
                      child: Container(width: 16, height: 16, decoration: BoxDecoration(color: _C.gold, borderRadius: BorderRadius.circular(3))))),
              Expanded(child: Container(color: Colors.white, alignment: Alignment.center, child: form)),
            ])
          : Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1D6A4D), _C.brand2, Color(0xFF5C4A12)], stops: [0, 0.6, 1])),
              alignment: Alignment.center,
              child: form,
            ),
    );
  }
}

/// หน้าล็อกอินย่อส่วน (ขนาดจริง 1280×760 แล้วย่อด้วย FittedBox) — โครงเดียวกับหน้าล็อกอินจริง ไม่มีฟอร์มที่ใช้งานได้
class _LoginPreview extends StatelessWidget {
  final String layout;
  final String name;
  final String tagline;
  final ImageProvider? logo;
  final ImageProvider? background;
  final bool isEnglish;
  const _LoginPreview({
    required this.layout,
    required this.name,
    required this.tagline,
    required this.logo,
    required this.background,
    required this.isEnglish,
  });

  Widget _logo() => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(image: logo ?? const AssetImage('assets/images/ANAN.png'), fit: BoxFit.contain),
      );

  Widget _form() {
    Widget field(String l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.ink2)),
          const SizedBox(height: 6),
          Container(height: 44, decoration: BoxDecoration(border: Border.all(color: _C.line), borderRadius: BorderRadius.circular(9))),
          const SizedBox(height: 14),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      field(isEnglish ? 'Database' : 'ฐานข้อมูล'),
      field(isEnglish ? 'Username' : 'ชื่อผู้ใช้งาน'),
      field(isEnglish ? 'Password' : 'รหัสผ่าน'),
      Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _C.brand, borderRadius: BorderRadius.circular(9)),
        child: Text(isEnglish ? 'Log in' : 'เข้าสู่ระบบ',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (layout == 'B') {
      return Stack(fit: StackFit.expand, children: [
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D6A4D), _C.brand2, Color(0xFF5C4A12)],
                    stops: [0, 0.6, 1]))),
        if (background != null) Image(image: background!, fit: BoxFit.cover),
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x40061E16), Color(0x8C061E16)]))),
        Center(
          child: Container(
            width: 440,
            padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: _C.line), borderRadius: BorderRadius.circular(20)),
                  child: _logo(),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _C.ink)),
              const SizedBox(height: 4),
              Text(tagline, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: _C.ink2)),
              const SizedBox(height: 20),
              _form(),
            ]),
          ),
        ),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: 105,
        child: Container(
          color: _C.brand2,
          padding: const EdgeInsets.fromLTRB(64, 56, 64, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 168,
              height: 168,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: _logo(),
            ),
            const SizedBox(height: 34),
            Text(name, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFFE8F3EC))),
            const SizedBox(height: 10),
            SizedBox(width: 440, child: Text(tagline, style: const TextStyle(fontSize: 17, color: Color(0xFF9FC0B0), height: 1.55))),
          ]),
        ),
      ),
      Expanded(
        flex: 100,
        child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(isEnglish ? 'Log in' : 'เข้าสู่ระบบ', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _C.ink)),
              const SizedBox(height: 22),
              _form(),
            ]),
          ),
        ),
      ),
    ]);
  }
}
