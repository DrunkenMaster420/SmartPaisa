import 'dart:convert';
import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isDefault;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'isDefault': isDefault,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: _getIconFromCodePoint(
        map['iconCodePoint'] ?? Icons.category.codePoint,
        map['iconFontFamily'],
      ),
      color: Color(map['colorValue'] ?? Colors.blue.value),
      isDefault: map['isDefault'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  static IconData _getIconFromCodePoint(int codePoint, String? fontFamily) {
    // Map common codePoints to const IconData instances
    const iconMap = {
      0xe57f: Icons.restaurant,
      0xe531: Icons.directions_car,
      0xe59c: Icons.shopping_bag,
      0xe405: Icons.movie,
      0xe3e4: Icons.flash_on,
      0xe3f0: Icons.local_hospital,
      0xe80c: Icons.school,
      0xe8f9: Icons.work,
      0xe8e5: Icons.trending_up,
      0xe574: Icons.category,
    };

    return iconMap[codePoint] ?? Icons.category;
  }


  String toJson() => json.encode(toMap());

  factory Category.fromJson(String source) =>
      Category.fromMap(json.decode(source));
}

class DefaultCategories {
  static List<Category> get defaults => [
    Category(
      id: 'food',
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: Colors.orange,
      isDefault: true,
    ),
    Category(
      id: 'transport',
      name: 'Transportation',
      icon: Icons.directions_car,
      color: Colors.blue,
      isDefault: true,
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      isDefault: true,
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: Colors.red,
      isDefault: true,
    ),
    Category(
      id: 'utilities',
      name: 'Utilities',
      icon: Icons.flash_on,
      color: Colors.green,
      isDefault: true,
    ),
    Category(
      id: 'healthcare',
      name: 'Healthcare',
      icon: Icons.local_hospital,
      color: Colors.pink,
      isDefault: true,
    ),
    Category(
      id: 'education',
      name: 'Education',
      icon: Icons.school,
      color: Colors.indigo,
      isDefault: true,
    ),
    Category(
      id: 'salary',
      name: 'Salary',
      icon: Icons.work,
      color: Colors.teal,
      isDefault: true,
    ),
    Category(
      id: 'investment',
      name: 'Investment',
      icon: Icons.trending_up,
      color: Colors.amber,
      isDefault: true,
    ),
    Category(
      id: 'other',
      name: 'Other',
      icon: Icons.category,
      color: Colors.grey,
      isDefault: true,
    ),
  ];
}
