import 'package:intl/intl.dart';
import '../models/daily_log_model.dart';
import '../models/briefing_model.dart';
import 'firestore_service.dart';
import 'gemini_service.dart';

/// معادل سمت‌کلاینت Cloud Function `analyzeDayAndPlanTomorrow` از بخش ۱ پرامپت.
/// چون روی Spark Plan نمی‌توان Cloud Function زمان‌بندی‌شده (نیازمند Blaze)
/// داشت، این سرویس هنگام باز شدن اپ (اگر گزارش امروز هنوز ساخته نشده) اجرا
/// می‌شود: دیروز را با میانگین ۷ روز قبل‌ترش مقایسه می‌کند، علت ریشه‌ای
/// احتمالی را حدس می‌زند، و یک بریفینگ انگیزشی/تاکتیکی برای امروز می‌سازد.
class DailyAnalysisService {
  final FirestoreService _firestore = FirestoreService();
  final GeminiService _gemini = GeminiService();

  /// اگر بریفینگ امروز از قبل وجود نداشت، آن را می‌سازد و برمی‌گرداند.
  /// اگر از قبل وجود داشت، همان را برمی‌گرداند (بدون فراخوانی مجدد API).
  Future<BriefingModel> ensureTodayBriefing(String uid, {String? geminiApiKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await _firestore.getBriefing(uid, today);
    if (existing != null) return existing;

    return regenerateTodayBriefing(uid, geminiApiKey: geminiApiKey);
  }

  /// بدون توجه به وجود قبلی، بریفینگ امروز را دوباره می‌سازد (دکمه «تحلیل مجدد»)
  Future<BriefingModel> regenerateTodayBriefing(String uid, {String? geminiApiKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday =
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

    final yesterdayLog = await _firestore.getLogForDate(uid, yesterday);
    final prevLogs = await _firestore.getPreviousDaysLogs(uid, yesterday, 7);

    final analysis = _computeDeviations(yesterdayLog, prevLogs);
    final templateText = _buildTemplateText(analysis);

    String finalText = templateText;
    bool aiGenerated = false;

    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      final aiText = await _gemini.generateText(
        apiKey: geminiApiKey,
        prompt: _buildPrompt(analysis),
      );
      if (aiText != null && aiText.isNotEmpty) {
        finalText = aiText;
        aiGenerated = true;
      }
    }

    final briefing = BriefingModel(
      date: today,
      summaryText: finalText,
      generatedAt: DateTime.now(),
      isAiGenerated: aiGenerated,
    );

    await _firestore.saveBriefing(uid, briefing);
    return briefing;
  }

  _DeviationAnalysis _computeDeviations(DailyLogModel yesterday, List<DailyLogModel> prevLogs) {
    double avg(int Function(DailyLogModel) field) {
      if (prevLogs.isEmpty) return 0;
      final sum = prevLogs.fold<int>(0, (acc, l) => acc + field(l));
      return sum / prevLogs.length;
    }

    final avgStudy = avg((l) => l.studyMinutes);
    final avgWorkout = avg((l) => l.workoutMinutes);
    final avgInstagram = avg((l) => l.instagramMinutes);

    return _DeviationAnalysis(
      yesterday: yesterday,
      avgStudyMinutes: avgStudy,
      avgWorkoutMinutes: avgWorkout,
      avgInstagramMinutes: avgInstagram,
      studyDropped: avgStudy > 0 && yesterday.studyMinutes < avgStudy * 0.7,
      workoutMissed: yesterday.workoutMinutes < 10,
      instagramSpiked: avgInstagram > 0 && yesterday.instagramMinutes > avgInstagram * 1.3,
    );
  }

  String _buildPrompt(_DeviationAnalysis a) {
    return '''
تو دستیار شخصی و کوچ سخت‌گیر ولی دلسوز «فرزان» هستی، دانشجوی دامپزشکی ۲۲ ساله با شخصیت ENTP.
داده‌های دیروز فرزان:
- مطالعه: ${a.yesterday.studyMinutes} دقیقه (میانگین ۷ روز قبل: ${a.avgStudyMinutes.toStringAsFixed(0)} دقیقه)
- ورزش: ${a.yesterday.workoutMinutes} دقیقه (میانگین: ${a.avgWorkoutMinutes.toStringAsFixed(0)} دقیقه)
- اینستاگرام: ${a.yesterday.instagramMinutes} دقیقه (میانگین: ${a.avgInstagramMinutes.toStringAsFixed(0)} دقیقه)
- استفاده کل از گوشی: ${a.yesterday.totalScreenTimeMinutes} دقیقه

یک پیام کوتاه (حداکثر ۴ جمله)، صادقانه، مستقیم و تاکتیکی به فارسی برای امروز فرزان بنویس.
اگر افت مطالعه مربوط به اینستاگرام بود، صریح بگو. یک اقدام مشخص و عملی برای امروز پیشنهاد بده
(مثلا گذاشتن گوشی جای خاص، یا یک جلسه کوتاه ورزش سبک). لحن باید مثل یک مربی واقعی باشد، نه
یک ربات مهربان بی‌خاصیت. مستقیم خطاب به او صحبت کن.
''';
  }

  String _buildTemplateText(_DeviationAnalysis a) {
    final buffer = StringBuffer();

    buffer.write('دیروز ${a.yesterday.studyMinutes} دقیقه مطالعه کردی');
    if (a.avgStudyMinutes > 0) {
      buffer.write(' (میانگین هفته‌ات ${a.avgStudyMinutes.toStringAsFixed(0)} دقیقه بود). ');
    } else {
      buffer.write('. ');
    }

    if (a.instagramSpiked && a.studyDropped) {
      buffer.write(
        'اینستاگرامت (${a.yesterday.instagramMinutes} دقیقه) خیلی بالاتر از حد معمول بود؛ '
        'به‌احتمال زیاد همین باعث افت مطالعه شده. ',
      );
    }

    if (a.workoutMissed) {
      buffer.write('ورزش هم امروز اصلا نبود یا خیلی کم بود. ');
    }

    buffer.write('برای امروز: ');
    if (a.studyDropped) {
      buffer.write('گوشی رو یه جای دور از دسترس بذار تا حداقل ${a.avgStudyMinutes.toStringAsFixed(0)} '
          'دقیقه بدون وقفه مطالعه کنی. ');
    }
    if (a.workoutMissed) {
      buffer.write('یه جلسه ۱۵ دقیقه‌ای سبک ورزش هم برنامه امروزت باشه.');
    }

    return buffer.toString().trim();
  }
}

class _DeviationAnalysis {
  final DailyLogModel yesterday;
  final double avgStudyMinutes;
  final double avgWorkoutMinutes;
  final double avgInstagramMinutes;
  final bool studyDropped;
  final bool workoutMissed;
  final bool instagramSpiked;

  _DeviationAnalysis({
    required this.yesterday,
    required this.avgStudyMinutes,
    required this.avgWorkoutMinutes,
    required this.avgInstagramMinutes,
    required this.studyDropped,
    required this.workoutMissed,
    required this.instagramSpiked,
  });
}
