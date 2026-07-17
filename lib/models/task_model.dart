import 'package:cloud_firestore/cloud_firestore.dart';

/// مدل تسک - نگاشت‌شده روی سند users/{uid}/tasks/{taskId}
/// هر تسک به یک گره در درخت هدف (معمولا از نوع day) متصل است، اما
/// می‌تواند مستقل (goalId == null) هم باشد؛ یعنی یک کار روزمره ساده.
class TaskModel {
  final String id;
  final String title;
  final String? goalId;
  final String? skillId;
  final DateTime? date;
  final bool isCompleted;
  final double xpReward;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.goalId,
    this.skillId,
    this.date,
    this.isCompleted = false,
    this.xpReward = 0,
    required this.createdAt,
  });

  factory TaskModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return TaskModel(
      id: doc.id,
      title: map['title'] ?? '',
      goalId: map['goalId'],
      skillId: map['skillId'],
      date: (map['date'] as Timestamp?)?.toDate(),
      isCompleted: map['isCompleted'] ?? false,
      xpReward: (map['xpReward'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'goalId': goalId,
      'skillId': skillId,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'isCompleted': isCompleted,
      'xpReward': xpReward,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
