// widgets/user_menu_detail_tree_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu.dart';
import '../models/menu_permission.dart';
import '../services/language_provider.dart';

class UserMenuDetailTreeWidget extends StatefulWidget {
  final List<Menu> lists;
  final Map<int, MenuPermission> initialPermissions;
  final bool isEditing;
  final Function(Map<int, MenuPermission>) onPermissionsChanged;

  const UserMenuDetailTreeWidget({
    super.key,
    required this.lists,
    required this.initialPermissions,
    required this.isEditing,
    required this.onPermissionsChanged,
  });

  @override
  State<UserMenuDetailTreeWidget> createState() => _UserMenuDetailTreeWidget();
}

class _UserMenuDetailTreeWidget extends State<UserMenuDetailTreeWidget> {
  late Map<int, MenuPermission> _currentPermissions;
  late List<Menu> _listRows;
  late Map<int, Menu> _mapRow;

  Set<int> get _currentGrantedIds => _currentPermissions.keys.toSet();

  @override
  void initState() {
    super.initState();
    _currentPermissions = Map.from(widget.initialPermissions);
    _buildTreeStructures();
    _ensureParentPermissions();
  }

  @override
  void didUpdateWidget(covariant UserMenuDetailTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lists != oldWidget.lists ||
        !_isMapEqual(widget.initialPermissions, oldWidget.initialPermissions)) {
      _currentPermissions = Map.from(widget.initialPermissions);
      _buildTreeStructures();
      _ensureParentPermissions();
    }
  }

  bool _isMapEqual(Map<int, MenuPermission> a, Map<int, MenuPermission> b) {
    if (a.length != b.length) return false;
    return a.keys.every((k) => b.containsKey(k));
  }

  void _buildTreeStructures() {
    _mapRow = {for (var row in widget.lists) row.id: row};
    _listRows = _buildTree(widget.lists, null);
  }

  List<Menu> _buildTree(List<Menu> rows, int? parentId) {
    final List<Menu> result = rows
        .where((row) => row.parentId == parentId)
        .toList()
        .cast<Menu>()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (var row in result) {
      row.children = _buildTree(rows, row.id);
    }
    return result;
  }

  void _togglePermission(int rowId, bool? value) {
    if (!widget.isEditing) return;

    setState(() {
      if (value == true) {
        _grantPermission(rowId);
      } else {
        _revokePermission(rowId);
      }
      _ensureParentPermissions();
      widget.onPermissionsChanged(_currentPermissions);
    });
  }

  void _grantPermission(int rowId) {
    if (!_currentPermissions.containsKey(rowId)) {
      _currentPermissions[rowId] = MenuPermission(menuId: rowId);
    }
    _mapRow[rowId]?.children.forEach((child) => _grantPermission(child.id));
  }

  void _revokePermission(int rowId) {
    _currentPermissions.remove(rowId);
    _mapRow[rowId]?.children.forEach((child) => _revokePermission(child.id));
  }

  void _ensureParentPermissions() {
    final Set<int> rowsToCheck = Set.from(_currentPermissions.keys);
    for (int rowId in rowsToCheck) {
      Menu? currentRow = _mapRow[rowId];
      while (currentRow != null && currentRow.parentId != null) {
        final parentId = currentRow.parentId!;
        if (!_currentPermissions.containsKey(parentId)) {
          _currentPermissions[parentId] = MenuPermission(menuId: parentId);
        }
        currentRow = _mapRow[parentId];
      }
    }
  }

  bool? _getCheckboxState(Menu row) {
    if (_currentGrantedIds.contains(row.id)) {
      bool allChildrenGranted = true;
      if (row.children.isNotEmpty) {
        allChildrenGranted =
            row.children.every((child) => _currentGrantedIds.contains(child.id));
      }
      return allChildrenGranted ? true : null;
    }

    if (row.children.isEmpty) {
      return false;
    }

    bool anyChildSelected = false;
    for (var child in row.children) {
      if (_currentGrantedIds.contains(child.id)) {
        anyChildSelected = true;
        break;
      }
    }

    return anyChildSelected ? null : false;
  }

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

  Widget _buildPermissionRow(int menuId, bool isEnglish) {
    final perm = _currentPermissions[menuId]!;

    Widget permCheckbox(
        String labelTh, String labelEn, bool value, ValueChanged<bool?> onChanged) {
      final label = isEnglish ? labelEn : labelTh;
      return InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Text(label, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    }

    void updatePerm(MenuPermission updated) {
      setState(() {
        _currentPermissions[menuId] = updated;
        widget.onPermissionsChanged(_currentPermissions);
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
        children: [
          permCheckbox('ดู', 'View', perm.canView,
              (v) => updatePerm(perm.copyWith(canView: v ?? perm.canView))),
          permCheckbox('สร้าง', 'Create', perm.canCreate,
              (v) => updatePerm(perm.copyWith(canCreate: v ?? perm.canCreate))),
          permCheckbox('แก้ไข', 'Edit', perm.canEdit,
              (v) => updatePerm(perm.copyWith(canEdit: v ?? perm.canEdit))),
          permCheckbox('ลบ', 'Delete', perm.canDelete,
              (v) => updatePerm(perm.copyWith(canDelete: v ?? perm.canDelete))),
          permCheckbox('อนุมัติ', 'Approve', perm.canApprove,
              (v) => updatePerm(perm.copyWith(canApprove: v ?? perm.canApprove))),
          permCheckbox('พิมพ์', 'Print', perm.canPrint,
              (v) => updatePerm(perm.copyWith(canPrint: v ?? perm.canPrint))),
          permCheckbox('ส่งออก', 'Export', perm.canExport,
              (v) => updatePerm(perm.copyWith(canExport: v ?? perm.canExport))),
        ],
      ),
    );
  }

  Widget _buildNodeItem(Menu row, int level, bool isEnglish) {
    if (!widget.isEditing) {
      if (!_hasAnyGrantedInSubtree(row)) {
        return const SizedBox.shrink();
      }
    }

    final bool isFolder = row.menuType == 'folder';
    bool? checkboxState = _getCheckboxState(row);

    // Show permission row only for non-folder items that have been granted
    final bool showPerms =
        widget.isEditing &&
        !isFolder &&
        _currentPermissions.containsKey(row.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 16.0, top: 1, bottom: 1),
          child: Row(
            children: [
              if (widget.isEditing)
                Checkbox(
                  value: checkboxState,
                  tristate: row.children.isNotEmpty,
                  onChanged: (bool? value) => _togglePermission(row.id, value),
                  activeColor: Colors.red,
                  checkColor: Colors.white,
                ),
              Flexible(
                child: Text(
                  row.localName(isEnglish),
                  style: TextStyle(
                    fontWeight: isFolder ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ),
              if (showPerms) ...[
                const SizedBox(width: 8),
                Flexible(child: _buildPermissionRow(row.id, isEnglish)),
              ],
            ],
          ),
        ),
        ...row.children
            .map((child) => _buildNodeItem(child, level + 1, isEnglish)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    if (widget.lists.isEmpty) {
      return Center(
          child: Text(isEnglish
              ? 'No menu items found in the system'
              : 'ไม่พบรายการเมนูในระบบ'));
    }

    final List<Menu> topLevelMenusToDisplay = widget.isEditing
        ? _listRows
        : _listRows
            .where((row) => _hasAnyGrantedInSubtree(row))
            .toList();

    if (topLevelMenusToDisplay.isEmpty && !widget.isEditing) {
      return Center(
          child: Text(isEnglish
              ? 'User has no menu access permissions'
              : 'ผู้ใช้ยังไม่ได้รับสิทธิ์เข้าถึงเมนูใดๆ'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: topLevelMenusToDisplay
            .map((menu) => _buildNodeItem(menu, 0, isEnglish))
            .toList(),
      ),
    );
  }
}
