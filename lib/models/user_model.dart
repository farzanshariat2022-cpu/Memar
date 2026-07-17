import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل کاربر - نگاشت‌شده روی سند users/{uid} در Firestore
class AppUserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final String geminiApiKey;

  /// تنظیمات قابل‌شخصی‌سازی مقدار XP هر فعالیت (فاز‌های بعدی از این استفاده می‌کنند)
  final Map<String, double> xpRates;

  AppUserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.geminiApiKey = '',
    Map<String, double>? xpRates,
  }) : xpRates = xpRates ?? defaultXpRates;

  /// نرخ‌های پیش‌فرض XP طبق مشخصات پرامپت (بخش ۳)
  static const Map<String, double> defaultXpRates = {
    'study_per_minute': 1.0,
    'workout_per_minute': 1.5,
    'chess_per_game': 20.0,
    'backgammon_per_game': 15.0,
    'language_per_minute': 1.0,
    'design_per_minute': 0.5,
    'reading_per_minute': 1.0,
    'podcast_per_minute': 0.25,
    'journal_per_day': 10.0,
    'meditation_per_minute': 1.5,
  };

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      geminiApiKey: map['geminiApiKey'] ?? '',
      xpRates: map['xpRates'] != null
          ? Map<String, double>.from(
              (map['xpRates'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'geminiApiKey': geminiApiKey,
      'xpRates': xpRates,
    };
  }
}
