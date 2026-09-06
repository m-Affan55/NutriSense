import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    with WidgetsBindingObserver {
  static const int _codeLength = 6;
  static const int _maxAttempts = 5;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  int _remainingAttempts = _maxAttempts;
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _clipboardCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldownTimer();
    _checkClipboardForCode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForCode();
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

  Future<void> _checkClipboardForCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (RegExp(r'^\d{6}$').hasMatch(text) && text != _currentCode) {
        if (mounted) {
          setState(() => _clipboardCode = text);
        }
      } else {
        if (mounted && _clipboardCode != null) {
          setState(() => _clipboardCode = null);
        }
      }
    } catch (_) {
      // Ignore clipboard read permission or access errors
    }
  }

  String get _currentCode =>
      _controllers.map((c) => c.text.trim()).join();

  void _fillCode(String code) {
    if (code.length != _codeLength) return;
    for (int i = 0; i < _codeLength; i++) {
      _controllers[i].text = code[i];
    }
    setState(() => _clipboardCode = null);
    _focusNodes.last.requestFocus();
    _verifyOtp(code);
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Pasted full string into single box
      final clean = value.replaceAll(RegExp(r'\D'), '');
      if (clean.length == _codeLength) {
        _fillCode(clean);
        return;
      }
      _controllers[index].text = value.substring(value.length - 1);
    }

    if (value.isNotEmpty) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        final code = _currentCode;
        if (code.length == _codeLength) {
          _verifyOtp(code);
        }
      }
    }
  }

  Future<void> _verifyOtp([String? explicitCode]) async {
    final code = explicitCode ?? _currentCode;
    if (code.length != _codeLength) {
      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'برائے مہربانی مکمل 6 ہندسوں کا کوڈ درج کریں'
            : 'Please enter all 6 digits of the verification code',
      );
      return;
    }

    if (_remainingAttempts <= 0) {
      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'بہت زیادہ غلط کوششیں۔ برائے مہربانی نیا کوڈ طلب کریں۔'
            : 'Too many failed attempts. Please request a new code.',
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      if (!mounted) return;

      if (res.session != null || res.user != null) {
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
      } else {
        throw const AuthException('Verification failed: No session established.');
      }
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _remainingAttempts = (_remainingAttempts - 1).clamp(0, _maxAttempts);
      });

      // Clear input fields for next attempt
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();

      final isUrdu = LanguageController.instance.isUrdu;
      if (_remainingAttempts > 0) {
        CustomToast.show(
          context,
          isUrdu
              ? 'غلط کوڈ۔ $_remainingAttempts کوششیں باقی ہیں'
              : 'Invalid code. $_remainingAttempts attempt${_remainingAttempts == 1 ? '' : 's'} remaining',
        );
      } else {
        CustomToast.show(
          context,
          isUrdu
              ? 'کوششیں ختم ہو گئیں۔ برائے مہربانی نیا کوڈ منگوائیں'
              : 'Attempts exhausted. Please request a new verification code',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
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
      setState(() {
        _remainingAttempts = _maxAttempts;
        for (final c in _controllers) {
          c.clear();
        }
      });
      _focusNodes.first.requestFocus();
      _startCooldownTimer();

      CustomToast.show(
        context,
        LanguageController.instance.isUrdu
            ? 'نیا کوڈ کامیابی سے بھیج دیا گیا ہے!'
            : 'New verification code sent to your email!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _openEmailApp() async {
    final mailtoUri = Uri(scheme: 'mailto', path: widget.email);
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        CustomToast.show(
          context,
          LanguageController.instance.isUrdu
              ? 'براہ کرم اپنا ای میل ایپ خود کھولیں'
              : 'Please open your email app manually',
        );
      }
    } catch (_) {
      if (mounted) {
        CustomToast.show(
          context,
          LanguageController.instance.isUrdu
              ? 'براہ کرم اپنا ای میل ایپ خود کھولیں'
              : 'Please open your email app manually',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final isUrdu = LanguageController.instance.isUrdu;
    final primaryColor = isRamadan ? RamadanColors.primaryCyan : const Color(0xFF00E676);
    final accentColor = isRamadan ? RamadanColors.accentGold : const Color(0xFFFF6D00);

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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Glowing Icon Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withAlpha(30),
                  border: Border.all(color: primaryColor.withAlpha(75), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(50),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 40,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isUrdu ? 'ای میل کی تصدیق کریں' : 'Verify Your Email',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                isUrdu
                    ? 'ہم نے آپ کے ای میل ایڈریس پر 6 ہندسوں کا کوڈ اور تصدیقی لنک بھیجا ہے:'
                    : 'We\'ve sent a 6-digit verification code and confirmation link to:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),

              // Email Chip with Edit Option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.email,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isRamadan ? RamadanColors.textGold : primaryColor,
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

              // Clipboard Quick Paste Chip (if detected)
              if (_clipboardCode != null) ...[
                GestureDetector(
                  onTap: () => _fillCode(_clipboardCode!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: primaryColor.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          isUrdu
                              ? 'کلپ بورڈ سے کوڈ لگائیں: $_clipboardCode'
                              : 'Paste code from clipboard: $_clipboardCode',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 6-Digit PIN Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (i) {
                  return Container(
                    width: 46,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[i].text.isEmpty &&
                            i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                      },
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        autofocus: i == 0,
                        enabled: _remainingAttempts > 0 && !_isVerifying,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: isRamadan
                              ? RamadanColors.surfaceElevated.withAlpha(180)
                              : const Color(0xFF161A22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(30),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(30),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.red.withAlpha(75),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(i, val),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),

              // Remaining attempts indicator
              if (_remainingAttempts < _maxAttempts) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _remainingAttempts > 0 ? Icons.warning_amber_rounded : Icons.lock_outline,
                      size: 16,
                      color: _remainingAttempts > 0 ? accentColor : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _remainingAttempts > 0
                          ? (isUrdu
                              ? '$_remainingAttempts کوششیں باقی ہیں'
                              : '$_remainingAttempts attempt${_remainingAttempts == 1 ? '' : 's'} remaining')
                          : (isUrdu
                              ? 'کوششیں ختم ہوگئیں۔ برائے مہربانی نیا کوڈ منگوائیں'
                              : 'Attempts exhausted. Please request a new code.'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _remainingAttempts > 0 ? accentColor : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isVerifying || _remainingAttempts <= 0)
                      ? null
                      : () => _verifyOtp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: primaryColor.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isUrdu ? 'تصدیق مکمل کریں' : 'Verify & Continue',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Magic Link "Open Email App" Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRamadan
                      ? RamadanColors.surfaceDark.withAlpha(200)
                      : const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRamadan
                        ? RamadanColors.primaryCyan.withAlpha(50)
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: isRamadan ? RamadanColors.accentGold : primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isUrdu
                                ? 'ایک کلک میں تصدیق چاہتے ہیں؟'
                                : 'Prefer one-tap verification?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isUrdu
                          ? 'آپ اپنے ای میل میں موجود "Confirm My Account" بٹن پر کلک کر کے بھی ایپ میں لاگ ان ہو سکتے ہیں۔'
                          : 'You can also tap the confirmation link sent in your email to verify instantly.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _openEmailApp,
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: Text(
                          isUrdu ? 'ای میل ایپ کھولیں' : 'Open Email App',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isRamadan ? RamadanColors.textGold : Colors.white,
                          side: BorderSide(
                            color: isRamadan
                                ? RamadanColors.accentGold.withAlpha(100)
                                : Colors.white24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Resend Cooldown Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isUrdu ? 'کوڈ موصول نہیں ہوا؟ ' : "Didn't receive the code? ",
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
                      onPressed: _isResending ? null : _resendCode,
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
