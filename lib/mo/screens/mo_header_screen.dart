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
        title: const MenuTitle(),
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
          TabBar(
            controller: _tabController,
            onTap: (index) {
              if (index == 1) _tabController.animateTo(_currentTabIndex, duration: Duration.zero);
            },
            dividerColor: Colors.grey,
            labelColor: Colors.teal[800],
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: isEnglish ? 'Search / Add MO' : 'ค้นหา/เพิ่มใบสั่งผลิต'),
              Tab(text: isEnglish ? 'MO Details' : 'รายละเอียดใบสั่งผลิต'),
            ],
          ),
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
                  onCancel: () {
                    setState(() => _currentTabIndex = 0);
                    _tabController.animateTo(0);
                  },
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
