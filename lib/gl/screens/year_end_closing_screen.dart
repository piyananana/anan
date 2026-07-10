// lib/gl/screens/year_end_closing_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/period.dart';
import '../models/year_end_closing.dart';
import '../services/period_service.dart';
import '../services/year_end_closing_service.dart';

class YearEndClosingScreen extends StatefulWidget {
  const YearEndClosingScreen({super.key});

  @override
  State<YearEndClosingScreen> createState() => _YearEndClosingScreenState();
}

class _YearEndClosingScreenState extends State<YearEndClosingScreen> {
  final YearEndClosingService _service = YearEndClosingService();
  final PeriodService _periodService = PeriodService();
  final AuthService _authService = AuthService();
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  List<FiscalYear> _fiscalYears = [];
  List<FiscalYear> _allFiscalYears = [];
  FiscalYear? _selectedYear;
  FiscalYear? _selectedNextYear;

  YearEndClosing? _closing;
  ClosingConfig? _config;

  // Periods for doc date validation
  PostingPeriod? _lastPeriod;       // last period of selected year (step 3 & 4)
  PostingPeriod? _firstNextPeriod;  // first period of next year   (step 5)

  // User-selected doc dates
  DateTime? _docDateStep3;
  DateTime? _docDateStep4;
  DateTime? _docDateStep5;

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMsg;

  // Preview data
  List<ClosingPreviewLine> _step3Preview = [];
  List<ClosingPreviewLine> _step5Preview = [];
  Map<String, dynamic>? _step4Preview;

  int _userId = 1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _authService.getAuthHeader();
      _userId = int.tryParse(headers['UserId'] ?? '1') ?? 1;

      // Load active years for closing selection, all years for next year selection
      final active = await _periodService.fetchActiveFiscalYears();
      final all = await _periodService.fetchFiscalYears();

      // Also try to load closing config
      ClosingConfig? cfg;
      try {
        cfg = await _service.fetchConfig();
      } catch (_) {
        // no config yet
      }

      setState(() {
        _fiscalYears = active;
        _allFiscalYears = all;
        _config = cfg;
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onYearSelected(FiscalYear? fy) async {
    if (fy == null) return;
    setState(() {
      _selectedYear = fy;
      _closing = null;
      _step3Preview = [];
      _step5Preview = [];
      _step4Preview = null;
      _errorMsg = null;
      _lastPeriod = null;
      _docDateStep3 = null;
      _docDateStep4 = null;
    });
    await _loadClosing(fy.id);
    await _loadLastPeriod(fy.id);
  }

  Future<void> _loadLastPeriod(int fyId) async {
    try {
      final periods = await _periodService.fetchPostingPeriodsByFiscalYearId(fyId);
      if (periods.isEmpty) return;
      periods.sort((a, b) => a.periodEndDate.compareTo(b.periodEndDate));
      final last = periods.last;
      setState(() {
        _lastPeriod = last;
        _docDateStep3 ??= last.periodEndDate;
        _docDateStep4 ??= last.periodEndDate;
      });
    } catch (_) {}
  }

  Future<void> _loadFirstNextPeriod(int fyId) async {
    try {
      final periods = await _periodService.fetchPostingPeriodsByFiscalYearId(fyId);
      if (periods.isEmpty) return;
      periods.sort((a, b) => a.periodStartDate.compareTo(b.periodStartDate));
      final first = periods.first;
      setState(() {
        _firstNextPeriod = first;
        _docDateStep5 ??= first.periodStartDate;
      });
    } catch (_) {}
  }

  Future<void> _loadClosing(int fyId) async {
    setState(() => _isLoading = true);
    try {
      final closing = await _service.getOrInitClosing(fyId);
      setState(() => _closing = closing);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runStep(Future<void> Function() action) async {
    setState(() { _isProcessing = true; _errorMsg = null; });
    try {
      await action();
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _toIso(DateTime d) => d.toIso8601String().split('T')[0];

  void _validateDocDate(DateTime? date, PostingPeriod? period, String stepLabel) {
    if (date == null) throw Exception('กรุณาระบุวันที่เอกสาร$stepLabel');
    if (period == null) throw Exception('ไม่พบข้อมูลงวดบัญชีสำหรับ$stepLabel');
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(period.periodStartDate.year, period.periodStartDate.month, period.periodStartDate.day);
    final e = DateTime(period.periodEndDate.year, period.periodEndDate.month, period.periodEndDate.day);
    if (d.isBefore(s) || d.isAfter(e)) {
      final fmt = DateFormat('dd/MM/yyyy');
      throw Exception(
        'วันที่เอกสาร$stepLabel (${fmt.format(date)}) ต้องอยู่ในช่วง ${fmt.format(period.periodStartDate)} – ${fmt.format(period.periodEndDate)}',
      );
    }
  }

  // ─── Step Actions ──────────────────────────────────────────────────────────

  Future<void> _doStep1() => _runStep(() async {
    final result = await _service.runStep1(_closing!.id);
    final ok = result['ok'] as bool;
    if (!ok) {
      final unposted   = result['unposted_count']   ?? 0;
      final unbalanced = result['unbalanced_count']  ?? 0;
      throw Exception('ตรวจพบปัญหา: รายการ Draft $unposted รายการ, ไม่สมดุล $unbalanced รายการ');
    }
    await _loadClosing(_selectedYear!.id);
  });

  Future<void> _doStep3Preview() => _runStep(() async {
    final lines = await _service.previewStep3(_closing!.id);
    setState(() => _step3Preview = lines);
  });

  Future<void> _doStep3Confirm() => _runStep(() async {
    _validateDocDate(_docDateStep3, _lastPeriod, 'ขั้นตอน 3');
    await _service.confirmStep3(_closing!.id, _toIso(_docDateStep3!), _userId);
    await _loadClosing(_selectedYear!.id);
    setState(() => _step3Preview = []);
  });

  Future<void> _doStep4Preview() => _runStep(() async {
    final data = await _service.previewStep4(_closing!.id);
    setState(() => _step4Preview = data);
  });

  Future<void> _doStep4Confirm() => _runStep(() async {
    _validateDocDate(_docDateStep4, _lastPeriod, 'ขั้นตอน 4');
    await _service.confirmStep4(_closing!.id, _toIso(_docDateStep4!), _userId);
    await _loadClosing(_selectedYear!.id);
    setState(() => _step4Preview = null);
  });

  Future<void> _doStep5Preview() => _runStep(() async {
    if (_selectedNextYear == null) throw Exception('กรุณาเลือกปีบัญชีถัดไป');
    final lines = await _service.previewStep5(_closing!.id);
    setState(() => _step5Preview = lines);
  });

  Future<void> _doStep5Confirm() => _runStep(() async {
    if (_selectedNextYear == null) throw Exception('กรุณาเลือกปีบัญชีถัดไป');
    _validateDocDate(_docDateStep5, _firstNextPeriod, 'ขั้นตอน 5');
    await _service.confirmStep5(_closing!.id, _toIso(_docDateStep5!), _selectedNextYear!.id, _userId);
    await _loadClosing(_selectedYear!.id);
    setState(() => _step5Preview = []);
  });

  Future<void> _doStep6() => _runStep(() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการล็อคปีบัญชี'),
        content: const Text('ปีบัญชีนี้จะถูกล็อคและไม่สามารถบันทึกรายการได้อีก ต้องการดำเนินการต่อหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.confirmStep6(_closing!.id);
    await _loadClosing(_selectedYear!.id);
  });

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _errorMsg = null),
                          ),
                        ],
                      ),
                    ),

                  // Config warning
                  if (_config == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('ยังไม่ได้ตั้งค่าการปิดบัญชี กรุณาตั้งค่าก่อน'),
                        ],
                      ),
                    ),

                  // Year selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text('ปีบัญชีที่ต้องการปิด:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 280,
                            child: DropdownButtonFormField<FiscalYear>(
                              isExpanded: true,
                              value: _selectedYear,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              hint: const Text('เลือกปีบัญชี'),
                              items: _fiscalYears.map((fy) => DropdownMenuItem(
                                value: fy,
                                child: Text(fy.description ?? ''),
                              )).toList(),
                              onChanged: _onYearSelected,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_closing != null)
                            _StatusChip(_closing!.status),
                        ],
                      ),
                    ),
                  ),

                  if (_closing != null) ...[
                    const SizedBox(height: 16),
                    _buildStepper(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStepper() {
    final closing = _closing!;
    final currentStep = closing.currentStep;

    return Stepper(
      currentStep: currentStep,
      controlsBuilder: (context, details) => const SizedBox.shrink(),
      steps: [
        // ── Step 1: Checklist ──────────────────────────────────────────────
        Step(
          title: const Text('ตรวจสอบความพร้อม'),
          subtitle: const Text('ตรวจสอบรายการที่ยังไม่ผ่านรายการและความสมดุล'),
          isActive: currentStep >= 0,
          state: closing.step1ChecklistOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step1ChecklistOk == true,
            isProcessing: _isProcessing,
            children: [
              if (closing.step1Result != null) ...[
                _ResultRow('รายการ Draft ที่ยังไม่ผ่านรายการ',
                    '${closing.step1Result!['unposted_count'] ?? 0} รายการ'),
                _ResultRow('รายการที่ไม่สมดุล',
                    '${closing.step1Result!['unbalanced_count'] ?? 0} รายการ'),
                const SizedBox(height: 8),
              ],
              if (closing.step1ChecklistOk != true)
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _doStep1,
                  icon: const Icon(Icons.search),
                  label: const Text('ตรวจสอบ'),
                ),
            ],
          ),
        ),

        // ── Step 2: Adjusting ──────────────────────────────────────────────
        Step(
          title: const Text('รายการปรับปรุง'),
          subtitle: const Text('บันทึกรายการปรับปรุงก่อนปิดบัญชี'),
          isActive: currentStep >= 1,
          state: closing.step2AdjustingOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step2AdjustingOk == true,
            isProcessing: _isProcessing,
            children: [
              const Text('บันทึกรายการปรับปรุงผ่านหน้าจอบันทึกบัญชีทั่วไป (GL Entry) เมื่อเสร็จสิ้นให้กดยืนยัน'),
              const SizedBox(height: 8),
              if (closing.step2AdjustingOk != true)
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _runStep(() async {
                          await _service.confirmStep2(_closing!.id);
                          await _loadClosing(_selectedYear!.id);
                        }),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('ยืนยันรายการปรับปรุงเสร็จสิ้น'),
                ),
            ],
          ),
        ),

        // ── Step 3: Close Rev/Exp ──────────────────────────────────────────
        Step(
          title: const Text('ปิดบัญชีรายได้และค่าใช้จ่าย'),
          subtitle: const Text('โอนยอดบัญชีรายได้/ค่าใช้จ่ายเข้าบัญชีกำไรขาดทุน'),
          isActive: currentStep >= 2,
          state: closing.step3ClosingOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step3ClosingOk == true,
            isProcessing: _isProcessing,
            children: [
              if (closing.step3EntryId != null)
                _ResultRow('เลขที่เอกสาร', 'Entry ID: ${closing.step3EntryId}'),
              if (_step3Preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PreviewTable(lines: _step3Preview, fmt: _fmt),
                const SizedBox(height: 8),
              ],
              if (closing.step3ClosingOk != true) ...[
                _DocDatePicker(
                  label: 'วันที่เอกสาร',
                  value: _docDateStep3,
                  period: _lastPeriod,
                  onChanged: (d) => setState(() => _docDateStep3 = d),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _doStep3Preview,
                      icon: const Icon(Icons.preview),
                      label: const Text('ดูตัวอย่าง'),
                    ),
                    const SizedBox(width: 12),
                    if (_step3Preview.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _doStep3Confirm,
                        icon: const Icon(Icons.done),
                        label: const Text('ยืนยันการปิดบัญชี'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Step 4: Transfer Net Income ────────────────────────────────────
        Step(
          title: const Text('โอนกำไร/ขาดทุนสุทธิ'),
          subtitle: const Text('โอนยอดจากบัญชีกำไรขาดทุนเข้ากำไรสะสม'),
          isActive: currentStep >= 3,
          state: closing.step4TransferOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step4TransferOk == true,
            isProcessing: _isProcessing,
            children: [
              if (closing.step4EntryId != null)
                _ResultRow('เลขที่เอกสาร', 'Entry ID: ${closing.step4EntryId}'),
              if (_step4Preview != null) ...[
                const SizedBox(height: 8),
                _ResultRow('กำไร/ขาดทุนสุทธิ',
                    _fmt.format(_step4Preview!['net_income'] ?? 0)),
                const SizedBox(height: 8),
              ],
              if (closing.step4TransferOk != true) ...[
                _DocDatePicker(
                  label: 'วันที่เอกสาร',
                  value: _docDateStep4,
                  period: _lastPeriod,
                  onChanged: (d) => setState(() => _docDateStep4 = d),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _doStep4Preview,
                      icon: const Icon(Icons.preview),
                      label: const Text('ดูตัวอย่าง'),
                    ),
                    const SizedBox(width: 12),
                    if (_step4Preview != null)
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _doStep4Confirm,
                        icon: const Icon(Icons.done),
                        label: const Text('ยืนยันการโอน'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Step 5: Carry Forward ──────────────────────────────────────────
        Step(
          title: const Text('ยกยอดงบดุลปีถัดไป'),
          subtitle: const Text('สร้างรายการยกยอดในงวดแรกของปีบัญชีถัดไป'),
          isActive: currentStep >= 4,
          state: closing.step5CarryForwardOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step5CarryForwardOk == true,
            isProcessing: _isProcessing,
            children: [
              if (closing.step5EntryId != null)
                _ResultRow('เลขที่เอกสาร', 'Entry ID: ${closing.step5EntryId}'),
              if (closing.step5CarryForwardOk != true) ...[
                // Next year selector
                Row(
                  children: [
                    const Text('ปีบัญชีถัดไป:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<FiscalYear>(
                        isExpanded: true,
                        value: _selectedNextYear,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        hint: const Text('เลือกปีบัญชีถัดไป'),
                        items: _allFiscalYears
                            .where((fy) => _selectedYear == null || fy.id != _selectedYear!.id)
                            .map((fy) => DropdownMenuItem(
                                  value: fy,
                                  child: Text(fy.description ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedNextYear = v;
                            _firstNextPeriod = null;
                            _docDateStep5 = null;
                          });
                          if (v != null) _loadFirstNextPeriod(v.id);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DocDatePicker(
                  label: 'วันที่เอกสาร (งวดแรกของปีถัดไป)',
                  value: _docDateStep5,
                  period: _firstNextPeriod,
                  onChanged: (d) => setState(() => _docDateStep5 = d),
                ),
                const SizedBox(height: 8),
                if (_step5Preview.isNotEmpty) ...[
                  _PreviewTable(lines: _step5Preview, fmt: _fmt),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _doStep5Preview,
                      icon: const Icon(Icons.preview),
                      label: const Text('ดูตัวอย่าง'),
                    ),
                    const SizedBox(width: 12),
                    if (_step5Preview.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _doStep5Confirm,
                        icon: const Icon(Icons.done),
                        label: const Text('ยืนยันการยกยอด'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Step 6: Lock Year ──────────────────────────────────────────────
        Step(
          title: const Text('ล็อคปีบัญชี'),
          subtitle: const Text('ปิดทุกงวดบัญชีและล็อคปีบัญชีนี้'),
          isActive: currentStep >= 5,
          state: closing.step6LockOk == true ? StepState.complete : StepState.indexed,
          content: _StepCard(
            isDone: closing.step6LockOk == true,
            isProcessing: _isProcessing,
            children: [
              if (closing.step6LockOk == true)
                const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ปีบัญชีถูกล็อคเรียบร้อยแล้ว',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _doStep6,
                  icon: const Icon(Icons.lock),
                  label: const Text('ล็อคปีบัญชี'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'COMPLETED': color = Colors.green; break;
      case 'CANCELLED': color = Colors.grey; break;
      default: color = Colors.orange;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }
}

class _StepCard extends StatelessWidget {
  final bool isDone;
  final bool isProcessing;
  final List<Widget> children;
  const _StepCard({required this.isDone, required this.isProcessing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDone)
                  const Row(children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('เสร็จสิ้น', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ]),
                ...children,
              ],
            ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text('$label:', style: const TextStyle(color: Colors.grey))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<ClosingPreviewLine> lines;
  final NumberFormat fmt;
  const _PreviewTable({required this.lines, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FlexColumnWidth(3),
          2: FixedColumnWidth(120),
          3: FixedColumnWidth(120),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade200),
            children: const [
              _TH('รหัส'), _TH('ชื่อบัญชี'), _TH('เดบิต'), _TH('เครดิต'),
            ],
          ),
          ...lines.map((l) => TableRow(children: [
            _TD(l.accountCode),
            _TD(l.accountName),
            _TDR(l.debit > 0 ? fmt.format(l.debit) : ''),
            _TDR(l.credit > 0 ? fmt.format(l.credit) : ''),
          ])),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(text));
}

class _TDR extends StatelessWidget {
  final String text;
  const _TDR(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(text, textAlign: TextAlign.right));
}

// ─── Doc Date Picker ───────────────────────────────────────────────────────────

class _DocDatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final PostingPeriod? period;
  final ValueChanged<DateTime?> onChanged;

  const _DocDatePicker({
    required this.label,
    required this.value,
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final hasRange = period != null;
    final rangeText = hasRange
        ? 'ช่วงงวด: ${fmt.format(period!.periodStartDate)} – ${fmt.format(period!.periodEndDate)}'
        : 'กำลังโหลดข้อมูลงวด...';

    return Row(
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        InkWell(
          onTap: hasRange
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? period!.periodEndDate,
                    firstDate: period!.periodStartDate,
                    lastDate: period!.periodEndDate,
                  );
                  if (picked != null) onChanged(picked);
                }
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasRange ? Colors.blueGrey : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(4),
              color: hasRange ? null : Colors.grey.shade50,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: hasRange ? Colors.blueGrey : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  value != null ? fmt.format(value!) : 'เลือกวันที่',
                  style: TextStyle(
                    color: hasRange ? Colors.black87 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          rangeText,
          style: TextStyle(
            fontSize: 12,
            color: hasRange ? Colors.grey.shade600 : Colors.orange,
            fontStyle: hasRange ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
