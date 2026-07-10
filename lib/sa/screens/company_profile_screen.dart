// screens/company_profile_screen.dart

import 'package:flutter/material.dart';
import '../utils/menu_scope.dart';
// import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb; // เพิ่ม kIsWeb
import 'package:intl/intl.dart'; // สำหรับ format วันที่
import '../models/company.dart';
import '../services/company_service.dart';
import '../utils/platform_file_picker.dart'; // import ไฟล์ใหม่
import '../../cd/models/zipcode.dart'; // <<< NEW: Import Zipcode model
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
  PickedPlatformFile?
      _pickedLogoFile; // เปลี่ยนจาก File? เป็น PickedPlatformFile?
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _thaiNameController = TextEditingController();
  final TextEditingController _englishNameController = TextEditingController();
  final TextEditingController _addressNoController = TextEditingController();
  final TextEditingController _addressBuildingVillageController =
      TextEditingController();
  final TextEditingController _addressAlleyController = TextEditingController();
  final TextEditingController _addressRoadController = TextEditingController();
  final TextEditingController _addressSubDistrictController =
      TextEditingController();
  final TextEditingController _addressDistrictController =
      TextEditingController();
  final TextEditingController _addressProvinceController =
      TextEditingController();
  final TextEditingController _addressCountryController =
      TextEditingController();
  final TextEditingController _addressZipcodeController =
      TextEditingController();
  final TextEditingController _taxIdNumberController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _maintenanceDateController =
      TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _faxNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _primaryContactPersonController =
      TextEditingController();

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

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  Future<void> _fetchCompanyInfo() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final company = await _companyService.fetchCompany();
      setState(() {
        _company = company;
        if (_company != null) {
          _thaiNameController.text = _company!.thaiName;
          _englishNameController.text = _company!.englishName ?? '';
          _addressNoController.text = _company!.addressNo ?? '';
          _addressBuildingVillageController.text =
              _company!.addressBuildingVillage ?? '';
          _addressAlleyController.text = _company!.addressAlley ?? '';
          _addressRoadController.text = _company!.addressRoad ?? '';
          _addressSubDistrictController.text =
              _company!.addressSubDistrict ?? '';
          _addressDistrictController.text = _company!.addressDistrict ?? '';
          _addressProvinceController.text = _company!.addressProvince ?? '';
          _addressCountryController.text = _company!.addressCountry ?? '';
          _addressZipcodeController.text = _company!.addressZipCode ?? '';
          _taxIdNumberController.text = _company!.taxIdNumber ?? '';
          _startDateController.text = _company!.startDate != null
              ? DateFormat('yyyy-MM-dd').format(_company!.startDate!)
              : '';
          _maintenanceDateController.text =
              _company!.maintenanceContractDate != null
                  ? DateFormat('yyyy-MM-dd')
                      .format(_company!.maintenanceContractDate!)
                  : '';
          _serialNumberController.text = _company!.serialNumber ?? '';
          _phoneNumberController.text = _company!.phoneNumber ?? '';
          _faxNumberController.text = _company!.faxNumber ?? '';
          _emailController.text = _company!.email ?? '';
          _websiteController.text = _company!.website ?? '';
          _primaryContactPersonController.text =
              _company!.primaryContactPerson ?? '';
        }
      });
    } catch (e) {
      _showSnackBar('Error loading company info: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await PlatformImagePicker.pickImage(); // ใช้ PlatformImagePicker
    if (pickedFile != null) {
      setState(() {
        _pickedLogoFile = pickedFile;
      });
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
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final companyToSave = Company(
        id: _company?.id,
        thaiName: _thaiNameController.text,
        englishName: _englishNameController.text.isEmpty
            ? null
            : _englishNameController.text,
        addressNo: _addressNoController.text.isEmpty
            ? null
            : _addressNoController.text,
        addressBuildingVillage: _addressBuildingVillageController.text.isEmpty
            ? null
            : _addressBuildingVillageController.text,
        addressAlley: _addressAlleyController.text.isEmpty
            ? null
            : _addressAlleyController.text,
        addressRoad: _addressRoadController.text.isEmpty
            ? null
            : _addressRoadController.text,
        addressSubDistrict: _addressSubDistrictController.text.isEmpty
            ? null
            : _addressSubDistrictController.text,
        addressDistrict: _addressDistrictController.text.isEmpty
            ? null
            : _addressDistrictController.text,
        addressProvince: _addressProvinceController.text.isEmpty
            ? null
            : _addressProvinceController.text,
        addressCountry: _addressCountryController.text.isEmpty
            ? null
            : _addressCountryController.text,
        addressZipCode: _addressZipcodeController.text.isEmpty
            ? null
            : _addressZipcodeController.text,
        taxIdNumber: _taxIdNumberController.text.isEmpty
            ? null
            : _taxIdNumberController.text,
        startDate: _startDateController.text.isNotEmpty
            ? DateTime.parse(_startDateController.text)
            : null,
        maintenanceContractDate: _maintenanceDateController.text.isNotEmpty
            ? DateTime.parse(_maintenanceDateController.text)
            : null,
        serialNumber: _serialNumberController.text.isEmpty
            ? null
            : _serialNumberController.text,
        phoneNumber: _phoneNumberController.text.isEmpty
            ? null
            : _phoneNumberController.text,
        faxNumber: _faxNumberController.text.isEmpty
            ? null
            : _faxNumberController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        website:
            _websiteController.text.isEmpty ? null : _websiteController.text,
        primaryContactPerson: _primaryContactPersonController.text.isEmpty
            ? null
            : _primaryContactPersonController.text,
      );

      if (_company == null || _company!.id == null) {
        // ไม่มีข้อมูลบริษัทเดิม -> สร้างใหม่
        await _companyService.createCompany(companyToSave,
            logoFile: _pickedLogoFile);
        _showSnackBar('บันทึกข้อมูลบริษัทสำเร็จ', Colors.green);
      } else {
        // มีข้อมูลบริษัทเดิม -> อัปเดต
        await _companyService.updateCompany(companyToSave,
            logoFile: _pickedLogoFile);
        _showSnackBar('อัปเดตข้อมูลบริษัทสำเร็จ', Colors.green);
      }
      await _fetchCompanyInfo(); // ดึงข้อมูลล่าสุดมาแสดงอีกครั้ง
    } catch (e) {
      print('Error saving company info: $e');
      _showSnackBar(
          'เกิดข้อผิดพลาดในการบันทึกข้อมูล: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // *** NEW: ฟังก์ชันสำหรับแสดง Card ค้นหารหัสไปรษณีย์ ***
  void _showZipcodeSearchCard() {
    ZipcodeListWidget.search(
      context,
      onSelected: (Zipcode selected) {
        setState(() {
          // กำหนดค่ากลับไปยัง TextFormField ที่เกี่ยวข้อง
          _addressSubDistrictController.text = selected.subDistrict;
          _addressDistrictController.text = selected.district;
          _addressProvinceController.text = selected.province;
          _addressZipcodeController.text = selected.zipcode;

          _showSnackBar(
              'เลือก: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}',
              Colors.green);
        });
      },
    );
    // ZipcodeSearchCard.show(
    //   context,
    //   onZipcodeSelected: (Zipcode selected) {
    //     setState(() {
    //       // กำหนดค่ากลับไปยัง TextFormField ที่เกี่ยวข้อง
    //       _addressSubDistrictController.text = selected.subDistrict;
    //       _addressDistrictController.text = selected.district;
    //       _addressProvinceController.text = selected.province;
    //       _addressZipcodeController.text = selected.zipcode;

    //       _showSnackBar(
    //           'เลือก: ${selected.subDistrict}, ${selected.district}, ${selected.province}, ${selected.zipcode}',
    //           Colors.green);
    //     });
    //   },
    // );
  }

  // *** (แก้ไข) โค้ดส่วนที่สร้าง TextFormField สำหรับ Address ***
  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // บ้านเลขที่ + อาคาร
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTextFormField(
              controller: _addressNoController,
              labelText: 'บ้านเลขที่ / ห้อง',
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildTextFormField(
              controller: _addressBuildingVillageController,
              labelText: 'อาคาร / หมู่บ้าน',
            )),
          ],
        ),
        // ซอย + ถนน
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTextFormField(
              controller: _addressAlleyController,
              labelText: 'ซอย',
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildTextFormField(
              controller: _addressRoadController,
              labelText: 'ถนน',
            )),
          ],
        ),
        // แขวง + เขต + จังหวัด + รหัสไปรษณีย์ (ปุ่มค้นหากึ่งกลาง)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue),
              tooltip: 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
              onPressed: _showZipcodeSearchCard,
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextFormField(
                        controller: _addressSubDistrictController,
                        labelText: 'แขวง / ตำบล',
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextFormField(
                        controller: _addressDistrictController,
                        labelText: 'เขต / อำเภอ',
                      )),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextFormField(
                        controller: _addressProvinceController,
                        labelText: 'จังหวัด',
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextFormField(
                        controller: _addressZipcodeController,
                        labelText: 'รหัสไปรษณีย์',
                        keyboardType: TextInputType.number,
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // ประเทศ
        _buildTextFormField(
          controller: _addressCountryController,
          labelText: 'ประเทศ',
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

  // *** เมธอดช่วยสร้าง TextFormField ที่มีสไตล์และการตรวจสอบพื้นฐาน ***
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () {
        //     widget.onExit?.call(); // เรียก Callback ย้อนกลับไป HomeScreen
        //   },
        // ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
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
                    // --- Logo Section ---
                    Center(
                      child: Column(
                        children: [
                          // ตรวจสอบเงื่อนไขการแสดงรูปภาพตามลำดับความสำคัญ
                          if (_pickedLogoFile !=
                              null) // 1. ถ้ามีการเลือกไฟล์ใหม่ (จาก ImagePicker)
                            FutureBuilder<Uint8List?>(
                              future: _pickedLogoFile!.isWeb
                                  ? Future.value(_pickedLogoFile!.bytes)
                                  : (File(_pickedLogoFile!.path!)
                                      .readAsBytes()),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasData) {
                                  return CircleAvatar(
                                    radius: 60,
                                    backgroundImage:
                                        MemoryImage(snapshot.data!),
                                  );
                                } else if (snapshot.hasError) {
                                  return const CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.error,
                                        size: 50, color: Colors.white),
                                  );
                                }
                                return const CircularProgressIndicator();
                              },
                            )
                          // 2. ถ้าไม่มีการเลือกไฟล์ใหม่ แต่มี logoUrl จากข้อมูลบริษัทที่ดึงมา (เมื่อโหลดหน้าจอ)
                          else if (_company?.logoUrl != null &&
                              _company!.logoUrl!.isNotEmpty)
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(
                                  _company!.logoUrl!), // <-- ส่วนนี้เลยครับ
                            )
                          // 3. ถ้าไม่มีโลโก้เลย (ไม่มีทั้ง _pickedLogoFile และ _company?.logoUrl)
                          else
                            const CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.business,
                                  size: 50, color: Colors.white),
                            ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('เลือกโลโก้'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // --- Basic Info ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _thaiNameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'ชื่อภาษาไทย *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.language),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณาป้อนชื่อภาษาไทย';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _englishNameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'ชื่อภาษาอังกฤษ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.language),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _taxIdNumberController,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'เลขประจำตัวผู้เสียภาษี *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาป้อนเลขประจำตัวผู้เสียภาษี';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- Address Section ---
                    const Text('ที่อยู่',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildAddressFields(),
                    const SizedBox(height: 20),

                    // --- Contact Info ---
                    const Text('ข้อมูลติดต่อ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneNumberController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'เบอร์โทรศัพท์',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _faxNumberController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'เบอร์แฟกซ์',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.fax),
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
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'อีเมล',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _websiteController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'เว็บไซต์',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _primaryContactPersonController,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'ผู้ติดต่อหลัก',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Contract & Serial Info ---
                    const Text('ข้อมูลสัญญาและอนุกรม',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startDateController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'วันที่เริ่มใช้',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(_startDateController),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _maintenanceDateController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'วันที่เริ่มสัญญาบำรุงรักษาล่าสุด',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month),
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
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'หมายเลขอนุกรม',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- Buttons ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveCompanyInfo,
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: Text(
                                _isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล'),
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
                                _pickedLogoFile = null; // เปลี่ยนเป็น null
                                _company?.logoUrl =
                                    null; // เคลียร์รูปโลโก้ที่แสดง
                              });
                              _showSnackBar(
                                  'ล้างข้อมูลในฟอร์มแล้ว', Colors.orange);
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้างข้อมูล'),
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
