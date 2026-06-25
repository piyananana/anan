import 'package:flutter/material.dart';
import '../widgets/ap_transaction_list_widget.dart';
import '../widgets/ap_transaction_detail_widget.dart';

class ApTransactionScreen extends StatefulWidget {
  const ApTransactionScreen({super.key});

  @override
  State<ApTransactionScreen> createState() => _ApTransactionScreenState();
}

class _ApTransactionScreenState extends State<ApTransactionScreen>
    with SingleTickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.receipt_long, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ธุรกรรมเจ้าหนี้การค้า (AP)'),
        ]),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
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
              if (index == 1) {
                _tabController.animateTo(_currentTabIndex, duration: Duration.zero);
              }
            },
            dividerColor: Colors.grey,
            labelColor: Colors.blue[800],
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'ค้นหา/เพิ่มธุรกรรม'),
              Tab(text: 'รายละเอียดธุรกรรม'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ApTransactionListWidget(
                  onAddPressed: () => _openDetailTab(),
                  onEditPressed: (id) => _openDetailTab(id: id),
                  onViewPressed: (id) => _openDetailTab(id: id, viewOnly: true),
                  shouldRefresh: _shouldRefreshList,
                  onRefreshComplete: () => setState(() => _shouldRefreshList = false),
                ),
                ApTransactionDetailWidget(
                  transactionId: _selectedTransactionId,
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
