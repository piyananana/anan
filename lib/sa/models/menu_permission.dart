class MenuPermission {
  final int menuId;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canApprove;
  final bool canPrint;
  final bool canExport;

  const MenuPermission({
    required this.menuId,
    this.canView = true,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canApprove = false,
    this.canPrint = false,
    this.canExport = false,
  });

  factory MenuPermission.fromJson(Map<String, dynamic> json) => MenuPermission(
        menuId: json['id'] ?? json['menu_id'] ?? 0,
        canView: json['can_view'] ?? true,
        canCreate: json['can_create'] ?? false,
        canEdit: json['can_edit'] ?? false,
        canDelete: json['can_delete'] ?? false,
        canApprove: json['can_approve'] ?? false,
        canPrint: json['can_print'] ?? false,
        canExport: json['can_export'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': menuId,
        'canView': canView,
        'canCreate': canCreate,
        'canEdit': canEdit,
        'canDelete': canDelete,
        'canApprove': canApprove,
        'canPrint': canPrint,
        'canExport': canExport,
      };

  MenuPermission copyWith({
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool? canApprove,
    bool? canPrint,
    bool? canExport,
  }) =>
      MenuPermission(
        menuId: menuId,
        canView: canView ?? this.canView,
        canCreate: canCreate ?? this.canCreate,
        canEdit: canEdit ?? this.canEdit,
        canDelete: canDelete ?? this.canDelete,
        canApprove: canApprove ?? this.canApprove,
        canPrint: canPrint ?? this.canPrint,
        canExport: canExport ?? this.canExport,
      );
}
