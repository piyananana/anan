import 'package:flutter/material.dart';
import '../../sa/utils/menu_scope.dart';
import '../widgets/gl_entry_list_widget.dart';
import '../widgets/gl_entry_detail_widget.dart';

class GlEntryScreen extends StatefulWidget {
  const GlEntryScreen({super.key});

  @override
  State<GlEntryScreen> createState() => _GlEntryScreenState();
}

class _GlEntryScreenState extends State<GlEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
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
          TabBar(
            controller: _tabController,
            onTap: (index) {
              if (index == 1) {
                _tabController.animateTo(_currentTabIndex, duration: Duration.zero);
              }
            },
            dividerColor: Colors.grey,
            labelColor: Colors.deepOrange[900],
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'ค้นหา/แก้ไข/เพิ่มธุรกรรม'),
              Tab(text: 'รายละเอียดธุรกรรม'),
            ],
          ),
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
                ),
                GlEntryDetailWidget(
                  entryId: _selectedEntryId,
                  viewOnly: _isViewOnly,
                  resetKey: _detailResetKey,
                  onSaveSuccess: _onSaveSuccess,
                  onCancel: () {
                    setState(() => _currentTabIndex = 0);
                    _tabController.animateTo(0);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
