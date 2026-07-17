import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_log_model.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../models/briefing_model.dart';
import '../models/skill_model.dart';

/// نقطه مرکزی تعامل با Firestore.
/// ساختار مجموعه‌ها دقیقا مطابق معماری کلی تعریف‌شده در پرامپت است تا
/// فازهای بعدی (اهداف، عادت‌ها، مهارت‌ها، ژورنال، ...) بدون تغییر ساختار روی
/// همین پایه سوار شوند.
///
/// users/{uid}
/// users/{uid}/daily_logs/{yyyy-MM-dd}
/// users/{uid}/goals/{goalId}          -> فاز ۲
/// users/{uid}/tasks/{taskId}          -> فاز ۲
/// users/{uid}/skills/{skillId}        -> فاز ۳
/// users/{uid}/habits/{habitId}        -> فاز ۴
/// users/{uid}/journal_entries/{id}    -> فاز ۵
/// users/{uid}/screen_time/{date}      -> فاز ۱ (نوشته می‌شود، در فازهای بعد تحلیل می‌شود)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  CollectionReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid).collection('daily_logs');

  Future<void> saveGeminiApiKey(String uid, String apiKey) async {
    await _db.collection('users').doc(uid).set(
      {'geminiApiKey': apiKey},
      SetOptions(merge: true),
    );
  }

  /// استریم زنده‌ی سند کاربر (پروفایل)
  Stream<AppUserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUserModel.fromMap(uid, snap.data()!);
    });
  }

  /// استریم زنده‌ی لاگ امروز - داشبورد مستقیماً به این گوش می‌دهد
  Stream<DailyLogModel> streamTodayLog(String uid) {
    return _userDoc(uid).doc(todayKey).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return DailyLogModel.empty(todayKey);
      }
      return DailyLogModel.fromMap(todayKey, snap.data()!);
    });
  }

  /// استریم زنده‌ی لاگ‌های ۷ روز اخیر - برای نمودار هفتگی داشبورد
  Stream<List<DailyLogModel>> streamLast7DaysLogs(String uid) {
    final sevenDaysAgo = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 6)));

    return _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: sevenDaysAgo)
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList());
  }

  /// آپدیت (merge) لاگ امروز - مثلا وقتی کاربر دقایق مطالعه را دستی وارد می‌کند
  Future<void> upsertTodayLog(String uid, Map<String, dynamic> partialData) async {
    await _userDoc(uid).doc(todayKey).set(partialData, SetOptions(merge: true));
  }

  /// ذخیره‌ی ساعتی داده اسکرین‌تایم (بخش ۱ پرامپت: users/{uid}/screen_time/{date})
  Future<void> saveScreenTimeSnapshot(
    String uid, {
    required int totalScreenTimeMinutes,
    required int instagramMinutes,
    required int youtubeMinutes,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('screen_time')
        .doc(todayKey)
        .set({
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'instagramMinutes': instagramMinutes,
      'youtubeMinutes': youtubeMinutes,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // هم‌زمان در لاگ روزانه هم منعکس می‌شود تا داشبورد یک‌جا بخواندش
    await upsertTodayLog(uid, {
      'totalScreenTimeMinutes': totalScreenTimeMinutes,
      'instagramMinutes': instagramMinutes,
      'youtubeMinutes': youtubeMinutes,
    });
  }

  // ================== سیستم هدف (Goal Hierarchy) - فاز ۲ ==================

  CollectionReference<Map<String, dynamic>> _goalsCol(String uid) =>
      _db.collection('users').doc(uid).collection('goals');

  CollectionReference<Map<String, dynamic>> _tasksCol(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  /// استریم زنده‌ی فرزندان مستقیم یک گره. parentId==null یعنی هدف‌های ریشه.
  Stream<List<GoalModel>> streamGoalChildren(String uid, String? parentId) {
    return _goalsCol(uid)
        .where('parentId', isEqualTo: parentId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((d) => GoalModel.fromDoc(d)).toList());
  }

  Future<String> addGoal(String uid, GoalModel goal) async {
    final doc = await _goalsCol(uid).add(goal.toMap());
    return doc.id;
  }

  Future<void> updateGoal(String uid, String goalId, Map<String, dynamic> data) async {
    await _goalsCol(uid).doc(goalId).update(data);
  }

  /// حذف یک گره به همراه تمام فرزندانش (بازگشتی) و تسک‌های متصل به آن‌ها
  Future<void> deleteGoalCascade(String uid, String goalId) async {
    final childrenSnap = await _goalsCol(uid).where('parentId', isEqualTo: goalId).get();
    for (final child in childrenSnap.docs) {
      await deleteGoalCascade(uid, child.id);
    }

    final tasksSnap = await _tasksCol(uid).where('goalId', isEqualTo: goalId).get();
    for (final task in tasksSnap.docs) {
      await task.reference.delete();
    }

    await _goalsCol(uid).doc(goalId).delete();
  }

  /// استریم زنده‌ی تسک‌های متصل به یک گره (معمولا یک گره از نوع «روز»)
  Stream<List<TaskModel>> streamTasksForGoal(String uid, String goalId) {
    return _tasksCol(uid)
        .where('goalId', isEqualTo: goalId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => TaskModel.fromDoc(d)).toList());
  }

  Future<void> addTask(String uid, TaskModel task) async {
    await _tasksCol(uid).add(task.toMap());
  }

  Future<void> deleteTask(String uid, String taskId) async {
    await _tasksCol(uid).doc(taskId).delete();
  }

  /// تیک‌زدن/برداشتن تسک - در صورت تکمیل، XP مربوطه به لاگ امروز و (در صورت
  /// اتصال) به مهارت مرتبط اضافه می‌شود.
  Future<void> toggleTaskCompletion(String uid, TaskModel task) async {
    final newState = !task.isCompleted;
    await _tasksCol(uid).doc(task.id).update({'isCompleted': newState});

    if (task.xpReward > 0) {
      await upsertTodayLog(uid, {
        'xpEarned': FieldValue.increment(newState ? task.xpReward : -task.xpReward),
      });

      if (task.skillId != null) {
        await applyXpDeltaToSkill(
          uid,
          task.skillId!,
          newState ? task.xpReward : -task.xpReward,
        );
      }
    }
  }

  // ================== DailyBriefing (تحلیل سمت کلاینت) - فاز ۲ ==================

  CollectionReference<Map<String, dynamic>> _briefingsCol(String uid) =>
      _db.collection('users').doc(uid).collection('briefings');

  Stream<BriefingModel?> streamBriefing(String uid, String date) {
    return _briefingsCol(uid).doc(date).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return BriefingModel.fromMap(date, snap.data()!);
    });
  }

  Future<BriefingModel?> getBriefing(String uid, String date) async {
    final doc = await _briefingsCol(uid).doc(date).get();
    if (!doc.exists || doc.data() == null) return null;
    return BriefingModel.fromMap(date, doc.data()!);
  }

  Future<void> saveBriefing(String uid, BriefingModel briefing) async {
    await _briefingsCol(uid).doc(briefing.date).set(briefing.toMap());
  }

  /// خواندن سند لاگ یک تاریخ مشخص (غیر-استریم) - برای محاسبات تحلیل شبانه
  Future<DailyLogModel> getLogForDate(String uid, String date) async {
    final doc = await _userDoc(uid).doc(date).get();
    if (!doc.exists || doc.data() == null) return DailyLogModel.empty(date);
    return DailyLogModel.fromMap(date, doc.data()!);
  }

  /// خواندن لاگ‌های N روز گذشته قبل از یک تاریخ مشخص (غیر-استریم)
  Future<List<DailyLogModel>> getPreviousDaysLogs(String uid, String beforeDate, int days) async {
    final before = DateFormat('yyyy-MM-dd').parse(beforeDate);
    final start = DateFormat('yyyy-MM-dd').format(before.subtract(Duration(days: days)));
    final end = DateFormat('yyyy-MM-dd').format(before.subtract(const Duration(days: 1)));

    final snap = await _userDoc(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThanOrEqualTo: end)
        .get();

    return snap.docs.map((d) => DailyLogModel.fromMap(d.id, d.data())).toList();
  }

  // ================== Skill Tree (XP و مهارت) - فاز ۳ ==================

  CollectionReference<Map<String, dynamic>> _skillsCol(String uid) =>
      _db.collection('users').doc(uid).collection('skills');

  Stream<List<SkillModel>> streamSkillsByCategory(String uid, SkillCategory category) {
    return _skillsCol(uid)
        .where('category', isEqualTo: category.name)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => SkillModel.fromDoc(d)).toList());
  }

  /// خواندن یک‌باره‌ی همه‌ی مهارت‌ها (برای دراپ‌داون انتخاب مهارت هنگام ساخت تسک)
  Future<List<SkillModel>> getAllSkillsOnce(String uid) async {
    final snap = await _skillsCol(uid).orderBy('name').get();
    return snap.docs.map((d) => SkillModel.fromDoc(d)).toList();
  }

  Future<void> addSkill(String uid, SkillModel skill) async {
    await _skillsCol(uid).add(skill.toMap());
  }

  Future<void> deleteSkill(String uid, String skillId) async {
    await _skillsCol(uid).doc(skillId).delete();
  }

  /// منطق لول‌آپ: وقتی XP به آستانه‌ی ۱۰۰ × لول فعلی رسید، یک لول بالا می‌رود.
  /// چون Cloud Function trigger نیاز به Blaze دارد، این محاسبه همین‌جا و در یک
  /// تراکنش (transaction) امن انجام می‌شود تا از race condition جلوگیری شود.
  /// خروجی: لولی که مهارت بعد از این تغییر در آن قرار گرفت، و اینکه لول‌آپ رخ داد یا نه.
  Future<({int newLevel, bool leveledUp})> applyXpDeltaToSkill(
    String uid,
    String skillId,
    double deltaXp,
  ) async {
    final docRef = _skillsCol(uid).doc(skillId);

    return _db.runTransaction<({int newLevel, bool leveledUp})>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return (newLevel: 1, leveledUp: false);

      var level = (snap.data()!['level'] ?? 1) as int;
      var xp = ((snap.data()!['xp'] as num?) ?? 0).toDouble();
      final startLevel = level;

      xp += deltaXp;

      // لول‌آپ به بالا
      var threshold = 100.0 * level;
      while (xp >= threshold) {
        xp -= threshold;
        level += 1;
        threshold = 100.0 * level;
      }

      // اگر XP منفی شد (مثلا برداشتن تیک یک تسک)، تا حد امکان لول را پایین می‌آوریم
      while (xp < 0 && level > 1) {
        level -= 1;
        threshold = 100.0 * level;
        xp += threshold;
      }
      xp = xp.clamp(0, threshold);

      tx.update(docRef, {'xp': xp, 'level': level});

      return (newLevel: level, leveledUp: level > startLevel);
    });
  }

  /// ثبت یک فعالیت روی یک مهارت (مثلا «۳۰ دقیقه مطالعه» یا «۱ بازی شطرنج»).
  /// XP بر اساس xpPerUnit همان مهارت محاسبه و هم به مهارت و هم به لاگ امروز اضافه می‌شود.
  Future<({int newLevel, bool leveledUp, double xpGained})> logSkillActivity(
    String uid,
    SkillModel skill,
    double amount,
  ) async {
    final xpGained = amount * skill.xpPerUnit;
    final result = await applyXpDeltaToSkill(uid, skill.id, xpGained);
    await upsertTodayLog(uid, {'xpEarned': FieldValue.increment(xpGained)});
    return (newLevel: result.newLevel, leveledUp: result.leveledUp, xpGained: xpGained);
  }

  /// ساخت مهارت‌های پیش‌فرض برای کاربر تازه‌ثبت‌نام‌شده، دقیقا طبق لیست بخش ۳ پرامپت.
  /// دسته «روابط» عمداً خالی می‌ماند تا کاربر خودش مهارت‌های اجتماعی دلخواهش را اضافه کند.
  Future<void> seedDefaultSkills(String uid) async {
    final batch = _db.batch();
    final now = DateTime.now();

    void addDefault(String name, SkillCategory category, double rate, String unit) {
      final ref = _skillsCol(uid).doc();
      batch.set(ref, SkillModel(
        id: ref.id,
        name: name,
        category: category,
        xpPerUnit: rate,
        unitLabel: unit,
        createdAt: now,
      ).toMap());
    }

    addDefault('مطالعه', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('زبان', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('کتاب‌خوانی', SkillCategory.knowledge, 1.0, 'دقیقه');
    addDefault('پادکست', SkillCategory.knowledge, 0.25, 'دقیقه');
    addDefault('طراحی', SkillCategory.knowledge, 0.5, 'دقیقه');
    addDefault('ورزش', SkillCategory.body, 1.5, 'دقیقه');
    addDefault('شطرنج', SkillCategory.mind, 20.0, 'بازی');
    addDefault('تخته‌نرد', SkillCategory.mind, 15.0, 'بازی');
    addDefault('مدیتیشن', SkillCategory.mind, 1.5, 'دقیقه');
    addDefault('ژورنال‌نویسی', SkillCategory.mind, 10.0, 'روز');

    await batch.commit();
  }
}
