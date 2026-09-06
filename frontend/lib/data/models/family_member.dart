import 'dart:convert';
import 'package:flutter/material.dart';

class FamilyMember {
  final String id;
  final String userId;
  final String name;
  final String relationship; // 'child', 'parent', 'spouse', 'sibling', 'other'
  final int age;
  final String gender; // 'male', 'female', 'other'
  final String goal; // 'maintenance', 'weight_loss', 'muscle_gain'
  final int dailyCalorieTarget;
  final int dailyProteinG;
  final int dailyCarbsG;
  final int dailyFatG;
  final List<String> medicalConditions;
  final List<String> dietaryRestrictions;
  final String avatarColor;
  final DateTime? createdAt;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.age,
    required this.gender,
    this.goal = 'maintenance',
    this.dailyCalorieTarget = 1800,
    this.dailyProteinG = 100,
    this.dailyCarbsG = 200,
    this.dailyFatG = 50,
    this.medicalConditions = const [],
    this.dietaryRestrictions = const [],
    this.avatarColor = '#00E676',
    this.createdAt,
  });

  String get relationshipEmoji {
    switch (relationship.toLowerCase()) {
      case 'child':
        return age <= 12 ? '🧒' : '🧑';
      case 'parent':
        return gender == 'female' ? '👵' : '👴';
      case 'spouse':
        return '❤️';
      case 'sibling':
        return '👥';
      default:
        return '👤';
    }
  }

  String getLocalizedRelationship(String lang) {
    if (lang == 'ur') {
      switch (relationship.toLowerCase()) {
        case 'child':
          return 'بچہ / اولاد';
        case 'parent':
          return gender == 'female' ? 'والدہ (امی)' : 'والد (ابو)';
        case 'spouse':
          return 'شریک حیات';
        case 'sibling':
          return 'بھائی / بہن';
        default:
          return 'رشتہ دار';
      }
    }
    switch (relationship.toLowerCase()) {
      case 'child':
        return 'Child';
      case 'parent':
        return gender == 'female' ? 'Mother' : 'Father';
      case 'spouse':
        return 'Spouse';
      case 'sibling':
        return 'Sibling';
      default:
        return 'Dependent';
    }
  }

  Color get color {
    try {
      final hex = avatarColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF00E676);
    }
  }

  /// Tailored daily water intake target in ml based on age and gender
  int get recommendedWaterTargetMl {
    if (age <= 5) return 1200;
    if (age <= 12) return 1600;
    if (age <= 18) return gender.toLowerCase() == 'male' ? 2200 : 1900;
    if (age >= 60) return 2000;
    return gender.toLowerCase() == 'male' ? 2600 : 2200;
  }

  /// Calculates tailored recommended daily macros based on age, gender, goal & conditions
  static Map<String, int> calculateRecommendedTargets({
    required int age,
    required String gender,
    required String relationship,
    String goal = 'maintenance',
    List<String> conditions = const [],
  }) {
    int cals = 1800;
    int protein = 100;
    int carbs = 200;
    int fat = 50;

    if (age <= 5) {
      cals = 1300;
      protein = 45;
      carbs = 160;
      fat = 40;
    } else if (age <= 12) {
      cals = 1650;
      protein = 70;
      carbs = 210;
      fat = 48;
    } else if (age <= 18) {
      cals = gender == 'male' ? 2400 : 2000;
      protein = gender == 'male' ? 120 : 95;
      carbs = gender == 'male' ? 280 : 230;
      fat = 65;
    } else if (age >= 60) {
      // Elderly parent nutrition: balanced, lower sugar/carbs, adequate protein for muscle preservation
      cals = 1600;
      protein = 85;
      carbs = 175;
      fat = 45;
    } else {
      cals = gender == 'male' ? 2200 : 1800;
      protein = gender == 'male' ? 130 : 100;
      carbs = gender == 'male' ? 240 : 200;
      fat = 60;
    }

    // Apply Health Goal adjustments
    final goalLower = goal.toLowerCase();
    if (goalLower.contains('lose') || goalLower.contains('fat') || goalLower.contains('weight_loss')) {
      cals = (cals - 350).clamp(1200, 3500);
      carbs = (carbs * 0.8).round();
      protein = (protein * 1.05).round(); // preserve lean mass
    } else if (goalLower.contains('muscle') || goalLower.contains('gain') || goalLower.contains('bulk')) {
      cals += 250;
      protein += 25;
      carbs += 20;
    } else if (goalLower.contains('diabetes') || goalLower.contains('blood sugar')) {
      carbs = (carbs * 0.75).round();
      protein = (protein * 1.1).round();
    }

    // Adjust for medical conditions (Diabetes, Hypertension, Heart Disease, High Cholesterol)
    final condLower = conditions.map((c) => c.toLowerCase()).toList();
    if (condLower.any((c) => c.contains('diabetes') || c.contains('sugar'))) {
      carbs = (carbs * 0.75).round(); // Lower carbs for diabetes
      protein = (protein * 1.1).round();
    }
    if (condLower.any((c) => c.contains('hypertension') || c.contains('blood pressure') || c.contains('bp'))) {
      fat = (fat * 0.85).round(); // Lower saturated fat
    }
    if (condLower.any((c) => c.contains('heart') || c.contains('cholesterol') || c.contains('lipid'))) {
      fat = (fat * 0.85).round(); // Cardiac protective fat reduction
    }

    return {
      'calories': cals,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? 'other',
      age: (map['age'] as num?)?.toInt() ?? 25,
      gender: map['gender'] ?? 'other',
      goal: map['goal']?.toString() ?? 'maintenance',
      dailyCalorieTarget: (map['daily_calorie_target'] as num?)?.toInt() ?? 1800,
      dailyProteinG: (map['daily_protein_g'] as num?)?.toInt() ?? 100,
      dailyCarbsG: (map['daily_carbs_g'] as num?)?.toInt() ?? 200,
      dailyFatG: (map['daily_fat_g'] as num?)?.toInt() ?? 50,
      medicalConditions: map['medical_conditions'] != null
          ? List<String>.from(map['medical_conditions'])
          : [],
      dietaryRestrictions: map['dietary_restrictions'] != null
          ? List<String>.from(map['dietary_restrictions'])
          : [],
      avatarColor: map['avatar_color'] ?? '#00E676',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'age': age,
      'gender': gender,
      'daily_calorie_target': dailyCalorieTarget,
      'daily_protein_g': dailyProteinG,
      'daily_carbs_g': dailyCarbsG,
      'daily_fat_g': dailyFatG,
      'medical_conditions': medicalConditions,
      'dietary_restrictions': dietaryRestrictions,
      'avatar_color': avatarColor,
    };
  }

  String toJson() => json.encode(toMap());

  factory FamilyMember.fromJson(String source) => FamilyMember.fromMap(json.decode(source));

  FamilyMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? relationship,
    int? age,
    String? gender,
    String? goal,
    int? dailyCalorieTarget,
    int? dailyProteinG,
    int? dailyCarbsG,
    int? dailyFatG,
    List<String>? medicalConditions,
    List<String>? dietaryRestrictions,
    String? avatarColor,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      dailyProteinG: dailyProteinG ?? this.dailyProteinG,
      dailyCarbsG: dailyCarbsG ?? this.dailyCarbsG,
      dailyFatG: dailyFatG ?? this.dailyFatG,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      avatarColor: avatarColor ?? this.avatarColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
