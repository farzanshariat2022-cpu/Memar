import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestoreService = FirestoreService();
  final _apiKeyController = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: StreamBuilder<AppUserModel?>(
        stream: _firestoreService.streamUserProfile(uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (profile != null && _apiKeyController.text.isEmpty && profile.geminiApiKey.isNotEmpty) {
            _apiKeyController.text = profile.geminiApiKey;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'کلید Gemini API',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'برای فعال شدن تحلیل هوشمند روزانه (DailyBriefing) و ژورنال هوشمند، '
                  'یک کلید رایگان از Google AI Studio (aistudio.google.com) بساز و اینجا وارد کن. '
                  'اگر خالی بگذاری، اپ همچنان یک تحلیل قالبی (بدون AI) نشان می‌دهد.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await _firestoreService.saveGeminiApiKey(
                            uid,
                            _apiKeyController.text.trim(),
                          );
                          setState(() => _saving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ذخیره شد ✅')),
                            );
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('ذخیره'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
