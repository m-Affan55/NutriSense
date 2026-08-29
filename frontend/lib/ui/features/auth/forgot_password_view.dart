import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../core/language_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_loadLanguage);
    _loadLanguage();
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_loadLanguage);
    _emailController.dispose();
    super.dispose();
  }

  void _loadLanguage() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'io.supabase.nutrisense://reset-password/',
      );

      if (mounted) {
        CustomToast.show(
          context,
          _t('successToast'),
          isError: false,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'Reset Password',
        'desc': 'Enter your email address and we will send you a link to reset your password.',
        'email': 'Email Address',
        'send': 'Send Reset Link',
        'back': 'Back to Login',
        'required': 'Please enter a valid email',
        'successToast': 'Password reset link sent to your email!',
      },
      'ur': {
        'title': 'پاس ورڈ دوبارہ ترتیب دیں',
        'desc': 'اپنا ای میل ایڈریس درج کریں اور ہم آپ کو آپ کا پاس ورڈ دوبارہ ترتیب دینے کا لنک بھیجیں گے۔',
        'email': 'ای میل ایڈریس',
        'send': 'ری سیٹ لنک بھیجیں',
        'back': 'لاگ ان پر واپس جائیں',
        'required': 'براہ کرم درست ای میل درج کریں',
        'successToast': 'پاس ورڈ ری سیٹ لنک آپ کے ای میل پر بھیج دیا گیا ہے!',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14),
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.2,
            colors: [
              theme.colorScheme.primary.withAlpha(20),
              const Color(0xFF0D0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_reset,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _t('title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('desc'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('email'),
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: const Color(0xFF161A22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF00E676)),
                        ),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? _t('required') : null,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, const Color(0xFF00BCD4)],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _t('send'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _t('back'),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
