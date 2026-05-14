import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/doc_number_branch.dart';
import '../services/doc_number_branch_service.dart';
import '../../cd/models/branch.dart';
import '../../cd/services/branch_service.dart';

class DocNumberResetScreen extends StatefulWidget {
  const DocNumberResetScreen({super.key});

  @override
  State<DocNumberResetScreen> createState() => _DocNumberResetScreenState();
}

class _DocNumberResetScreenState extends State<DocNumberResetScreen> {
  final _configService  = DocNumberBranchService();
  final _branchService  = BranchService();
  final _newValueCtrl   = TextEditingController(text: '1');

  List<Branch> _branches = [];
  bool _useGlobal = true;
  Branch? _selectedBranch;
  List<DocNumberBranchConfig> _docTypes = []; // all auto-numbering doc types (for global)
  List<DocNumberBranchConfig> _branchConfigs = []; // branch-specific configs only
  DocNumberBranchConfig? _selectedDocType;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _newValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final branches = await _branchService.fetchRows();
      // Use branch 0 to get all global doc types (LEFT JOIN returns global values)
      final globalTypes = await _configService.fetchByBranch(0);
      setState(() {
        _branches = branches.where((b) => b.isActive).toList()
          ..sort((a, b) => a.branchCode.compareTo(b.branchCode));
        _docTypes = globalTypes;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e'), backgroundColor: Colors.red));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBranchConfigs(Branch branch) async {
    setState(() { _loading = true; _branchConfigs = []; _selectedDocType = null; });
    try {
      final configs = await _configService.fetchByBranch(branch.id!);
      setState(() {
        // Show only doc types that have a branch-specific config
        _branchConfigs = configs.where((c) => c.hasConfig).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_selectedDocType == null) return;
    final newVal = int.tryParse(_newValueCtrl.text);
    if (newVal == null || newVal < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาใส่ค่าที่ถูกต้อง (≥ 1)')));
      return;
    }

    final branchLabel = _useGlobal ? 'Global' : '${_selectedBranch!.branchCode}';
    final docLabel    = _selectedDocType!.docCode;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการ Reset'),
        content: Text(
          'Reset เลขที่เอกสาร [$branchLabel] $docLabel\n'
          'ค่าใหม่: $newVal\n\n'
          'เลขที่เอกสารที่สร้างก่อนหน้านี้จะไม่เปลี่ยนแปลง แต่เลขถัดไปจะเริ่มจากค่าใหม่',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _configService.resetCounter(
        branchId: _useGlobal ? null : _selectedBranch?.id,
        docId: _selectedDocType!.docId,
        newValue: newVal,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reset สำเร็จ'), backgroundColor: Colors.green));
        // Reload to show updated counter
        if (_useGlobal) {
          await _loadInitial();
        } else if (_selectedBranch != null) {
          await _loadBranchConfigs(_selectedBranch!);
        }
        setState(() => _selectedDocType = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reset ล้มเหลว: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.restart_alt, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Reset เลขที่เอกสาร'),
        ]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Scope toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ขอบเขต', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _useGlobal,
                          onChanged: (v) => setState(() {
                            _useGlobal = v!;
                            _selectedDocType = null;
                            _selectedBranch  = null;
                          }),
                        ),
                        const Text('Global (ทั้งระบบ)'),
                        const SizedBox(width: 32),
                        Radio<bool>(
                          value: false,
                          groupValue: _useGlobal,
                          onChanged: (v) => setState(() {
                            _useGlobal = v!;
                            _selectedDocType = null;
                          }),
                        ),
                        const Text('แยกตามสาขา'),
                      ]),
                      if (!_useGlobal) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Branch>(
                          value: _selectedBranch,
                          decoration: const InputDecoration(
                            labelText: 'สาขา',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _branches.map((b) => DropdownMenuItem(
                            value: b,
                            child: Text('${b.branchCode}  ${b.branchNameThai}'),
                          )).toList(),
                          onChanged: (b) {
                            setState(() {
                              _selectedBranch  = b;
                              _selectedDocType = null;
                            });
                            if (b != null) _loadBranchConfigs(b);
                          },
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Doc type selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ประเภทเอกสาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final list = _useGlobal ? _docTypes : _branchConfigs;
                        if (!_useGlobal && _selectedBranch == null) {
                          return const Text('เลือกสาขาก่อน', style: TextStyle(color: Colors.grey));
                        }
                        if (!_useGlobal && list.isEmpty) {
                          return const Text('ไม่มีการตั้งค่าเลขที่สาขานี้', style: TextStyle(color: Colors.orange));
                        }
                        return DropdownButtonFormField<DocNumberBranchConfig>(
                          value: _selectedDocType,
                          decoration: const InputDecoration(
                            labelText: 'ประเภทเอกสาร',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: list.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text('[${d.sysModule}] ${d.docCode}  ${d.docNameThai}'),
                          )).toList(),
                          onChanged: (d) => setState(() {
                            _selectedDocType = d;
                            _newValueCtrl.text = '1';
                          }),
                        );
                      }),
                    ]),
                  ),
                ),

                // Counter info + new value
                if (_selectedDocType != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Counter ปัจจุบัน',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.numbers, size: 20, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Text(
                            _useGlobal
                                ? '${_selectedDocType!.globalNextRunning}'
                                : '${_selectedDocType!.nextRunningNumber}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                color: Colors.deepOrange[700]),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _newValueCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ค่าเริ่มต้นใหม่',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _reset,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset Counter'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }
}
