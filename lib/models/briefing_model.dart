import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل DailyBriefing - نگاشت‌شده روی سند users/{uid}/briefings/{yyyy-MM-dd}
/// تولید این سند در فاز ۱-۲ به‌جای Cloud Function، سمت کلاینت (داخل خود اپ
/// فلاتر) انجام می‌شود تا نیازی به پلن Blaze نباشد.
class BriefingModel {
  final String date;
  final String summaryText;
  final DateTime generatedAt;
  final bool isAiGenerated; // false یعنی نسخه‌ی قالبی بدون Gemini

  BriefingModel({
    required this.date,
    required this.summaryText,
    required this.generatedAt,
    this.isAiGenerated = false,
  });

  factory BriefingModel.fromMap(String date, Map<String, dynamic> map) {
    return BriefingModel(
      date: date,
      summaryText: map['summaryText'] ?? '',
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAiGenerated: map['isAiGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summaryText': summaryText,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'isAiGenerated': isAiGenerated,
    };
  }
}
