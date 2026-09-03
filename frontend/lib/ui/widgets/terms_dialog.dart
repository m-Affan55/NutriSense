import 'package:flutter/material.dart';
import '../../core/language_controller.dart';

void showTermsAndPrivacyDialog(BuildContext context) {
  final isUrdu = LanguageController.instance.isUrdu;
  final theme = Theme.of(context);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isUrdu ? 'شرائط، پرائیویسی اور پالیسی' : 'Terms & Privacy Policy',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: isUrdu ? 18 : 17,
                  fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Directionality(
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- SECTION 1: DATA PRIVACY ---
                  _buildSectionHeader(
                    icon: Icons.shield_outlined,
                    title: isUrdu ? '۱. پرائیویسی اور ڈیٹا کا تحفظ' : '1. Data Privacy & Protection',
                    isUrdu: isUrdu,
                    theme: theme,
                  ),
                  const SizedBox(height: 6),
                  _buildBulletPoint(
                    isUrdu
                        ? 'آپ کی پرائیویسی اولین ترجیح: آپ کی تمام ذاتی اور طبی معلومات — بشمول بیماریاں، قد، وزن، روزانہ کی خوراک، آواز کی ریکارڈنگ، اور لوکیشن — مکمل طور پر محفوظ اور خفیہ رکھی جاتی ہیں۔'
                        : 'Your Privacy First: Your personal health data — including medical conditions, biometrics (weight, height, age), logged meals, microphone recordings, and location — is encrypted and strictly confidential.',
                    isUrdu: isUrdu,
                  ),
                  _buildBulletPoint(
                    isUrdu
                        ? 'ڈیٹا کی حفاظت: ہم آپ کا ڈیٹا کسی بھی اشتہاری کمپنی یا تیسرے فریق کو فروخت یا شیئر نہیں کرتے۔ یہ معلومات صرف آپ کے ذاتی تجربے اور نیوٹریشن کو مؤثر بنانے کے لیے استعمال ہوتی ہے۔'
                        : 'No Third-Party Sharing: We never sell, rent, or trade your personal or medical data to advertisers or third parties. Your data is used solely to personalize your nutrition experience.',
                    isUrdu: isUrdu,
                  ),
                  const SizedBox(height: 14),

                  // --- SECTION 2: WHAT NUTRISENSE PROVIDES ---
                  _buildSectionHeader(
                    icon: Icons.lightbulb_outline,
                    title: isUrdu ? '۲. نیوٹریسنس کیا فراہم کرتا ہے' : '2. What NutriSense Provides',
                    isUrdu: isUrdu,
                    theme: theme,
                  ),
                  const SizedBox(height: 6),
                  _buildBulletPoint(
                    isUrdu
                        ? 'آپ کا ذاتی نیوٹریشن گائیڈ: نیوٹریسنس آپ کا ڈیجیٹل غذائی معاون ہے جو آپ کو پاکستانی کھانوں کے مطابق صحت مند غذا کے انتخاب، کیلوریز، اور میکروز ٹریک کرنے میں مدد دیتا ہے۔'
                        : 'Your Personal Nutrition Guide: NutriSense is designed to assist and empower you with personalized nutrition, culturally tailored South Asian food recommendations, and meal tracking.',
                    isUrdu: isUrdu,
                  ),
                  _buildBulletPoint(
                    isUrdu
                        ? 'پروفائل کے مطابق رہنمائی: کھانے کے متبادل، مشورے، اور گروسری کی فہرست آپ کی ذاتی صحت، بیماریوں (جیسے شوگر یا بلڈ پریشر)، اور اہداف (وزن میں کمی یا مسل گین) کو مدنظر رکھ کر تیار کی جاتی ہے۔'
                        : 'Profile-Aware Guidance: All dietary suggestions, healthy food alternatives, and grocery plans are dynamically customized to your specific health profile, medical conditions (e.g., Diabetes, Hypertension), and fitness goals (Fat Loss, Muscle Gain).',
                    isUrdu: isUrdu,
                  ),
                  const SizedBox(height: 14),

                  // --- SECTION 3: MEDICAL RESPONSIBILITY & AI CAPABILITIES ---
                  _buildSectionHeader(
                    icon: Icons.health_and_safety_outlined,
                    title: isUrdu ? '۳. طبی ذمہ داری اور اے آئی کی صلاحیت' : '3. Medical Responsibility & AI Capabilities',
                    isUrdu: isUrdu,
                    theme: theme,
                  ),
                  const SizedBox(height: 6),
                  _buildBulletPoint(
                    isUrdu
                        ? 'عام اے آئی کے مقابلے میں زیادہ درست: عام چیٹ باٹس کے برعکس جو بغیر سوچے سمجھے مشورے دیتے ہیں، نیوٹریسنس آپ کے مکمل میڈیکل پروفائل اور کھانوں کے ریکارڈ کو دیکھ کر رہنمائی کرتا ہے، جس سے اس کی تجاویز کہیں زیادہ محفوظ اور درست ہوتی ہیں۔'
                        : 'High-Context Precision over Generic AI: Unlike generic AI chatbots that give blind advice, NutriSense grounds its recommendations in your verified health profile and meal logs, making it substantially more accurate and condition-safe.',
                    isUrdu: isUrdu,
                  ),
                  _buildBulletPoint(
                    isUrdu
                        ? 'غیر متوقع صورتحال کا امکان: اگرچہ ہماری کلینیکل سیفٹی اور پروفائل سسٹم غلطیوں کو کم سے کم رکھتا ہے، مگر شاذ و نادر ایسے معاملات ہو سکتے ہیں جہاں اے آئی کی تجویز کو آپ کی انفرادی کیفیت کے مطابق تبدیلی کی ضرورت ہو۔ الرجی والی اشیاء کا خود جائزہ لیں۔'
                        : 'Edge-Case Notice: While our clinical safety filters and profile-aware algorithms minimize errors, rare edge cases can still occur where an AI suggestion may need adjustment for unique bodily reactions. Always verify personal food allergens.',
                    isUrdu: isUrdu,
                  ),
                  _buildBulletPoint(
                    isUrdu
                        ? 'ڈاکٹر کا متبادل نہیں: نیوٹریسنس ایک ذہین معاون ہے، کوئی ہسپتال یا ڈاکٹر نہیں۔ یہ ایپ باقاعدہ طبی نسخہ، تشخیص یا ایمرجنسی علاج فراہم نہیں کرتی۔ سنگین معاملات میں ہمیشہ مستند معالج کی رائے کو ترجیح دیں۔'
                        : 'Not a Medical Substitute: NutriSense is an intelligent educational and wellness companion, not a licensed medical clinic. It does not replace clinical diagnosis, medical prescriptions, or emergency care from your doctor.',
                    isUrdu: isUrdu,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withAlpha(25),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isUrdu ? 'میں سمجھ گیا / گئی' : 'I Understand',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: isUrdu ? 16 : 14,
                fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildSectionHeader({
  required IconData icon,
  required String title,
  required bool isUrdu,
  required ThemeData theme,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary.withAlpha(220)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isUrdu ? 16 : 14,
            fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
          ),
        ),
      ),
    ],
  );
}

Widget _buildBulletPoint(String text, {required bool isUrdu}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: isUrdu ? 15 : 13,
              height: 1.45,
              fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
            ),
          ),
        ),
      ],
    ),
  );
}
