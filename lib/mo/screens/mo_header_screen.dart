// lib/mo/screens/mo_header_screen.dart — มิเรอร์ po_transaction_screen.dart (List/Detail tab shell)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../widgets/mo_header_list_widget.dart';
import '../widgets/mo_header_detail_widget.dart';

class MoHeaderScreen extends StatefulWidget {
  // เปิดตรงไปที่แท็บรายละเอียดของ id นี้ทันที (เช่น จากกระดิ่งรายการรออนุมัติ)
  final int? initialDetailId;
  const MoHeaderScreen({super.key, this.initialDetailId});

  @override
  State<MoHeaderScreen> createState() => _MoHeaderScreenState();
}

class _MoHeaderScreenState extends State<MoHeaderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    if (!_tabController.indexIsChanging && _currentTabIndex != _tabController.index) {
      setState(() => _currentTabIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
                onPressed: _backToList,
              )
            : null,
        automaticallyImplyLeading: false,
        title: _currentTabIndex == 1
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Flexible(child: MenuTitle()),
                Text('  >  ${isEnglish ? 'MO Details' : 'รายละเอียดใบสั่งผลิต'}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal)),
              ])
            : const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
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
                MoHeaderListWidget(
                  onAddPressed: () => _openDetailTab(),
                  onEditPressed: (id) => _openDetailTab(id: id),
                  onViewPressed: (id) => _openDetailTab(id: id),
                  shouldRefresh: _shouldRefreshList,
                  onRefreshComplete: () => setState(() => _shouldRefreshList = false),
                  enableAddButton: canCreate,
                  enableEditButton: canEdit,
                ),
                MoHeaderDetailWidget(
                  transactionId: _selectedTransactionId,
                  viewOnly: _isViewOnly || !canEdit,
                  resetKey: _detailResetKey,
                  onSaveSuccess: _onSaveSuccess,
                  onCancel: _backToList,
                  canDelete: canDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
