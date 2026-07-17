import 'dart:convert';
import 'package:http/http.dart' as http;

/// فراخوانی مستقیم Gemini 1.5 Flash از داخل اپ فلاتر.
/// چون Cloud Functions نیاز به پلن Blaze دارد، طبق درخواست صریح کاربر برای
/// ماندن روی Spark Plan رایگان، این تماس مستقیماً از کلاینت انجام می‌شود.
///
/// نکته امنیتی: چون این اپ کاملاً شخصی و تک‌کاربره است، نگه‌داشتن کلید API
/// در Firestore (سند خود کاربر، پشت قوانین امنیتی auth.uid==userId) پذیرفتنی
/// است. اگر بعداً اپ را عمومی کردی، حتما این تماس را پشت یک بک‌اند ببر.
class GeminiService {
  static const _model = 'gemini-1.5-flash';

  Future<String?> generateText({
    required String apiKey,
    required String prompt,
  }) async {
    if (apiKey.isEmpty) return null;

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'maxOutputTokens': 400,
          },
        }),
      );

      if (response.statusCode != 200) {
        return null; // در صورت خطا، سرویس فراخواننده باید fallback قالبی نمایش دهد
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      return (parts[0]['text'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }
}
