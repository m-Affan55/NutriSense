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
    with SingleTickerProviderStateMixin {
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isResending = false;
  bool _isVerifyingOtp = false;
  bool _hasNavigated = false;

  static const int _codeLength = 6;
  final List<TextEditingController> _otpControllers =
      List.generate(_codeLength, (_) => TextEditingController());
  late final List<FocusNode> _otpFocusNodes;

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _otpFocusNodes = List.generate(_codeLength, (i) {
      return FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpControllers[i].text.isEmpty &&
              i > 0) {
            _otpFocusNodes[i - 1].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
      );
    });

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

  void _onVerified() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    CustomToast.show(
      context,
      LanguageController.instance.isUrdu
          ? 'ای میل کی تصدیق کامیاب رہی!'
          : 'Email verified successfully!',
      subtitle: LanguageController.instance.isUrdu
          ? 'نیوٹری سینس میں خوش آمدید'
          : 'Welcome to NutriSense!',
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
      );

      if (!mounted) return;
      _startCooldownTimer();

      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'تصدیقی کوڈ دوبارہ بھیج دیا گیا ہے!'
            : 'Verification code resent successfully!',
        subtitle: LanguageController.instance.isUrdu
            ? 'براہ کرم اپنا ای میل ان باکس چیک کریں۔'
            : 'Please check your email inbox for the 6-digit code.',
        isError: false,
      );
    } on AuthException catch (ae) {
      if (!mounted) return;
      final msg = ae.message.toLowerCase();
      String reason;
      if (ae.statusCode == '429' ||
          msg.contains('rate limit') ||
          msg.contains('over_email_send_rate_limit')) {
        reason =
            'Email send limit exceeded. Please wait a few minutes before trying again.';
      } else {
        reason = ae.message;
      }
      CustomToast.show(
        context,
        'Unable to resend code',
        subtitle: reason,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to resend code',
        subtitle: 'Network error. Please check your internet connection.',
        isError: true,
      );
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
        throw const AuthException('Invalid or expired verification code');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to verify OTP',
        subtitle: e.message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to verify OTP',
        subtitle: 'Network error or invalid code entered.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Handle pasting a multi-digit string
    if (digits.length > 1) {
      for (int i = 0; i < _codeLength && i < digits.length; i++) {
        _otpControllers[i].text = digits[i];
      }
      if (digits.length >= _codeLength) {
        _otpFocusNodes.last.unfocus();
        _verifyManualOtp();
      } else {
        _otpFocusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (digits.isNotEmpty) {
      _otpControllers[index].text = digits;
      if (index < _codeLength - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        final fullCode = _otpControllers.map((c) => c.text.trim()).join();
        if (fullCode.length == _codeLength) {
          _verifyManualOtp();
        }
      }
    }
  }

  Widget _buildOtpBox(int index, Color primaryColor) {
    return Container(
      width: 46,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFF161A22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _otpControllers[index].text.isNotEmpty
                  ? primaryColor.withAlpha(160)
                  : Colors.white.withAlpha(25),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
        onChanged: (val) => _onDigitChanged(index, val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final isUrdu = LanguageController.instance.isUrdu;
    final primaryColor =
        isRamadan ? RamadanColors.primaryCyan : const Color(0xFF00E676);
    final accentGold =
        isRamadan ? RamadanColors.accentGold : const Color(0xFFFFD166);

    return Scaffold(
      backgroundColor:
          isRamadan ? RamadanColors.bgMidnight : const Color(0xFF0D0F14),
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

              // Animated Pulsing Icon
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
                isUrdu ? 'اپنا تصدیقی کوڈ درج کریں' : 'Enter Verification Code',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                isUrdu
                    ? 'ہم نے 6 ہندسوں کا تصدیقی کوڈ اس پتے پر بھیجا ہے:'
                    : "We've sent a 6-digit verification code to:",
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
              const SizedBox(height: 36),

              // 6-Digit OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (i) => _buildOtpBox(i, primaryColor)),
              ),
              const SizedBox(height: 32),

              // Verify Code Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifyingOtp ? null : _verifyManualOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: primaryColor.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isVerifyingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isUrdu ? 'کوڈ کی تصدیق کریں' : 'Verify Code',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isUrdu ? 'کوڈ موصول نہیں ہوا؟ ' : "Didn't get the code? ",
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
                              isUrdu ? 'دوبارہ بھیجیں' : 'Resend Code',
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
              const SizedBox(height: 32),

              // Helpful Info Note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: accentGold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isUrdu
                            ? 'کوڈ 10 منٹ میں ختم ہو جائے گا۔ اگر ای میل نہ ملے تو سپیم فولڈر چیک کریں۔'
                            : 'This code expires in 10 minutes. If you don\'t see the email, check your spam folder.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
