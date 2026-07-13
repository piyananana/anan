// widgets/permission_menu_treeview.dart

import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:provider/provider.dart';
import '../models/module_document.dart';
import '../services/language_provider.dart';

class UserDocumentDetailTreeWidget extends StatefulWidget {
  final List<ModuleDocument> lists; // ประเภทเอกสารทั้งหมดที่มีในระบบ
  final Set<int> initialGrantedIds; // ประเภทเอกสารที่ผู้ใช้คนนี้มีสิทธิ์เริ่มต้น
  final bool isEditing; // true ถ้าอยู่ในโหมดแก้ไข, false ถ้าเป็นโหมดดู
  final Function(Set<int>) onPermissionsChanged; // Callback เมื่อมีการเลือก/ยกเลิกสิทธิ์

  const UserDocumentDetailTreeWidget({
    super.key,
    required this.lists,
    required this.initialGrantedIds,
    required this.isEditing,
    required this.onPermissionsChanged,
  });

  @override
  State<UserDocumentDetailTreeWidget> createState() =>
      _UserDocumentDetailTreeWidgetState();
}

class _UserDocumentDetailTreeWidgetState
    extends State<UserDocumentDetailTreeWidget> {
  late Set<int> _currentGrantedIds; // ใช้ HashSet เพื่อประสิทธิภาพในการค้นหาและเพิ่ม/ลบ
  late List<ModuleDocument> _listRows; // ประเภทเอกสารในรูปแบบ Tree Structure
  late Map<int, ModuleDocument> _mapRow; // สำหรับค้นหาประเภทเอกสารด้วย ID ได้เร็วขึ้น

  @override
  void initState() {
    super.initState();
    _currentGrantedIds = HashSet.from(widget.initialGrantedIds);
    _buildTreeStructures();
    _ensureParentPermissions(); // <-- **สำคัญ**: เรียกใช้เมื่อเริ่มต้นเพื่อแก้ไขสถานะ Parent
  }

  @override
  void didUpdateWidget(covariant UserDocumentDetailTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัปเดตเมื่อ lists หรือ initialGrantedIds เปลี่ยนไป
    if (widget.lists != oldWidget.lists ||
        !_isSetEqual(widget.initialGrantedIds, oldWidget.initialGrantedIds)) {
      _currentGrantedIds = HashSet.from(widget.initialGrantedIds);
      _buildTreeStructures();
      _ensureParentPermissions(); // <-- **สำคัญ**: เรียกใช้เมื่อ widget อัปเดต
    }
  }

  bool _isSetEqual(Set<int> set1, Set<int> set2) {
    if (set1.length != set2.length) return false;
    return set1.containsAll(set2);
  }

  void _buildTreeStructures() {
    _mapRow = {for (var row in widget.lists) row.id: row};
    _listRows = _buildTree(widget.lists, null);
  }

  List<ModuleDocument> _buildTree(List<ModuleDocument> rows, int? parentId) {
    final List<ModuleDocument> result = rows
        .where((row) => row.parentId == parentId)
        .toList()
        .cast<ModuleDocument>() // Ensure it's cast to List<ModuleDocument>
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (var row in result) {
      row.children = _buildTree(rows, row.id);
    }
    return result;
  }

  void _togglePermission(int rowId, bool? value) {
    if (!widget.isEditing) return; // ไม่อนุญาตให้แก้ไขในโหมด View

    setState(() {
      if (value == true) {
        _grantPermission(rowId);
      } else {
        _revokePermission(rowId);
      }
      _ensureParentPermissions(); // <-- **สำคัญ**: ตรวจสอบและเพิ่มสิทธิ์ Parent หลังการเปลี่ยนแปลง
      widget.onPermissionsChanged(_currentGrantedIds); // ส่งค่าที่ถูกแก้ไขแล้วกลับไป
    });
  }

  void _grantPermission(int rowId) {
    if (!_currentGrantedIds.contains(rowId)) {
      _currentGrantedIds.add(rowId);
    }
    // Grant permissions to all children (cascading)
    _mapRow[rowId]?.children.forEach((child) {
      _grantPermission(child.id);
    });
  }

  void _revokePermission(int rowId) {
    if (_currentGrantedIds.contains(rowId)) {
      _currentGrantedIds.remove(rowId);
    }
    // Revoke permissions from all children (cascading)
    _mapRow[rowId]?.children.forEach((child) {
      _revokePermission(child.id);
    });
  }

  // New method: Ensures that if any child is selected, its parent is also selected.
  // This is crucial for correctly storing permissions for parent nodes.
  void _ensureParentPermissions() {
    // สร้างสำเนาของ Set เพื่อวนลูป ในขณะที่เราอาจจะแก้ไข Set ต้นฉบับ
    final Set<int> rowsToCheck = HashSet.from(_currentGrantedIds);
    Set<int> newParentsToAdd = HashSet();

    for (int rowId in rowsToCheck) {
      ModuleDocument? currentRow = _mapRow[rowId];
      // เดินทางขึ้นไปหา Parent เรื่อยๆ จนกว่าจะไม่มี Parent หรือ Parent ได้รับสิทธิ์แล้ว
      while (currentRow != null && currentRow.parentId != null) {
        final parentId = currentRow.parentId!;
        // ถ้า Parent ยังไม่ได้รับสิทธิ์ ให้เพิ่ม Parent เข้าไปในรายการที่จะเพิ่ม
        if (!_currentGrantedIds.contains(parentId)) {
          newParentsToAdd.add(parentId);
        }
        currentRow = _mapRow[parentId]; // เลื่อนขึ้นไปหา Parent ของ Parent
      }
    }
    // เพิ่ม Parent ทั้งหมดที่ระบุเข้าไปใน Set สิทธิ์ปัจจุบัน
    _currentGrantedIds.addAll(newParentsToAdd);
  }

  // This method checks the checkbox state based on children's state
  // and ensures indeterminate state is handled correctly for display.
  bool? _getCheckboxState(ModuleDocument row) {
    // ถ้าประเภทเอกสารนี้ถูกเลือกโดยตรง
    if (_currentGrantedIds.contains(row.id)) {
      // ตรวจสอบว่ามีประเภทเอกสารย่อยที่ "ไม่" ได้รับสิทธิ์ครบทั้งหมดหรือไม่
      // ถ้ามีประเภทเอกสารย่อยที่ไม่ได้ถูกเลือกทั้งหมด จะเป็น indeterminate (null)
      // มิฉะนั้นจะเป็น true (ถูกเลือกทั้งหมด)
      bool allChildrenGranted = true;
      if (row.children.isNotEmpty) {
        allChildrenGranted = row.children.every((child) => _currentGrantedIds.contains(child.id));
      }
      return allChildrenGranted ? true : null;
    }

    // ถ้าประเภทเอกสารนี้ไม่มีประเภทเอกสารย่อยและไม่ได้ถูกเลือกเอง ก็คือ false
    if (row.children.isEmpty) {
      return false;
    }

    // สำหรับประเภทเอกสารที่มีประเภทเอกสารย่อย แต่ตัวมันเองไม่ได้ถูกเลือกโดยตรง
    bool anyChildSelected = false;
    for (var child in row.children) {
      if (_currentGrantedIds.contains(child.id)) {
        anyChildSelected = true;
        break; // พบประเภทเอกสารย่อยที่ถูกเลือกแล้ว
      }
    }

    // ถ้ามีประเภทเอกสารย่อยบางส่วนถูกเลือก (แต่ตัวมันเองไม่ได้ถูกเลือก) ให้เป็น indeterminate
    if (anyChildSelected) {
      return null;
    } else {
      // ถ้าไม่มีประเภทเอกสารย่อยใดๆ ถูกเลือกเลย ก็คือ false
      return false;
    }
  }

  // Build a single menu item (recursive)
  Widget _buildNodeItem(ModuleDocument row, int level) {
    // ในโหมด View: จะแสดงเฉพาะประเภทเอกสารที่ถูก 'granted' หรือเป็น 'parent' ของประเภทเอกสารที่ถูก granted
    if (!widget.isEditing) {
      // ตรวจสอบว่าประเภทเอกสารนี้หรือประเภทเอกสารย่อยใดๆ ภายใต้มันถูกเลือกหรือไม่
      // ถ้าไม่มีการเลือกในสาขาประเภทเอกสารนี้เลย ก็ให้ซ่อนไป
      if (!_hasAnyGrantedInSubtree(row)) {
        return const SizedBox.shrink(); // ซ่อนประเภทเอกสารนี้
      }
    }

    bool? checkboxState = _getCheckboxState(row); // รับสถานะ checkbox

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: Row(
            children: [
              if (widget.isEditing) // แสดง Checkbox เฉพาะในโหมดแก้ไข
                Checkbox(
                  value: checkboxState,
                  tristate:
                      row.children.isNotEmpty, // เป็น tristate ถ้ามีประเภทเอกสารย่อย
                  onChanged: (bool? value) => _togglePermission(row.id, value),
                  activeColor: Colors.red, // สีแดงเมื่อเลือก
                  checkColor: Colors.white, // สีของเครื่องหมายถูก
                ),
              Expanded(
                child: Text(
                  '${row.docCode} - ${row.docNameThai}',
                  style: TextStyle(
                    fontWeight: row.children.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.black, // สีตัวอักษรเป็นสีดำเสมอในโหมดแก้ไข
                  ),
                ),
              ),
            ],
          ),
        ),
        // สร้างประเภทเอกสารย่อยแบบ Recursive
        ...row.children.map((child) => _buildNodeItem(child, level + 1)).toList(),
      ],
    );
  }

  // Helper method to check if any menu in the subtree (including itself) is granted
  bool _hasAnyGrantedInSubtree(ModuleDocument row) {
    if (_currentGrantedIds.contains(row.id)) {
      return true;
    }
    for (var child in row.children) {
      if (_hasAnyGrantedInSubtree(child)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (widget.lists.isEmpty) {
      return Center(child: Text(isEnglish
          ? 'No document types found in the system'
          : 'ไม่พบรายการประเภทเอกสารในระบบ'));
    }

    final List<ModuleDocument> topLevelToDisplay = widget.isEditing
        ? _listRows
        : _listRows
            .where((row) => _hasAnyGrantedInSubtree(row))
            .toList();

    if (topLevelToDisplay.isEmpty && !widget.isEditing) {
      return Center(child: Text(isEnglish
          ? 'User has not been granted access to any document types'
          : 'ผู้ใช้ยังไม่ได้รับสิทธิ์เข้าถึงประเภทเอกสารใดๆ'));
    }

    return SingleChildScrollView(
      key: const Key('user_document_detail_tree_view_column'),
      child: Column(
        // key: const Key('user_document_detail_tree_view_column'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: topLevelToDisplay
            .map((row) => _buildNodeItem(row, 1))
            .toList(),
      ),
    );
  }
}
