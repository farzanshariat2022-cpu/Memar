import 'package:flutter/material.dart';
import '../../models/skill_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class SkillCard extends StatelessWidget {
  final String uid;
  final SkillModel skill;
  final FirestoreService firestoreService;

  const SkillCard({
    super.key,
    required this.uid,
    required this.skill,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${skill.level}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: skill.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${skill.xp.toStringAsFixed(0)} / ${skill.xpThreshold.toStringAsFixed(0)} XP',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceLight,
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                onSelected: (value) {
                  if (value == 'delete') _confirmDelete(context);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('حذف مهارت')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogActivityDialog(context),
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: Text(
                'ثبت فعالیت (${skill.unitLabel})',
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogActivityDialog(BuildContext context) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('ثبت فعالیت: ${skill.name}'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'چند ${skill.unitLabel}؟',
            suffixText: '${skill.xpPerUnit} XP / ${skill.unitLabel}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;

              Navigator.pop(ctx);
              final result = await firestoreService.logSkillActivity(uid, skill, amount);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: result.leveledUp ? AppColors.success : null,
                    content: Text(
                      result.leveledUp
                          ? '🎉 ${skill.name} به لول ${result.newLevel} رسید! (+${result.xpGained.toStringAsFixed(0)} XP)'
                          : '+${result.xpGained.toStringAsFixed(0)} XP به ${skill.name} اضافه شد',
                    ),
                  ),
                );
              }
            },
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف مهارت؟'),
        content: Text(
          '«${skill.name}» و تاریخچه‌ی پیشرفتش حذف می‌شود.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await firestoreService.deleteSkill(uid, skill.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
