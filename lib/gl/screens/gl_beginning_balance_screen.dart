import 'package:anan/gl/models/period.dart';
import 'package:anan/gl/services/period_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../cd/models/branch.dart';
import '../../cd/models/business_unit.dart';
import '../../cd/models/currency.dart';
import '../../cd/models/project.dart';
import '../../cd/services/branch_service.dart';
import '../../cd/services/business_unit_service.dart';
import '../../cd/services/currency_service.dart';
import '../../cd/services/project_service.dart';
import '../models/account.dart'; // import model ของคุณ
import '../services/account_service.dart'; // import service ของคุณ
import '../models/gl_beginning_balance.dart';
import '../services/gl_beginning_balance_service.dart';

// --- Helper Model สำหรับจัดการ State ในหน้าจอนี้ ---
class AccountRowData {
  final Account account;
  double totalDr; // ยอดรวมที่จะแสดงบนบรรทัด
  double totalCr;
  bool isExpanded;

  // เก็บรายการย่อย (สำหรับกรณี Account ที่มี BusinessUnit/Branch/Project)
  List<GlBeginningBalance> details;

  AccountRowData({
    required this.account,
    this.totalDr = 0.0,
    this.totalCr = 0.0,
    this.isExpanded = true,
    this.details = const [],
  });
}

class GlBeginningBalanceScreen extends StatefulWidget {
  const GlBeginningBalanceScreen({super.key});

  @override
  State<GlBeginningBalanceScreen> createState() =>
      _GlBeginningBalanceScreenState();
}

class _GlBeginningBalanceScreenState extends State<GlBeginningBalanceScreen>
    with AutomaticKeepAliveClientMixin {
  final GlBeginningBalanceService _balanceService = GlBeginningBalanceService();
  final PeriodService periodService = PeriodService();
  final AccountService _accountService = AccountService();
  final BusinessUnitService _buService = BusinessUnitService();
  final ProjectService _projectService = ProjectService();
  final BranchService _branchService = BranchService();
  final CurrencyService _currencyService = CurrencyService(); // Add Service

  List<Account> _allAccounts = [];
  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _postingPeriods = [];
  List<BusinessUnit> _businessUnits = []; // ตัวอย่างข้อมูล
  List<Project> _projects = [];
  List<Branch> _branches = [];
  List<Currency> _currencies = []; // Add Currencies List
  String _baseCurrency = 'THB'; // Add Base Currency Code

  // String _selectedFiscalYear = DateTime.now().year.toString();
  int _fiscalYearId = 0;
  String _fiscalYearCode = '';
  int _postingPeriodId = 0; // สมมติใช้ 0 เป็นค่าเริ่มต้น
  int _postingPeriodNumber = 0;
  bool _isLoading = false;

  // เก็บข้อมูลทั้งหมด Map ด้วย AccountId
  final Map<int, AccountRowData> _rowMap = {};
  List<Account> _rootAccounts = []; // เก็บเฉพาะ Root ไว้เริ่มวาด Tree

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // _loadData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // โหลด Chart of Accounts
      // final accountService =
      //     Provider.of<AccountService>(context, listen: false);
      _allAccounts = await _accountService.fetchRows(); // หรือ getAllAccounts()
      _businessUnits = await _buService.fetchRows();
      _projects = await _projectService.fetchRows();
      _branches = await _branchService.fetchRows();
      _currencies = await _currencyService.fetchActiveRows();

      // โหลด Fiscal Years
      _fiscalYears = await periodService.fetchFiscalYears();
      if (_fiscalYears.isNotEmpty) {
        final fy = _fiscalYears.firstWhere((fy) => fy.isActive == true,
            orElse: () => _fiscalYears[_fiscalYears.length - 1]);
        _fiscalYearId = fy.id;
        _fiscalYearCode = fy.fyCode;

        // โหลด Posting Periods ของปีนั้น
        _postingPeriods = await periodService
            .fetchPostingPeriodsByFiscalYearId(_fiscalYearId);
        if (_postingPeriods.isNotEmpty) {
          final pp = _postingPeriods.firstWhere((pp) => (pp.glStatus == 'OPEN'),
              orElse: () => _postingPeriods[0]);
          _postingPeriodId = pp.id;
          _postingPeriodNumber = pp.periodNumber;
        }
      }
      if (_currencies.isNotEmpty) {
        _baseCurrency = _getBaseCurrency();
      }
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getBaseCurrency() {
    final item = _currencies.firstWhere((e) => e.baseCurrencyFlag == true,
        orElse: () => Currency(
            id: 0,
            isActive: true,
            currencyCode: 'THB',
            currencyNameThai: '',
            currencyNameEng: '',
            baseRate: 1,
            baseCurrencyFlag: true,
            numOfDecimal: 2));
    return item.currencyCode;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // // 1. โหลด Chart of Accounts
      // final accountService = Provider.of<AccountService>(context, listen: false);
      // // สมมติว่า accountService.fetchRows() คืนค่า List<Account> ทั้งหมด
      // final allAccounts = await accountService.fetchRows(); // หรือ getAllAccounts()

      // // 2. โหลด Fiscal Years & Posting Periods
      // final periodService = Provider.of<PeriodService>(context, listen: false);
      // _fiscalYears = await periodService.fetchFiscalYears();
      // if (_fiscalYears.isNotEmpty) {
      //   final fy = _fiscalYears.firstWhere((fy) => fy.isActive == true, orElse: () => _fiscalYears[_fiscalYears.length - 1]);
      //   _fiscalYearId = fy.id;
      //   _fiscalYearCode = fy.fyCode;
      //   _postingPeriods = await periodService.fetchPostingPeriodsByFiscalYearId(_fiscalYearId);
      //   if (_postingPeriods.isNotEmpty) {
      //     final pp = _postingPeriods.firstWhere((pp) => (pp.glStatus == 'OPEN'), orElse: () => _postingPeriods[0]);
      //     _postingPeriodId = pp.id;
      //     _postingPeriodNumber = pp.periodNumber;
      //   }
      // }

      // 3. โหลด Balances ของปีที่เลือก
      // final existingBalances = await _balanceService.fetchByYear(_selectedFiscalYear);
      // final existingBalances = await _balanceService.fetchByYearId(_fiscalYearId);
      final existingBalances =
          await _balanceService.fetchByPeriodId(_postingPeriodId);

      // 4. เตรียม Data Structure
      _rowMap.clear();
      _rootAccounts.clear();

      // 4.1 สร้าง RowData รอไว้
      for (var acc in _allAccounts) {
        _rowMap[acc.id] = AccountRowData(account: acc, details: []);
      }

      // 4.2 หา Root Nodes
      _rootAccounts = _allAccounts.where((a) => a.parentId == null).toList();

      // 4.3 เอา existingBalances มาหยอดใส่ _rowMap
      for (var bal in existingBalances) {
        if (_rowMap.containsKey(bal.accountId)) {
          final row = _rowMap[bal.accountId]!;
          // ถ้ามีรายละเอียด Branch/Project ก็เก็บเข้า details
          row.details.add(bal);
        }
      }

      // 3.4 ถ้าบัญชีไหนไม่มี details เลย ให้สร้าง Default ไว้ 1 อัน (เพื่อรองรับการกรอกแบบ simple)
      for (var row in _rowMap.values) {
        if (row.account.isControlAccount && row.details.isEmpty) {
          row.details.add(GlBeginningBalance(
            postingPeriodId: _postingPeriodId,
            accountId: row.account.id,
          ));
        }
      }

      // 4. คำนวณยอดรวม (Roll-up)
      _recalculateRollup();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Logic: Roll-up Calculation ---
  void _recalculateRollup() {
    // รีเซ็ตยอด Header เป็น 0 ก่อนคำนวณใหม่
    for (var row in _rowMap.values) {
      // เคลียร์ยอดรวมก่อน (sum from details)
      double sumDetailsDr = 0;
      double sumDetailsCr = 0;

      if (row.account.isControlAccount) {
        // ถ้าเป็น Control Account ให้รวมยอดจาก details ตัวเอง
        for (var d in row.details) {
          sumDetailsDr += d.amountDr;
          sumDetailsCr += d.amountCr;
        }
        row.totalDr = sumDetailsDr;
        row.totalCr = sumDetailsCr;
      } else {
        // ถ้าเป็น Header Account รีเซ็ตเป็น 0 รอรับจากลูก
        row.totalDr = 0;
        row.totalCr = 0;
      }
    }

    // คำนวณจากล่างขึ้นบน หรือ ใช้ Recursive จากบนลงล่าง
    // ในที่นี้ใช้ Recursive จาก Root ลงไปหาลูก แล้วส่งค่ากลับขึ้นมาบวก
    for (var root in _rootAccounts) {
      _calculateNode(root);
    }
  }

  // ฟังก์ชัน Recursive คืนค่า (Dr, Cr) ของ Node นั้นๆ
  (double, double) _calculateNode(Account acc) {
    final row = _rowMap[acc.id]!;

    if (row.account.isControlAccount) {
      return (row.totalDr, row.totalCr);
    } else {
      double sumDr = 0;
      double sumCr = 0;

      // หาบัญชีลูก
      final children = _rowMap.values
          .where((r) => r.account.parentId == acc.id)
          .map((r) => r.account);

      for (var child in children) {
        final (childDr, childCr) = _calculateNode(child);
        sumDr += childDr;
        sumCr += childCr;
      }

      row.totalDr = sumDr;
      row.totalCr = sumCr;
      return (sumDr, sumCr);
    }
  }

  // --- Logic: Save ---
  Future<void> _save() async {
    // รวบรวมข้อมูลที่จะ Save เฉพาะ Control Accounts
    List<GlBeginningBalance> toSave = [];

    for (var row in _rowMap.values) {
      if (row.account.isControlAccount) {
        toSave.addAll(row.details);
      }
    }

    try {
      await _balanceService.saveBeginningBalances(_postingPeriodId, toSave);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  // Widget Helper สำหรับ Text สีเทาใต้ Field
  Widget _buildUnderlineText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // คำนวณ Grand Total
    double grandTotalDr = 0;
    double grandTotalCr = 0;
    for (var root in _rootAccounts) {
      grandTotalDr += _rowMap[root.id]?.totalDr ?? 0;
      grandTotalCr += _rowMap[root.id]?.totalCr ?? 0;
    }
    double diff = grandTotalDr - grandTotalCr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ยอดบัญชีคงเหลือยกมา (Beginning Balance)'),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _loadInitialData();
                _loadData();
              });
            },
            tooltip: 'โหลดข้อมูลใหม่',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            // onPressed: (diff.abs() < 0.01)
            //     ? _save
            //     : null, // Save ได้เมื่อดุลลงตัว (หรือจะยอมให้ Save ก่อนก็ได้แล้วแต่ Business Rule)
            onPressed: _save,
            tooltip: diff.abs() >= 0.01
                ? 'ยอดเดบิตและเครดิตควรเท่ากันก่อนบันทึก'
                : 'บันทึก',
          )
        ],
      ),
      body: Column(
        children: [
          // Filter & Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                // const Text('ปีบัญชี: '),
                // DropdownButton<String>(
                //   value: _selectedFiscalYear,
                //   underline: const SizedBox(),
                //   items: ['2566', '2567', '2568'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                //   onChanged: (v) {
                //     if (v != null) {
                //       setState(() => _selectedFiscalYear = v);
                //       _loadData();
                //     }
                //   },
                // ),

                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<FiscalYear>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<FiscalYear>.empty();
                          }
                          return _fiscalYears.where((fy) =>
                              fy.fyCode.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              fy.description!.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (FiscalYear option) =>
                            '${option.fyCode} - ${option.description})',
                        initialValue: TextEditingValue(text: _fiscalYearCode),
                        onSelected: (selection) async {
                          final periods = await periodService
                              .fetchPostingPeriodsByFiscalYearId(selection.id);
                          if (!mounted) return; // เช็ค mounted ก่อน setState
                          setState(() {
                            _fiscalYearId = selection.id;
                            _fiscalYearCode = selection.fyCode;
                            _postingPeriods = periods;
                            if (_postingPeriods.isNotEmpty) {
                              final pp = _postingPeriods.firstWhere(
                                  (pp) => pp.glStatus == 'OPEN',
                                  orElse: () => _postingPeriods[0]);
                              _postingPeriodId = pp.id;
                              _postingPeriodNumber = pp.periodNumber;
                            } else {
                              _postingPeriodId = 0;
                              _postingPeriodNumber = 0;
                            }
                          });
                          FocusScope.of(context).unfocus();
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != _fiscalYearCode) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text != _fiscalYearCode) {
                                controller.text = _fiscalYearCode;
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'ปีบัญชี',
                                isDense: true),
                            // enabled: !_isReadOnly,
                          );
                        },
                      ),
                      // แสดงชื่อปีบัญชีใต้ Field
                      _buildUnderlineText(_fiscalYears.isEmpty
                          ? '-'
                          : _fiscalYears
                              .firstWhere((fy) => fy.id == _fiscalYearId,
                                  orElse: () => FiscalYear(
                                      id: 0,
                                      fyCode: '',
                                      description: '-',
                                      yearStartDate: DateTime.now(),
                                      yearEndDate: DateTime.now(),
                                      numOfPeriods: 0,
                                      isActive: false))
                              .description!),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<PostingPeriod>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<PostingPeriod>.empty();
                          }
                          return _postingPeriods.where((pp) =>
                              NumberFormat("00")
                                  .format(pp.periodNumber)
                                  .toString()
                                  .contains(
                                      textEditingValue.text.toLowerCase()) ||
                              pp.periodName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (PostingPeriod option) =>
                            '${NumberFormat("00").format(option.periodNumber).toString()} - ${option.periodName})',
                        initialValue: TextEditingValue(
                            text: _postingPeriodNumber.toString()),
                        onSelected: (selection) {
                          setState(() {
                            _postingPeriodId = selection.id;
                            _postingPeriodNumber = selection.periodNumber;
                          });
                          _loadData();
                          FocusScope.of(context).unfocus();
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text !=
                              _postingPeriodNumber.toString()) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text !=
                                      NumberFormat("00")
                                          .format(_postingPeriodNumber)
                                          .toString()) {
                                controller.text = NumberFormat("00")
                                    .format(_postingPeriodNumber)
                                    .toString();
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'งวดเดือน',
                                isDense: true),
                            // enabled: !_isReadOnly,
                          );
                        },
                      ),
                      // แสดงชื่อบัญชีใต้ Field
                      _buildUnderlineText(_postingPeriods.isEmpty
                          ? '-'
                          : _postingPeriods
                              .firstWhere(
                                  (pp) =>
                                      pp.periodNumber == _postingPeriodNumber,
                                  orElse: () => PostingPeriod(
                                      id: 0,
                                      fiscalYearId: 0,
                                      periodNumber: 0,
                                      periodName: '-',
                                      glStatus: 'CLOSED',
                                      periodStartDate: DateTime.now(),
                                      periodEndDate: DateTime.now(),
                                      apStatus: '',
                                      arStatus: '',
                                      imStatus: ''))
                              .periodName),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: 
                    Text(diff == 0 ? '' : 'ผลต่าง: ${diff.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: diff.abs() < 0.01 ? Colors.grey : Colors.red,
                            fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child:   
                    Text('รวมเดบิต: ${grandTotalDr.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.blue[500], fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child:   
                    Text('รวมเครดิต: ${grandTotalCr.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.green[500], fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // Header Row
          Container(
            color: Colors.blue[800],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Expanded(
                    flex: 5,
                    child: Text('รหัส,ชื่อบัญชี',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white))),
                Expanded(
                    flex: 2,
                    child: Text('เดบิต',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white))),
                SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: Text('เครดิต',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white))),
                SizedBox(width: 40), // Space for action button
              ],
            ),
          ),

          // Tree List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _rootAccounts.length,
                    itemBuilder: (context, index) {
                      return _buildTreeNode(_rootAccounts[index], 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(Account account, int level) {
    final row = _rowMap[account.id]!;
    final children = _rowMap.values
        .where((r) => r.account.parentId == account.id)
        .map((r) => r.account)
        .toList();
    final bool hasChildren = children.isNotEmpty;
    final bool isHeader = !account.isControlAccount;

    return Column(
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() => row.isExpanded = !row.isExpanded)
              : null,
          child: Container(
            color: isHeader ? Colors.grey[50] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // 1. Indent & Name
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.only(left: level * 20.0 + 8),
                    child: Row(
                      children: [
                        if (hasChildren)
                          Icon(
                              row.isExpanded
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                              size: 20,
                              color: Colors.grey)
                        else
                          const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            '${account.accountCode} - ${account.accountNameThai}',
                            style: TextStyle(
                                fontWeight: isHeader
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Debit
                Expanded(flex: 2, child: _buildAmountCell(row, true, isHeader)),
                const SizedBox(width: 10),

                // 3. Credit
                Expanded(
                    flex: 2, child: _buildAmountCell(row, false, isHeader)),

                // 4. Detail Button
                SizedBox(
                  width: 40,
                  child: (account.costCenterRequired ||
                              account.branchRequired ||
                              account.projectRequired) &&
                          !isHeader
                      ? IconButton(
                          icon: const Icon(Icons.list, color: Colors.red),
                          onPressed: () => _showDetailDialog(row),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 0.5),

        // Render Children
        if (row.isExpanded && hasChildren)
          ...children.map((c) => _buildTreeNode(c, level + 1)),
      ],
    );
  }

  Widget _buildAmountCell(AccountRowData row, bool isDr, bool isHeader) {
    if (isHeader) {
      final val = isDr ? row.totalDr : row.totalCr;
      return Text(
        val == 0 ? '-' : val.toStringAsFixed(2),
        textAlign: TextAlign.right,
        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
      );
    }

    // ถ้าต้องการ Branch/Project ต้องห้ามแก้ตรงนี้ ให้ไปแก้ใน Dialog
    bool isLocked = row.account.costCenterRequired ||
        row.account.branchRequired ||
        row.account.projectRequired;
    if (isLocked) {
      final val = isDr ? row.totalDr : row.totalCr;
      return Text(
        val == 0 ? '-' : val.toStringAsFixed(2),
        textAlign: TextAlign.right,
        style: const TextStyle(color: Colors.grey),
      );
    }

    // กรณีปกติ แก้ไขได้เลย
    // หมายเหตุ: ตรงนี้เราแก้ที่ details[0] เพราะสร้าง placeholder ไว้แล้ว
    return TextFormField(
      style: TextStyle(color: isDr ? Colors.blue[500] : Colors.green[500]),
      initialValue: (isDr ? row.totalDr : row.totalCr) == 0
          ? ''
          : (isDr ? row.totalDr : row.totalCr).toStringAsFixed(2),
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: InputBorder.none,
          hintText: '0.00',
          hintStyle: TextStyle(
              fontSize: 12,
              color: isDr ? Colors.blue[500] : Colors.green[500])),
      onChanged: (val) {
        double newVal = double.tryParse(val.replaceAll(',', '')) ?? 0.0;

        setState(() {
          if (row.details.isEmpty) return;
          if (isDr) {
            row.details[0].amountDr = newVal;
          } else {
            row.details[0].amountCr = newVal;
          }
          // คำนวณยอดรวมใหม่ทันที
          _recalculateRollup();
        });
      },
    );
  }

  // --- Dimension Dialog ---
  void _showDetailDialog(AccountRowData row) {
    // โคลนข้อมูลไปแก้ไขใน Dialog ก่อน
    // (ในที่นี้ทำแบบง่ายคือแก้ตรงๆ แต่ถ้าจะให้ดีควร Clone list ก่อนแล้วค่อย save กลับ)

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('รายละเอียด: ${row.account.accountCode} - ${row.account.accountNameThai}'),
            content: SizedBox(
              width: 700,
              height: 400,
              child: Column(
                children: [
                  Text(
                      'กรุณาระบุ ${row.account.costCenterRequired ? 'หน่วยงาน ' : ''}${row.account.branchRequired ? 'สาขา ' : ''}${row.account.projectRequired ? 'โครงการ' : ''} จำนวนเงินเดบิตและเครดิต'),
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: row.details.length,
                      itemBuilder: (context, index) {
                        final detail = row.details[index];
                        return Row(
                          children: [
                            // // Business Unit Dropdown (Mockup)
                            // if (row.account.costCenterRequired)
                            //   Expanded(
                            //       child: Text(
                            //           'หน่วยงาน... (ID:${detail.businessUnitId})')),
                            // // Branch Dropdown (Mockup)
                            // if (row.account.branchRequired)
                            //   Expanded(
                            //       child:
                            //           Text('สาขา... (ID:${detail.branchId})')),
                            // // Project Dropdown (Mockup)
                            // if (row.account.projectRequired)
                            //   Expanded(
                            //       child: Text(
                            //           'โครงการ... (ID:${detail.projectId})')),
                            // Expanded(
                            //     child: TextFormField(
                            //   initialValue: detail.amountDr.toString(),
                            //   decoration:
                            //       const InputDecoration(labelText: 'เดบิต'),
                            //   onChanged: (v) =>
                            //       detail.amountDr = double.tryParse(v) ?? 0,
                            // )),
                            // const SizedBox(width: 8),
                            // Expanded(
                            //     child: TextFormField(
                            //   initialValue: detail.amountCr.toString(),
                            //   decoration:
                            //       const InputDecoration(labelText: 'เครดิต'),
                            //   onChanged: (v) =>
                            //       detail.amountCr = double.tryParse(v) ?? 0,
                            // )),

                            // Business Unit (หน่วยงาน)
                            if (row.account.costCenterRequired)
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Autocomplete<BusinessUnit>(
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<
                                              BusinessUnit>.empty();
                                        }
                                        return _businessUnits.where(
                                            (businessUnit) =>
                                                businessUnit.buCode
                                                    .toLowerCase()
                                                    .contains(
                                                        textEditingValue
                                                            .text
                                                            .toLowerCase()) ||
                                                businessUnit.buNameEng
                                                    .toLowerCase()
                                                    .contains(textEditingValue
                                                        .text
                                                        .toLowerCase()) ||
                                                businessUnit.buNameThai
                                                    .toLowerCase()
                                                    .contains(textEditingValue
                                                        .text
                                                        .toLowerCase()));
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: SizedBox(
                                              width: 400,
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final BusinessUnit option = options.elementAt(index);
                                                  return ListTile(
                                                    // ในรายการตัวเลือก เรายังแสดงทั้ง รหัส และ ชื่อ เพื่อให้เลือกง่าย
                                                    title: Text('${option.buCode} - ${option.buNameThai}'),
                                                    // onSelected: () => onSelected(option),
                                                    onTap: () => onSelected(option),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      // displayStringForOption: (BusinessUnit
                                      //         option) =>
                                      //     '${option.buCode} - ${option.buNameThai}(${option.buNameEng})',
                                      displayStringForOption: (BusinessUnit
                                              option) => option.buCode,
                                      initialValue: TextEditingValue(
                                          text: detail.businessUnitCode ?? ''),
                                      onSelected: (selection) {
                                        setDialogState(() {
                                          detail.businessUnitId = selection.id;
                                          detail.businessUnitCode =
                                              selection.buCode;
                                          detail.businessUnitName =
                                              selection.buNameThai;
                                        });
                                      },
                                      fieldViewBuilder: (context, controller,
                                          focusNode, onFieldSubmitted) {
                                        // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                                        if (controller.text !=
                                            detail.businessUnitCode) {
                                          controller.text =
                                              detail.businessUnitCode ?? '';
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              labelText: 'รหัสหน่วยงาน',
                                              isDense: true),
                                          enabled: true,
                                        );
                                      },
                                    ),
                                    // แสดงชื่อหน่วยงานใต้ Field
                                    _buildUnderlineText(
                                        (detail.businessUnitName?.isEmpty ??
                                                true)
                                            ? '-'
                                            : detail.businessUnitName ?? '-'),
                                  ],
                                ),
                              ),
                            if (row.account.costCenterRequired)
                              const SizedBox(width: 8),

                            // Branch (สาขา)
                            if (row.account.branchRequired)
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Autocomplete<Branch>(
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<Branch>.empty();
                                        }
                                        return _branches.where((branch) =>
                                            branch.branchCode
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            branch.branchNameEng
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            branch.branchNameThai
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()));
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: SizedBox(
                                              width: 400,
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final Branch option = options.elementAt(index);
                                                  return ListTile(
                                                    // ในรายการตัวเลือก เรายังแสดงทั้ง รหัส และ ชื่อ เพื่อให้เลือกง่าย
                                                    title: Text('${option.branchCode} - ${option.branchNameThai}'),
                                                    // onSelected: () => onSelected(option),
                                                    onTap: () => onSelected(option),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      // displayStringForOption: (Branch option) =>
                                      //     '${option.branchCode} - ${option.branchNameThai}(${option.branchNameEng})',
                                      displayStringForOption: (Branch option) => option.branchCode,
                                      initialValue: TextEditingValue(
                                          text: detail.branchCode ?? ''),
                                      onSelected: (selection) {
                                        setDialogState(() {
                                          detail.branchId = selection.id;
                                          detail.branchCode =
                                              selection.branchCode;
                                          detail.branchName =
                                              selection.branchNameThai;
                                        });
                                      },
                                      fieldViewBuilder: (context, controller,
                                          focusNode, onFieldSubmitted) {
                                        // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                                        if (controller.text !=
                                            detail.branchCode) {
                                          controller.text =
                                              detail.branchCode ?? '';
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              labelText: 'รหัสสาขา',
                                              isDense: true),
                                          enabled: true,
                                        );
                                      },
                                    ),
                                    // แสดงชื่อสาขาใต้ Field
                                    _buildUnderlineText(
                                        (detail.branchName?.isEmpty ?? true)
                                            ? '-'
                                            : detail.branchName ?? '-'),
                                  ],
                                ),
                              ),
                            if (row.account.branchRequired)
                              const SizedBox(width: 8),

                            // Project (โครงการ)
                            if (row.account.projectRequired)
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Autocomplete<Project>(
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<
                                              Project>.empty();
                                        }
                                        return _projects.where((project) =>
                                            project.projectCode
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            project.projectNameEng
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            project.projectNameThai
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()));
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: SizedBox(
                                              width: 400,
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final Project option = options.elementAt(index);
                                                  return ListTile(
                                                    // ในรายการตัวเลือก เรายังแสดงทั้ง รหัส และ ชื่อ เพื่อให้เลือกง่าย
                                                    title: Text('${option.projectCode} - ${option.projectNameThai}'),
                                                    // onSelected: () => onSelected(option),
                                                    onTap: () => onSelected(option),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      // displayStringForOption: (Project
                                      //         option) =>
                                      //     '${option.projectCode} - ${option.projectNameThai}(${option.projectNameEng})',
                                      displayStringForOption: (Project option) => option.projectCode,
                                      initialValue: TextEditingValue(
                                          text: detail.projectCode ?? ''),
                                      onSelected: (selection) {
                                        setDialogState(() {
                                          detail.projectId = selection.id;
                                          detail.projectCode =
                                              selection.projectCode;
                                          detail.projectName =
                                              selection.projectNameThai;
                                        });
                                      },
                                      fieldViewBuilder: (context, controller,
                                          focusNode, onFieldSubmitted) {
                                        // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                                        if (controller.text !=
                                            detail.projectCode) {
                                          controller.text =
                                              detail.projectCode ?? '';
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              labelText: 'รหัสโครงการ',
                                              isDense: true),
                                          enabled: true,
                                        );
                                      },
                                    ),
                                    // แสดงชื่อโครงการใต้ Field
                                    _buildUnderlineText(
                                        (detail.projectName?.isEmpty ?? true)
                                            ? '-'
                                            : detail.projectName ?? '-'),
                                  ],
                                ),
                              ),
                            if (row.account.projectRequired)
                              const SizedBox(width: 8),

                            // Debit
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    initialValue: detail.amountDr == 0
                                        ? ''
                                        : detail.amountDr.toString(),
                                    decoration: InputDecoration(
                                        labelStyle:
                                            TextStyle(color: Colors.grey[400]),
                                        labelText: 'เดบิต ($_baseCurrency)',
                                        isDense: true),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                    enabled: true,
                                    onChanged: (val) {
                                      setState(() {
                                        detail.amountDr =
                                            double.tryParse(val) ?? 0;
                                        // _calculateTotals();
                                      });
                                    },
                                  ),
                                  _buildUnderlineText(''), // เว้นที่ไว้ไม่ให้มันกระชั้นเกินไป
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Credit
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    initialValue: detail.amountCr == 0
                                        ? ''
                                        : detail.amountCr.toString(),
                                    decoration: InputDecoration(
                                        labelStyle:
                                            TextStyle(color: Colors.grey[400]),
                                        labelText: 'เครดิต ($_baseCurrency)',
                                        isDense: true),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                    enabled: true,
                                    onChanged: (val) {
                                      setState(() {
                                        detail.amountCr =
                                            double.tryParse(val) ?? 0;
                                        // _calculateTotals();
                                      });
                                    },
                                  ),
                                  _buildUnderlineText(''), // เว้นที่ไว้ไม่ให้มันกระชั้นเกินไป
                                ],
                              ),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  row.details.removeAt(index);
                                });
                              },
                            )
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setDialogState(() {
                        row.details.add(GlBeginningBalance(
                          postingPeriodId: _postingPeriodId,
                          accountId: row.account.id,
                          // Set default branch/project if needed
                        ));
                      });
                    },
                    // child: const Text('เพิ่มรายการ'),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 4),
                          Text('เพิ่มรายการ'),
                        ],
                    )
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    // Update ยอดรวมหน้าหลัก
                    setState(() {
                      _recalculateRollup();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('ปิด'))
            ],
          );
        });
      },
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
