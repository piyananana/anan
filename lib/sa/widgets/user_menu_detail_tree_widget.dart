// widgets/permission_menu_treeview.dart

import 'package:flutter/material.dart';
import 'dart:collection'; // สำหรับ HashSet
import '../models/menu.dart'; // ตรวจสอบให้แน่ใจว่า path ถูกต้อง

class UserMenuDetailTreeWidget extends StatefulWidget {
  final List<Menu> lists; // เมนูทั้งหมดที่มีในระบบ
  final Set<int> initialGrantedIds; // เมนูที่ผู้ใช้คนนี้มีสิทธิ์เริ่มต้น
  final bool isEditing; // true ถ้าอยู่ในโหมดแก้ไข, false ถ้าเป็นโหมดดู
  final Function(Set<int>) onPermissionsChanged; // Callback เมื่อมีการเลือก/ยกเลิกสิทธิ์

  const UserMenuDetailTreeWidget({
    super.key,
    required this.lists,
    required this.initialGrantedIds,
    required this.isEditing,
    required this.onPermissionsChanged,
  });

  @override
  State<UserMenuDetailTreeWidget> createState() => _UserMenuDetailTreeWidget();
}

class _UserMenuDetailTreeWidget extends State<UserMenuDetailTreeWidget> {
  late Set<int> _currentGrantedIds;   // ใช้ HashSet เพื่อประสิทธิภาพในการค้นหาและเพิ่ม/ลบ
  late List<Menu> _listRows; // เมนูในรูปแบบ Tree Structure
  late Map<int, Menu> _mapRow; // สำหรับค้นหาเมนูด้วย ID ได้เร็วขึ้น

  @override
  void initState() {
    super.initState();
    _currentGrantedIds = HashSet.from(widget.initialGrantedIds);
    _buildTreeStructures();
    _ensureParentPermissions(); // <-- **สำคัญ**: เรียกใช้เมื่อเริ่มต้นเพื่อแก้ไขสถานะ Parent
  }

  @override
  void didUpdateWidget(covariant UserMenuDetailTreeWidget oldWidget) {
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
    _mapRow = { for (var row in widget.lists) row.id: row };
    _listRows = _buildTree(widget.lists, null);
  }

  List<Menu> _buildTree(List<Menu> rows, int? parentId) {
    final List<Menu> result = rows
        .where((row) => row.parentId == parentId)
        .toList()
        .cast<Menu>() // Ensure it's cast to List<Menu>
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
      Menu? currentRow = _mapRow[rowId];
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
  bool? _getCheckboxState(Menu row) {
    // ถ้าเมนูนี้ถูกเลือกโดยตรง
    if (_currentGrantedIds.contains(row.id)) {
      // ตรวจสอบว่ามีเมนูย่อยที่ "ไม่" ได้รับสิทธิ์ครบทั้งหมดหรือไม่
      // ถ้ามีเมนูย่อยที่ไม่ได้ถูกเลือกทั้งหมด จะเป็น indeterminate (null)
      // มิฉะนั้นจะเป็น true (ถูกเลือกทั้งหมด)
      bool allChildrenGranted = true;
      if (row.children.isNotEmpty) {
        allChildrenGranted = row.children.every((child) => _currentGrantedIds.contains(child.id));
      }
      return allChildrenGranted ? true : null;
    }

    // ถ้าเมนูนี้ไม่มีเมนูย่อยและไม่ได้ถูกเลือกเอง ก็คือ false
    if (row.children.isEmpty) {
      return false;
    }

    // สำหรับเมนูที่มีเมนูย่อย แต่ตัวมันเองไม่ได้ถูกเลือกโดยตรง
    bool anyChildSelected = false;
    for (var child in row.children) {
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

  // Build a single menu item (recursive)
  Widget _buildNodeItem(Menu row, int level) {
    // ในโหมด View: จะแสดงเฉพาะเมนูที่ถูก 'granted' หรือเป็น 'parent' ของเมนูที่ถูก granted
    if (!widget.isEditing) {
      // ตรวจสอบว่าเมนูนี้หรือเมนูย่อยใดๆ ภายใต้มันถูกเลือกหรือไม่
      // ถ้าไม่มีการเลือกในสาขาเมนูนี้เลย ก็ให้ซ่อนไป
      if (!_hasAnyGrantedInSubtree(row)) {
        return const SizedBox.shrink(); // ซ่อนเมนูนี้
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
                  tristate: row.children.isNotEmpty, // เป็น tristate ถ้ามีเมนูย่อย
                  onChanged: (bool? value) => _togglePermission(row.id, value),
                  activeColor: Colors.red, // สีแดงเมื่อเลือก
                  checkColor: Colors.white, // สีของเครื่องหมายถูก
                ),
              Expanded(
                child: Text(
                  row.menuName,
                  style: TextStyle(
                    fontWeight: row.children.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black, // สีตัวอักษรเป็นสีดำเสมอในโหมดแก้ไข
                  ),
                ),
              ),
            ],
          ),
        ),
        // สร้างเมนูย่อยแบบ Recursive
        ...row.children.map((child) => _buildNodeItem(child, level + 1)).toList(),
      ],
    );
  }

  // Helper method to check if any menu in the subtree (including itself) is granted
  bool _hasAnyGrantedInSubtree(Menu row) {
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
    if (widget.lists.isEmpty) {
      return const Center(child: Text('ไม่พบรายการเมนูในระบบ'));
    }

    // กรองเมนูระดับบนสุดที่จะแสดง
    final List<Menu> topLevelMenusToDisplay = widget.isEditing
        ? _listRows // ในโหมดแก้ไข แสดงเมนูระดับบนสุดทั้งหมด
        : _listRows
            .where((row) => _hasAnyGrantedInSubtree(row))
            .toList(); // ในโหมด View แสดงเฉพาะเมนูระดับบนสุดที่มีการให้สิทธิ์ใน subtree

    if (topLevelMenusToDisplay.isEmpty && !widget.isEditing) {
      return const Center(
          child: Text('ผู้ใช้ยังไม่ได้รับสิทธิ์เข้าถึงเมนูใดๆ'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: topLevelMenusToDisplay
            .map((menu) => _buildNodeItem(menu, 0))
            .toList(),
      ),
    );
  }
}
