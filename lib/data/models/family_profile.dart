import 'child_profile.dart';

class FamilyProfile {
  final String familyId;
  final String currentTheme;
  final String pinCode;
  final List<ChildProfile> children;

  FamilyProfile({
    required this.familyId,
    this.currentTheme = 'ultraman',
    required this.pinCode,
    required this.children,
  });

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      familyId: json['familyId'] as String,
      currentTheme: json['currentTheme'] as String? ?? 'ultraman',
      pinCode: json['pinCode'] as String,
      children: (json['children'] as List<dynamic>?)
          ?.map((e) => ChildProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'familyId': familyId,
      'currentTheme': currentTheme,
      'pinCode': pinCode,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}