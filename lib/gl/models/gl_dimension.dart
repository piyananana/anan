// GL Dimension Framework models

class GlDimensionType {
  final int slotNo;
  final String typeCode;
  final String nameThai;
  final String? nameEng;
  final bool isActive;
  final int sortOrder;

  const GlDimensionType({
    required this.slotNo,
    required this.typeCode,
    required this.nameThai,
    this.nameEng,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GlDimensionType.fromJson(Map<String, dynamic> j) => GlDimensionType(
        slotNo:    j['slot_no'] as int,
        typeCode:  j['type_code'] as String,
        nameThai:  j['name_thai'] as String,
        nameEng:   j['name_eng'] as String?,
        isActive:  j['is_active'] as bool? ?? true,
        sortOrder: j['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'slot_no':    slotNo,
        'type_code':  typeCode,
        'name_thai':  nameThai,
        'name_eng':   nameEng,
        'is_active':  isActive,
        'sort_order': sortOrder,
      };
}

class GlDimensionValue {
  final int id;
  final String typeCode;
  final String valueCode;
  final String valueNameThai;
  final String? valueNameEng;
  final int? parentId;
  final String? parentCode;
  final String? parentName;
  final bool isActive;
  final int sortOrder;

  const GlDimensionValue({
    required this.id,
    required this.typeCode,
    required this.valueCode,
    required this.valueNameThai,
    this.valueNameEng,
    this.parentId,
    this.parentCode,
    this.parentName,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GlDimensionValue.fromJson(Map<String, dynamic> j) => GlDimensionValue(
        id:            j['id'] as int,
        typeCode:      j['type_code'] as String,
        valueCode:     j['value_code'] as String,
        valueNameThai: j['value_name_thai'] as String,
        valueNameEng:  j['value_name_eng'] as String?,
        parentId:      j['parent_id'] as int?,
        parentCode:    j['parent_code'] as String?,
        parentName:    j['parent_name'] as String?,
        isActive:      j['is_active'] as bool? ?? true,
        sortOrder:     j['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id':              id,
        'type_code':       typeCode,
        'value_code':      valueCode,
        'value_name_thai': valueNameThai,
        'value_name_eng':  valueNameEng,
        'parent_id':       parentId,
        'is_active':       isActive,
        'sort_order':      sortOrder,
      };

  String get displayName => '$valueCode — $valueNameThai';
}
