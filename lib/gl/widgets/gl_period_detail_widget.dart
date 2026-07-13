// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
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

  const PeriodDetailWidget({
    super.key,
    required this.mode,
    this.selectedHead,
    this.selectedDetail,
    required this.onSubmitHead,
    required this.onCancel,
    this.isPlaceholder = false,
    required this.onDetailChange,
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
              content: Text('เกิดข้อผิดพลาด: $e'),
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
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกปีบัญชีเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มปีบัญชีใหม่'),
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
                      ? 'ดูข้อมูล'
                      : widget.mode == Mode.edit
                          ? 'แก้ไข'
                          : 'เพิ่มข้อมูลใหม่',
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
                        decoration: const InputDecoration(
                          labelText: 'ปีพ.ศ. หรือ ค.ศ.',
                          border: OutlineInputBorder(),
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
                            return 'กรุณาป้อนรหัสปีบัญชี';
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
                        decoration: const InputDecoration(
                          labelText: 'อธิบาย',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        // maxLength: 255,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาป้อนคำอธิบาย';
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
                        title: Text('สถานะ: ${_isActive ? 'เปิด' : 'ปิด'}'),
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
                      title: Text('วันที่เริ่มต้น: ${_dateFormat.format(_yearStartDate)}'),
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
                      title: Text('วันที่สิ้นสุด: ${_dateFormat.format(_yearEndDate)}'),
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
                      decoration: const InputDecoration(
                        labelText: 'จำนวนงวดเดือนบัญชี (12, 13, ...)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(),
                      validator: (value) {
                        if (value == null ||
                            int.tryParse(value) == null ||
                            int.tryParse(value)! <= 0) {
                          return 'โปรดระบุจำนวนงวดเดือนที่ถูกต้อง';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                const SizedBox(height: 8),
                if (widget.mode == Mode.add || widget.selectedHead == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                      'หมายเหตุ: วันที่เริ่มต้น/สิ้นสุด และจำนวนงวดเดือนใช้สร้างงวดครั้งแรกเท่านั้น โปรดตรวจสอบให้แน่ใจก่อนบันทึก',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
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
                                  ? 'กำลังบันทึก...'
                                  : widget.mode == Mode.edit
                                      ? 'บันทึก'
                                      : 'เพิ่ม'),
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
          tabs: const [
            Tab(text: 'รายละเอียดงวดเดือนบัญชี'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailList() {
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
                  'จำนวนงวดเดือนบัญชี = ${_selectedDetail.length} งวด',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.mode != Mode.view)
                ElevatedButton.icon(
                  onPressed: () => _showDetailDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มงวดเดือนพิเศษ'),
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
                _tableHeaderCell('ชื่อ/วันที่'),
                _tableHeaderCell('สถานะ GL'),
                _tableHeaderCell('สถานะ AR'),
                _tableHeaderCell('สถานะ AP'),
                _tableHeaderCell('สถานะ CM'),
                _tableHeaderCell('สถานะ IM'),
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
                    child: Center(child: _buildStatusChip(period.glStatus, 'GL', period)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.arStatus, 'AR', period)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.apStatus, 'AP', period)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.cmStatus, 'CM', period)),
                  )),
                  TableCell(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: _buildStatusChip(period.imStatus, 'IM', period)),
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
                          tooltip: 'แก้ไขวันที่/ชื่องวดเดือนบัญชี',
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
                          tooltip: 'ลบงวดเดือนบัญชี',
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
                    ? 'เพิ่มงวดเดือนบัญชีใหม่'
                    : 'แก้ไขงวดเดือนบัญชี ${period.periodName}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: periodNumber.toString(),
                            decoration: const InputDecoration(
                              labelText: 'ลำดับงวดเดือนบัญชี',
                              border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'ชื่องวดเดือนบัญชี',
                              border: OutlineInputBorder(),
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
                                  // 'วันที่เริ่มต้น: ${_dateFormat.format(startDate.toLocal())}'),
                                  'วันที่เริ่มต้น: ${_dateFormat.format(startDate)}'),
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
                                  // 'วันที่สิ้นสุด: ${_dateFormat.format(endDate.toLocal())}'),
                                  'วันที่สิ้นสุด: ${_dateFormat.format(endDate)}'),
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
                        const Text(
                            'ไม่สามารถแก้ไขวันที่ได้ เนื่องจากงวดเดือนบัญชีถูกปิดแล้ว',
                            style: TextStyle(color: Colors.red)),
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
                          const SnackBar(
                            content: Text(
                                'ข้อมูลไม่ถูกต้อง: ชื่อห้ามว่าง และวันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด'),
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
                          const SnackBar(
                            content: Text('บันทึกงวดเดือนบัญชีสำเร็จ'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        widget.onDetailChange(); // แจ้งให้หน้าหลักโหลด Periods ใหม่
                        Navigator.of(context).pop();
                      } catch (e) {
                        // widget.onMessage('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}',);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
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

  Widget _buildStatusChip(String status, String module, PostingPeriod period) {
    Color chipColor;
    switch (status) {
      case 'OPEN':
        chipColor = Colors.green;
        break;
      case 'LOCKED':
        chipColor = Colors.orange;
        break;
      case 'CLOSED':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }
    if (widget.mode == Mode.view) chipColor = Colors.grey;

    // Icons ใต้ chip (เฉพาะ edit mode)
    List<Widget> actionIcons = [];
    if (widget.mode != Mode.view) {
      if (status == 'OPEN') {
        // icon ล็อคสีส้ม → LOCKED
        actionIcons.add(Tooltip(
          message: 'ล็อค (LOCKED)',
          child: InkWell(
            onTap: () => _confirmSoftClose(period, module),
            child: const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
          ),
        ));
        // icon ปิดสีแดง → CLOSED (2-step approval)
        actionIcons.add(Tooltip(
          message: 'ปิดงวด (CLOSED)',
          child: InkWell(
            onTap: () => _confirmClose(period, module, 'OPEN'),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
          ),
        ));
      } else if (status == 'LOCKED') {
        // icon ปลดล็อคสีเขียว → OPEN
        actionIcons.add(Tooltip(
          message: 'ปลดล็อค (OPEN)',
          child: InkWell(
            onTap: () => _updateStatus(period, module, 'OPEN'),
            child: const Icon(Icons.lock_open_outlined, color: Colors.green, size: 20),
          ),
        ));
        // icon ปิดสีแดง → CLOSED (2-step approval)
        actionIcons.add(Tooltip(
          message: 'ปิดงวด (CLOSED)',
          child: InkWell(
            onTap: () => _confirmClose(period, module, 'LOCKED'),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
          ),
        ));
      }
      // CLOSED → ไม่มี icon
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(
            status.replaceAll('_', ' '),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: chipColor,
          padding: const EdgeInsets.all(2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (actionIcons.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              actionIcons[0],
              const SizedBox(width: 4),
              actionIcons[1],
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
            title: const Text('ยืนยันการลบ'),
            content: const Text(
                'คุณแน่ใจว่าต้องการลบงวดเดือนบัญชีนี้หรือไม่? (ลบได้เฉพาะรอบที่ยังไม่ลงบัญชี)'),
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
          const SnackBar(
            content: Text('ลบงวดเดือนบัญชีสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDetailChange();
      } catch (e) {
        // widget.onMessage('ไม่สามารถลบได้: ${e.toString()}',);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถลบได้: ${e.toString()}'),
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
                const Text('คำเตือน: ปิดงวดบัญชี'),
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
                          Text('งวดเดือนบัญชี: ${period.periodName}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('โมดูล: $module'),
                          const SizedBox(height: 2),
                          Text('การเปลี่ยนสถานะ: $fromStatus → CLOSED',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _warningRow(Icons.lock, 'ไม่สามารถบันทึก/แก้ไขรายการในงวดนี้ได้อีก'),
                    _warningRow(Icons.block, 'ไม่สามารถย้อนสถานะกลับเป็น OPEN หรือ LOCKED ได้'),
                    _warningRow(Icons.people_outline, 'ผู้ใช้ทุกคนจะไม่สามารถลงรายการในงวดนี้ได้'),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ควรตรวจสอบให้แน่ใจว่าลงรายการและกระทบยอดครบถ้วนแล้ว\nก่อนดำเนินการปิดงวดบัญชี',
                            style: TextStyle(fontSize: 12),
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
                  label: const Text('ดำเนินการต่อ'),
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
              const Text('ผู้อนุมัติการปิดงวดบัญชี'),
            ]),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'โปรดให้ผู้มีสิทธิ์อนุมัติกรอกข้อมูลเพื่อยืนยัน\n(ผู้ใช้ที่อยู่ในกลุ่มที่มีสิทธิ์อนุมัติการปิดงวดบัญชี)',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDs(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pwCtrl,
                    obscureText: !pwVisible,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
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
                label: const Text('ยืนยันปิดงวด'),
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
        title: const Text('ยืนยันการเปลี่ยนสถานะ'),
        content: const Text(
          'การเปลี่ยนสถานะ OPEN เป็น LOCKED เพื่อการตรวจสอบข้อมูล '
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
    try {
      // await _service.updatePeriodStatus(period.id, module, newStatus, _currentUserId);
      await _detailService.updateStatusDetailRow(period.id, module, newStatus);
      // widget.onMessage('อัปเดตสถานะ ${module} เป็น ${newStatus} สำเร็จ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตสถานะ $module เป็น $newStatus สำเร็จ'),
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
}
