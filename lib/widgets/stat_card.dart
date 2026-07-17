import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// کارت نمایش یک آمار روزانه (مثلا دقایق مطالعه) همراه با نوار پیشرفت
/// نسبت به یک هدف روزانه دلخواه.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final double? progress; // بین ۰ و ۱ - اختیاری

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
