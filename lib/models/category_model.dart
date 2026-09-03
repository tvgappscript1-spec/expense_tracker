import 'package:flutter/material.dart';

import 'transaction_model.dart';

/// Danh muc 2 cap kieu Money Lover.
///
/// - Danh muc CHA: parentId == null.
/// - Danh muc CON: parentId tro toi id cua cha.
///
/// LUU Y KY THUAT: icon va color luu duoi dang codePoint/gia tri int trong DB.
/// Vi day la danh muc do NGUOI DUNG co the them, khong the hardcode IconData
/// hang so nhu bo cu. De tranh loi tree-shake-icons khi build release, ta se
/// TAT tree-shaking bang co --no-tree-shake-icons trong lenh build (xem workflow).
class CategoryModel {
  final int? id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final TransactionType type;
  final int? parentId;
  final int sortOrder;

  /// Danh muc mac dinh do app seed san thi khoa (khong cho xoa).
  final bool isSystem;

  const CategoryModel({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.type,
    this.parentId,
    this.sortOrder = 0,
    this.isSystem = false,
  });

  bool get isParent => parentId == null;
  bool get isChild => parentId != null;

  IconData get icon =>
      IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'name': name,
      'icon_code': iconCodePoint,
      'color_value': colorValue,
      'type': type.index,
      'parent_id': parentId,
      'sort_order': sortOrder,
      'is_system': isSystem ? 1 : 0,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      iconCodePoint:
          (map['icon_code'] as int?) ?? Icons.category_rounded.codePoint,
      colorValue: (map['color_value'] as int?) ?? 0xFF78909C,
      type: TransactionTypeX.fromIndex((map['type'] as int?) ?? 0),
      parentId: map['parent_id'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isSystem: ((map['is_system'] as int?) ?? 0) == 1,
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    TransactionType? type,
    int? parentId,
    bool clearParent = false,
    int? sortOrder,
    bool? isSystem,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, parent: $parentId, ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CategoryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Mot danh muc cha kem danh sach con cua no — dung cho UI chon danh muc va
/// cho bieu do tron phan cap.
class CategoryGroup {
  final CategoryModel parent;
  final List<CategoryModel> children;

  const CategoryGroup({required this.parent, required this.children});

  bool get hasChildren => children.isNotEmpty;
}
