import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../widgets/gl_entry_list_widget.dart';
import '../widgets/gl_entry_detail_widget.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';

class GlEntryScreen extends StatefulWidget {
  const GlEntryScreen({super.key});

  @override
  State<GlEntryScreen> createState() => _GlEntryScreenState();
}

class _GlEntryScreenState extends State<GlEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _detailActions = DocAppBarActions(); // ปุ่มของเอกสารบน AppBar
  int _currentTabIndex = 0;

  int? _selectedEntryId;
  bool _isViewOnly = false;
  bool _shouldRefreshList = false;
  int _detailResetKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _currentTabIndex != _tabController.index) {
      setState(() => _currentTabIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _detailActions.dispose();
    super.dispose();
  }

  void _openDetailTab({int? id, bool viewOnly = false}) {
    setState(() {
      if (id == null) _detailResetKey++;
      _selectedEntryId = id;
      _isViewOnly = viewOnly;
      _currentTabIndex = 1;
    });
    _tabController.animateTo(1);
  }

  // ลูกศรย้อนกลับบน AppBar — มีการแก้ไขที่ยังไม่บันทึก ต้องยืนยันก่อนออกจากหน้ารายละเอียด
  Future<void> _confirmBackToList(bool isEnglish) async {
    if (_detailActions.isDirty && !await confirmDiscardChanges(context, isEnglish)) return;
    if (mounted) _backToList();
  }

  void _backToList() {
    setState(() => _currentTabIndex = 0);
    _tabController.animateTo(0);
  }

  void _onSaveSuccess() {
    setState(() {
      _shouldRefreshList = true;
      _selectedEntryId = null;
      _currentTabIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.animateTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    return Scaffold(
      appBar: AppBar(
        // ไม่มีแถบแท็บ (เพิ่มพื้นที่หน้าจอ): หน้ารายละเอียดใช้ปุ่มย้อนกลับบน AppBar กลับไปหน้ารายการ
        leading: _currentTabIndex == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: isEnglish ? 'Back to list' : 'กลับไปรายการ',
                onPressed: () => _confirmBackToList(isEnglish),
              )
            : null,
        automaticallyImplyLeading: false,
        title: _currentTabIndex == 1
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Flexible(child: MenuTitle()),
                Text('  >  ${isEnglish ? 'Transaction Details' : 'รายละเอียดธุรกรรม'}'),
              ])
            : const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มของเอกสาร (บันทึก/Post/ถอย/ยกเลิก ...) — แสดงเฉพาะหน้ารายละเอียด (แทนแถบปุ่มเดิม)
          if (_currentTabIndex == 1)
            AnimatedBuilder(
              animation: _detailActions,
              builder: (ctx, _) => _detailActions.build(ctx, isEnglish),
            ),
          // หน้ารายละเอียดซ่อนปุ่มรีเฟรช (กดพลาดแล้วการแก้ไขหาย) — กลับรายการด้วยลูกศรย้อนกลับ
          if (_currentTabIndex == 0)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () => setState(() {
              _shouldRefreshList = true;
              _selectedEntryId = null;
              _currentTabIndex = 0;
              _tabController.animateTo(0);
            }),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                GlEntryListWidget(
                  onAddPressed: () =>
                      _openDetailTab(id: null, viewOnly: false),
                  onEditPressed: (id) =>
                      _openDetailTab(id: id, viewOnly: false),
                  onViewPressed: (id) =>
                      _openDetailTab(id: id, viewOnly: true),
                  shouldRefresh: _shouldRefreshList,
                  onRefreshComplete: () =>
                      setState(() => _shouldRefreshList = false),
                  enableAddButton: canCreate,
                  enableEditButton: canEdit,
                  enableDeleteButton: canDelete,
                ),
                GlEntryDetailWidget(
                  entryId: _selectedEntryId,
                  viewOnly: _isViewOnly || !canEdit,
                  resetKey: _detailResetKey,
                  onSaveSuccess: _onSaveSuccess,
                  onCancel: _backToList,
                  canDelete: canDelete,
                  actions: _detailActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
