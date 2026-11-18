// lib/cd/widgets/cd_user_branch_picker.dart
// สาขาของเอกสารธุรกรรม (user-approved 2026-11-18)
//   - ค่าเริ่มต้น: สาขาหลักของผู้ใช้ → สาขาของคลัง (ถ้าหน้าจอมีคลัง) → ไม่พบ = ผู้ใช้เลือกเอง
//   - เลือกได้เฉพาะสาขาที่ผู้ใช้มีสิทธิ์ (sa_user_branch) — ผู้ใช้ที่ยังไม่ได้กำหนดสิทธิ์สาขา เลือกได้ทุกสาขาที่ใช้งาน
//   - ไม่บังคับทุกเอกสาร: บังคับเฉพาะเมื่อบัญชีที่ลงรายการเปิด "ต้องระบุสาขา" (backend utils/glDims.js assertRequiredBranch)
import 'package:flutter/material.dart';

import '../../sa/services/sa_auth_service.dart';
import '../models/cd_branch.dart';

/// สาขาเริ่มต้นของเอกสารใหม่: สาขาหลักของผู้ใช้ ก่อนสาขาของคลัง
int? defaultDocBranchId({int? warehouseBranchId}) =>
    AuthService().defaultBranch?.branchId ?? warehouseBranchId;

/// สาขาที่ผู้ใช้เลือกได้ (มีสิทธิ์) จากรายการสาขาที่ใช้งาน
List<Branch> userSelectableBranches(List<Branch> branches) {
  final allowed = AuthService().allowedBranches.map((b) => b.branchId).toSet();
  final active = branches.where((b) => b.isActive && b.id != null).toList();
  return allowed.isEmpty ? active : active.where((b) => allowed.contains(b.id)).toList();
}

String branchLabel(Branch? b, bool isEnglish) {
  if (b == null) return '';
  final name = isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
  return '${b.branchCode} $name';
}

Branch? findBranch(List<Branch> branches, int? id) {
  if (id == null) return null;
  for (final b in branches) {
    if (b.id == id) return b;
  }
  return null;
}

/// dialog เลือกสาขา (ค้นหารหัส/ชื่อ) — คืน (เลือก, สาขา): ปิด = null, ล้างค่า = (true, null)
/// userFilter = false: ข้อมูลหลัก (เช่น บัญชีธนาคาร) เลือกได้ทุกสาขาที่ใช้งาน ไม่จำกัดตามสิทธิ์ผู้ใช้
Future<(bool, Branch?)?> showUserBranchPicker(
  BuildContext context, {
  required List<Branch> branches,
  int? selectedId,
  required bool isEnglish,
  bool allowClear = true,
  bool userFilter = true,
}) {
  final source = userFilter
      ? userSelectableBranches(branches)
      : branches.where((b) => b.isActive && b.id != null).toList();
  var filtered = List<Branch>.from(source);
  return showDialog<(bool, Branch?)>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      void doFilter(String q) {
        final lq = q.toLowerCase();
        setS(() => filtered = q.isEmpty
            ? source
            : source
                .where((b) =>
                    b.branchCode.toLowerCase().contains(lq) ||
                    b.branchNameThai.toLowerCase().contains(lq) ||
                    b.branchNameEng.toLowerCase().contains(lq))
                .toList());
      }

      return Dialog(
        child: SizedBox(
          width: 480,
          height: 460,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Search branch (code / name)' : 'ค้นหาสาขา (รหัส / ชื่อ)',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: doFilter,
                autofocus: true,
              ),
            ),
            Expanded(
              child: source.isEmpty
                  ? Center(
                      child: Text(isEnglish ? 'No branches available' : 'ไม่มีสาขาที่เลือกได้',
                          style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final b = filtered[i];
                        final sel = b.id == selectedId;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor: Colors.teal.shade50,
                          leading: sel
                              ? const Icon(Icons.check_circle, color: Colors.teal, size: 18)
                              : const SizedBox(width: 18),
                          title: Text(branchLabel(b, isEnglish), style: const TextStyle(fontSize: 14)),
                          onTap: () => Navigator.pop(ctx, (true, b)),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Row(children: [
              const SizedBox(width: 8),
              if (allowClear && selectedId != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(isEnglish ? 'Clear' : 'ล้างค่า'),
                  onPressed: () => Navigator.pop(ctx, (true, null)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Close' : 'ปิด')),
              const SizedBox(width: 8),
            ]),
          ]),
        ),
      );
    }),
  );
}
