// screens/company_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/menu_scope.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:intl/intl.dart';
import '../models/company.dart';
import '../services/company_service.dart';
import '../services/language_provider.dart';
import '../utils/platform_file_picker.dart';
import '../../cd/models/zipcode.dart';
import '../../cd/widgets/zipcode_list_widget.dart';

class CompanyProfileScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const CompanyProfileScreen({
    super.key,
    this.onExit,
  });

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final CompanyService _companyService = CompanyService();

  Company? _company;
  PickedPlatformFile? _pickedLogoFile;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _thaiNameController = TextEditingController();
  final TextEditingController _englishNameController = TextEditingController();
  final TextEditingController _addressNoController = TextEditingController();
  final TextEditingController _addressBuildingVillageController = TextEditingController();
  final TextEditingController _addressAlleyController = TextEditingController();
  final TextEditingController _addressRoadController = TextEditingController();
  final TextEditingController _addressSubDistrictController = TextEditingController();
  final TextEditingController _addressDistrictController = TextEditingController();
  final TextEditingController _addressProvinceController = TextEditingController();
  final TextEditingController _addressCountryController = TextEditingController();
  final TextEditingController _addressZipcodeController = TextEditingController();
  final TextEditingController _taxIdNumberController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _maintenanceDateController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _faxNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _primaryContactPersonController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCompanyInfo();
  }

  @override
  void dispose() {
    _thaiNameController.dispose();
    _englishNameController.dispose();
    _addressNoController.dispose();
    _addressBuildingVillageController.dispose();
    _addressAlleyController.dispose();
    _addressRoadController.dispose();
    _addressSubDistrictController.dispose();
    _addressDistrictController.dispose();
    _addressProvinceController.dispose();
    _addressCountryController.dispose();
    _addressZipcodeController.dispose();
    _taxIdNumberController.dispose();
    _startDateController.dispose();
    _maintenanceDateController.dispose();
    _serialNumberController.dispose();
    _phoneNumberController.dispose();
    _faxNumberController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _primaryContactPersonController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanyInfo() async {
    setState(() => _isLoading = true);
    try {
      final company = await _companyService.fetchCompany();
      setState(() {
        _company = company;
        if (_company != null) {
          _thaiNameController.text                = _company!.thaiName;
          _englishNameController.text             = _company!.englishName ?? '';
          _addressNoController.text               = _company!.addressNo ?? '';
          _addressBuildingVillageController.text  = _company!.addressBuildingVillage ?? '';
          _addressAlleyController.text            = _company!.addressAlley ?? '';
          _addressRoadController.text             = _company!.addressRoad ?? '';
          _addressSubDistrictController.text      = _company!.addressSubDistrict ?? '';
          _addressDistrictController.text         = _company!.addressDistrict ?? '';
          _addressProvinceController.text         = _company!.addressProvince ?? '';
          _addressCountryController.text          = _company!.addressCountry ?? '';
          _addressZipcodeController.text          = _company!.addressZipCode ?? '';
          _taxIdNumberController.text             = _company!.taxIdNumber ?? '';
          _startDateController.text               = _company!.startDate != null
              ? DateFormat('yyyy-MM-dd').format(_company!.startDate!) : '';
          _maintenanceDateController.text         = _company!.maintenanceContractDate != null
              ? DateFormat('yyyy-MM-dd').format(_company!.maintenanceContractDate!) : '';
          _serialNumberController.text            = _company!.serialNumber ?? '';
          _phoneNumberController.text             = _company!.phoneNumber ?? '';
          _faxNumberController.text               = _company!.faxNumber ?? '';
          _emailController.text                   = _company!.email ?? '';
          _websiteController.text                 = _company!.website ?? '';
          _primaryContactPersonController.text    = _company!.primaryContactPerson ?? '';
        }
      });
    } catch (e) {
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        _showSnackBar(
            isEnglish ? 'Error loading company info: $e' : 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e',
            Colors.red);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await PlatformImagePicker.pickImage();
    if (pickedFile != null) {
      setState(() => _pickedLogoFile = pickedFile);
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() => _isSaving = true);

    try {
      final companyToSave = Company(
        id:                     _company?.id,
        thaiName:               _thaiNameController.text,
        englishName:            _englishNameController.text.isEmpty ? null : _englishNameController.text,
        addressNo:              _addressNoController.text.isEmpty ? null : _addressNoController.text,
        addressBuildingVillage: _addressBuildingVillageController.text.isEmpty ? null : _addressBuildingVillageController.text,
        addressAlley:           _addressAlleyController.text.isEmpty ? null : _addressAlleyController.text,
        addressRoad:            _addressRoadController.text.isEmpty ? null : _addressRoadController.text,
        addressSubDistrict:     _addressSubDistrictController.text.isEmpty ? null : _addressSubDistrictController.text,
        addressDistrict:        _addressDistrictController.text.isEmpty ? null : _addressDistrictController.text,
        addressProvince:        _addressProvinceController.text.isEmpty ? null : _addressProvinceController.text,
        addressCountry:         _addressCountryController.text.isEmpty ? null : _addressCountryController.text,
        addressZipCode:         _addressZipcodeController.text.isEmpty ? null : _addressZipcodeController.text,
        taxIdNumber:            _taxIdNumberController.text.isEmpty ? null : _taxIdNumberController.text,
        startDate:              _startDateController.text.isNotEmpty ? DateTime.parse(_startDateController.text) : null,
        maintenanceContractDate: _maintenanceDateController.text.isNotEmpty ? DateTime.parse(_maintenanceDateController.text) : null,
        serialNumber:           _serialNumberController.text.isEmpty ? null : _serialNumberController.text,
        phoneNumber:            _phoneNumberController.text.isEmpty ? null : _phoneNumberController.text,
        faxNumber:              _faxNumberController.text.isEmpty ? null : _faxNumberController.text,
        email:                  _emailController.text.isEmpty ? null : _emailController.text,
        website:                _websiteController.text.isEmpty ? null : _websiteController.text,
        primaryContactPerson:   _primaryContactPersonController.text.isEmpty ? null : _primaryContactPersonController.text,
      );

      if (_company == null || _company!.id == null) {
        await _companyService.createCompany(companyToSave, logoFile: _pickedLogoFile);
        _showSnackBar(
            isEnglish ? 'Company saved successfully' : 'บันทึกข้อมูลบริษัทสำเร็จ',
            Colors.green);
      } else {
        await _companyService.updateCompany(companyToSave, logoFile: _pickedLogoFile);
        _showSnackBar(
            isEnglish ? 'Company updated successfully' : 'อัปเดตข้อมูลบริษัทสำเร็จ',
            Colors.green);
      }
      await _fetchCompanyInfo();
    } catch (e) {
      _showSnackBar(
          isEnglish ? 'Error saving company info: $e' : 'เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e',
          Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showZipcodeSearchCard(bool isEnglish) {
    ZipcodeListWidget.search(
      context,
      onSelected: (Zipcode selected) {
        setState(() {
          _addressSubDistrictController.text = selected.subDistrict;
          _addressDistrictController.text    = selected.district;
          _addressProvinceController.text    = selected.province;
          _addressZipcodeController.text     = selected.zipcode;
          _showSnackBar(
              isEnglish
                  ? 'Selected: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}'
                  : 'เลือก: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}',
              Colors.green);
        });
      },
    );
  }

  Widget _buildAddressFields(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTextFormField(
              controller: _addressNoController,
              labelText: isEnglish ? 'No./Room' : 'บ้านเลขที่ / ห้อง',
              isEnglish: isEnglish,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildTextFormField(
              controller: _addressBuildingVillageController,
              labelText: isEnglish ? 'Building/Village' : 'อาคาร / หมู่บ้าน',
              isEnglish: isEnglish,
            )),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTextFormField(
              controller: _addressAlleyController,
              labelText: isEnglish ? 'Alley' : 'ซอย',
              isEnglish: isEnglish,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildTextFormField(
              controller: _addressRoadController,
              labelText: isEnglish ? 'Road' : 'ถนน',
              isEnglish: isEnglish,
            )),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue),
              tooltip: isEnglish
                  ? 'Search Sub-District, District, Province, Zipcode'
                  : 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
              onPressed: () => _showZipcodeSearchCard(isEnglish),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextFormField(
                        controller: _addressSubDistrictController,
                        labelText: isEnglish ? 'Sub-District' : 'แขวง / ตำบล',
                        isEnglish: isEnglish,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextFormField(
                        controller: _addressDistrictController,
                        labelText: isEnglish ? 'District' : 'เขต / อำเภอ',
                        isEnglish: isEnglish,
                      )),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextFormField(
                        controller: _addressProvinceController,
                        labelText: isEnglish ? 'Province' : 'จังหวัด',
                        isEnglish: isEnglish,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextFormField(
                        controller: _addressZipcodeController,
                        labelText: isEnglish ? 'Zipcode' : 'รหัสไปรษณีย์',
                        keyboardType: TextInputType.number,
                        isEnglish: isEnglish,
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        _buildTextFormField(
          controller: _addressCountryController,
          labelText: isEnglish ? 'Country' : 'ประเทศ',
          isEnglish: isEnglish,
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required bool isEnglish,
    String? hintText,
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onTap: onTap,
        decoration: InputDecoration(
          isDense: true,
          labelText: required ? '$labelText *' : labelText,
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
          suffixIcon: required
              ? const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Text('*', style: TextStyle(color: Colors.red, fontSize: 20)),
                )
              : null,
          suffixIconConstraints:
              required ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return isEnglish ? 'Please enter $labelText' : 'กรุณากรอก $labelText';
          }
          if (validator != null) return validator(value);
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: _fetchCompanyInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo ─────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          if (_pickedLogoFile != null)
                            FutureBuilder<Uint8List?>(
                              future: _pickedLogoFile!.isWeb
                                  ? Future.value(_pickedLogoFile!.bytes)
                                  : (File(_pickedLogoFile!.path!).readAsBytes()),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done &&
                                    snapshot.hasData) {
                                  return CircleAvatar(
                                      radius: 60,
                                      backgroundImage: MemoryImage(snapshot.data!));
                                } else if (snapshot.hasError) {
                                  return const CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.error, size: 50, color: Colors.white));
                                }
                                return const CircularProgressIndicator();
                              },
                            )
                          else if (_company?.logoUrl != null && _company!.logoUrl!.isNotEmpty)
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(_company!.logoUrl!),
                            )
                          else
                            const CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.business, size: 50, color: Colors.white),
                            ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(isEnglish ? 'Select Logo' : 'เลือกโลโก้'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Basic Info ────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _thaiNameController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Thai Name *' : 'ชื่อภาษาไทย *',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.language),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return isEnglish
                                    ? 'Please enter Thai name'
                                    : 'กรุณาป้อนชื่อภาษาไทย';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _englishNameController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'English Name' : 'ชื่อภาษาอังกฤษ',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.language),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _taxIdNumberController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: isEnglish ? 'Tax ID *' : 'เลขประจำตัวผู้เสียภาษี *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return isEnglish
                              ? 'Please enter Tax ID'
                              : 'กรุณาป้อนเลขประจำตัวผู้เสียภาษี';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Address ───────────────────────────────────────────
                    Text(isEnglish ? 'Address' : 'ที่อยู่',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildAddressFields(isEnglish),
                    const SizedBox(height: 20),

                    // ── Contact Info ──────────────────────────────────────
                    Text(isEnglish ? 'Contact Info' : 'ข้อมูลติดต่อ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneNumberController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Phone' : 'เบอร์โทรศัพท์',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _faxNumberController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Fax' : 'เบอร์แฟกซ์',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.fax),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Email' : 'อีเมล',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _websiteController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Website' : 'เว็บไซต์',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.link),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _primaryContactPersonController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: isEnglish ? 'Primary Contact' : 'ผู้ติดต่อหลัก',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Contract & Serial ─────────────────────────────────
                    Text(isEnglish ? 'Contract & Serial Info' : 'ข้อมูลสัญญาและอนุกรม',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startDateController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish ? 'Start Date' : 'วันที่เริ่มใช้',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(_startDateController),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _maintenanceDateController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isEnglish
                                  ? 'Maintenance Contract Date'
                                  : 'วันที่เริ่มสัญญาบำรุงรักษาล่าสุด',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.calendar_month),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(_maintenanceDateController),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _serialNumberController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: isEnglish ? 'Serial Number' : 'หมายเลขอนุกรม',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Buttons ───────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveCompanyInfo,
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: Text(_isSaving
                                ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                                : (isEnglish ? 'Save' : 'บันทึกข้อมูล')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _formKey.currentState?.reset();
                              _thaiNameController.clear();
                              _englishNameController.clear();
                              _addressNoController.clear();
                              _addressBuildingVillageController.clear();
                              _addressAlleyController.clear();
                              _addressRoadController.clear();
                              _addressSubDistrictController.clear();
                              _addressDistrictController.clear();
                              _addressProvinceController.clear();
                              _addressCountryController.clear();
                              _addressZipcodeController.clear();
                              _taxIdNumberController.clear();
                              _startDateController.clear();
                              _maintenanceDateController.clear();
                              _serialNumberController.clear();
                              _phoneNumberController.clear();
                              _faxNumberController.clear();
                              _emailController.clear();
                              _websiteController.clear();
                              _primaryContactPersonController.clear();
                              setState(() {
                                _pickedLogoFile  = null;
                                _company?.logoUrl = null;
                              });
                              final isEn = Provider.of<LanguageProvider>(
                                  context, listen: false).isEnglish;
                              _showSnackBar(
                                  isEn ? 'Form cleared' : 'ล้างข้อมูลในฟอร์มแล้ว',
                                  Colors.orange);
                            },
                            icon: const Icon(Icons.clear),
                            label: Text(isEnglish ? 'Clear' : 'ล้างข้อมูล'),
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
    );
  }
}
