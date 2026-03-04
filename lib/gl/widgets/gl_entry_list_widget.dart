import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gl_entry.dart';
import '../models/period.dart'; // Import Model Period
import '../services/gl_entry_service.dart';
import '../services/period_service.dart'; // Import Service ใหม่

class GlEntryListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;

  const GlEntryListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
  });

  @override
  State<GlEntryListWidget> createState() => _GlEntryListWidgetState();
}

class _GlEntryListWidgetState extends State<GlEntryListWidget> {
  // final GlEntryService _service = GlEntryService();
  final GlEntryService _entryService = GlEntryService();
  final PeriodService _periodService = PeriodService(); // เรียกใช้ Service
  List<GlEntryHeader> _entries = [];
  bool _isLoading = false;

  // Master Data สำหรับ Dropdown
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  // Filter States (เก็บค่าที่เลือก)
  FiscalYear? _selectedFiscalYear;
  PostingPeriod? _selectedPeriod;
  final TextEditingController _searchCtrl = TextEditingController();

  // // Filter States
  // String? _selectedFiscalYear;
  // String? _selectedPeriod;
  // final TextEditingController _searchCtrl = TextEditingController();

  // // Mock Dropdown Data (ควรดึงจาก DB จริง)
  // final List<String> _fiscalYears = ['2024', '2025'];
  // final List<String> _periods = List.generate(12, (index) => (index + 1).toString());

  // @override
  // void initState() {
  //   super.initState();
  //   // Default Values
  //   _selectedFiscalYear = '2025';
  //   _selectedPeriod = DateTime.now().month.toString();
  //   _fetchData();
  // }

  @override
  void initState() {
    super.initState();
    _initialLoad(); // โหลดข้อมูล Master Data ก่อน
  }

  // @override
  // void didUpdateWidget(covariant GlEntryListWidget oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (widget.shouldRefresh) {
  //     _fetchData();
  //     widget.onRefreshComplete();
  //   }
  // }

  @override
  void didUpdateWidget(covariant GlEntryListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRefresh) {
      _fetchEntries(); // รีเฟรชรายการเมื่อมีการบันทึกเสร็จ
      widget.onRefreshComplete();
    }
  }

  // โหลดปีบัญชี -> ตั้งค่าเริ่มต้น -> โหลดงวด -> ตั้งค่าเริ่มต้น -> โหลดรายการ
  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    try {
      // 1. ดึงปีบัญชีทั้งหมด
      final fys = await _periodService.fetchFiscalYears();
      setState(() {
        _fiscalYears = fys;
      });

      if (fys.isNotEmpty) {
        // 2. หาปีปัจจุบัน หรือใช้ปีล่าสุด
        final now = DateTime.now();
        // ลองหาปีที่ครอบคลุมวันที่ปัจจุบัน
        try {
          _selectedFiscalYear = fys.firstWhere((fy) =>
              now.isAfter(fy.yearStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(fy.yearEndDate.add(const Duration(days: 1))));
        } catch (_) {
          // ถ้าไม่เจอ ให้เอาตัวแรก (ล่าสุด ตาม Order DESC ใน Controller)
          _selectedFiscalYear = fys.first;
        }

        // 3. ดึงงวดบัญชีของปีที่เลือก
        if (_selectedFiscalYear != null) {
          await _fetchPeriods(_selectedFiscalYear!.id);
        }
      }

      // 4. ดึงรายการบัญชี
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading master data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันดึงงวดบัญชีตาม ID ปี
  Future<void> _fetchPeriods(int fyId) async {
    try {
      final periods = await _periodService.fetchPostingPeriodsByFiscalYearId(fyId);
      setState(() {
        _periods = periods;

        // หาเดือนปัจจุบันเพื่อตั้งเป็นค่าเริ่มต้น
        final now = DateTime.now();
        try {
          _selectedPeriod = periods.firstWhere((p) =>
              now.isAfter(
                  p.periodStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(p.periodEndDate.add(const Duration(days: 1))));
        } catch (_) {
          // ถ้าไม่เจอวันปัจจุบันในงวดใดเลย (เช่น ข้ามปี) ให้เลือกงวดแรก หรือ null
          if (periods.isNotEmpty) {
            _selectedPeriod = periods.first;
          } else {
            _selectedPeriod = null;
          }
        }
      });
    } catch (e) {
      print('Error fetching periods: $e');
    }
  }

  // Future<void> _fetchData() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final data = await _service.fetchEntries(
  //       fiscalYear: _selectedFiscalYear,
  //       periodNo: _selectedPeriod,
  //       search: _searchCtrl.text,
  //     );
  //     setState(() {
  //       _entries = data;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  //   }
  // }

  // ฟังก์ชันดึงรายการ GL (Transaction)
  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _entryService.fetchEntries(
        fiscalYear: _selectedFiscalYear?.fyCode, // ส่ง Code ไป Filter
        periodNo:
            _selectedPeriod?.periodNumber.toString(), // ส่ง Number ไป Filter
        search: _searchCtrl.text,
      );
      setState(() {
        _entries = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching entries: $e')));
      }
    }
  }

  // Future<void> _deleteEntry(int id) async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('ยืนยันการลบ'),
  //       content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
  //         TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
  //       ],
  //     ),
  //   );

  //   if (confirm == true) {
  //     try {
  //       await _service.deleteEntry(id);
  //       _fetchData();
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบรายการสำเร็จ')));
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
  //     }
  //   }
  // }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _entryService.deleteEntry(id);
        _fetchEntries();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('ลบรายการสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.red;
      case 'Deleted':
        return Colors.grey;
      case 'Posted':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header Filters ---
        Container(
          padding: const EdgeInsets.all(8.0),
          // color: Colors.grey[100],
          child: Row(
            children: [
              // // Fiscal Year
              // SizedBox(
              //   width: 100,
              //   child: DropdownButtonFormField<String>(
              //     value: _selectedFiscalYear,
              //     items: _fiscalYears.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              //     onChanged: (val) {
              //       setState(() => _selectedFiscalYear = val);
              //       _fetchData();
              //     },
              //     decoration: const InputDecoration(
              //       labelText: 'รหัสปีบัญชี',
              //       border: OutlineInputBorder(),
              //       contentPadding: EdgeInsets.all(8)),
              //   ),
              // ),
              // const SizedBox(width: 8),
              // Fiscal Year Dropdown
              SizedBox(
                width: 120, // ขยายความกว้างนิดหน่อยเผื่อชื่อยาว
                child: DropdownButtonFormField<FiscalYear>(
                  value: _selectedFiscalYear,
                  isExpanded: true, // ให้ข้อความไม่ล้น
                  items: _fiscalYears
                      .map((fy) => DropdownMenuItem(
                          value: fy,
                          child:
                              Text(fy.fyCode, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFiscalYear = val;
                        _selectedPeriod = null; // เคลียร์งวดเก่าก่อน
                        _periods = []; // เคลียร์ List งวดเก่า
                      });
                      // โหลดงวดใหม่ แล้วโหลดรายการ
                      _fetchPeriods(val.id).then((_) => _fetchEntries());
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'ปีบัญชี',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // // Period
              // SizedBox(
              //   width: 80,
              //   child: DropdownButtonFormField<String>(
              //     value: _selectedPeriod,
              //     items: _periods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              //     onChanged: (val) {
              //       setState(() => _selectedPeriod = val);
              //       _fetchData();
              //     },
              //     decoration: const InputDecoration(
              //       labelText: 'งวด',
              //       border: OutlineInputBorder(),
              //       contentPadding: EdgeInsets.all(8)),
              //   ),
              // ),
              // const SizedBox(width: 8),
              // Period Dropdown
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<PostingPeriod>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  items: _periods
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.periodNumber.toString()} (${p.periodStartDate.toLocal().day}/${p.periodStartDate.toLocal().month}/${p.periodStartDate.toLocal().year} - ${p.periodEndDate.toLocal().day}/${p.periodEndDate.toLocal().month}/${p.periodEndDate.toLocal().year})', 
                            overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedPeriod = val);
                    _fetchEntries(); // โหลดรายการใหม่ทันทีเมื่อเปลี่ยนงวด
                  },
                  decoration: const InputDecoration(
                    labelText: 'งวด',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // // Search
              // Expanded(
              //   child: TextFormField(
              //     controller: _searchCtrl,
              //     decoration: InputDecoration(
              //       labelText: 'ค้นหา (เลขที่, รายละเอียด)',
              //       border: const OutlineInputBorder(),
              //       suffixIcon: IconButton(
              //         icon: const Icon(Icons.search),
              //         onPressed: _fetchData,
              //       ),
              //       contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              //     ),
              //     onFieldSubmitted: (_) => _fetchData(),
              //   ),
              // ),
              // const SizedBox(width: 8),
              // Search
              Expanded(
                child: TextFormField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'ค้นหา (เลขที่, รายละเอียด)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _fetchEntries,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    border: const OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _fetchEntries(),
                ),
              ),
              const SizedBox(width: 8),
              // Add Button
              IconButton(
                icon:
                    const Icon(Icons.add_circle, size: 32, color: Colors.green),
                tooltip: 'เพิ่มรายการใหม่',
                onPressed: widget.onAddPressed,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // --- Data Table /List ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? const Center(child: Text('ไม่พบรายการบัญชีตามเงื่อนไข'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _entries.length,
                      // separatorBuilder: (ctx, i) => const Divider(),
                      separatorBuilder: (ctx, i) => const SizedBox(height: 2),
                      itemBuilder: (ctx, index) {
                        final item = _entries[index];
                        final textColor = _getStatusColor(item.status);

                        return Card(child: 
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(item.status),
                              child: Text(item.status[0], style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text('${item.docCode} ${item.docNo}',
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              // 'วันที่: ${item.docDate.toString().split(' ')[0]} | ${item.description}\nสถานะ: ${item.status}',
                              'วันที่: ${item.docDate.toString().split(' ')[0]} | ${item.description}',
                              style: TextStyle(color: textColor.withOpacity(0.8)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(NumberFormat("#,##0.00").format(item.totalDebitLc), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(item.status, style: TextStyle(fontSize: 10, color: _getStatusColor(item.status))),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                // IconButton(
                                //   icon: const Icon(Icons.visibility,
                                //       color: Colors.blue),
                                //   tooltip: 'ดู',
                                //   onPressed: () => widget.onEditPressed(item.id),
                                // ),
                                IconButton(
                                  icon: const Icon(Icons.visibility, 
                                      color: Colors.blue),
                                  tooltip: 'ดูรายละเอียด',
                                  onPressed: () => widget.onViewPressed(item.id),
                                ),
                                // IconButton(
                                //   icon: const Icon(Icons.edit,
                                //       color: Colors.orange),
                                //   tooltip: 'แก้ไข',
                                //   onPressed: item.status == 'Draft'
                                //       ? () => widget.onEditPressed(item.id)
                                //       : null, // Disable if not Draft
                                // ),
                                if (item.status == 'Draft')
                                  IconButton(
                                    icon: const Icon(Icons.edit, 
                                        color: Colors.orange),
                                    tooltip: 'แก้ไข',
                                    onPressed: () => widget.onEditPressed(item.id),
                                  ),
                                if (item.status == 'Draft')
                                  IconButton(
                                    icon:
                                        const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'ลบทั้งใบ',
                                    onPressed: () => _deleteEntry(item.id),
                                  ),
                              ],
                            ),
                            onTap: () => widget.onViewPressed(item.id),
                          )
                        );
                      },
                    ),
          // ListView.separated(
          //   padding: const EdgeInsets.all(8),
          //   itemCount: _entries.length,
          //   separatorBuilder: (ctx, i) => const Divider(),
          //   itemBuilder: (ctx, index) {
          //     final item = _entries[index];
          //     final textColor = _getStatusColor(item.status);

          //     return ListTile(
          //       title: Text('${item.docCode} ${item.docNo}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          //       subtitle: Text(
          //         'วันที่: ${item.docDate.toString().split(' ')[0]} | ${item.description}\nสถานะ: ${item.status}',
          //         style: TextStyle(color: textColor.withOpacity(0.8)),
          //       ),
          //       trailing: Row(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           IconButton(
          //             icon: const Icon(Icons.visibility, color: Colors.blue),
          //             tooltip: 'ดู',
          //             onPressed: () => widget.onEditPressed(item.id),
          //           ),
          //           IconButton(
          //             icon: const Icon(Icons.edit, color: Colors.orange),
          //             tooltip: 'แก้ไข',
          //             onPressed: item.status == 'Draft'
          //                 ? () => widget.onEditPressed(item.id)
          //                 : null, // Disable if not Draft
          //           ),
          //           IconButton(
          //             icon: const Icon(Icons.delete, color: Colors.red),
          //             tooltip: 'ลบทั้งใบ',
          //             onPressed: item.status == 'Draft'
          //                 ? () => _deleteEntry(item.id)
          //                 : null,
          //           ),
          //         ],
          //       ),
          //     );
          //   },
          // ),
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../models/gl_entry.dart';
// import '../screens/gl_entry_screen.dart';

// class GlEntryListScreen extends StatefulWidget {
//   const GlEntryListScreen({super.key});

//   @override
//   State<GlEntryListScreen> createState() => _GlEntryListScreenState();
// }

// class _GlEntryListScreenState extends State<GlEntryListScreen> {
//   List<GlEntryHeader> _transactions = [];
//   bool _isLoading = true;
//   final TextEditingController _searchCtrl = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _fetchTransactions();
//   }

//   Future<void> _fetchTransactions() async {
//     setState(() => _isLoading = true);
//     try {
//       final res = await http.get(
//         Uri.parse('http://localhost:3000/api/gl/transactions?search=${_searchCtrl.text}'),
//         // Add Headers with Auth
//       );
//       if (res.statusCode == 200) {
//         final List data = jsonDecode(res.body);
//         setState(() {
//           _transactions = data.map((e) => GlEntryHeader.fromJson(e)).toList();
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print(e);
//       setState(() => _isLoading = false);
//     }
//   }

//   Color _getStatusColor(String status) {
//     if (status == 'Draft') return Colors.orange;
//     if (status == 'Posted') return Colors.green;
//     return Colors.grey;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('บันทึกรายการรายวัน (GL Journal)')),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           await Navigator.push(context, MaterialPageRoute(builder: (_) => const GlEntryScreen()));
//           _fetchTransactions();
//         },
//         child: const Icon(Icons.add),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _searchCtrl,
//               decoration: InputDecoration(
//                 labelText: 'ค้นหา (เลขที่, Ref)',
//                 suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _fetchTransactions),
//                 border: const OutlineInputBorder(),
//               ),
//               onSubmitted: (_) => _fetchTransactions(),
//             ),
//           ),
//           Expanded(
//             child: _isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : ListView.builder(
//                     itemCount: _transactions.length,
//                     itemBuilder: (context, index) {
//                       final item = _transactions[index];
//                       return Card(
//                         child: ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: _getStatusColor(item.status),
//                             child: Text(item.status[0], style: const TextStyle(color: Colors.white)),
//                           ),
//                           title: Text('${item.docCode} : ${item.docNo}'),
//                           subtitle: Text('วันที่: ${item.docDate.toString().split(' ')[0]}\nRef: ${item.refNo}'),
//                           trailing: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               Text(item.totalDebit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
//                               const Icon(Icons.chevron_right),
//                             ],
//                           ),
//                           onTap: () async {
//                             await Navigator.push(
//                               context,
//                               MaterialPageRoute(builder: (_) => GlEntryScreen(transactionId: item.id))
//                             );
//                             _fetchTransactions();
//                           },
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
