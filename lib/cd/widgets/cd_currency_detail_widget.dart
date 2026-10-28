// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/cd_currency.dart';
import '../services/cd_currency_service.dart';

class CurrencyDetailWidget extends StatefulWidget {
  final Mode mode;
  final Currency? selected;
  final Function(Currency) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน
  final int requestSeq;

  const CurrencyDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<CurrencyDetailWidget> createState() => CurrencyDetailWidgetState();
}

class CurrencyDetailWidgetState extends State<CurrencyDetailWidget> {
  Currency? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _currencyCodeController;
  late TextEditingController _currencyNameThaiController;
  late TextEditingController _currencyNameEngController;
  late TextEditingController _baseRateController;
  late TextEditingController _symbolController;
  late bool _baseCurrencyFlag;
  late int _numOfDecimal;
  late bool _isActive;

  final List<int> _numOfDecimals = [0, 1, 2, 3, 4, 5, 6];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;

    _currencyCodeController = TextEditingController(text: _selected?.currencyCode ?? '');
    _currencyNameThaiController = TextEditingController(text: _selected?.currencyNameThai ?? '');
    _currencyNameEngController = TextEditingController(text: _selected?.currencyNameEng ?? '');
    _baseRateController = TextEditingController(text: _selected?.baseRate.toString() ?? '1.00');
    _baseCurrencyFlag = _selected?.baseCurrencyFlag ?? false;
    _symbolController = TextEditingController(text: _selected?.symbol);
    _numOfDecimal = _selected?.numOfDecimal ?? 2;
    _isActive = _selected?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant CurrencyDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.requestSeq != oldWidget.requestSeq) {
      _selected = widget.selected;

      _currencyCodeController.text = _selected?.currencyCode ?? '';
      _currencyNameThaiController.text = _selected?.currencyNameThai ?? '';
      _currencyNameEngController.text = _selected?.currencyNameEng ?? '';
      _baseRateController.text = _selected?.baseRate.toString() ?? '1.00';
      _baseCurrencyFlag = _selected?.baseCurrencyFlag ?? false;
      _symbolController.text = _selected?.symbol ?? '';
      _numOfDecimal = _selected?.numOfDecimal ?? 2;
      _isActive = _selected?.isActive ?? true;
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _selected = null;
      _currencyCodeController.clear();
      _currencyNameThaiController.clear();
      _currencyNameEngController.clear();
      _baseRateController.text = '1.00';
      _baseCurrencyFlag = false;
      _symbolController.clear();
      _numOfDecimal = 2;
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _currencyCodeController.dispose();
    _currencyNameThaiController.dispose();
    _currencyNameEngController.dispose();
    _baseRateController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  // เปลี่ยนสกุลเงินหลัก (ตั้งสกุลอื่นเป็นหลัก หรือยกเลิกสกุลหลักปัจจุบัน) — เตือนผลกระทบและให้ยืนยันก่อนบันทึก
  Future<bool> _confirmBaseChange() async {
    final wasBase = widget.selected?.baseCurrencyFlag ?? false;
    if (_baseCurrencyFlag == wasBase) return true;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    Map<String, dynamic> impact = {};
    try {
      impact = await CurrencyService().fetchBaseChangeImpact();
    } catch (_) {}
    if (!mounted) return false;
    int n(String k) => (impact[k] as num?)?.toInt() ?? 0;
    final oldCode = (impact['base_currency_code'] as String?) ?? CurrencyService.baseCode;
    final newCode = _currencyCodeController.text.trim().toUpperCase();
    final turningOff = wasBase && !_baseCurrencyFlag;
    final title = turningOff
        ? (isEnglish ? 'Remove base currency $newCode?' : 'ยกเลิกสกุลเงินหลัก $newCode?')
        : (isEnglish ? 'Change base currency $oldCode → $newCode?' : 'เปลี่ยนสกุลเงินหลัก $oldCode → $newCode?');
    final target = turningOff ? (isEnglish ? 'no base currency (the system will fall back to THB)' : 'ไม่มีสกุลเงินหลัก (ระบบจะใช้ THB แทน)') : newCode;
    final items = <String>[
      isEnglish
          ? 'Base-currency amounts already recorded stay in $oldCode and are NOT converted: '
              '${n('gl_entries')} posted GL entries, ${n('ar_documents')} AR / ${n('ap_documents')} AP documents, ${n('im_documents')} IM documents. '
              'Reports and GL balances will mix $oldCode and the new base currency.'
          : 'ยอดสกุลเงินหลักที่บันทึกไปแล้วยังเป็น $oldCode และระบบจะไม่แปลงย้อนหลัง: '
              'รายการบัญชีที่โพสต์แล้ว ${n('gl_entries')} รายการ, เอกสาร AR ${n('ar_documents')} / AP ${n('ap_documents')} ใบ, เอกสาร IM ${n('im_documents')} ใบ '
              '— รายงานและยอดคงเหลือบัญชีจะรวมยอด $oldCode กับสกุลเงินหลักใหม่ปนกัน',
      isEnglish
          ? 'Base exchange rates of the other ${n('other_currencies')} active currencies are quoted against $oldCode — they must all be re-entered against the new base.'
          : 'อัตราแลกเปลี่ยนพื้นฐานของสกุลเงินอื่นที่ใช้งานอยู่ ${n('other_currencies')} สกุล เทียบกับ $oldCode — ต้องแก้ใหม่ทั้งหมดให้เทียบกับสกุลเงินหลักใหม่',
      isEnglish
          ? 'Open receivables ${n('open_ar_documents')} / payables ${n('open_ap_documents')}: FX revaluation and realized gain/loss will be calculated against the wrong base.'
          : 'ลูกหนี้ค้างชำระ ${n('open_ar_documents')} ใบ / เจ้าหนี้ค้างชำระ ${n('open_ap_documents')} ใบ: การตีราคาและกำไรขาดทุนจากอัตราแลกเปลี่ยนจะคำนวณเทียบกับสกุลเงินหลักที่ผิด',
      isEnglish
          ? 'Credit limits of ${n('customers_with_credit_limit')} customers are amounts in $oldCode but will be compared in the new base currency.'
          : 'วงเงินเครดิตลูกค้า ${n('customers_with_credit_limit')} ราย เป็นยอด $oldCode แต่จะถูกเทียบเป็นสกุลเงินหลักใหม่',
      isEnglish
          ? 'New documents without a currency, tax-invoice base amounts and labels will use $target. Other users must log out and back in.'
          : 'เอกสารใหม่ที่ไม่ระบุสกุลเงิน ยอดสกุลเงินหลักในใบกำกับภาษี และป้ายบนหน้าจอ จะใช้ $target — ผู้ใช้อื่นต้องออกจากระบบแล้วเข้าใหม่',
    ];
    bool understood = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber, color: Colors.red[700]),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ]),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEnglish
                    ? 'Changing the base currency should only be done before go-live. Impact on this database:'
                    : 'การเปลี่ยนสกุลเงินหลักควรทำก่อนเริ่มใช้งานระบบเท่านั้น ผลกระทบกับฐานข้อมูลนี้:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('•  '),
                        Expanded(child: Text(t)),
                      ]),
                    )),
                if (impact.isEmpty)
                  Text(isEnglish ? '(Could not load document counts)' : '(โหลดจำนวนเอกสารไม่สำเร็จ)',
                      style: TextStyle(color: Colors.grey[600])),
                const Divider(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: understood,
                  onChanged: (v) => setD(() => understood = v ?? false),
                  title: Text(isEnglish ? 'I understand the impact and want to continue' : 'ฉันเข้าใจผลกระทบและต้องการดำเนินการต่อ'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppL10n(isEnglish).cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              onPressed: understood ? () => Navigator.pop(ctx, true) : null,
              child: Text(isEnglish ? 'Confirm change' : 'ยืนยันการเปลี่ยน'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (!await _confirmBaseChange()) return;
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = Currency(
          id: widget.selected?.id ?? 0,
          currencyCode: _currencyCodeController.text.toUpperCase(),
          currencyNameThai: _currencyNameThaiController.text,
          currencyNameEng: _currencyNameEngController.text,
          baseRate: double.tryParse(_baseRateController.text) ?? 1.00,
          baseCurrencyFlag: _baseCurrencyFlag,
          symbol: _symbolController.text,
          numOfDecimal: _numOfDecimal,
          isActive: _isActive,
        );
        await widget.onSubmit(newDetail);
      } catch (e) {
        if (mounted) {
          final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l.errorOccurred}: $e'),
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
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(isEnglish
            ? 'Select a currency to edit or press + to add new'
            : 'เลือกสกุลเงินเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มสกุลเงินใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;

    return SingleChildScrollView(
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
                      ? (isEnglish ? 'Edit' : 'แก้ไขข้อมูล')
                      : (isEnglish ? 'Add New' : 'เพิ่มข้อมูลใหม่'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child:
                  TextFormField(
                    readOnly: widget.mode != Mode.add,
                    controller: _currencyCodeController,
                    style: const TextStyle(fontSize: 31, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Currency Code (ISO 3-letter)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length != 3) {
                        return isEnglish ? 'Please enter a 3-letter code' : 'โปรดระบุรหัส 3 ตัวอักษร';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _symbolController,
                    style: const TextStyle(fontSize: 31, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Currency Symbol' : 'สัญลักษณ์สกุลเงิน',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _currencyNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสกุลเงิน (ไทย)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish ? 'Please enter Thai name' : 'โปรดระบุชื่อสกุลเงินภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _currencyNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'Currency Name (EN)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish ? 'Please enter English name' : 'โปรดระบุชื่อสกุลเงินภาษาอังกฤษ';
                      }
                      return null;
                    },
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('${l.status}: ${_isActive ? l.active : l.inactive}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly ? null : (bool value) {
                    setState(() {
                      _isActive = value;
                      if (!_isActive) {
                        _baseCurrencyFlag = false;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(isEnglish
                      ? 'Base currency of system: ${_baseCurrencyFlag ? 'Yes' : 'No'}'
                      : 'เป็นสกุลเงินหลักของระบบ: ${_baseCurrencyFlag ? 'เป็น' : 'ไม่เป็น'}'),
                ),
                Switch(
                  value: _baseCurrencyFlag,
                  onChanged: readOnly ? null : (bool value) {
                    setState(() {
                      _baseCurrencyFlag = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: readOnly,
              controller: _baseRateController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: isEnglish
                    ? 'Base Exchange Rate (vs. base currency)'
                    : 'อัตราแลกเปลี่ยนพื้นฐาน (เทียบกับสกุลเงินหลัก)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_baseCurrencyFlag) {
                  value = '1.00';
                  return null;
                } else if (value == null || double.tryParse(value) == null) {
                  return isEnglish ? 'Please enter a valid rate' : 'โปรดระบุอัตราแลกเปลี่ยนที่ถูกต้อง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              value: _numOfDecimal,
              alignment: Alignment.centerRight,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Decimal places (0–6)' : 'เลือกจำนวนทศนิยม 0 - 6 ตำแหน่ง',
                border: const OutlineInputBorder(),
              ),
              items: _numOfDecimals.map((val) {
                return DropdownMenuItem(
                  value: val,
                  child: Text(val.toString()),
                );
              }).toList(),
              onChanged: readOnly ? null : (value) {
                if (value != null) {
                  setState(() {
                    _numOfDecimal = value;
                  });
                }
              },
            ),
            const SizedBox(height: 48),
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
    );
  }
}
