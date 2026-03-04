class GlBeginningBalance {
  int? id;
  int postingPeriodId;
  int accountId;
  int? businessUnitId;
  String? businessUnitCode; // Display
  String? businessUnitName; // Display
  int? branchId;
  String? branchCode; // Display
  String? branchName; // Display
  int? projectId;
  String? projectCode; // Display
  String? projectName; // Display
  double amountDr;
  double amountCr;

  GlBeginningBalance({
    this.id,
    required this.postingPeriodId,
    required this.accountId,
    this.businessUnitId,
    this.businessUnitCode = '',
    this.businessUnitName = '',
    this.branchId,
    this.branchCode = '',
    this.branchName = '',
    this.projectId,
    this.projectCode = '',
    this.projectName = '',
    this.amountDr = 0.0,
    this.amountCr = 0.0,
  });

  factory GlBeginningBalance.fromJson(Map<String, dynamic> json) {
    return GlBeginningBalance(
      id: json['id'],
      postingPeriodId: json['posting_period_id'],
      accountId: json['account_id'],
      businessUnitId: json['business_unit_id'],
      businessUnitCode: json['bu_code'],
      businessUnitName: json['bu_name_thai'],
      branchId: json['branch_id'],
      branchCode: json['branch_code'],
      branchName: json['branch_name_thai'],
      projectId: json['project_id'],
      projectCode: json['project_code'],
      projectName: json['project_name_thai'],
      amountDr: double.tryParse(json['amount_dr'].toString()) ?? 0.0,
      amountCr: double.tryParse(json['amount_cr'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'posting_period_id': postingPeriodId,
      'account_id': accountId,
      'business_unit_id': businessUnitId,
      'bu_code': businessUnitCode,
      'bu_name_thai': businessUnitName,
      'branch_id': branchId,
      'branch_code': branchCode,
      'branch_name_thai': branchName,
      'project_id': projectId,
      'project_code': projectCode,
      'project_name_thai': projectName,
      'amount_dr': amountDr,
      'amount_cr': amountCr,
    };
  }
}