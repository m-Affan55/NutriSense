import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../core/language_controller.dart';
import 'auth_view.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadLanguage() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        CustomToast.show(
          context,
          _t('successToast'),
          isError: false,
        );

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          // If launched via email password recovery link (stack was cleared),
          // sign out temporary recovery session and redirect cleanly back to Login!
          await supabase.auth.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
            );
          }
        }
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
        'title': 'Update Password',
        'desc': 'Enter your new password below to update your credentials.',
        'newPassword': 'New Password',
        'confirmPassword': 'Confirm New Password',
        'save': 'Update Password',
        'required': 'Required',
        'mismatch': 'Passwords do not match',
        'minLength': 'Password must be at least 8 characters',
        'successToast': 'Password updated successfully!',
      },
      'ur': {
        'title': 'پاس ورڈ اپ ڈیٹ کریں',
        'desc': 'اپنی نئی اسناد اپ ڈیٹ کرنے کے لیے نیچے اپنا نیا پاس ورڈ درج کریں۔',
        'newPassword': 'نیا پاس ورڈ',
        'confirmPassword': 'نئے پاس ورڈ کی تصدیق کریں',
        'save': 'پاس ورڈ تبدیل کریں',
        'required': 'لازمی',
        'mismatch': 'پاس ورڈ مطابقت نہیں رکھتے',
        'minLength': 'پاس ورڈ کم از کم 8 حروف کا ہونا چاہئے',
        'successToast': 'پاس ورڈ کامیابی کے ساتھ تبدیل ہو گیا!',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
      ),
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
                    Text(
                      _t('desc'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('newPassword'),
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return _t('required');
                        if (v.length < 8) return _t('minLength');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('confirmPassword'),
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return _t('required');
                        if (v != _passwordController.text) return _t('mismatch');
                        return null;
                      },
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
                        onPressed: _isLoading ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _t('save'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
