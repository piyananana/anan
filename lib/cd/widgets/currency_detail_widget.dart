// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
import '../../sa/models/anan_module.dart';
import '../models/currency.dart';

class CurrencyDetailWidget extends StatefulWidget {
  final Mode mode;
  final Currency? selected;
  final Function(Currency) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const CurrencyDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
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
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _currencyCodeController.text = _selected?.currencyCode ?? '';
      _currencyNameThaiController.text = _selected?.currencyNameThai ?? '';
      _currencyNameEngController.text = _selected?.currencyNameEng ?? '';
      _baseRateController.text = _selected?.baseRate.toString() ?? '1.00';
      _baseCurrencyFlag = _selected?.baseCurrencyFlag ?? false;
      _symbolController.text = _selected?.symbol ?? '';
      _numOfDecimal = _selected?.numOfDecimal ?? 2;
      _isActive = _selected?.isActive ?? true;  

      // *ไม่ต้องเรียก setState() เพราะการเปลี่ยนแปลงสถานะใน didUpdateWidget จะถูกนำไปใช้ในการ build ถัดไป*
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      // กรณีเปลี่ยนเป็นโหมดเพิ่มข้อมูลใหม่
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
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
            'เลือกสกุลเงินเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มสกุลเงินใหม่'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view // _isViewing
                  ? 'ดูข้อมูล'
                  : widget.mode == Mode.edit // _isEditing
                      ? 'แก้ไขข้อมูล'
                      : 'เพิ่มข้อมูลใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: 
                  TextFormField(
                    enabled: widget.mode != Mode.edit,
                    controller: _currencyCodeController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'รหัสสกุลเงิน (ISO 3-letter code)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length != 3) {
                        return 'โปรดระบุรหัส 3 ตัวอักษร';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: 
                  TextFormField(
                    controller: _symbolController,
                    style: const TextStyle(fontSize: 31, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'สัญลักษณ์สกุลเงิน',
                      border: OutlineInputBorder(),
                    ),
                    // validator: (value) {
                    //   if (value == null || value.isEmpty) {
                    //     return 'โปรดระบุสัญลักษณ์สกุลเงิน';
                    //   }
                    //   return null;
                    // },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: 
                  TextFormField(
                    controller: _currencyNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสกุลเงิน (ไทย)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อสกุลเงินภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: 
                  TextFormField(
                    controller: _currencyNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสกุลเงิน (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อสกุลเงินภาษาอังกฤษ';
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
                  child: Text(
                      'สถานะการใช้: ${_isActive ? 'ใช้' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (bool value) {
                    setState(() {
                      _isActive = value;
                      if (!_isActive) {
                        _baseCurrencyFlag = false; // หากหยุดใช้ ให้ยกเลิกสกุลเงินหลักด้วย
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
                  child: Text(
                      'เป็นสกุลเงินหลักของระบบ: ${_baseCurrencyFlag ? 'เป็น' : 'ไม่เป็น'}'),
                ),
                Switch(
                  value: _baseCurrencyFlag,
                  onChanged: (bool value) {
                    setState(() {
                      _baseCurrencyFlag = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseRateController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'อัตราแลกเปลี่ยนพื้นฐาน (เทียบกับสกุลเงินหลัก)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_baseCurrencyFlag) {
                  value = '1.00'; // หากเป็นสกุลเงินหลัก ให้ตั้งค่า base rate เป็น 1.00 อัตโนมัติ
                  return null;
                } else if (value == null || double.tryParse(value) == null) {
                  return 'โปรดระบุอัตราแลกเปลี่ยนที่ถูกต้อง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Row(
            //   children: [
            //     // const Expanded(
            //     //   child: 
            //     //     Text('จำนวนทศนิยม'),
            //     // ),
            //   ],
            // ),
                DropdownButtonFormField<int>(
                  value: _numOfDecimal,
                  alignment: Alignment.centerRight,
                  decoration: const InputDecoration(
                    labelText:
                        'เลือกจำนวนทศนิยม 0 - 6 ตำแหน่ง',
                    border: OutlineInputBorder(),
                  ),
                  items: _numOfDecimals.map((val) {
                    return DropdownMenuItem(
                      value: val,
                      child: Text(val.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _numOfDecimal = value;
                      });
                    }
                  },
                ),
            const SizedBox(height: 16),
            // --- สิ้นสุดการเพิ่ม Currency ---
            const SizedBox(height: 32),
            // --- Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container() // ไม่แสดงปุ่มเพิ่ม/บันทึก หากเป็นโหมดดูอย่างเดียว
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
    );
  }
}
