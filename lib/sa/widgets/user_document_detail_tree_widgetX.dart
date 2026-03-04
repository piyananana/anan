// widgets/user_document_detail_tree_widget.dart

import 'package:flutter/material.dart';
import 'dart:collection'; // สำหรับ HashSet
import '../models/module_document.dart';

class ModuleDocumentDetailTreeWidget extends StatefulWidget {
  final List<ModuleDocument> lists;
  final Set<int> initialGrantedIds;
  final bool isEditing;
  final Function(Set<int>) onPermissionsChanged;

  const ModuleDocumentDetailTreeWidget({
    super.key,
    required this.lists,
    required this.initialGrantedIds,
    required this.isEditing,
    required this.onPermissionsChanged,
  });

  @override
  State<ModuleDocumentDetailTreeWidget> createState() =>
      _ModuleDocumentDetailTreeWidgetState();
}

class _ModuleDocumentDetailTreeWidgetState
    extends State<ModuleDocumentDetailTreeWidget> {
  late Set<int>
      _currentGrantedIds; // ใช้ HashSet เพื่อประสิทธิภาพในการค้นหาและเพิ่ม/ลบ
  late List<ModuleDocument> _listTree;
  late Map<int, ModuleDocument>
      _detailMap; // สำหรับค้นหาด้วย ID ได้เร็วขึ้น

  @override
  void initState() {
    super.initState();
    _currentGrantedIds = HashSet.from(widget.initialGrantedIds);
    _buildDetailTree();
    _ensureParentPermissions(); // <-- **สำคัญ**: เรียกใช้เมื่อเริ่มต้นเพื่อแก้ไขสถานะ Parent
  }

  @override
  void didUpdateWidget(covariant ModuleDocumentDetailTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัปเดตเมื่อ lists หรือ initialGrantedIds เปลี่ยนไป
    if (widget.lists != oldWidget.lists ||
        !_isSetEqual(widget.initialGrantedIds, oldWidget.initialGrantedIds)) {
      _currentGrantedIds = HashSet.from(widget.initialGrantedIds);
      _buildDetailTree();
      _ensureParentPermissions(); // <-- **สำคัญ**: เรียกใช้เมื่อ widget อัปเดต
    }
  }

  bool _isSetEqual(Set<int> set1, Set<int> set2) {
    if (set1.length != set2.length) return false;
    return set1.containsAll(set2);
  }

  void _buildDetailTree() {
    _detailMap = {for (var detail in widget.lists) detail.id: detail};
    _listTree = _buildTree(widget.lists, null);
  }

  List<ModuleDocument> _buildTree(List<ModuleDocument> details, int? parentId) {
    final List<ModuleDocument> result = details
        .where((detail) => detail.parentId == parentId)
        .toList()
        .cast<ModuleDocument>() // Ensure it's cast to List<ModuleDocument>
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (var detail in result) {
      detail.children = _buildTree(details, detail.id);
    }
    return result;
  }

  void _togglePermission(int detailId, bool? value) {
    if (!widget.isEditing) return; // ไม่อนุญาตให้แก้ไขในโหมด View

    setState(() {
      if (value == true) {
        _grantPermission(detailId);
      } else {
        _revokePermission(detailId);
      }
      _ensureParentPermissions(); // <-- **สำคัญ**: ตรวจสอบและเพิ่มสิทธิ์ Parent หลังการเปลี่ยนแปลง
      widget.onPermissionsChanged(
          _currentGrantedIds); // ส่งค่าที่ถูกแก้ไขแล้วกลับไป
    });
  }

// // **** แก้ไขเมธอด _togglePermission ****
//   void _togglePermission(int detailId, bool? value) {
//     if (!widget.isEditing) return;

//     final currentDetail = _detailMap[detailId];
//     if (currentDetail == null) return;

//     // คำนวณสถานะปัจจุบัน (true/false/null) ของ Checkbox
//     final bool? currentState = _getCheckboxState(currentDetail);

//     setState(() {
//       // ถ้าสถานะปัจจุบันคือ 'ถูกเลือกทั้งหมด' (true) -> ให้ยกเลิกสิทธิ์ทั้งหมด (Revoke)
//       if (currentState == true) {
//         _revokePermission(detailId);
//       } else {
//         // ถ้าสถานะปัจจุบันคือ 'ว่าง' (false) หรือ 'บางส่วน' (null)
//         // -> ให้สิทธิ์ทั้งหมด (Grant)
//         _grantPermission(detailId);
//       }

//       _ensureParentPermissions();
//       widget.onPermissionsChanged(_currentGrantedIds);
//     });
//   }

  void _grantPermission(int detailId) {
    if (!_currentGrantedIds.contains(detailId)) {
      _currentGrantedIds.add(detailId);
    }
    // Grant permissions to all children (cascading)
    _detailMap[detailId]?.children.forEach((child) {
      _grantPermission(child.id);
    });
  }

  void _revokePermission(int detailId) {
    if (_currentGrantedIds.contains(detailId)) {
      _currentGrantedIds.remove(detailId);
    }
    // Revoke permissions from all children (cascading)
    _detailMap[detailId]?.children.forEach((child) {
      _revokePermission(child.id);
    });
  }

  // New method: Ensures that if any child is selected, its parent is also selected.
  // This is crucial for correctly storing permissions for parent nodes.
  void _ensureParentPermissions() {
    // สร้างสำเนาของ Set เพื่อวนลูป ในขณะที่เราอาจจะแก้ไข Set ต้นฉบับ
    final Set<int> detailsToCheck = HashSet.from(_currentGrantedIds);
    Set<int> newParentsToAdd = HashSet();

    for (int detailId in detailsToCheck) {
      ModuleDocument? currentHead = _detailMap[detailId];
      // เดินทางขึ้นไปหา Parent เรื่อยๆ จนกว่าจะไม่มี Parent หรือ Parent ได้รับสิทธิ์แล้ว
      while (currentHead != null && currentHead.parentId != null) {
        final parentId = currentHead.parentId!;
        // ถ้า Parent ยังไม่ได้รับสิทธิ์ ให้เพิ่ม Parent เข้าไปในรายการที่จะเพิ่ม
        if (!_currentGrantedIds.contains(parentId)) {
          newParentsToAdd.add(parentId);
        }
        currentHead = _detailMap[parentId]; // เลื่อนขึ้นไปหา Parent ของ Parent
      }
    }
    // เพิ่ม Parent ทั้งหมดที่ระบุเข้าไปใน Set สิทธิ์ปัจจุบัน
    _currentGrantedIds.addAll(newParentsToAdd);
  }

  // This method checks the checkbox state based on children's state
  // and ensures indeterminate state is handled correctly for display.
  bool? _getCheckboxState(ModuleDocument detail) {
    // ถ้าเมนูนี้ถูกเลือกโดยตรง
    if (_currentGrantedIds.contains(detail.id)) {
      // ตรวจสอบว่ามีเมนูย่อยที่ "ไม่" ได้รับสิทธิ์ครบทั้งหมดหรือไม่
      // ถ้ามีเมนูย่อยที่ไม่ได้ถูกเลือกทั้งหมด จะเป็น indeterminate (null)
      // มิฉะนั้นจะเป็น true (ถูกเลือกทั้งหมด)
      bool allChildrenGranted = true;
      if (detail.children.isNotEmpty) {
        allChildrenGranted = detail.children
            .every((child) => _currentGrantedIds.contains(child.id));
      }
      return allChildrenGranted ? true : null;
    }

    // ถ้าเมนูนี้ไม่มีเมนูย่อยและไม่ได้ถูกเลือกเอง ก็คือ false
    if (detail.children.isEmpty) {
      return false;
    }

    // สำหรับเมนูที่มีเมนูย่อย แต่ตัวมันเองไม่ได้ถูกเลือกโดยตรง
    bool anyChildSelected = false;
    for (var child in detail.children) {
      if (_currentGrantedIds.contains(child.id)) {
        anyChildSelected = true;
        break; // พบเมนูย่อยที่ถูกเลือกแล้ว
      }
    }

    // ถ้ามีเมนูย่อยบางส่วนถูกเลือก (แต่ตัวมันเองไม่ได้ถูกเลือก) ให้เป็น indeterminate
    if (anyChildSelected) {
      return null;
    } else {
      // ถ้าไม่มีเมนูย่อยใดๆ ถูกเลือกเลย ก็คือ false
      return false;
    }
  }

// // **** แก้ไขเมธอด _getCheckboxState ****
//   // คำนวณสถานะ Checked/Unchecked/Indeterminate จาก Child Node โดยตรง
//   bool? _getCheckboxState(ModuleDocument detail) {
//     // 1. ถ้าไม่มีเมนูย่อย (Leaf node) ให้ดูสถานะของตัวเอง
//     if (detail.children.isEmpty) {
//       return _currentGrantedIds.contains(detail.id);
//     }

//     // 2. ถ้ามีเมนูย่อย (Parent node): คำนวณสถานะจาก Child ระดับแรก
//     int totalDirectChildren = detail.children.length;
//     int grantedDirectChildrenCount = 0;

//     // นับจำนวน Child ระดับแรกที่ถูกเลือก
//     for (var child in detail.children) {
//       if (_currentGrantedIds.contains(child.id)) {
//         grantedDirectChildrenCount++;
//       }
//     }

//     if (grantedDirectChildrenCount == 0) {
//       return false; // Child 0% ถูกเลือก
//     }

//     if (grantedDirectChildrenCount == totalDirectChildren) {
//       return true; // Child 100% ถูกเลือก
//     }

//     // Child ถูกเลือกบางส่วน (Tristate)
//     return null;
//   }

// bool? _getCheckboxState(ModuleDocument detail) {
//   // ถ้าเป็น leaf node (ไม่มี children)
//   if (detail.children.isEmpty) {
//     return _currentGrantedIds.contains(detail.id);
//   }

//   // ถ้าเป็น parent node
//   bool allChildrenSelected = true;
//   bool someChildrenSelected = false;

//   for (var child in detail.children) {
//     bool? childState = _getCheckboxState(child);
//     if (childState == true) {
//       someChildrenSelected = true;
//     } else if (childState != false) { // null หรือ false
//       allChildrenSelected = false;
//     }
//   }

//   if (allChildrenSelected) {
//     return true;
//   } else if (someChildrenSelected) {
//     return null; // indeterminate
//   } else {
//     return false;
//   }
// }

  // Build a single detail item (recursive)
  Widget _buildDetailItem(ModuleDocument detail, int level) {
    // ในโหมด View: จะแสดงเฉพาะเมนูที่ถูก 'granted' หรือเป็น 'parent' ของเมนูที่ถูก granted
    if (!widget.isEditing) {
      // ตรวจสอบว่าเมนูนี้หรือเมนูย่อยใดๆ ภายใต้มันถูกเลือกหรือไม่
      // ถ้าไม่มีการเลือกในสาขาเมนูนี้เลย ก็ให้ซ่อนไป
      if (!_hasAnyGrantedInSubtree(detail)) {
        return const SizedBox.shrink(); // ซ่อนเมนูนี้
      }
    }

    bool? checkboxState = _getCheckboxState(detail); // รับสถานะ checkbox

    return Column(
      // crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: Row(
            children: [
              if (widget.isEditing) // แสดง Checkbox เฉพาะในโหมดแก้ไข
                Checkbox(
                  value: checkboxState,
                  tristate:
                      detail.children.isNotEmpty, // เป็น tristate ถ้ามีเมนูย่อย
                  // onChanged: (bool? value) =>
                  //     _togglePermission(detail.id, value),
                  onChanged: (bool? value) {
                    setState(() {
                      checkboxState = value;
                      _togglePermission(detail.id, value);
                    });
                  },
                  activeColor: Colors.red, // สีแดงเมื่อเลือก
                  checkColor: Colors.white, // สีของเครื่องหมายถูก
                ),
              Expanded(
                child: Text(
                  '${detail.docCode} - ${detail.docNameThai}',
                  style: TextStyle(
                    fontWeight: detail.children.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.black, // สีตัวอักษรเป็นสีดำเสมอในโหมดแก้ไข
                  ),
                ),
              ),
            ],
          ),
        ),
        // สร้างเมนูย่อยแบบ Recursive
        ...detail.children.map((child) => _buildDetailItem(child, level + 1)),
      ],
    );
  }

  // Helper method to check if any detail in the subtree (including itself) is granted
  bool _hasAnyGrantedInSubtree(ModuleDocument detail) {
    if (_currentGrantedIds.contains(detail.id)) {
      return true;
    }
    for (var child in detail.children) {
      if (_hasAnyGrantedInSubtree(child)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lists.isEmpty) {
      return const Center(child: Text('ไม่พบรายการข้อมูลในระบบ'));
    }

    // กรองเมนูระดับบนสุดที่จะแสดง
    final List<ModuleDocument> topLevelToDisplay = widget.isEditing
        ? _listTree // ในโหมดแก้ไข แสดงเมนูระดับบนสุดทั้งหมด
        : _listTree
            .where((detail) => _hasAnyGrantedInSubtree(detail))
            .toList(); // ในโหมด View แสดงเฉพาะเมนูระดับบนสุดที่มีการให้สิทธิ์ใน subtree

    if (topLevelToDisplay.isEmpty && !widget.isEditing) {
      return const Center(
          child: Text('ผู้ใช้ยังไม่ได้รับสิทธิ์เข้าถึงประเภทเอกสารใดๆ'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: topLevelToDisplay
            .map((detail) => _buildDetailItem(detail, 1))
            .toList(),
      ),
    );
  }
}
