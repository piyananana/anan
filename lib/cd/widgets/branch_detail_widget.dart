// widgets/zipcode_detail_form.dart
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import '../../sa/models/sa_anan_module.dart';
import '../models/branch.dart';
import '../models/zipcode.dart';
import 'zipcode_list_widget.dart';

class BranchDetailWidget extends StatefulWidget {
  final Mode mode;
  final Branch? selected;
  final Function(Branch) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const BranchDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<BranchDetailWidget> createState() => BranchDetailWidgetState();
}

class BranchDetailWidgetState extends State<BranchDetailWidget> {
  Branch? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _branchCodeController;
  late TextEditingController _branchNameThaiController;
  late TextEditingController _branchNameEngController;
  late bool _isActive; 
  late TextEditingController _addressNoController;
  late TextEditingController _addressBuildingVillageController;
  late TextEditingController _addressSoiController;
  late TextEditingController _addressRoadController;
  late TextEditingController _addressSubDistrictController;
  late TextEditingController _addressDistrictController;
  late TextEditingController _addressProvinceController;
  late TextEditingController _addressCountryController;
  late TextEditingController _addressZipCodeController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _faxNumberController;
  late TextEditingController _primaryContactPersonController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;

    _branchCodeController = TextEditingController(text: _selected?.branchCode ?? '');
    _branchNameThaiController = TextEditingController(text: _selected?.branchNameThai ?? '');
    _branchNameEngController = TextEditingController(text: _selected?.branchNameEng ?? '');
    _isActive = _selected?.isActive ?? true;  
        DateTime.now().add(const Duration(days: 365)).toLocal();
    _addressNoController = TextEditingController(text: _selected?.addressNo ?? '');
    _addressBuildingVillageController = TextEditingController(text: _selected?.addressBuildingVillage ?? '');
    _addressSoiController = TextEditingController(text: _selected?.addressSoi ?? '');
    _addressRoadController = TextEditingController(text: _selected?.addressRoad ?? '');
    _addressSubDistrictController = TextEditingController(text: _selected?.addressSubDistrict ?? '');
    _addressDistrictController = TextEditingController(text: _selected?.addressDistrict ?? '');
    _addressProvinceController = TextEditingController(text: _selected?.addressProvince ?? '');
    _addressCountryController = TextEditingController(text: _selected?.addressCountry ?? '');
    _addressZipCodeController = TextEditingController(text: _selected?.addressZipCode ?? '');
    _phoneNumberController = TextEditingController(text: _selected?.phoneNumber ?? '');
    _faxNumberController = TextEditingController(text: _selected?.faxNumber ?? '');
    _primaryContactPersonController = TextEditingController(text: _selected?.primaryContactPerson ?? '');
  }

  @override
  void didUpdateWidget(covariant BranchDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _branchCodeController.text = _selected?.branchCode ?? '';
      _branchNameThaiController.text = _selected?.branchNameThai ?? '';
      _branchNameEngController.text = _selected?.branchNameEng ?? '';
      _isActive = _selected?.isActive ?? true;  
      _addressNoController = TextEditingController(text: _selected?.addressNo ?? '');
      _addressBuildingVillageController = TextEditingController(text: _selected?.addressBuildingVillage ?? '');
      _addressSoiController = TextEditingController(text: _selected?.addressSoi ?? '');
      _addressRoadController = TextEditingController(text: _selected?.addressRoad ?? '');
      _addressSubDistrictController = TextEditingController(text: _selected?.addressSubDistrict ?? '');
      _addressDistrictController = TextEditingController(text: _selected?.addressDistrict ?? '');
      _addressProvinceController = TextEditingController(text: _selected?.addressProvince ?? '');
      _addressCountryController = TextEditingController(text: _selected?.addressCountry ?? '');
      _addressZipCodeController = TextEditingController(text: _selected?.addressZipCode ?? '');
      _phoneNumberController = TextEditingController(text: _selected?.phoneNumber ?? '');
      _faxNumberController = TextEditingController(text: _selected?.faxNumber ?? '');
      _primaryContactPersonController = TextEditingController(text: _selected?.primaryContactPerson ?? '');

      // *ไม่ต้องเรียก setState() เพราะการเปลี่ยนแปลงสถานะใน didUpdateWidget จะถูกนำไปใช้ในการ build ถัดไป*
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      // กรณีเปลี่ยนเป็นโหมดเพิ่มข้อมูลใหม่
      _selected = null;
      _branchCodeController.clear();
      _branchNameThaiController.clear();
      _branchNameEngController.clear();
      _isActive = true;  
      _addressNoController.clear();
      _addressBuildingVillageController.clear();
      _addressSoiController.clear();
      _addressRoadController.clear();
      _addressSubDistrictController.clear();
      _addressDistrictController.clear();
      _addressProvinceController.clear();
      _addressCountryController.clear();
      _addressZipCodeController.clear();
      _phoneNumberController.clear();
      _faxNumberController.clear();
      _primaryContactPersonController.clear();
    }
  }

  @override
  void dispose() {
    _branchCodeController.dispose();
    _branchNameThaiController.dispose();
    _branchNameEngController.dispose();
    _addressNoController.clear();
    _addressBuildingVillageController.clear();
    _addressSoiController.clear();
    _addressRoadController.clear();
    _addressSubDistrictController.clear();
    _addressDistrictController.clear();
    _addressProvinceController.clear();
    _addressCountryController.clear();
    _addressZipCodeController.clear();
    _phoneNumberController.clear();
    _faxNumberController.clear();
    _primaryContactPersonController.clear();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = Branch(
          id: widget.selected?.id ?? 0,
          branchCode: _branchCodeController.text.toUpperCase(),
          branchNameThai: _branchNameThaiController.text,
          branchNameEng: _branchNameEngController.text,
          isActive: _isActive,
          addressNo: _addressNoController.text,
          addressBuildingVillage: _addressBuildingVillageController.text,
          addressSoi: _addressSoiController.text,
          addressRoad: _addressRoadController.text,
          addressSubDistrict: _addressSubDistrictController.text,
          addressDistrict: _addressDistrictController.text,
          addressProvince: _addressProvinceController.text,
          addressCountry: _addressCountryController.text,
          addressZipCode: _addressZipCodeController.text,
          phoneNumber: _phoneNumberController.text,
          faxNumber: _faxNumberController.text,
          primaryContactPerson: _primaryContactPersonController.text,
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
            'เลือกสาขาเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มสาขาใหม่'),
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
                    readOnly: widget.mode != Mode.add,
                    controller: _branchCodeController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'รหัสสาขา',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 50,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length > 50) {
                        return 'โปรดระบุรหัสไม่เกิน 50 ตัวอักษร';
                      }
                      return null;
                    },
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
                    controller: _branchNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสาขา (ไทย)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 255,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อสาขาภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child:
                  TextFormField(
                    readOnly: readOnly,
                    controller: _branchNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสาขา (อังกฤษ)',
                      border: OutlineInputBorder(),
                    ),
                    // maxLength: 255,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'โปรดระบุชื่อสาขาภาษาอังกฤษ';
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
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      side: BorderSide(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                    trailing: Switch(
                      value: _isActive,
                      onChanged: readOnly ? null : (bool value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('ที่อยู่',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildAddressFields(),
            const SizedBox(height: 20),
            const Text('ข้อมูลติดต่อ',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildContactFields(),
            // --- สิ้นสุดการเพิ่ม Branch ---
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

  Widget _buildAddressFields() {
    final bool readOnly = widget.mode == Mode.view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... (Address No, Building/Village, Soi, Road - ไม่มีการเปลี่ยนแปลง)
        Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child:
              _buildTextFormField(
                controller: _addressNoController,
                labelText: 'บ้านเลขที่ / ห้อง',
                // maxLength: 50,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 4,),
            Expanded(child:
              _buildTextFormField(
                controller: _addressBuildingVillageController,
                labelText: 'อาคาร / หมู่บ้าน',
                // maxLength: 100,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 4,),
            Expanded(child:
              _buildTextFormField(
                controller: _addressSoiController,
                labelText: 'ซอย',
                // maxLength: 100,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 4,),
            Expanded(child:
              _buildTextFormField(
                controller: _addressRoadController,
                labelText: 'ถนน',
                // maxLength: 100,
                readOnly: readOnly,
              ),
            ),
          ],
        ),
        // NEW: แถวที่มี IconButton สำหรับค้นหารหัสไปรษณีย์
        Row(
          children: [
            // ปุ่มค้นหา
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue),
              tooltip: 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
              onPressed: readOnly ? null : _showZipCodeSearchCard,
            ),
            Expanded(child:
              Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child:
                      // แขวง / ตำบล
                      _buildTextFormField(
                        controller: _addressSubDistrictController,
                        labelText: 'ตำบล / แขวง',
                        // maxLength: 100,
                        readOnly: readOnly,
                      ),
                    ),
                    const SizedBox(width: 4,),
                    Expanded(child:
                      // อำเภอ / เขต
                      _buildTextFormField(
                        controller: _addressDistrictController,
                        labelText: 'อำเภอ / เขต',
                        // maxLength: 100,
                        readOnly: readOnly,
                      ),
                    ),
                    const SizedBox(width: 4,),
                    Expanded(child:
                      // จังหวัด
                      _buildTextFormField(
                        controller: _addressProvinceController,
                        labelText: 'จังหวัด',
                        // maxLength: 100,
                        readOnly: readOnly,
                      ),
                    ),
                    const SizedBox(width: 4,),
                    Expanded(child:
                      // รหัสไปรษณีย์
                      _buildTextFormField(
                        controller: _addressZipCodeController,
                        labelText: 'รหัสไปรษณีย์',
                        // maxLength: 10,
                        keyboardType: TextInputType.number,
                        readOnly: readOnly,
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
        // ประเทศ
        _buildTextFormField(
          controller: _addressCountryController,
          labelText: 'ประเทศ',
          // maxLength: 100,
          keyboardType: TextInputType.text,
          readOnly: readOnly,
        ),

        // TextFormField(
        //   controller: _addressCountryController,
        //   decoration: const InputDecoration(
        //     labelText: 'ประเทศ',
        //     border: OutlineInputBorder(),
        //     prefixIcon: Icon(Icons.public),
        //   ),
        //   // อาจมีค่าเริ่มต้นเป็น 'Thailand'
        //   onTap: () {
        //     if (_addressCountryController.text.isEmpty) {
        //       _addressCountryController.text = 'Thailand';
        //     }
        //   },
        // ),
      ],
    );
  }

  Widget _buildContactFields() {
    final bool readOnly = widget.mode == Mode.view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child:
              _buildTextFormField(
                controller: _phoneNumberController,
                labelText: 'เบอร์โทรศัพท์',
                keyboardType: TextInputType.phone,
                // maxLength: 50,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 4,),
            Expanded(child:
              _buildTextFormField(
                controller: _faxNumberController,
                labelText: 'เบอร์แฟกซ์',
                keyboardType: TextInputType.phone,
                // maxLength: 50,
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 4,),
            Expanded(child:
              _buildTextFormField(
                controller: _primaryContactPersonController,
                labelText: 'ผู้ติดต่อหลัก',
                keyboardType: TextInputType.text,
                // maxLength: 100,
                readOnly: readOnly,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    int? maxLength,
    String? hintText,
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback?
        onTap, // สำหรับกรณีต้องการให้แตะแล้วทำบางอย่าง เช่น DatePicker
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: required ? '$labelText *' : labelText,
          hintText: hintText,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
          // เพิ่มไอคอน * สำหรับฟิลด์ที่ต้องการ
          suffixIcon: required
              ? const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Text('*',
                      style: TextStyle(color: Colors.red, fontSize: 20)),
                )
              : null,
          suffixIconConstraints:
              required ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'กรุณากรอก $labelText';
          }
          if (validator != null) {
            return validator(value);
          }
          return null;
        },
      ),
    );
  }

  void _showZipCodeSearchCard() {
    ZipcodeListWidget.search(
      context,
      onSelected: (Zipcode selected) {
        setState(() {
          // กำหนดค่ากลับไปยัง TextFormField ที่เกี่ยวข้อง
          _addressSubDistrictController.text = selected.subDistrict;
          _addressDistrictController.text = selected.district;
          _addressProvinceController.text = selected.province;
          _addressZipCodeController.text = selected.zipcode;

          _showSnackBar(
              'เลือก: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}',
              Colors.green);
        });
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }


}
