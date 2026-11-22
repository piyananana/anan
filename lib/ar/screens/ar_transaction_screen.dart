import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../widgets/ar_transaction_list_widget.dart';
import '../widgets/ar_transaction_detail_widget.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';

class ArTransactionScreen extends StatefulWidget {
  // เปิดตรงไปที่แท็บรายละเอียดของ id นี้ทันที (เช่น จากกระดิ่งรายการรออนุมัติเกินวงเงิน)
  final int? initialDetailId;
  const ArTransactionScreen({super.key, this.initialDetailId});

  @override
  State<ArTransactionScreen> createState() => _ArTransactionScreenState();
}

class _ArTransactionScreenState extends State<ArTransactionScreen>
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
          // ปุ่มของเอกสาร (บันทึก/Post/ถอย/ยกเลิก ...) — แสดงเฉพาะหน้ารายละเอียด (แทนแถบปุ่มเดิม)
          if (_currentTabIndex == 1)
            AnimatedBuilder(
              animation: _detailActions,
              builder: (ctx, _) => _detailActions.build(ctx, isEnglish),
            ),
          // หน้ารายการ: ปุ่มเพิ่มเอกสารบน AppBar (ปุ่มทึบแบบเดียวกับปุ่มของหน้ารายละเอียด)
          if (_currentTabIndex == 0 && canCreate)
            buildDocBarActions(
              context,
              [DocBarAction.primary(isEnglish ? 'Add Document' : 'เพิ่มเอกสาร', () => _openDetailTab(), DocBarColors.submit)],
              isEnglish: isEnglish,
            ),
          // หน้ารายละเอียดซ่อนปุ่มรีเฟรช (กดพลาดแล้วการแก้ไขหาย) — กลับรายการด้วยลูกศรย้อนกลับ
          if (_currentTabIndex == 0)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: () => setState(() {
              _shouldRefreshList = true;
              _selectedTransactionId = null;
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
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ArTransactionListWidget(
                  onEditPressed: (id) => _openDetailTab(id: id),
                  onViewPressed: (id) => _openDetailTab(id: id, viewOnly: true),
                  shouldRefresh: _shouldRefreshList,
                  onRefreshComplete: () => setState(() => _shouldRefreshList = false),
                  enableEditButton: canEdit,
                ),
                ArTransactionDetailWidget(
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
