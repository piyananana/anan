// widgets/cd_branch_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/cd_branch.dart';
import '../models/cd_zipcode.dart';
import 'cd_zipcode_list_widget.dart';

class BranchDetailWidget extends StatefulWidget {
  final Mode mode;
  final Branch? selected;
  final Function(Branch) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน
  final int requestSeq;

  const BranchDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
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
    if (widget.selected != oldWidget.selected || widget.requestSeq != oldWidget.requestSeq) {
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
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
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

  Future<void> _submitForm(bool isEnglish) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
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
          final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l.errorOccurred}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
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
            ? 'Select a branch to edit or press + to add new'
            : 'เลือกสาขาเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มสาขาใหม่'),
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
            TextFormField(
              readOnly: widget.mode != Mode.add,
              controller: _branchCodeController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Branch Code' : 'รหัสสาขา',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty || value.length > 50) {
                  return isEnglish
                      ? 'Please enter code (max 50 chars)'
                      : 'โปรดระบุรหัสไม่เกิน 50 ตัวอักษร';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _branchNameThaiController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสาขา (ไทย)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish
                            ? 'Please enter Thai name'
                            : 'โปรดระบุชื่อสาขาภาษาไทย';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _branchNameEngController,
                    decoration: const InputDecoration(
                      labelText: 'Branch Name (EN)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish
                            ? 'Please enter English name'
                            : 'โปรดระบุชื่อสาขาภาษาอังกฤษ';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(color: Colors.grey.shade700),
              ),
              title: Text('${l.status}: ${_isActive ? l.active : l.inactive}'),
              trailing: Switch(
                value: _isActive,
                onChanged: readOnly
                    ? null
                    : (bool value) => setState(() => _isActive = value),
              ),
            ),
            const SizedBox(height: 20),
            Text(isEnglish ? 'Address' : 'ที่อยู่',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildAddressFields(isEnglish, readOnly),
            const SizedBox(height: 20),
            Text(isEnglish ? 'Contact Information' : 'ข้อมูลติดต่อ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildContactFields(isEnglish, readOnly),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container()
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _submitForm(isEnglish),
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

  Widget _buildAddressFields(bool isEnglish, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildTextField(
            controller: _addressNoController,
            labelText: isEnglish ? 'No. / Room' : 'บ้านเลขที่ / ห้อง',
            readOnly: readOnly,
          )),
          const SizedBox(width: 4),
          Expanded(child: _buildTextField(
            controller: _addressBuildingVillageController,
            labelText: isEnglish ? 'Building / Village' : 'อาคาร / หมู่บ้าน',
            readOnly: readOnly,
          )),
          const SizedBox(width: 4),
          Expanded(child: _buildTextField(
            controller: _addressSoiController,
            labelText: isEnglish ? 'Lane (Soi)' : 'ซอย',
            readOnly: readOnly,
          )),
          const SizedBox(width: 4),
          Expanded(child: _buildTextField(
            controller: _addressRoadController,
            labelText: isEnglish ? 'Road' : 'ถนน',
            readOnly: readOnly,
          )),
        ]),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            tooltip: isEnglish
                ? 'Search Sub-district, District, Province, Zipcode'
                : 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
            onPressed: readOnly ? null : () => _showZipCodeSearchCard(isEnglish),
          ),
          Expanded(
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildTextField(
                  controller: _addressSubDistrictController,
                  labelText: isEnglish ? 'Sub-district' : 'ตำบล / แขวง',
                  readOnly: readOnly,
                )),
                const SizedBox(width: 4),
                Expanded(child: _buildTextField(
                  controller: _addressDistrictController,
                  labelText: isEnglish ? 'District' : 'อำเภอ / เขต',
                  readOnly: readOnly,
                )),
                const SizedBox(width: 4),
                Expanded(child: _buildTextField(
                  controller: _addressProvinceController,
                  labelText: isEnglish ? 'Province' : 'จังหวัด',
                  readOnly: readOnly,
                )),
                const SizedBox(width: 4),
                Expanded(child: _buildTextField(
                  controller: _addressZipCodeController,
                  labelText: isEnglish ? 'Zipcode' : 'รหัสไปรษณีย์',
                  keyboardType: TextInputType.number,
                  readOnly: readOnly,
                )),
              ]),
            ]),
          ),
        ]),
        _buildTextField(
          controller: _addressCountryController,
          labelText: isEnglish ? 'Country' : 'ประเทศ',
          readOnly: readOnly,
        ),
      ],
    );
  }

  Widget _buildContactFields(bool isEnglish, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildTextField(
            controller: _phoneNumberController,
            labelText: isEnglish ? 'Phone' : 'เบอร์โทรศัพท์',
            keyboardType: TextInputType.phone,
            readOnly: readOnly,
          )),
          const SizedBox(width: 4),
          Expanded(child: _buildTextField(
            controller: _faxNumberController,
            labelText: isEnglish ? 'Fax' : 'เบอร์แฟกซ์',
            keyboardType: TextInputType.phone,
            readOnly: readOnly,
          )),
          const SizedBox(width: 4),
          Expanded(child: _buildTextField(
            controller: _primaryContactPersonController,
            labelText: isEnglish ? 'Primary Contact' : 'ผู้ติดต่อหลัก',
            readOnly: readOnly,
          )),
        ]),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onTap,
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
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'กรุณากรอก $labelText';
          }
          if (validator != null) return validator(value);
          return null;
        },
      ),
    );
  }

  void _showZipCodeSearchCard(bool isEnglish) {
    ZipcodeListWidget.search(
      context,
      onSelected: (Zipcode selected) {
        setState(() {
          _addressSubDistrictController.text = selected.subDistrict;
          _addressDistrictController.text = selected.district;
          _addressProvinceController.text = selected.province;
          _addressZipCodeController.text = selected.zipcode;

          _showSnackBar(
            isEnglish
                ? 'Selected: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}'
                : 'เลือก: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}',
            Colors.green,
          );
        });
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }
}
