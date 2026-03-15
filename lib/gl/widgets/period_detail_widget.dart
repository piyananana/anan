// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/models/anan_module.dart';
import '../models/period.dart';
import '../services/period_service.dart';

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
                        label: const Text('ยกเลิก'),
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
    _selectedDetail =
        widget.selectedDetail != null ? widget.selectedDetail! : [];
    return Column(
      children: [
        const SizedBox(height: 8),
        // const Divider(),
        Row(
          children: [
            Expanded(
              child: Text('จำนวนงวดเดือนบัญชี = ${_selectedDetail.length} งวด',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      // fontSize: 16, 
                      )),
            ),
            if (widget.mode != Mode.view)
              ElevatedButton.icon(
                  onPressed: () => _showDetailDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มงวดเดือนพิเศษ')),
          ],
        ),
        // const Divider(),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Row(children: [
          Expanded(
            child: DataTable(
              border: TableBorder.all(width: 1, color: Colors.grey.shade500),
              columnSpacing: 10,
              dataRowMinHeight: 72,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(
                    label: Expanded(
                        child: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
                DataColumn(
                  label: Expanded(
                      child: Text(
                    'ชื่อ/วันที่',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  )),
                ),
                DataColumn(
                    label: Expanded(
                        child: Text(
                  'สถานะ GL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
                DataColumn(
                    label: Expanded(
                        child: Text(
                  'สถานะ AR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
                DataColumn(
                    label: Expanded(
                        child: Text(
                  'สถานะ AP',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
                DataColumn(
                    label: Expanded(
                        child: Text(
                  'สถานะ IM',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
                DataColumn(
                    label: Expanded(
                        child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ))),
              ],
              rows: _selectedDetail.map((period) {
                final bool isClosed = period.glStatus == 'CLOSED';
                return DataRow(cells: [
                  DataCell(
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text(period.periodNumber.toString())]),
                  ),
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(period.periodName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          // '${_dateFormat.format(period.periodStartDate.toLocal())} - ${_dateFormat.format(period.periodEndDate.toLocal())}',
                          '${_dateFormat.format(period.periodStartDate)} - ${_dateFormat.format(period.periodEndDate)}',
                          style: const TextStyle(fontSize: 10)),
                    ],
                  )),
                  DataCell(Center(
                      child: _buildStatusChip(period.glStatus, 'GL', period))),
                  DataCell(Center(
                      child: _buildStatusChip(period.arStatus, 'AR', period))),
                  DataCell(Center(
                      child: _buildStatusChip(period.apStatus, 'AP', period))),
                  DataCell(Center(
                      child: _buildStatusChip(period.imStatus, 'IM', period))),
                  DataCell(Row(
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
                      ])),
                ]);
              }).toList(),
            ),
          ),
        ])),
        ),
      ],
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
                      child: const Text('ยกเลิก')),
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
                    child: Text(period == null ? 'เพิ่ม' : 'บันทึก'),
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

    Widget? actionButton;
    if (widget.mode != Mode.view) {
      if (status == 'OPEN') {
        // ปุ่มกลมสีแดง → HARD CLOSE
        actionButton = Tooltip(
          message: 'ปิด',
          child: SizedBox(
            width: 22,
            height: 22,
            child: ElevatedButton(
              onPressed: () => _confirmDirectClose(period, module),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.lock, size: 12, color: Colors.white),
            ),
          ),
        );
      } else if (status == 'LOCKED') {
        // ปุ่มกลมสีเขียว → เปลี่ยนกลับเป็น OPEN
        actionButton = Tooltip(
          message: 'ปลดล็อค',
          child: SizedBox(
            width: 22,
            height: 22,
            child: ElevatedButton(
              onPressed: () => _updateStatus(period, module, 'OPEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.lock_open, size: 12, color: Colors.white),
            ),
          ),
        );
      }
    }

    // Chip คลิกได้: OPEN→SOFT_CLOSE (มี dialog), SOFT_CLOSE→HARD_CLOSE (มี dialog + ตรวจ Draft)
    VoidCallback? chipOnTap;
    if (widget.mode != Mode.view) {
      if (status == 'OPEN') {
        chipOnTap = () => _confirmSoftClose(period, module);
      } else if (status == 'LOCKED') {
        chipOnTap = () => _confirmHardClose(period, module);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: chipOnTap,
          child: Chip(
            label: Text(
              status.replaceAll('_', ' '),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            backgroundColor: chipColor,
            padding: const EdgeInsets.all(2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (actionButton != null) actionButton,
      ],
    );
  }

  void _deletePeriod(int periodId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: const Text(
                'คุณแน่ใจว่าต้องการลบงวดเดือนบัญชีนี้หรือไม่? (ลบได้เฉพาะรอบที่ยังไม่ลงบัญชี)'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ลบ')),
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

  Future<void> _confirmDirectClose(PostingPeriod period, String module) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเปลี่ยนสถานะ'),
        content: const Text(
          'การเปลี่ยนสถานะ OPEN เป็น CLOSED '
          'เพื่อป้องกันการแก้ไข/เพิ่มเติมรายการทุกกรณีของงวดและโมดูลนี้ '
          'จะไม่สามารถย้อนกลับมาได้อีก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateStatus(period, module, 'CLOSED');
    }
  }

  Future<void> _confirmSoftClose(PostingPeriod period, String module) async {
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
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateStatus(period, module, 'LOCKED');
    }
  }

  Future<void> _confirmHardClose(PostingPeriod period, String module) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเปลี่ยนสถานะ'),
        content: const Text(
          'การเปลี่ยนสถานะ LOCKED เป็น CLOSED '
          'เพื่อป้องกันการแก้ไข/เพิ่มเติมรายการทุกกรณีของงวดและโมดูลนี้ '
          'จะไม่สามารถย้อนกลับมาได้อีก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateStatus(period, module, 'CLOSED');
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
