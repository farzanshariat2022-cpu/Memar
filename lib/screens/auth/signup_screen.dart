import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _handleSignup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final error = await auth.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ساخت حساب')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'نام'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'ایمیل'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'رمز عبور (حداقل ۶ کاراکتر)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _handleSignup,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('ثبت‌نام'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
