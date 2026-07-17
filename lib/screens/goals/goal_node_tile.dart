import 'package:flutter/material.dart';
import '../../models/goal_model.dart';
import '../../models/task_model.dart';
import '../../models/skill_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class GoalNodeTile extends StatelessWidget {
  final String uid;
  final GoalModel goal;
  final FirestoreService firestoreService;

  const GoalNodeTile({
    super.key,
    required this.uid,
    required this.goal,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          title: Text(
            goal.title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            goal.type.label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            color: AppColors.surfaceLight,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              if (goal.type.childType != null)
                const PopupMenuItem(value: 'add_child', child: Text('افزودن زیرمجموعه')),
              const PopupMenuItem(value: 'add_task', child: Text('افزودن تسک')),
              const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              const PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (goal.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    goal.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),

            // تسک‌های متصل به این گره
            StreamBuilder<List<TaskModel>>(
              stream: firestoreService.streamTasksForGoal(uid, goal.id),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: tasks.map((t) => _buildTaskRow(context, t)).toList(),
                );
              },
            ),

            // زیرگره‌ها (بازگشتی)
            if (goal.type.childType != null)
              StreamBuilder<List<GoalModel>>(
                stream: firestoreService.streamGoalChildren(uid, goal.id),
                builder: (context, snapshot) {
                  final children = snapshot.data ?? [];
                  if (children.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'زیرمجموعه‌ای ثبت نشده',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    );
                  }
                  return Column(
                    children: children
                        .map((child) => GoalNodeTile(
                              uid: uid,
                              goal: child,
                              firestoreService: firestoreService,
                            ))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (_) => firestoreService.toggleTaskCompletion(uid, task),
          ),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (task.xpReward > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '+${task.xpReward.toStringAsFixed(0)} XP',
                style: const TextStyle(color: AppColors.primary, fontSize: 11),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            onPressed: () => firestoreService.deleteTask(uid, task.id),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'add_child':
        _showGoalFormDialog(context, parentId: goal.id, type: goal.type.childType!);
        break;
      case 'add_task':
        _showAddTaskDialog(context);
        break;
      case 'edit':
        _showGoalFormDialog(context, existing: goal);
        break;
      case 'delete':
        _confirmDelete(context);
        break;
    }
  }

  void _showGoalFormDialog(
    BuildContext context, {
    String? parentId,
    GoalNodeType? type,
    GoalModel? existing,
  }) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(existing != null ? 'ویرایش' : 'افزودن ${type!.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'عنوان'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(hintText: 'توضیحات (اختیاری)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              if (existing != null) {
                await firestoreService.updateGoal(uid, existing.id, {
                  'title': title,
                  'description': descController.text.trim(),
                });
              } else {
                await firestoreService.addGoal(
                  uid,
                  GoalModel(
                    id: '',
                    title: title,
                    description: descController.text.trim(),
                    type: type!,
                    parentId: parentId,
                    createdAt: DateTime.now(),
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final xpController = TextEditingController(text: '10');
    String? selectedSkillId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('افزودن تسک'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'عنوان تسک'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: xpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'پاداش XP'),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<SkillModel>>(
                future: firestoreService.getAllSkillsOnce(uid),
                builder: (context, snapshot) {
                  final skills = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: selectedSkillId,
                    dropdownColor: AppColors.surfaceLight,
                    decoration: const InputDecoration(hintText: 'اتصال به مهارت (اختیاری)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('هیچکدام')),
                      ...skills.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setState(() => selectedSkillId = v),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                await firestoreService.addTask(
                  uid,
                  TaskModel(
                    id: '',
                    title: title,
                    goalId: goal.id,
                    skillId: selectedSkillId,
                    xpReward: double.tryParse(xpController.text) ?? 0,
                    createdAt: DateTime.now(),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف شود؟'),
        content: Text(
          'این کار «${goal.title}» و تمام زیرمجموعه‌ها و تسک‌های متصل به آن را برای همیشه حذف می‌کند.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteGoalCascade(uid, goal.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
