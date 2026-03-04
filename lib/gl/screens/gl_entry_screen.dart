import 'package:flutter/material.dart';
import '../widgets/gl_entry_list_widget.dart';
import '../widgets/gl_entry_detail_widget.dart';
import '../models/gl_entry.dart';

class GlEntryScreen extends StatefulWidget {
  const GlEntryScreen({super.key});

  @override
  State<GlEntryScreen> createState() => _GlEntryScreenState();
}

class _GlEntryScreenState extends State<GlEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State to pass to Detail Tab
  int? _selectedEntryId; // null = New Entry
  bool _isViewOnly = false;
  bool _shouldRefreshList = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ฟังก์ชันเปิด Tab รายละเอียด (Add/Edit)
  void _openDetailTab({int? id, bool viewOnly = false}) {
    setState(() {
      _selectedEntryId = id;
      _isViewOnly = viewOnly;
    });
    _tabController.animateTo(1); // Switch to "รายการบัญชี"
  }

  // ฟังก์ชันเมื่อบันทึกเสร็จ ให้กลับมาหน้า List
  void _onSaveSuccess() {
    setState(() {
      _shouldRefreshList = true; // Trigger refresh in List Tab
      _selectedEntryId = null; // Reset selection
    });
    _tabController.animateTo(0); // Switch back to "ค้นหา"
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บันทึกรายการบัญชี'),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            dividerColor: Colors.grey,
            labelColor: Colors.deepOrange[900],
            // indicatorColor: Colors.white,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'ค้นหา/แก้ไข/เพิ่ม'),
              Tab(text: 'รายการบัญชี'),
            ],
          ),
          Expanded(
            child:
              TabBarView(
                key: ValueKey(_shouldRefreshList
                    ? 'refresh_${DateTime.now().millisecondsSinceEpoch}'
                    : 'no_refresh'),
                controller: _tabController,
                physics:
                    const NeverScrollableScrollPhysics(), // ป้องกันการ Swipe เปลี่ยน Tab โดยไม่ตั้งใจ
                children: [
                  // Tab 1: List
                  GlEntryListWidget(
                    // onAddPressed: () => _openDetailTab(id: null),
                    // onEditPressed: (id) => _openDetailTab(id: id),
                    onAddPressed: () => _openDetailTab(id: null, viewOnly: false), // เพิ่มใหม่ -> ไม่ View Only
                    onEditPressed: (id) => _openDetailTab(id: id, viewOnly: false), // แก้ไข -> ไม่ View Only
                    onViewPressed: (id) => _openDetailTab(id: id, viewOnly: true),  // [NEW] ดู -> View Only = true
                    shouldRefresh: _shouldRefreshList,
                    onRefreshComplete: () => setState(() => _shouldRefreshList = false),
                  ),
                  // Tab 2: Detail
                  GlEntryDetailWidget(
                    entryId: _selectedEntryId,
                    viewOnly: _isViewOnly,
                    onSaveSuccess: _onSaveSuccess,
                    onCancel: () => _tabController.animateTo(0),
                  ),
                ],
              ),),
        ],
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../../sa/models/module_document.dart';
// import '../models/gl_entry.dart';
// import '../models/account.dart'; // For Dropdown

// class GlEntryScreen extends StatefulWidget {
//   final int? transactionId;
//   const GlEntryScreen({super.key, this.transactionId});

//   @override
//   State<GlEntryScreen> createState() => _GlTransactionFormScreenState();
// }

// class _GlTransactionFormScreenState extends State<GlEntryScreen> {
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;
  
//   // Master Data
//   List<ModuleDocument> _allowedDocTypes = [];
//   List<Account> _accounts = []; // Should fetch all active accounts
  
//   // Form Data
//   GlEntryHeader _header = GlEntryHeader(
//     docId: 0, docDate: DateTime.now(), postingDate: DateTime.now()
//   );
//   List<GlEntryDetail> _details = [];

//   // Config
//   bool _isAutoNumbering = false;
//   ModuleDocument? _selectedDocType;

//   @override
//   void initState() {
//     super.initState();
//     _fetchMasterData().then((_) {
//       if (widget.transactionId != null) {
//         _fetchTransaction(widget.transactionId!);
//       }
//     });
//   }

//   Future<void> _fetchMasterData() async {
//     // 1. Fetch Allowed Doc Types for User (Replace userId with actual)
//     final docRes = await http.get(Uri.parse('http://localhost:3000/api/gl/doctypes/allowed/1'));
//     // 2. Fetch Accounts
//     // ... logic similar to previous services
    
//     if (docRes.statusCode == 200) {
//       setState(() {
//         _allowedDocTypes = (jsonDecode(docRes.body) as List).map((e) => ModuleDocument.fromJson(e)).toList();
//       });
//     }
//   }

//   Future<void> _fetchTransaction(int id) async {
//     // Implement fetch logic (GET /api/gl/transactions/:id)
//     // Populate _header and _details
//     // If Status != Draft -> Disable Editing
//   }

//   void _onDocTypeChanged(ModuleDocument? val) {
//     if (val == null) return;
//     setState(() {
//       _selectedDocType = val;
//       _header = GlEntryHeader(
//         id: _header.id, docId: val.id, docNo: val.isAutoNumbering ? 'AUTO' : '', 
//         docCode: val.docCode, docName: val.docNameThai,
//         docDate: _header.docDate, postingDate: _header.postingDate
//       );
//       _isAutoNumbering = val.isAutoNumbering;
//     });
//   }

//   void _addDetailRow() {
//     setState(() {
//       _details.add(GlEntryDetail(accountId: 0));
//     });
//   }

//   void _recalculateTotals() {
//     double dr = 0, cr = 0;
//     for (var d in _details) {
//       dr += d.debit;
//       cr += d.credit;
//     }
//     _header.totalDebit = dr;
//     _header.totalCredit = cr;
//   }

//   Future<void> _save(String action) async {
//     if (!_formKey.currentState!.validate()) return;
//     _formKey.currentState!.save();

//     if (action == 'Post' && (_header.totalDebit != _header.totalCredit)) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยอดรวมเดบิตและเครดิตไม่เท่ากัน')));
//       return;
//     }

//     setState(() => _isLoading = true);
    
//     final body = {
//       'header': _header.toJson(),
//       'details': _details.map((e) => {
//         'account_id': e.accountId, 'description': e.description,
//         'debit': e.debit, 'credit': e.credit,
//         'branch_id': e.branchId // ... other dimensions
//       }).toList(),
//       'action': action // 'Draft' or 'Post'
//     };

//     final url = widget.transactionId == null 
//         ? 'http://localhost:3000/api/gl/transactions'
//         : 'http://localhost:3000/api/gl/transactions/${widget.transactionId}';

//     final method = widget.transactionId == null ? http.post : http.put;

//     try {
//       final res = await method(Uri.parse(url), 
//           headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      
//       if (res.statusCode == 200 || res.statusCode == 201) {
//         Navigator.pop(context);
//       } else {
//         throw Exception(res.body);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
  
//   Future<void> _reverse() async {
//     // Call API Reverse logic
//   }

//   Future<void> _delete() async {
//     // Call API Delete logic
//   }

//   @override
//   Widget build(BuildContext context) {
//     bool isReadOnly = _header.status != 'Draft' && widget.transactionId != null;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.transactionId == null ? 'สร้างรายการใหม่' : 'แก้ไขรายการ ${_header.docNo}'),
//         actions: [
//           if (!isReadOnly && widget.transactionId != null)
//              IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
//           if (isReadOnly && _header.status == 'Posted')
//              TextButton(onPressed: _reverse, child: const Text('Reverse', style: TextStyle(color: Colors.white))),
//         ],
//       ),
//       body: _isLoading ? const Center(child: CircularProgressIndicator()) : Form(
//         key: _formKey,
//         child: Column(
//           children: [
//             // --- Header Section ---
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: DropdownButtonFormField<ModuleDocument>(
//                             value: _selectedDocType, // Must match object in list
//                             items: _allowedDocTypes.map((e) => DropdownMenuItem(value: e, child: Text('${e.docCode} - ${e.docNameThai}'))).toList(),
//                             onChanged: isReadOnly ? null : _onDocTypeChanged,
//                             decoration: const InputDecoration(labelText: 'ประเภทเอกสาร'),
//                             validator: (v) => v == null ? 'กรุณาเลือก' : null,
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: TextFormField(
//                             initialValue: _header.docNo,
//                             decoration: const InputDecoration(labelText: 'เลขที่เอกสาร'),
//                             readOnly: _isAutoNumbering || isReadOnly,
//                             onSaved: (v) => _header.docNo = v ?? '',
//                           ),
//                         ),
//                       ],
//                     ),
//                     // ... Date Pickers, Ref No, Description inputs ...
//                   ],
//                 ),
//               ),
//             ),
            
//             // --- Details Section ---
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _details.length + 1,
//                 itemBuilder: (context, index) {
//                   if (index == _details.length) {
//                     return isReadOnly ? const SizedBox() : TextButton.icon(
//                       icon: const Icon(Icons.add), label: const Text('เพิ่มรายการ'), 
//                       onPressed: _addDetailRow
//                     );
//                   }
//                   final detail = _details[index];
//                   return Card(
//                     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     child: Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Row(
//                         children: [
//                           Expanded(flex: 3, child: TextFormField(
//                             decoration: const InputDecoration(labelText: 'รหัสบัญชี'),
//                             // Ideally use a Searchable Dropdown or Modal here
//                             onChanged: (v) => detail.accountCode = v,
//                           )),
//                           Expanded(flex: 2, child: TextFormField(
//                             initialValue: detail.debit.toString(),
//                             decoration: const InputDecoration(labelText: 'เดบิต'),
//                             keyboardType: TextInputType.number,
//                             onChanged: (v) {
//                                 detail.debit = double.tryParse(v) ?? 0;
//                                 _recalculateTotals();
//                             },
//                           )),
//                           Expanded(flex: 2, child: TextFormField(
//                             initialValue: detail.credit.toString(),
//                             decoration: const InputDecoration(labelText: 'เครดิต'),
//                             keyboardType: TextInputType.number,
//                             onChanged: (v) {
//                                 detail.credit = double.tryParse(v) ?? 0;
//                                 _recalculateTotals();
//                             },
//                           )),
//                           if (!isReadOnly) IconButton(
//                             icon: const Icon(Icons.remove_circle, color: Colors.red),
//                             onPressed: () {
//                               setState(() { _details.removeAt(index); _recalculateTotals(); });
//                             }
//                           )
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
            
//             // --- Footer Section ---
//             Container(
//               padding: const EdgeInsets.all(16),
//               color: Colors.grey[200],
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text('Dr: ${_header.totalDebit.toStringAsFixed(2)} | Cr: ${_header.totalCredit.toStringAsFixed(2)}'),
//                   Row(
//                     children: [
//                       if (!isReadOnly) ...[
//                         OutlinedButton(onPressed: () => _save('Draft'), child: const Text('บันทึก Draft')),
//                         const SizedBox(width: 8),
//                         ElevatedButton(onPressed: () => _save('Post'), child: const Text('Post รายการ')),
//                       ]
//                     ],
//                   )
//                 ],
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }