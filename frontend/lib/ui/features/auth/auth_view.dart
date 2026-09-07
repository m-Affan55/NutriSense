import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/onboarding_view.dart';
import '../navigation/main_navigation_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/language_controller.dart';
import '../../../core/email_verifier_service.dart';
import '../../widgets/terms_dialog.dart';
import 'forgot_password_view.dart';
import 'email_verification_view.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  String _tagline = "AI-Powered Personal Nutritionist";

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTagline();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTagline() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? prefs.getString('language');
    if (lang == 'ur') {
      setState(() {
        _tagline = "مصنوعی ذہانت سے لیس آپ کا غذائی ماہر";
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!isLogin && !_acceptedTerms) {
        CustomToast.show(context, 'Please accept the terms and privacy policy');
        return;
      }
      
      setState(() => _isLoading = true);
      final email = _emailController.text.trim();
      
      try {
        final supabase = Supabase.instance.client;
        
        if (isLogin) {
          try {
            await supabase.auth.signInWithPassword(
              email: email,
              password: _passwordController.text,
            );
          } on AuthException catch (ae) {
            final msg = ae.message.toLowerCase();
            if (msg.contains('email not confirmed') || msg.contains('unconfirmed')) {
              if (!mounted) return;
              final isUrdu = LanguageController.instance.isUrdu;
              CustomToast.show(
                context,
                isUrdu
                    ? 'برائے مہربانی لاگ ان کرنے سے پہلے اپنے ای میل کی تصدیق کریں'
                    : 'Please verify your email before logging in.',
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmailVerificationScreen(
                    email: email,
                  ),
                ),
              );
              return;
            }
            rethrow;
          }
          
          if (!mounted) return;
          
          // Check if they have a completed profile or completed onboarding
          final user = supabase.auth.currentUser;
          if (user != null) {
            final prefs = await SharedPreferences.getInstance();
            final localDone = prefs.getBool('onboarding_completed_${user.id}') ?? false;
            if (localDone) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              );
              return;
            }

            final profileResponse = await supabase
                .from('health_profiles')
                .select('id')
                .eq('user_id', user.id)
                .maybeSingle();
                
            if (profileResponse != null) {
              await prefs.setBool('onboarding_completed_${user.id}', true);
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              );
              return;
            }
          }
          
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingWizardScreen()),
          );
          
        } else {
          // -------------------------------------------------------------
          // STEP 1: Verify whether the email actually exists
          // -------------------------------------------------------------
          final existenceStatus = await EmailVerifierService.verifyEmailExistence(email);
          if (existenceStatus == EmailVerificationStatus.noInternet) {
            if (!mounted) return;
            CustomToast.show(
              context,
              'Unable to verify your email address',
              subtitle: 'Network error. Please check your internet connection and try again.',
              isError: true,
            );
            return;
          }
          if (existenceStatus == EmailVerificationStatus.domainDoesNotExist) {
            if (!mounted) return;
            CustomToast.show(
              context,
              'Unable to verify your email address',
              subtitle: 'This email address does not exist.',
              isError: true,
            );
            return;
          }

          // -------------------------------------------------------------
          // STEP 2: Send Email via Supabase Auth
          // -------------------------------------------------------------
          final res = await supabase.auth.signUp(
            email: email,
            password: _passwordController.text,
            data: {'full_name': _nameController.text.trim()},
          );
          
          if (!mounted) return;

          // Check if email already registered (Supabase email enumeration protection returns empty identities)
          final identities = res.user?.identities;
          if (res.user != null && (identities == null || identities.isEmpty)) {
            // The email already exists in Supabase auth.users.
            // If it was never verified, attempt to resend the signup OTP so the user can complete verification!
            try {
              await supabase.auth.resend(
                type: OtpType.signup,
                email: email,
              );

              if (!mounted) return;
              CustomToast.show(
                context,
                'Verification code sent!',
                subtitle: 'This account was pending verification. A new 6-digit code was sent to your email.',
                isError: false,
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmailVerificationScreen(email: email),
                ),
              );
              return;
            } on AuthException catch (resendErr) {
              if (!mounted) return;
              final rMsg = resendErr.message.toLowerCase();
              String reason;
              if (rMsg.contains('already confirmed') || rMsg.contains('verified')) {
                reason = 'An account with this email is already verified. Please log in.';
              } else if (resendErr.statusCode == '429' || rMsg.contains('rate limit')) {
                reason = 'Email send limit reached. Please wait a few minutes before trying again.';
              } else {
                reason = resendErr.message;
              }
              CustomToast.show(
                context,
                'Unable to create account',
                subtitle: reason,
                isError: true,
              );
              return;
            } catch (e) {
              if (!mounted) return;
              CustomToast.show(
                context,
                'Unable to create account',
                subtitle: 'An account with this email already exists. Please log in.',
                isError: true,
              );
              return;
            }
          }

          // If session is already created (Confirm Email is disabled in Supabase)
          if (res.session != null) {
            CustomToast.show(
              context,
              'Account created successfully!',
              isError: false,
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingWizardScreen()),
            );
            return;
          }

          // -------------------------------------------------------------
          // STEP 3: Only on actual new signup show alert & open OTP page
          // -------------------------------------------------------------
          CustomToast.show(
            context,
            'Verification code sent successfully!',
            subtitle: 'Please check your email inbox for the 6-digit code.',
            isError: false,
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email),
            ),
          );
        }
      } on AuthException catch (ae) {
        if (!mounted) return;
        final msg = ae.message.toLowerCase();
        String reason;
        if (ae.statusCode == '429' || msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
          reason = 'Email send limit exceeded. Please wait a few minutes before trying again.';
        } else if (msg.contains('already registered') || msg.contains('already exists')) {
          reason = 'An account with this email already exists.';
        } else if (msg.contains('invalid') || msg.contains('does not exist') || msg.contains('recipient')) {
          reason = 'This email address does not exist.';
        } else if (msg.contains('disabled') || msg.contains('smtp') || msg.contains('provider')) {
          reason = 'Email delivery service is currently unavailable. Please contact support.';
        } else {
          reason = ae.message;
        }
        CustomToast.show(
          context,
          'Unable to verify your email address',
          subtitle: reason,
          isError: true,
        );
      } on SocketException {
        if (!mounted) return;
        CustomToast.show(
          context,
          'Unable to verify your email address',
          subtitle: 'Network error. Please check your internet connection.',
          isError: true,
        );
      } catch (e) {
        if (!mounted) return;
        final errStr = e.toString().replaceAll(RegExp(r'.*Exception:?\s*'), '');
        CustomToast.show(
          context,
          'Unable to verify your email address',
          subtitle: errStr.isNotEmpty ? errStr : 'An unexpected error occurred. Please try again.',
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

      if (webClientId == null || webClientId.isEmpty) {
        throw Exception('GOOGLE_WEB_CLIENT_ID is not configured in your .env file.');
      }

      // Initialize the singleton instance with our client IDs
      await GoogleSignIn.instance.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      // Authenticate natively (throws on cancel/failure)
      final googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: ID Token is null.');
      }

      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (!mounted) return;

      // Check if user has completed onboarding / health profile
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileResponse = await supabase
            .from('health_profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (!mounted) return;

        if (profileResponse != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingWizardScreen()),
      );
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        // Ignore user cancellation errors to prevent showing confusing toast popups
        if (!errStr.contains('sign_in_canceled') && !errStr.contains('canceled')) {
          CustomToast.show(context, errStr);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTermsDialog() {
    showTermsAndPrivacyDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final theme = isRamadan ? buildRamadanTheme(false) : buildDarkTheme(false);
    final isUrdu = LanguageController.instance.isUrdu;
    
    return Scaffold(
      body: Theme(
        data: theme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const SizedBox(height: 20),
                    Text(
                      'NutriSense',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tagline,
                      textAlign: TextAlign.center,
                      style: isUrdu
                          ? const TextStyle(
                              fontFamily: 'JameelNooriNastaleeq',
                              fontSize: 18,
                              color: Colors.white70,
                            )
                          : GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                    ),
                  const SizedBox(height: 48),

                  // Tab Switcher
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: isLogin ? 0 : MediaQuery.of(context).size.width / 2 - 24,
                          right: isLogin ? MediaQuery.of(context).size.width / 2 - 24 : 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(40),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => isLogin = true),
                                child: Center(
                                  child: Text(
                                    'Login',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: isLogin ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(150),
                                      fontWeight: isLogin ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => isLogin = false),
                                child: Center(
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: !isLogin ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(150),
                                      fontWeight: !isLogin ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form Fields
                  if (!isLogin)
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
                    ),
                  if (!isLogin) const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your email';
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(v.trim())) return 'Please enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
                  ),
                  
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your password';
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _showTermsDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'I agree to Terms & Privacy Policy', 
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  
                  SizedBox(height: isLogin ? 20 : 32),

                  // Submit Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, const Color(0xFF00BCD4)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isLogin ? 'Login' : 'Create Account',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),

                  if (isLogin) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withAlpha(30))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withAlpha(30))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withAlpha(40)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.white),
                      label: Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],

                ],
              ),
            ),
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final activeColor = isRamadan ? RamadanColors.primaryCyan : const Color(0xFF00E676);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textDirection: TextDirection.ltr,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        suffixIcon: suffixIcon,
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
          borderSide: BorderSide(color: activeColor, width: 1.5),
        ),
      ),
    );
  }
}
