import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/skill_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'skill_card.dart';

/// درخت مهارت (بخش ۳ پرامپت): چهار تب دانش / بدن / ذهن / روابط.
/// هر مهارت یک نوار پیشرفت و لول دارد؛ کاربر می‌تواند مهارت دلخواه اضافه کند.
class SkillTreeScreen extends StatelessWidget {
  const SkillTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;
    final firestoreService = FirestoreService();

    return DefaultTabController(
      length: SkillCategory.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهارت‌ها'),
          bottom: TabBar(
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: SkillCategory.values.map((c) => Tab(text: c.label)).toList(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () => _showAddSkillDialog(context, uid, firestoreService),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        body: TabBarView(
          children: SkillCategory.values.map((category) {
            return StreamBuilder<List<SkillModel>>(
              stream: firestoreService.streamSkillsByCategory(uid, category),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final skills = snapshot.data ?? [];
                if (skills.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'هنوز مهارتی در دسته «${category.label}» نداری.\nبا دکمه + یکی اضافه کن.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: skills
                      .map((s) => SkillCard(uid: uid, skill: s, firestoreService: firestoreService))
                      .toList(),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context, String uid, FirestoreService firestoreService) {
    final nameController = TextEditingController();
    final unitController = TextEditingController(text: 'دقیقه');
    final rateController = TextEditingController(text: '1');
    SkillCategory selectedCategory = SkillCategory.knowledge;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('افزودن مهارت جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'اسم مهارت (مثلا: نقاشی)'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<SkillCategory>(
                value: selectedCategory,
                dropdownColor: AppColors.surfaceLight,
                decoration: const InputDecoration(hintText: 'دسته'),
                items: SkillCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCategory = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(hintText: 'واحد (دقیقه/بازی/...)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'XP هر واحد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                await firestoreService.addSkill(
                  uid,
                  SkillModel(
                    id: '',
                    name: name,
                    category: selectedCategory,
                    xpPerUnit: double.tryParse(rateController.text) ?? 1,
                    unitLabel: unitController.text.trim().isEmpty
                        ? 'دقیقه'
                        : unitController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
