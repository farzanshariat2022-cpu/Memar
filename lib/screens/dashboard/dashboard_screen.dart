import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/daily_log_model.dart';
import '../../models/briefing_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/daily_analysis_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../settings/settings_screen.dart';

/// داشبورد اصلی «معمار».
/// شامل آمار امروز، روند ۷ روز اخیر، و DailyBriefing واقعی که سمت کلاینت
/// (بدون Cloud Function، طبق محدودیت Spark Plan) تولید می‌شود.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestoreService = FirestoreService();
  final _analysisService = DailyAnalysisService();

  static const int studyGoalMinutes = 240; // ۴ ساعت هدف روزانه مطالعه (قابل تنظیم فاز بعد)
  static const int workoutGoalMinutes = 45;

  bool _briefingLoading = false;
  String? _geminiApiKey;

  @override
  void initState() {
    super.initState();
    _autoGenerateBriefingIfNeeded();
  }

  /// اگر بریفینگ امروز هنوز ساخته نشده، آن را بر پایه‌ی داده‌های دیروز می‌سازد.
  /// این معادل کلاینت‌ساید همان Cloud Function شبانه‌ی توضیح‌داده‌شده در پرامپت است.
  Future<void> _autoGenerateBriefingIfNeeded() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    final profile = await _firestoreService.streamUserProfile(uid).first;
    _geminiApiKey = profile?.geminiApiKey;

    setState(() => _briefingLoading = true);
    try {
      await _analysisService.ensureTodayBriefing(uid, geminiApiKey: _geminiApiKey);
    } catch (_) {
      // در صورت خطا (مثلا نبود اینترنت)، بریفینگ ساخته نمی‌شود؛ کاربر می‌تواند
      // دستی دکمه‌ی تحلیل مجدد را بزند.
    } finally {
      if (mounted) setState(() => _briefingLoading = false);
    }
  }

  Future<void> _regenerateBriefing(String uid) async {
    setState(() => _briefingLoading = true);
    try {
      await _analysisService.regenerateTodayBriefing(uid, geminiApiKey: _geminiApiKey);
    } finally {
      if (mounted) setState(() => _briefingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('کاربر یافت نشد')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('امروز'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<BriefingModel?>(
                stream: _firestoreService.streamBriefing(uid, _firestoreService.todayKey),
                builder: (context, snapshot) {
                  return _buildBriefingCard(uid, snapshot.data);
                },
              ),
              const SizedBox(height: 20),
              StreamBuilder<DailyLogModel>(
                stream: _firestoreService.streamTodayLog(uid),
                builder: (context, snapshot) {
                  final log = snapshot.data ?? DailyLogModel.empty(_firestoreService.todayKey);
                  return _buildStatsGrid(log);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'روند ۷ روز اخیر',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<DailyLogModel>>(
                stream: _firestoreService.streamLast7DaysLogs(uid),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  return _buildWeeklyChart(logs);
                },
              ),
              const SizedBox(height: 24),
              _buildManualEntrySection(uid),
            ],
          ),
        ),
      ),
    );
  }

  /// کارت DailyBriefing واقعی (بخش ۱ پرامپت) - تولیدشده سمت کلاینت.
  Widget _buildBriefingCard(String uid, BriefingModel? briefing) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'تحلیل امروز',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              if (briefing?.isAiGenerated == true) ...[
                const SizedBox(width: 6),
                const Text('(Gemini)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
              const Spacer(),
              _briefingLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                      onPressed: () => _regenerateBriefing(uid),
                      tooltip: 'تحلیل مجدد',
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            briefing?.summaryText ??
                (_briefingLoading
                    ? 'در حال تحلیل روند چند روز اخیرت...'
                    : 'هنوز داده‌ی کافی برای تحلیل نیست. چند روز لاگ کن تا تحلیل شروع شود.'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DailyLogModel log) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'مطالعه (دقیقه)',
          value: '${log.studyMinutes}',
          icon: Icons.menu_book,
          accentColor: AppColors.primary,
          progress: log.studyMinutes / studyGoalMinutes,
        ),
        StatCard(
          title: 'ورزش (دقیقه)',
          value: '${log.workoutMinutes}',
          icon: Icons.fitness_center,
          accentColor: AppColors.success,
          progress: log.workoutMinutes / workoutGoalMinutes,
        ),
        StatCard(
          title: 'استفاده از گوشی',
          value: '${log.totalScreenTimeMinutes} دقیقه',
          icon: Icons.smartphone,
          accentColor: AppColors.danger,
        ),
        StatCard(
          title: 'XP امروز',
          value: log.xpEarned.toStringAsFixed(0),
          icon: Icons.bolt,
          accentColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(List<DailyLogModel> logs) {
    if (logs.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'هنوز داده‌ای برای این هفته ثبت نشده',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(i.toDouble(), logs[i].studyMinutes.toDouble()),
              ],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(i.toDouble(), logs[i].workoutMinutes.toDouble()),
              ],
              isCurved: true,
              color: AppColors.success,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  /// فرم ورود دستی ساده برای ثبت دقایق مطالعه/ورزش امروز.
  /// در فازهای بعد این با ردیاب زنده (تایمر) جایگزین/تکمیل می‌شود.
  Widget _buildManualEntrySection(String uid) {
    final studyController = TextEditingController();
    final workoutController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ثبت دستی امروز',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: studyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'دقایق مطالعه'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: workoutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'دقایق ورزش'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final study = int.tryParse(studyController.text) ?? 0;
              final workout = int.tryParse(workoutController.text) ?? 0;
              await _firestoreService.upsertTodayLog(uid, {
                'studyMinutes': study,
                'workoutMinutes': workout,
              });
              studyController.clear();
              workoutController.clear();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ثبت شد ✅')),
                );
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
