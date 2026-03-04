// Models
class Currency {
  final int? id;
  final String currencyCode;
  final String currencyNameThai;
  final String currencyNameEng;
  final double baseRate;
  final bool baseCurrencyFlag;
  final String? symbol;
  final int numOfDecimal;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int? lockedByUserId;
  final String? lockedByUserName;

  Currency({
    this.id,
    required this.currencyCode,
    required this.currencyNameThai,
    required this.currencyNameEng,
    required this.baseRate,
    required this.baseCurrencyFlag,
    this.symbol,
    required this.numOfDecimal,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.lockedByUserId,
    this.lockedByUserName,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: json['id'],
      currencyCode: json['currency_code'],
      currencyNameThai: json['currency_name_th'],
      currencyNameEng: json['currency_name_en'],
      baseRate: json['base_rate'],
      baseCurrencyFlag: json['base_currency_flag'],
      symbol: json['symbol'] ?? '',
      numOfDecimal: json['num_of_decimal'],
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      createdBy: json['created_by'] ?? '',
      updatedBy: json['updated_by'] ?? '',
      lockedByUserId: json['locked_by_user_id'] ?? 0,
      lockedByUserName: json['locked_by_user_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currency_code': currencyCode,
      'currency_name_th': currencyNameThai,
      'currency_name_en': currencyNameEng,
      'base_rate': baseRate,
      'base_currency_flag': baseCurrencyFlag,
      'symbol': symbol,
      'num_of_decimal': numOfDecimal,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'locked_by_user_id': lockedByUserId,
      'locked_by_user_name': lockedByUserName,
    };
  }
}

