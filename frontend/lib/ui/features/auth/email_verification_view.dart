import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/language_controller.dart';
import '../../../core/ramadan_controller.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../core/theme.dart';
import '../onboarding/onboarding_view.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isResending = false;
  bool _isCheckingStatus = false;
  bool _showManualOtp = false;

  // Manual OTP input support
  static const int _codeLength = 6;
  final List<TextEditingController> _otpControllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(_codeLength, (_) => FocusNode());
  bool _isVerifyingOtp = false;

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldownTimer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToAuthChanges();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _authSubscription?.cancel();
    _pulseController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _onVerified();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerificationStatus(silent: true);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (_isCheckingStatus) return;
    if (!silent) setState(() => _isCheckingStatus = true);

    try {
      final supabase = Supabase.instance.client;
      // Refresh the session to check if confirmed
      final res = await supabase.auth.refreshSession();
      final user = res.user ?? supabase.auth.currentUser;

      if (user != null && user.emailConfirmedAt != null) {
        _onVerified();
        return;
      }

      if (!silent && mounted) {
        CustomToast.show(
          context,
          LanguageController.instance.isUrdu
              ? 'تصدیق ابھی تک مکمل نہیں ہوئی۔ براہ کرم اپنے ای میل میں موجود لنک پر کلک کریں۔'
              : 'Email not verified yet. Please tap the link in your email.',
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        CustomToast.show(
          context,
          LanguageController.instance.isUrdu
              ? 'تصدیق کا انتظار ہے... براہ کرم اپنے ای میل میں لنک چیک کریں۔'
              : 'Waiting for verification... Please check the link in your email.',
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _isCheckingStatus = false);
    }
  }

  void _onVerified() {
    if (!mounted) return;
    CustomToast.show(
      context,
      LanguageController.instance.isUrdu
          ? 'ای میل کی تصدیق کامیاب رہی!'
          : 'Email verified successfully!',
      isError: false,
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingWizardScreen()),
      (route) => false,
    );
  }

  Future<void> _resendEmail() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'io.supabase.nutrisense://login-callback/',
      );

      if (!mounted) return;
      _startCooldownTimer();

      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'تصدیقی ای میل دوبارہ بھیج دی گئی ہے!'
            : 'Verification email resent successfully!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyManualOtp() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != _codeLength) {
      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'براہ کرم مکمل 6 ہندسوں کا کوڈ درج کریں'
            : 'Please enter all 6 digits',
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      if (!mounted) return;
      if (res.session != null || res.user != null) {
        _onVerified();
      } else {
        throw const AuthException('Invalid verification code');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      CustomToast.show(context, e.message);
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final isUrdu = LanguageController.instance.isUrdu;
    final primaryColor = isRamadan ? RamadanColors.primaryCyan : const Color(0xFF00E676);
    final accentGold = isRamadan ? RamadanColors.accentGold : const Color(0xFFFFD166);

    return Scaffold(
      backgroundColor: isRamadan ? RamadanColors.bgMidnight : const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: isUrdu ? 'واپس جائیں' : 'Back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Animated Pulsing Envelope Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withAlpha(25),
                    border: Border.all(color: primaryColor.withAlpha(80), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withAlpha(50),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 46,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                isUrdu ? 'اپنا ای میل چیک کریں' : 'Check Your Inbox',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                isUrdu
                    ? 'ہم نے تصدیقی ای میل اس پتے پر بھیجی ہے:'
                    : 'We\'ve sent an account activation email to:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 10),

              // Email Badge with Edit Option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.email,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isRamadan ? RamadanColors.textGold : primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.edit,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Step-by-step instructions card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isRamadan
                      ? RamadanColors.surfaceDark.withAlpha(220)
                      : const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRamadan
                        ? RamadanColors.primaryCyan.withAlpha(50)
                        : Colors.white.withAlpha(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          color: accentGold,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isUrdu ? 'اکاؤنٹ کیسے فعال کریں؟' : 'How to activate:',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStepRow(
                      step: '1',
                      title: isUrdu
                          ? 'اپنے فون پر جی میل (Gmail) کھولیں'
                          : 'Open your Gmail app on your phone',
                      icon: Icons.mail_outline,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      step: '2',
                      title: isUrdu
                          ? 'ای میل میں موجود "Confirm email address" پر کلک کریں'
                          : 'Tap "Confirm email address" in the email',
                      icon: Icons.link,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      step: '3',
                      title: isUrdu
                          ? 'ایپ خود بخود لاگ ان ہو جائے گی!'
                          : 'NutriSense will automatically activate!',
                      icon: Icons.check_circle_outline,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // "I've Verified My Email" Check Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingStatus ? null : () => _checkVerificationStatus(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: primaryColor.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20, color: Colors.black),
                  label: Text(
                    isUrdu ? 'میں نے تصدیق کر لی ہے' : 'I\'ve Confirmed in Email',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Optional: Manual OTP section toggle
              if (!_showManualOtp)
                TextButton(
                  onPressed: () => setState(() => _showManualOtp = true),
                  child: Text(
                    isUrdu ? 'یا 6 ہندسوں کا کوڈ درج کریں' : 'Or enter 6-digit code manually',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white54,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else ...[
                // Manual 6-Digit OTP Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isUrdu ? '6 ہندسوں کا کوڈ درج کریں' : 'Enter 6-digit code',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_codeLength, (i) {
                          return Container(
                            width: 42,
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            child: TextField(
                              controller: _otpControllers[i],
                              focusNode: _otpFocusNodes[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: const Color(0xFF161A22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: primaryColor, width: 2),
                                ),
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty && i < _codeLength - 1) {
                                  _otpFocusNodes[i + 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isVerifyingOtp ? null : _verifyManualOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isVerifyingOtp
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  isUrdu ? 'کوڈ تصدیق کریں' : 'Verify Code',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Resend Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isUrdu ? 'ای میل موصول نہیں ہوئی؟ ' : "Didn't get the email? ",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                  if (_cooldownSeconds > 0)
                    Text(
                      '${isUrdu ? 'دوبارہ بھیجیں ' : 'Resend in '}0:${_cooldownSeconds.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _resendEmail,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isResending
                          ? SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            )
                          : Text(
                              isUrdu ? 'دوبارہ بھیجیں' : 'Resend Email',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(30),
            border: Border.all(color: color.withAlpha(100)),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withAlpha(220),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
