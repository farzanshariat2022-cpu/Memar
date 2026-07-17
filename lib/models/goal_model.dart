import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع گره در درخت هدف. ترتیب از کلی به جزئی طبق بخش ۲ پرامپت:
/// Goal -> Project -> Milestone -> Week -> Day
enum GoalNodeType { goal, project, milestone, week, day }

extension GoalNodeTypeLabel on GoalNodeType {
  String get label {
    switch (this) {
      case GoalNodeType.goal:
        return 'هدف اصلی';
      case GoalNodeType.project:
        return 'پروژه';
      case GoalNodeType.milestone:
        return 'نقطه عطف';
      case GoalNodeType.week:
        return 'هفته';
      case GoalNodeType.day:
        return 'روز';
    }
  }

  /// نوع فرزند پیش‌فرض هنگام افزودن زیرمجموعه به این گره
  GoalNodeType? get childType {
    switch (this) {
      case GoalNodeType.goal:
        return GoalNodeType.project;
      case GoalNodeType.project:
        return GoalNodeType.milestone;
      case GoalNodeType.milestone:
        return GoalNodeType.week;
      case GoalNodeType.week:
        return GoalNodeType.day;
      case GoalNodeType.day:
        return null; // زیر «روز» فقط تسک تعریف می‌شود، نه گره جدید
    }
  }
}

/// مدل گره درخت هدف - نگاشت‌شده روی سند users/{uid}/goals/{goalId}
class GoalModel {
  final String id;
  final String title;
  final String description;
  final GoalNodeType type;
  final String? parentId; // null یعنی ریشه (Goal اصلی)
  final int order;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.parentId,
    this.order = 0,
    required this.createdAt,
  });

  factory GoalModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return GoalModel(
      id: doc.id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: GoalNodeType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GoalNodeType.goal,
      ),
      parentId: map['parentId'],
      order: map['order'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'parentId': parentId,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
