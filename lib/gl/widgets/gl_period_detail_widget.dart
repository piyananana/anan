// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/services/sa_auth_service.dart';
import '../models/gl_period.dart';
import '../services/gl_period_service.dart';

class PeriodDetailWidget extends StatefulWidget {
  final Mode mode;
  final FiscalYear? selectedHead;
  final List<PostingPeriod>? selectedDetail;
  final Function(FiscalYear) onSubmitHead;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  final Function() onDetailChange; // Callback เมื่อมีการสร้าง/ลบ period
  final bool canApprove; // สิทธิ์ "อนุมัติ" — คุมปุ่มอนุมัติ/ปฏิเสธคำขอปิดงวด GL

  const PeriodDetailWidget({
    super.key,
    required this.mode,
    this.selectedHead,
    this.selectedDetail,
    required this.onSubmitHead,
    required this.onCancel,
    this.isPlaceholder = false,
    required this.onDetailChange,
    this.canApprove = true,
  });

  @override
  State<PeriodDetailWidget> createState() => PeriodDetailWidgetState();
}

class PeriodDetailWidgetState extends State<PeriodDetailWidget>
    with SingleTickerProviderStateMixin {
  FiscalYear? _selectedHead;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fiscalYearCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _numOfPeriodsController;
  late DateTime _yearStartDate;
  late DateTime _yearEndDate;
  late bool _isActive;
  List<PostingPeriod> _selectedDetail = [];
  late TabController _tabController;
  final PeriodService _detailService = PeriodService();

  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  bool _isSaving = false;
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _selectedHead = widget.selectedHead;

    _fiscalYearCodeController =
        TextEditingController(text: _selectedHead?.fyCode ?? '');
    _descriptionController =
        TextEditingController(text: _selectedHead?.description ?? '');
    // _yearStartDate = _selectedHead?.yearStartDate.toLocal() ?? DateTime.now().toLocal();
    // _yearEndDate = _selectedHead?.yearEndDate.toLocal() ??
    //     DateTime.now().add(const Duration(days: 365)).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _yearStartDate = _selectedHead?.yearStartDate ?? today;
    _yearEndDate = _selectedHead?.yearEndDate ??
        DateTime(today.year + 1, today.month, today.day)
            .subtract(const Duration(days: 1));
    _numOfPeriodsController = TextEditingController(
        text: _selectedHead?.numOfPeriods.toString() ?? '12');
    _isActive = _selectedHead?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant PeriodDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedHead != oldWidget.selectedHead) {
      _selectedHead = widget.selectedHead;

      _fiscalYearCodeController.text = _selectedHead?.fyCode ?? '';
      _descriptionController.text = _selectedHead?.description ?? '';
      // _yearStartDate = _selectedHead?.yearStartDate.toLocal() ?? DateTime.now().toLocal();
      // _yearEndDate = _selectedHead?.yearEndDate.toLocal() ??
      //     DateTime.now().add(const Duration(days: 365)).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _yearStartDate = _selectedHead?.yearStartDate ?? today;
      _yearEndDate = _selectedHead?.yearEndDate ??
          DateTime(today.year + 1, today.month, today.day)
              .subtract(const Duration(days: 1));
      _numOfPeriodsController = TextEditingController(
          text: _selectedHead?.numOfPeriods.toString() ?? '12');
      _isActive = _selectedHead?.isActive ?? true;

      // *ไม่ต้องเรียก setState() เพราะการเปลี่ยนแปลงสถานะใน didUpdateWidget จะถูกนำไปใช้ในการ build ถัดไป*
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      // กรณีเพิ่มข้อมูลใหม่ ให้ล้างฟิลด์
      _selectedHead = null;
      _selectedDetail = [];
      _fiscalYearCodeController.clear();
      _descriptionController.clear();
      // _yearStartDate = DateTime.now().toLocal();
      // _yearEndDate = DateTime.now().add(const Duration(days: 365)).toLocal();
      _yearStartDate = DateTime.now();
      _yearEndDate = DateTime.now().add(const Duration(days: 365));
      _numOfPeriodsController.clear();
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _fiscalYearCodeController.dispose();
    _descriptionController.dispose();
    _numOfPeriodsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final isEnglish = _isEnglish;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newHeader = FiscalYear(
          id: widget.selectedHead?.id ?? 0,
          fyCode: _fiscalYearCodeController.text,
          description: _descriptionController.text,
          yearStartDate: _yearStartDate,
          yearEndDate: _yearEndDate,
          numOfPeriods: int.parse(_numOfPeriodsController.text),
          isActive: _isActive,
        );
        await widget.onSubmitHead(newHeader);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    if (widget.isPlaceholder) {
      return Center(
        child: Text(
            isEnglish
                ? 'Select a fiscal year to edit or delete, or press + to add a new fiscal year'
                : 'เลือกปีบัญชีเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มปีบัญชีใหม่'),
      );
    }

    return Column(
      children: [
        // ส่วน Form (scroll ได้)
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode == Mode.view
                      ? (isEnglish ? 'View' : 'ดูข้อมูล')
                      : widget.mode == Mode.edit
                          ? (isEnglish ? 'Edit' : 'แก้ไข')
                          : (isEnglish ? 'Add New' : 'เพิ่มข้อมูลใหม่'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fiscalYearCodeController,
                        readOnly: widget.mode != Mode.add,
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Fiscal Year (B.E. or A.D.)' : 'ปีพ.ศ. หรือ ค.ศ.',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        // maxLength: 10,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          // fontSize: 12,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isEnglish ? 'Please enter the fiscal year code' : 'กรุณาป้อนรหัสปีบัญชี';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        readOnly: widget.mode == Mode.view,
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l.description,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        // maxLength: 255,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isEnglish ? 'Please enter a description' : 'กรุณาป้อนคำอธิบาย';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        title: Text('${l.status}: ${_isActive ? l.open : l.closed}'),
                        trailing: Switch(
                          value: _isActive,
                          onChanged: widget.mode == Mode.view ? null : (bool value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                const SizedBox(height: 8),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ListTile(
                      dense: true,
                      enabled: widget.mode == Mode.add || widget.selectedHead == null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        side: BorderSide(
                          color: widget.mode == Mode.view
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                        ),
                      ),
                      title: Text('${isEnglish ? 'Start Date' : 'วันที่เริ่มต้น'}: ${_dateFormat.format(_yearStartDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: widget.selectedHead == null
                          ? () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _yearStartDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100));
                              if (picked != null) {
                                setState(() {
                                  _yearStartDate = picked;
                                  if (widget.mode == Mode.add) {
                                    _yearEndDate = DateTime(picked.year + 1,
                                            picked.month, picked.day)
                                        .subtract(const Duration(days: 1));
                                    _numOfPeriodsController.text = '12';
                                  }
                                });
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      dense: true,
                      enabled: widget.mode == Mode.add || widget.selectedHead == null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        side: BorderSide(
                          color: widget.mode == Mode.view
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                        ),
                      ),
                      title: Text('${isEnglish ? 'End Date' : 'วันที่สิ้นสุด'}: ${_dateFormat.format(_yearEndDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: widget.selectedHead == null
                          ? () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _yearEndDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100));
                              if (picked != null) {
                                setState(() => _yearEndDate = picked);
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _numOfPeriodsController,
                      enabled: widget.selectedHead == null,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Number of Periods (12, 13, ...)' : 'จำนวนงวดเดือนบัญชี (12, 13, ...)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(),
                      validator: (value) {
                        if (value == null ||
                            int.tryParse(value) == null ||
                            int.tryParse(value)! <= 0) {
                          return isEnglish ? 'Please specify a valid number of periods' : 'โปรดระบุจำนวนงวดเดือนที่ถูกต้อง';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                const SizedBox(height: 8),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      isEnglish
                          ? 'Note: Start/end date and number of periods are used only for the first period generation. Please verify before saving'
                          : 'หมายเหตุ: วันที่เริ่มต้น/สิ้นสุด และจำนวนงวดเดือนใช้สร้างงวดครั้งแรกเท่านั้น โปรดตรวจสอบให้แน่ใจก่อนบันทึก',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                const SizedBox(height: 16),
                // --- Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    widget.mode == Mode.view
                        ? Container()
                        : Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _submitForm,
                              icon: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: Text(_isSaving
                                  ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                                  : widget.mode == Mode.edit
                                      ? l.save
                                      : l.add),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.cancel),
                        label: Text(l.cancel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ส่วน Tab (Expanded ได้เพราะอยู่ใน Column โดยตรง)
        const Divider(height: 1),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isEnglish ? 'Period Details' : 'รายละเอียดงวดเดือนบัญชี'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailList(isEnglish),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailList(bool isEnglish) {
    _selectedDetail = widget.selectedDetail != null ? widget.selectedDetail! : [];

    const Map<int, TableColumnWidth> colWidths = {
      0: FixedColumnWidth(44),
      1: FlexColumnWidth(2),
      2: FixedColumnWidth(90),
      3: FixedColumnWidth(90),
      4: FixedColumnWidth(90),
      5: FixedColumnWidth(90),
      6: FixedColumnWidth(90),
      7: FixedColumnWidth(80),
    };
    final borderSide = BorderSide(width: 1, color: Colors.grey.shade500);

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEnglish
                      ? 'Number of Periods = ${_selectedDetail.length}'
                      : 'จำนวนงวดเดือนบัญชี = ${_selectedDetail.length} งวด',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.mode != Mode.view)
                ElevatedButton.icon(
                  onPressed: () => _showDetailDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(isEnglish ? 'Add Special Period' : 'เพิ่มงวดเดือนพิเศษ'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Frozen header ─────────────────────────────────────────────────
        Table(
          columnWidths: colWidths,
          border: TableBorder.all(width: 1, color: Colors.grey.shade500),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                _tableHeaderCell('#'),
                _tableHeaderCell(isEnglish ? 'Name/Date' : 'ชื่อ/วันที่'),
                _tableHeaderCell(isEnglish ? 'GL Status' : 'สถานะ GL'),
                _tableHeaderCell(isEnglish ? 'AR Status' : 'สถานะ AR'),
                _tableHeaderCell(isEnglish ? 'AP Status' : 'สถานะ AP'),
                _tableHeaderCell(isEnglish ? 'CM Status' : 'สถานะ CM'),
                _tableHeaderCell(isEnglish ? 'IM Status' : 'สถานะ IM'),
                _tableHeaderCell('Actions'),
              ],
            ),
          ],
        ),
        // ── Scrollable rows ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: colWidths,
              border: TableBorder(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
                horizontalInside: borderSide,
                verticalInside: borderSide,
              ),
              children: _selectedDetail.map((period) {
                final bool isClosed = period.glStatus == 'CLOSED';
                return TableRow(children: [
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(period.periodNumber.toString(),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(period.periodName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${_dateFormat.format(period.periodStartDate)} - ${_dateFormat.format(period.periodEndDate)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.glStatus, 'GL', period, isEnglish)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.arStatus, 'AR', period, isEnglish)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.apStatus, 'AP', period, isEnglish)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.cmStatus, 'CM', period, isEnglish)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.imStatus, 'IM', period, isEnglish)),
                  )),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: Key('edit_${period.id}'),
                          icon: Icon(Icons.edit,
                              size: 18,
                              color: widget.mode == Mode.view
                                  ? Colors.grey
                                  : Colors.blue),
                          onPressed: isClosed || widget.mode == Mode.view
                              ? null
                              : () => _showDetailDialog(period: period),
                          tooltip: isEnglish
                              ? 'Edit period date/name'
                              : 'แก้ไขวันที่/ชื่องวดเดือนบัญชี',
                        ),
                        IconButton(
                          key: Key('delete_${period.id}'),
                          icon: Icon(Icons.delete,
                              size: 18,
                              color: widget.mode == Mode.view
                                  ? Colors.grey
                                  : Colors.red),
                          onPressed: isClosed || widget.mode == Mode.view
                              ? null
                              : () => _deletePeriod(period.id),
                          tooltip: isEnglish ? 'Delete period' : 'ลบงวดเดือนบัญชี',
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _showDetailDialog({PostingPeriod? period}) async {
    // กำหนดค่าเริ่มต้น
    String periodName = period?.periodName ?? '';
    DateTime startDate = period?.periodStartDate ?? _yearStartDate;
    DateTime endDate = period?.periodEndDate ?? _yearEndDate;
    // int periodNumber = period?.periodNumber ?? (widget.periods.isNotEmpty ? widget.periods.last.periodNumber + 1 : 1);
    int periodNumber = period?.periodNumber ??
        (_selectedDetail.isNotEmpty
            ? _selectedDetail.last.periodNumber + 10
            : 10);

    // หากเป็น Period ที่ถูกปิดแล้ว ไม่ควรอนุญาตให้แก้ไขวันที่
    final bool isClosed = period != null && period.glStatus != 'OPEN';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: Text(period == null
                    ? (l.isEnglish ? 'Add New Period' : 'เพิ่มงวดเดือนบัญชีใหม่')
                    : (l.isEnglish
                        ? 'Edit Period ${period.periodName}'
                        : 'แก้ไขงวดเดือนบัญชี ${period.periodName}')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: periodNumber.toString(),
                            decoration: InputDecoration(
                              labelText: l.isEnglish ? 'Period Number' : 'ลำดับงวดเดือนบัญชี',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            enabled: period == null, // ลำดับห้ามแก้ไข
                            onChanged: (v) =>
                                periodNumber = int.tryParse(v) ?? periodNumber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            initialValue: periodName,
                            decoration: InputDecoration(
                              labelText: l.isEnglish ? 'Period Name' : 'ชื่องวดเดือนบัญชี',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => periodName = v,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      // Date Pickers
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              dense: true,
                              key: Key('start_date_${period?.id ?? 'new'}'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                                side: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                  '${l.isEnglish ? 'Start Date' : 'วันที่เริ่มต้น'}: ${_dateFormat.format(startDate)}'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: isClosed
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: startDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (picked != null) {
                                        setDialogState(() {
                                          startDate = picked;
                                        });
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ListTile(
                              dense: true,
                              key: Key('end_date_${period?.id ?? 'new'}'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                                side: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                  '${l.isEnglish ? 'End Date' : 'วันที่สิ้นสุด'}: ${_dateFormat.format(endDate)}'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: isClosed
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: endDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (picked != null) {
                                        setDialogState(() {
                                          endDate = picked;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (isClosed)
                        Text(
                            l.isEnglish
                                ? 'Dates cannot be edited because the period is already closed'
                                : 'ไม่สามารถแก้ไขวันที่ได้ เนื่องจากงวดเดือนบัญชีถูกปิดแล้ว',
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.cancel)),
                  ElevatedButton(
                    onPressed: () async {
                      if (periodName.isEmpty || startDate.isAfter(endDate)) {
                        // widget.onMessage('ข้อมูลไม่ถูกต้อง: ชื่อห้ามว่าง และวันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Invalid data: name must not be empty, and start date must not be after end date'
                                : 'ข้อมูลไม่ถูกต้อง: ชื่อห้ามว่าง และวันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final newPeriod = PostingPeriod(
                        id: period?.id ?? 0,
                        fiscalYearId: widget.selectedHead!.id,
                        periodNumber: periodNumber,
                        periodName: periodName,
                        periodStartDate: startDate,
                        periodEndDate: endDate,
                        glStatus: period?.glStatus ?? 'LOCKED',
                        apStatus: period?.apStatus ?? 'LOCKED',
                        arStatus: period?.arStatus ?? 'LOCKED',
                        imStatus: period?.imStatus ?? 'LOCKED',
                        cmStatus: period?.cmStatus ?? 'LOCKED',
                      );

                      try {
                        if (period == null) {
                          await _detailService.addDetailRow(newPeriod);
                        } else {
                          await _detailService.updateDetailRow(newPeriod);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Period saved successfully'
                                : 'บันทึกงวดเดือนบัญชีสำเร็จ'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        widget.onDetailChange(); // แจ้งให้หน้าหลักโหลด Periods ใหม่
                        Navigator.of(context).pop();
                      } catch (e) {
                        // widget.onMessage('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}',);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Error saving: ${e.toString()}'
                                : 'เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: Text(period == null ? l.add : l.save),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  Widget _buildStatusChip(String status, String module, PostingPeriod period, bool isEnglish) {
    Color chipColor;
    switch (status) {
      case 'OPEN':
        chipColor = Colors.green;
        break;
      case 'LOCKED':
        chipColor = Colors.orange;
        break;
      case 'PENDING_CLOSE':
        chipColor = Colors.purple;
        break;
      case 'CLOSED':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }
    if (widget.mode == Mode.view) chipColor = Colors.grey;

    final currentUserId = AuthService().currentUser?.id;

    // Icons ใต้ chip (เฉพาะ edit mode)
    List<Widget> actionIcons = [];
    if (widget.mode != Mode.view) {
      if (module == 'GL' && status == 'PENDING_CLOSE') {
        // งวด GL ที่รออนุมัติ — แสดงปุ่มตามบทบาทของผู้ใช้ปัจจุบัน
        final isApprover = widget.canApprove &&
            period.closeApproverUserId != null &&
            currentUserId == period.closeApproverUserId;
        final isRequester = period.closeRequestedBy != null &&
            currentUserId == period.closeRequestedBy;
        if (isApprover) {
          actionIcons.add(Tooltip(
            message: isEnglish ? 'Approve Close' : 'อนุมัติปิดงวด',
            child: InkWell(
              onTap: () => _approveGlClose(period),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            ),
          ));
          actionIcons.add(Tooltip(
            message: isEnglish ? 'Reject' : 'ปฏิเสธ',
            child: InkWell(
              onTap: () => _rejectGlClose(period),
              child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
            ),
          ));
        } else if (isRequester) {
          actionIcons.add(Tooltip(
            message: isEnglish ? 'Cancel Request' : 'ยกเลิกคำขอ',
            child: InkWell(
              onTap: () => _cancelGlCloseRequest(period),
              child: const Icon(Icons.undo, color: Colors.blueGrey, size: 20),
            ),
          ));
        }
      } else if (status == 'OPEN') {
        // icon ล็อคสีส้ม → LOCKED
        actionIcons.add(Tooltip(
          message: isEnglish ? 'Lock (LOCKED)' : 'ล็อค (LOCKED)',
          child: InkWell(
            onTap: () => _confirmSoftClose(period, module),
            child: const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
          ),
        ));
        // icon ปิดสีแดง → CLOSED (GL ต้องขออนุมัติก่อน, โมดูลอื่น 2-step credential)
        actionIcons.add(Tooltip(
          message: module == 'GL'
              ? (isEnglish ? 'Request Close Period' : 'ขอปิดงวด')
              : (isEnglish ? 'Close Period (CLOSED)' : 'ปิดงวด (CLOSED)'),
          child: InkWell(
            onTap: () => module == 'GL'
                ? _confirmRequestGlClose(period)
                : _confirmClose(period, module, 'OPEN'),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
          ),
        ));
      } else if (status == 'LOCKED') {
        // icon ปลดล็อคสีเขียว → OPEN
        actionIcons.add(Tooltip(
          message: isEnglish ? 'Unlock (OPEN)' : 'ปลดล็อค (OPEN)',
          child: InkWell(
            onTap: () => _updateStatus(period, module, 'OPEN'),
            child: const Icon(Icons.lock_open_outlined, color: Colors.green, size: 20),
          ),
        ));
        // icon ปิดสีแดง → CLOSED (GL ต้องขออนุมัติก่อน, โมดูลอื่น 2-step credential)
        actionIcons.add(Tooltip(
          message: module == 'GL'
              ? (isEnglish ? 'Request Close Period' : 'ขอปิดงวด')
              : (isEnglish ? 'Close Period (CLOSED)' : 'ปิดงวด (CLOSED)'),
          child: InkWell(
            onTap: () => module == 'GL'
                ? _confirmRequestGlClose(period)
                : _confirmClose(period, module, 'LOCKED'),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
          ),
        ));
      }
      // CLOSED → ไม่มี icon
    }

    String chipLabel = status.replaceAll('_', ' ');
    if (status == 'PENDING_CLOSE') {
      chipLabel = isEnglish ? 'PENDING' : 'รออนุมัติ';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(
            chipLabel,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: chipColor,
          padding: const EdgeInsets.all(2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (module == 'GL' && status == 'PENDING_CLOSE' && period.closeApproverUserName != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              isEnglish
                  ? 'Approver: ${period.closeApproverUserName}'
                  : 'ผู้อนุมัติ: ${period.closeApproverUserName}',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        if (actionIcons.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              actionIcons[0],
              if (actionIcons.length > 1) ...[
                const SizedBox(width: 4),
                actionIcons[1],
              ],
            ],
          ),
      ],
    );
  }

  void _deletePeriod(int periodId) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.confirmDelete),
            content: Text(
                l.isEnglish
                    ? 'Are you sure you want to delete this period? (Only periods not yet posted can be deleted)'
                    : 'คุณแน่ใจว่าต้องการลบงวดเดือนบัญชีนี้หรือไม่? (ลบได้เฉพาะรอบที่ยังไม่ลงบัญชี)'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.cancel)),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l.delete)),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        // await _detailService.deletePeriod(periodId);
        await _detailService.deleteDetailRow(periodId);
        // widget.onMessage('ลบงวดเดือนบัญชีสำเร็จ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isEnglish ? 'Period deleted successfully' : 'ลบงวดเดือนบัญชีสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDetailChange();
      } catch (e) {
        // widget.onMessage('ไม่สามารถลบได้: ${e.toString()}',);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isEnglish ? 'Unable to delete: ${e.toString()}' : 'ไม่สามารถลบได้: ${e.toString()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ปิดงวด (CLOSED) — 2-step: warning → credential approval
  Future<void> _confirmClose(
      PostingPeriod period, String module, String fromStatus) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    int step = 1;
    final confirmCtrl = TextEditingController(); // username
    final pwCtrl = TextEditingController();      // password
    bool pwVisible = false;
    String approvalError = '';
    bool isApproving = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          if (step == 1) {
            return AlertDialog(
              title: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                const SizedBox(width: 8),
                Text(l.isEnglish ? 'Warning: Close Period' : 'คำเตือน: ปิดงวดบัญชี'),
              ]),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l.isEnglish ? 'Period' : 'งวดเดือนบัญชี'}: ${period.periodName}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${l.isEnglish ? 'Module' : 'โมดูล'}: $module'),
                          const SizedBox(height: 2),
                          Text('${l.isEnglish ? 'Status change' : 'การเปลี่ยนสถานะ'}: $fromStatus → CLOSED',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _warningRow(Icons.lock, l.isEnglish
                        ? 'Entries in this period can no longer be recorded/edited'
                        : 'ไม่สามารถบันทึก/แก้ไขรายการในงวดนี้ได้อีก'),
                    _warningRow(Icons.block, l.isEnglish
                        ? 'The status cannot be reverted back to OPEN or LOCKED'
                        : 'ไม่สามารถย้อนสถานะกลับเป็น OPEN หรือ LOCKED ได้'),
                    _warningRow(Icons.people_outline, l.isEnglish
                        ? 'No user will be able to post entries in this period'
                        : 'ผู้ใช้ทุกคนจะไม่สามารถลงรายการในงวดนี้ได้'),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.isEnglish
                                ? 'Please make sure all entries are recorded and reconciled\nbefore closing this period'
                                : 'ควรตรวจสอบให้แน่ใจว่าลงรายการและกระทบยอดครบถ้วนแล้ว\nก่อนดำเนินการปิดงวดบัญชี',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.cancel),
                ),
                ElevatedButton.icon(
                  onPressed: () => setDs(() => step = 2),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(l.isEnglish ? 'Continue' : 'ดำเนินการต่อ'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            );
          }

          // ── Step 2: credential approval ─────────────────────────────────
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.verified_user, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Text(l.isEnglish ? 'Period Closing Approver' : 'ผู้อนุมัติการปิดงวดบัญชี'),
            ]),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isEnglish
                        ? 'Please have an authorized approver fill in the details to confirm\n(a user belonging to a group with permission to approve period closing)'
                        : 'โปรดให้ผู้มีสิทธิ์อนุมัติกรอกข้อมูลเพื่อยืนยัน\n(ผู้ใช้ที่อยู่ในกลุ่มที่มีสิทธิ์อนุมัติการปิดงวดบัญชี)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l.isEnglish ? 'Username' : 'ชื่อผู้ใช้',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDs(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pwCtrl,
                    obscureText: !pwVisible,
                    decoration: InputDecoration(
                      labelText: l.isEnglish ? 'Password' : 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(pwVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDs(() => pwVisible = !pwVisible),
                      ),
                    ),
                    onChanged: (_) => setDs(() {}),
                  ),
                  if (approvalError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          approvalError,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isApproving ? null : () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel),
              ),
              ElevatedButton.icon(
                onPressed: (confirmCtrl.text.trim().isNotEmpty &&
                        pwCtrl.text.isNotEmpty &&
                        !isApproving)
                    ? () async {
                        setDs(() {
                          isApproving = true;
                          approvalError = '';
                        });
                        try {
                          await _detailService.verifyCloseApprover(
                              confirmCtrl.text.trim(), pwCtrl.text);
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          setDs(() {
                            approvalError = e.toString().replaceFirst('Exception: ', '');
                            isApproving = false;
                          });
                        }
                      }
                    : null,
                icon: isApproving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock, size: 16),
                label: Text(l.isEnglish ? 'Confirm Close Period' : 'ยืนยันปิดงวด'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          );
        },
      ),
    );

    confirmCtrl.dispose();
    pwCtrl.dispose();
    if (confirmed == true) {
      _updateStatus(period, module, 'CLOSED');
    }
  }

  Widget _warningRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Future<void> _confirmSoftClose(PostingPeriod period, String module) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.isEnglish ? 'Confirm Status Change' : 'ยืนยันการเปลี่ยนสถานะ'),
        content: Text(
          l.isEnglish
              ? 'Changing status from OPEN to LOCKED is for data review purposes. '
                  'It will prevent further entries from being added to this period and module, '
                  'but the status can still be reverted back to OPEN.'
              : 'การเปลี่ยนสถานะ OPEN เป็น LOCKED เพื่อการตรวจสอบข้อมูล '
                  'จะทำให้เพิ่มเติมรายการของงวดและโมดูลนี้ไม่ได้ '
                  'แต่ยังสามารถย้อนสถานะกลับมา OPEN ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateStatus(period, module, 'LOCKED');
    }
  }

  void _updateStatus(
      PostingPeriod period, String module, String newStatus) async {
    final isEnglish = _isEnglish;
    try {
      // await _service.updatePeriodStatus(period.id, module, newStatus, _currentUserId);
      await _detailService.updateStatusDetailRow(period.id, module, newStatus);
      // widget.onMessage('อัปเดตสถานะ ${module} เป็น ${newStatus} สำเร็จ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Updated $module status to $newStatus successfully'
              : 'อัปเดตสถานะ $module เป็น $newStatus สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onDetailChange();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── GL Period Close Approval Workflow ──────────────────────────────────

  // ขอปิดงวดบัญชี GL — แทนที่ flow รหัสผ่านเดิม ด้วยการส่งคำขอไปยังผู้อนุมัติที่ตั้งค่าไว้
  Future<void> _confirmRequestGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Request to Close Period' : 'ขออนุมัติปิดงวดบัญชี'),
        ]),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${isEnglish ? 'Period' : 'งวดเดือนบัญชี'}: ${period.periodName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isEnglish
                          ? 'Closing a GL period is irreversible once approved'
                          : 'การปิดงวดบัญชี GL ไม่สามารถย้อนกลับได้เมื่อได้รับการอนุมัติแล้ว',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _warningRow(Icons.playlist_add_check, isEnglish
                  ? 'AP, AR, CM and IM periods must all be CLOSED first'
                  : 'งวดบัญชีของ AP, AR, CM และ IM ต้องถูกปิด (CLOSED) ให้ครบก่อน'),
              _warningRow(Icons.fact_check_outlined, isEnglish
                  ? 'There must be no Draft GL entries remaining in this period'
                  : 'ต้องไม่มีรายการบัญชี GL ที่ยังอยู่ในสถานะ Draft ค้างอยู่'),
              _warningRow(Icons.how_to_reg, isEnglish
                  ? 'This request will be sent to the configured approver for confirmation'
                  : 'คำขอนี้จะถูกส่งไปยังผู้อนุมัติที่ตั้งค่าไว้เพื่อยืนยันการปิดงวด'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send, size: 16),
            label: Text(isEnglish ? 'Send Request' : 'ส่งคำขอ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _detailService.requestClose(period.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ??
            (isEnglish ? 'Close request sent successfully' : 'ส่งคำขอปิดงวดสำเร็จ')),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _approveGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Approve Period Close' : 'อนุมัติปิดงวดบัญชี'),
        content: Text(isEnglish
            ? 'Approve closing period "${period.periodName}"? This action cannot be undone.'
            : 'ยืนยันอนุมัติปิดงวดบัญชี "${period.periodName}" ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _detailService.approveCloseRequest(period.closeRequestId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Period closed successfully' : 'อนุมัติปิดงวดบัญชีสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _rejectGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final remarksCtrl = TextEditingController();
    String? errorText;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDs) => AlertDialog(
        title: Text(isEnglish ? 'Reject Close Request' : 'ปฏิเสธคำขอปิดงวด'),
        content: TextField(
          controller: remarksCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isEnglish ? 'Reason (required)' : 'เหตุผล (จำเป็น)',
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: errorText,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () {
              if (remarksCtrl.text.trim().isEmpty) {
                setDs(() => errorText = isEnglish ? 'Required' : 'กรุณาระบุ');
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isEnglish ? 'Reject' : 'ปฏิเสธ'),
          ),
        ],
      )),
    );
    final remarks = remarksCtrl.text.trim();
    remarksCtrl.dispose();
    if (confirm != true) return;
    try {
      await _detailService.rejectCloseRequest(period.closeRequestId!, remarks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Request rejected' : 'ปฏิเสธคำขอสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _cancelGlCloseRequest(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Cancel Close Request' : 'ยกเลิกคำขอปิดงวด'),
        content: Text(isEnglish
            ? 'Cancel the pending close request for "${period.periodName}"?'
            : 'ยกเลิกคำขอปิดงวดบัญชี "${period.periodName}" ที่รออนุมัติอยู่ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _detailService.cancelCloseRequest(period.closeRequestId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Request cancelled' : 'ยกเลิกคำขอสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }
}
