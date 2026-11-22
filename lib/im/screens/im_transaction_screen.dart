import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../widgets/im_transaction_list_widget.dart';
import '../widgets/im_transaction_detail_widget.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';

class ImTransactionScreen extends StatefulWidget {
  // เปิดตรงไปที่แท็บรายละเอียดของ id นี้ทันที (เช่น จากกระดิ่งรายการรออนุมัติเกินวงเงิน)
  final int? initialDetailId;
  const ImTransactionScreen({super.key, this.initialDetailId});

  @override
  State<ImTransactionScreen> createState() => _ImTransactionScreenState();
}

class _ImTransactionScreenState extends State<ImTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _detailActions = DocAppBarActions(); // ปุ่มของเอกสารบน AppBar
  int _currentTabIndex = 0;

  int? _selectedTransactionId;
  bool _isViewOnly = false;
  bool _shouldRefreshList = false;
  int _detailResetKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    if (widget.initialDetailId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDetailTab(id: widget.initialDetailId);
      });
    }
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
      _selectedTransactionId = id;
      _isViewOnly = viewOnly;
      _currentTabIndex = 1;
    });
    _tabController.animateTo(1);
  }

  void _backToList() {
    setState(() => _currentTabIndex = 0);
    _tabController.animateTo(0);
  }

  // ลูกศรย้อนกลับบน AppBar — มีการแก้ไขที่ยังไม่บันทึก ต้องยืนยันก่อนออกจากหน้ารายละเอียด
  Future<void> _confirmBackToList(bool isEnglish) async {
    if (_detailActions.isDirty && !await confirmDiscardChanges(context, isEnglish)) return;
    if (mounted) _backToList();
  }

  void _refreshList() {
    setState(() {
      _shouldRefreshList = true;
      _selectedTransactionId = null;
      _currentTabIndex = 0;
      _tabController.animateTo(0);
    });
  }

  void _onSaveSuccess() {
    setState(() {
      _shouldRefreshList = true;
      _selectedTransactionId = null;
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
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มของเอกสาร (บันทึกร่าง/Post/ถอย/ยกเลิก ...) — แสดงเฉพาะหน้ารายละเอียด (แทนแถบปุ่มด้านล่างเดิม)
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
              onPressed: _refreshList,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ImTransactionListWidget(
                  onAddPressed: () => _openDetailTab(),
                  onEditPressed: (id) => _openDetailTab(id: id),
                  // ไม่บังคับ viewOnly:true สำหรับเอกสารที่ไม่ใช่ Draft — ฟิลด์ข้อมูลถูกล็อกด้วย _isReadOnly
                  // (ยึดตาม status) อยู่แล้วโดยไม่ต้องพึ่ง viewOnly เลย แต่ viewOnly:true จะซ่อนปุ่ม action ทั้งหมด
                  // (Void/Reverse to Draft/Post AP-AR billing) ไปด้วย ซึ่งไม่ใช่เจตนา — ปุ่ม "ดู" ควรยังกดปุ่มเหล่านี้ได้
                  onViewPressed: (id) => _openDetailTab(id: id),
                  shouldRefresh: _shouldRefreshList,
                  onRefreshComplete: () => setState(() => _shouldRefreshList = false),
                  enableAddButton: canCreate,
                  enableEditButton: canEdit,
                ),
                ImTransactionDetailWidget(
                  transactionId: _selectedTransactionId,
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
