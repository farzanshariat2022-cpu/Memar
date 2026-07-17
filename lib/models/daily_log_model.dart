import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل لاگ روزانه - نگاشت‌شده روی سند users/{uid}/daily_logs/{yyyy-MM-dd}
/// این سند در فازهای بعدی توسط Cloud Function تحلیل شبانه خوانده می‌شود.
class DailyLogModel {
  final String date; // فرمت yyyy-MM-dd، هم‌زمان شناسه سند
  final int studyMinutes;
  final int workoutMinutes;
  final int totalScreenTimeMinutes;
  final int instagramMinutes;
  final int youtubeMinutes;
  final double? sleepHours;
  final int? moodScore; // ۱ تا ۱۰
  final double xpEarned;
  final bool journalWritten;

  DailyLogModel({
    required this.date,
    this.studyMinutes = 0,
    this.workoutMinutes = 0,
    this.totalScreenTimeMinutes = 0,
    this.instagramMinutes = 0,
    this.youtubeMinutes = 0,
    this.sleepHours,
    this.moodScore,
    this.xpEarned = 0,
    this.journalWritten = false,
  });

  factory DailyLogModel.empty(String date) => DailyLogModel(date: date);

  factory DailyLogModel.fromMap(String date, Map<String, dynamic> map) {
    return DailyLogModel(
      date: date,
      studyMinutes: (map['studyMinutes'] ?? 0) as int,
      workoutMinutes: (map['workoutMinutes'] ?? 0) as int,
      totalScreenTimeMinutes: (map['totalScreenTimeMinutes'] ?? 0) as int,
      instagramMinutes: (map['instagramMinutes'] ?? 0) as int,
      youtubeMinutes: (map['youtubeMinutes'] ?? 0) as int,
      sleepHours: (map['sleepHours'] as num?)?.toDouble(),
      moodScore: map['moodScore'] as int?,
      xpEarned: (map['xpEarned'] as num?)?.toDouble() ?? 0,
      journalWritten: map['journalWritten'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studyMinutes': studyMinutes,
      'workoutMinutes': workoutMinutes,
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'instagramMinutes': instagramMinutes,
      'youtubeMinutes': youtubeMinutes,
      'sleepHours': sleepHours,
      'moodScore': moodScore,
      'xpEarned': xpEarned,
      'journalWritten': journalWritten,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DailyLogModel copyWith({
    int? studyMinutes,
    int? workoutMinutes,
    int? totalScreenTimeMinutes,
    int? instagramMinutes,
    int? youtubeMinutes,
    double? sleepHours,
    int? moodScore,
    double? xpEarned,
    bool? journalWritten,
  }) {
    return DailyLogModel(
      date: date,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      totalScreenTimeMinutes: totalScreenTimeMinutes ?? this.totalScreenTimeMinutes,
      instagramMinutes: instagramMinutes ?? this.instagramMinutes,
      youtubeMinutes: youtubeMinutes ?? this.youtubeMinutes,
      sleepHours: sleepHours ?? this.sleepHours,
      moodScore: moodScore ?? this.moodScore,
      xpEarned: xpEarned ?? this.xpEarned,
      journalWritten: journalWritten ?? this.journalWritten,
    );
  }
}
