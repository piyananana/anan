class UserBranch {
  final int id;
  final int userId;
  final int branchId;
  final String branchCode;
  final String branchNameThai;
  final bool isDefault;

  const UserBranch({
    required this.id,
    required this.userId,
    required this.branchId,
    required this.branchCode,
    required this.branchNameThai,
    required this.isDefault,
  });

  factory UserBranch.fromJson(Map<String, dynamic> json) => UserBranch(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        branchId: json['branch_id'] as int,
        branchCode: json['branch_code'] as String,
        branchNameThai: json['branch_name_thai'] as String,
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'branch_id': branchId,
        'branch_code': branchCode,
        'branch_name_thai': branchNameThai,
        'is_default': isDefault,
      };

  UserBranch copyWith({bool? isDefault}) => UserBranch(
        id: id,
        userId: userId,
        branchId: branchId,
        branchCode: branchCode,
        branchNameThai: branchNameThai,
        isDefault: isDefault ?? this.isDefault,
      );
}
