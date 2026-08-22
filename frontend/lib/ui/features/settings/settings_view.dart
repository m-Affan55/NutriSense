import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/api_client.dart';
import '../../../core/ramadan_controller.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../auth/auth_view.dart';
import '../auth/update_password_screen.dart';
import '../grocery_list/grocery_view.dart';
import '../health_sync/health_sync_view.dart';
import '../family_profiles/family_view.dart';
import '../family_profiles/family_viewmodel.dart';
import '../chat/clinic_finder_screen.dart';
import '../../../core/reminder_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _budgetController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _dietaryRestrictionsController = TextEditingController();

  String? _goal;
  String? _activityLevel;
  bool _isLoading = false;
  bool _isSaving = false;
  String _language = 'en';

  bool _adaptiveReminders = true;
  bool _streakAlerts = true;
  bool _riskAlerts = true;

  final List<String> _goals = ['fat_loss', 'muscle_gain', 'maintenance'];
  final List<String> _activityLevels = ['sedentary', 'lightly_active', 'moderately_active', 'very_active'];
  final List<String> _medicalOptions = ["Diabetes", "Hypertension", "IBS", "Heart Disease", "None"];
  final List<String> _dietaryOptions = ["Halal Only", "Vegetarian", "Lactose-Free", "Gluten-Free", "None"];

  List<String> _selectedMedical = [];
  List<String> _selectedDietary = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No user found');

      // 1. Fetch metadata name
      _nameController.text = user.userMetadata?['full_name'] ?? '';

      // 2. Fetch health profile details
      final healthRes = await supabase
          .from('health_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (healthRes != null) {
        _ageController.text = '${healthRes['age'] ?? ''}';
        _weightController.text = '${healthRes['weight_kg'] ?? ''}';
        _heightController.text = '${healthRes['height_cm'] ?? ''}';
        _budgetController.text = '${healthRes['daily_budget_pkr'] ?? ''}';
        
        final medList = (healthRes['medical_conditions'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final dietList = (healthRes['dietary_restrictions'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _selectedMedical = medList.isEmpty ? [] : medList;
        _selectedDietary = dietList.isEmpty ? [] : dietList;
        
        _medicalConditionsController.text = _selectedMedical.join(', ');
        _dietaryRestrictionsController.text = _selectedDietary.join(', ');
        
        setState(() {
          _goal = healthRes['goal'];
          _activityLevel = healthRes['activity_level'];
          _adaptiveReminders = prefs.getBool(ReminderManager.keyAdaptiveReminders) ?? true;
          _streakAlerts = prefs.getBool(ReminderManager.keyStreakAlerts) ?? true;
          _riskAlerts = prefs.getBool(ReminderManager.keyRiskAlerts) ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to load settings: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _language);
      await prefs.setString('app_language', _language);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session invalid');

      // 1. Update user auth metadata name
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );

      // 2. Update health profile targets in database
      final payload = {
        'age': int.parse(_ageController.text),
        'weight_kg': double.parse(_weightController.text),
        'height_cm': double.parse(_heightController.text),
        'daily_budget_pkr': int.parse(_budgetController.text),
        'goal': _goal,
        'activity_level': _activityLevel,
        'medical_conditions': _selectedMedical,
        'dietary_restrictions': _selectedDietary,
      };

      await supabase
          .from('health_profiles')
          .update(payload)
          .eq('user_id', user.id);

      if (mounted) {
        CustomToast.show(context, _t('saved'), isError: false);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Save failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Logout failed: ${e.toString()}');
      }
    }
  }

  Future<void> _exportPdfReceipt() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No session found');

      final profile = await supabase.from('health_profiles').select().eq('user_id', user.id).maybeSingle();
      
      final mealsResponse = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at', ascending: false)
          .limit(20);
      final List<dynamic> meals = mealsResponse as List<dynamic>;

      final waterResponse = await supabase
          .from('water_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at', ascending: false)
          .limit(20);
      final List<dynamic> water = waterResponse as List<dynamic>;

      // 2. Build PDF Document
      final pdfDoc = pw.Document();
      
      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            pw.Widget pdfMetric(String label, String value) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                  pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              );
            }

            return [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0D0F14),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NUTRISENSE', style: pw.TextStyle(fontSize: 22, color: PdfColor.fromInt(0xFF00E676), fontWeight: pw.FontWeight.bold)),
                    pw.Text('HEALTH STATEMENT', style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated At: ${DateTime.now().toLocal().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('User Email: ${user.email}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Health targets card
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF161A22),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HEALTH TARGETS & PROFILE', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF00E676), fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 12),
                    if (profile != null) ...[
                      pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              pw.Expanded(child: pdfMetric('Age', '${profile['age']} years')),
                              pw.Expanded(child: pdfMetric('Weight', '${profile['weight_kg']} kg')),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Expanded(child: pdfMetric('Height', '${profile['height_cm']} cm')),
                              pw.Expanded(child: pdfMetric('Goal', profile['goal'].toString().replaceAll('_', ' ').toUpperCase())),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Expanded(child: pdfMetric('Calorie Target', '${profile['daily_calorie_target']} kcal')),
                              pw.Expanded(child: pdfMetric('Daily Food Budget', '${profile['daily_budget_pkr']} PKR')),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(color: PdfColors.grey700),
                      pw.SizedBox(height: 6),
                      pw.Text('Medical Conditions: ${profile['medical_conditions'] != null ? (profile['medical_conditions'] as List).join(", ") : "None"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      pw.Text('Dietary Restrictions: ${profile['dietary_restrictions'] != null ? (profile['dietary_restrictions'] as List).join(", ") : "None"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Meal log section
              pw.Text('MEAL LOG DETAILS', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF00E676))),
              pw.SizedBox(height: 8),
              if (meals.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text('No meals logged recently.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Meal Description', 'Meal Type', 'Calories (kcal)', 'Logged Date'],
                  data: meals.map((m) => [
                    m['notes'] ?? 'Meal',
                    m['meal_type'] ?? 'unknown',
                    '${m['total_calories'] ?? 0}',
                    m['logged_at'].toString().substring(0, 10),
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D0F14)),
                  cellAlignment: pw.Alignment.centerLeft,
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                ),
              pw.SizedBox(height: 24),
              
              // Hydration log section
              pw.Text('HYDRATION LOG DETAILS', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF00E676))),
              pw.SizedBox(height: 8),
              if (water.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text('No hydration logged recently.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Hydration Amount', 'Logged Date'],
                  data: water.map((w) => [
                    '${w['amount_ml']} ml',
                    w['logged_at'].toString().substring(0, 10),
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D0F14)),
                  cellAlignment: pw.Alignment.centerLeft,
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                ),
            ];
          },
        ),
      );

      // 3. Save to safe documents directory across platforms
      Directory saveDir;
      if (kIsWeb) {
        throw Exception('Web download not supported directly yet.');
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final file = File('${saveDir.path}/nutrisense_health_receipt.pdf');
      await file.writeAsBytes(await pdfDoc.save());

      if (mounted) {
        CustomToast.show(
          context,
          'Opening PDF Receipt...',
          isError: false,
        );
      }
      
      // Auto-open the file
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'PDF generation failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delConfirmTitle')),
        content: Text(_t('delConfirmBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('delCancelBtn'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delConfirmBtn')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session not valid');

      final url = Uri.parse('${ApiClient.getBaseUrl()}/profile/delete-account');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.id}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error during account removal.');
      }

      await supabase.auth.signOut();

      if (mounted) {
        CustomToast.show(context, _t('delSuccess'), isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Deletion failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showSelectionDialog(String title, List<String> options, List<String> selectedOptions, bool isMultiSelect, Function(List<String>) onChange) async {
    List<String> tempSelected = List.from(selectedOptions);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161A22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((opt) {
                    final isSelected = tempSelected.contains(opt);
                    return ListTile(
                      title: Text(
                        opt, 
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        )
                      ),
                      onTap: () {
                        setState(() {
                          if (isMultiSelect) {
                            if (isSelected) {
                              tempSelected.remove(opt);
                            } else {
                              if (opt == 'None') {
                                tempSelected = ['None'];
                              } else {
                                tempSelected.remove('None');
                                tempSelected.add(opt);
                              }
                            }
                            onChange(tempSelected);
                          } else {
                            tempSelected = [opt];
                            onChange(tempSelected);
                            Navigator.pop(ctx);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'Profile Settings',
        'userInfo': 'User Info',
        'fullName': 'Full Name',
        'bodyParams': 'Body Parameters',
        'age': 'Age',
        'weight': 'Weight (kg)',
        'height': 'Height (cm)',
        'budget': 'Daily Budget (PKR)',
        'goalsActivity': 'Goals & Activity',
        'goal': 'Health Goal',
        'activity': 'Activity Index',
        'medicalConditions': 'Medical Conditions',
        'dietaryRestrictions': 'Dietary Restrictions',
        'save': 'Save Targets',
        'privacy': 'Privacy & Account',
        'export': 'Export Health Data (PDF)',
        'exportSub': 'Save your health profile & log as PDF.',
        'delete': 'Delete Account',
        'deleteSub': 'Permanently remove your health profile.',
        'logout': 'Sign Out',
        'language': 'Language',
        'required': 'Required',
        'saved': 'Settings saved successfully!',
        'delConfirmTitle': 'Delete Account?',
        'delConfirmBody': 'WARNING: This will permanently delete your account and delete all logged meal visualizer information. This action is irreversible.',
        'delConfirmBtn': 'Delete Permanently',
        'delCancelBtn': 'Cancel',
        'delSuccess': 'Your account has been deleted.',
        'changePassword': 'Change Password',
        'changePasswordSub': 'Update your login password.',
        'groceryTitle': 'Smart Grocery List',
        'grocerySub': 'Get AI shopping list based on your recent meals.',
        'ramadanTitle': 'Ramadan Mode',
        'ramadanSub': 'Celestial midnight blue theme & Islamic fasting mode.',
        'ramadanSection': 'Ramadan Fasting & Timings',
        'suhoorTime': 'Sehri / Suhoor Time',
        'iftarTime': 'Iftar Time',
        'ramadanReminders': 'Sehri & Iftar Alerts',
        'ramadanRemindersSub': 'Receive alerts 30m before Sehri and at Iftar.',
        'smartNotifTitle': 'Smart Notifications & Alerts',
        'smartNotifSub': 'Personalized reminders, streaks and safety alerts.',
        'adaptiveReminders': 'Adaptive Meal Reminders',
        'adaptiveRemindersSub': 'Auto-adjusts reminder timing based on your actual eating routine.',
        'streakAlerts': 'Streak Milestones & Streak Saver',
        'streakAlertsSub': 'Celebratory streak milestone alerts & evening reminders.',
        'riskAlerts': 'AI Clinical Safety Alerts',
        'riskAlertsSub': 'Urgent heads-up for allergen conflicts or health safety risks.',
      },
      'ur': {
        'title': 'پروفائل کی ترتیبات',
        'userInfo': 'صارف کی معلومات',
        'fullName': 'پورا نام',
        'bodyParams': 'جسمانی پیمائش',
        'age': 'عمر',
        'weight': 'وزن (کلوگرام)',
        'height': 'قد (سینٹی میٹر)',
        'budget': 'روزانہ کا بجٹ (روپے)',
        'goalsActivity': 'اهداف اور سرگرمی',
        'goal': 'صحت کا ہدف',
        'activity': 'سرگرمی کا انڈیکس',
        'medicalConditions': 'طبی مسائل',
        'dietaryRestrictions': 'غذائی پابندیاں',
        'save': 'ترتیبات محفوظ کریں',
        'privacy': 'پرائیویسی اور اکاؤنٹ',
        'export': 'ڈیٹا ایکسپورٹ کریں (PDF)',
        'exportSub': 'ہیلتھ ریکارڈ کو پی ڈی ایف کے طور پر محفوظ کریں۔',
        'delete': 'اکاؤنٹ حذف کریں',
        'deleteSub': 'اپنا ہیلتھ پروفائل مستقل طور پر حذف کریں۔',
        'logout': 'سائن آؤٹ',
        'language': 'زبان',
        'required': 'لازمی',
        'saved': 'ترتیبات کامیابی کے ساتھ محفوظ ہو گئیں!',
        'delConfirmTitle': 'اکاؤنٹ حذف کریں؟',
        'delConfirmBody': 'انتباہ: یہ مستقل طور پر آپ کا اکاؤنٹ اور لاگ ان معلومات کو حذف کر دے گا۔ یہ عمل ناقابل واپسی ہے۔',
        'delConfirmBtn': 'مستقل طور پر حذف کریں',
        'delCancelBtn': 'منسوخ کریں',
        'delSuccess': 'آپ کا اکاؤنٹ حذف کر دیا گیا ہے۔',
        'changePassword': 'پاس ورڈ تبدیل کریں',
        'changePasswordSub': 'اپنا لاگ ان پاس ورڈ تبدیل کریں۔',
        'groceryTitle': 'اسمارٹ گروسری لسٹ',
        'grocerySub': 'حالیہ کھانوں کی بنیاد پر خریداری کی فہرست بنائیں۔',
        'ramadanTitle': 'رمضان موڈ',
        'ramadanSub': 'نیلا آسمانی تھیم اور سحر و افطار کے اوزار فعال کریں۔',
        'ramadanSection': 'رمضان المبارک اور اوقات',
        'suhoorTime': 'سحری ختم ہونے کا وقت',
        'iftarTime': 'افطار کا وقت',
        'ramadanReminders': 'سحر و افطار کے الرٹس',
        'ramadanRemindersSub': 'سحری سے 30 منٹ پہلے اور افطار کے وقت الرٹ حاصل کریں۔',
        'smartNotifTitle': 'سمارٹ نوٹیفیکیشنز اور الرٹس',
        'smartNotifSub': 'ذاتی یاد دہانیاں، اسٹریک اور حفاظتی انتباہات۔',
        'adaptiveReminders': 'عادات کے مطابق کھانے کی یاددہانی',
        'adaptiveRemindersSub': 'آپ کے معمول کے مطابق خودکار وقت ایڈجسٹ کرتا ہے۔',
        'streakAlerts': 'اسٹریک کی خوشخبری اور یاد دہانی',
        'streakAlertsSub': 'اسٹریک سنگ میل اور رات کو اسٹریک بچانے کے الرٹس۔',
        'riskAlerts': 'اے آئی طبی و حفاظتی الرٹس',
        'riskAlertsSub': 'الرجی یا شوگر کے خطرے سے متعلق فوری انتباہات۔',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRamadan = RamadanController.instance.isRamadanMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RamadanBackgroundWrapper(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('userInfo'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: _t('fullName'), border: const OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: InputDecoration(labelText: _t('language'), border: const OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ur', child: Text('Urdu (اردو)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _language = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(_t('bodyParams'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: _t('age'), border: const OutlineInputBorder()),
                            validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: _t('weight'), border: const OutlineInputBorder()),
                            validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: _t('height'), border: const OutlineInputBorder()),
                            validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: _t('budget'), border: const OutlineInputBorder()),
                            validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(_t('goalsActivity'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showSelectionDialog(
                        _t('goal'),
                        _goals.map((g) => g.replaceAll('_', ' ').toUpperCase()).toList(),
                        [_goal?.replaceAll('_', ' ').toUpperCase() ?? ''],
                        false,
                        (selected) {
                          if (selected.isNotEmpty) {
                            setState(() {
                              _goal = _goals.firstWhere((g) => g.replaceAll('_', ' ').toUpperCase() == selected.first);
                            });
                          }
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          key: ValueKey(_goal),
                          initialValue: _goal?.replaceAll('_', ' ').toUpperCase(),
                          decoration: InputDecoration(
                            labelText: _t('goal'),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showSelectionDialog(
                        _t('activity'),
                        _activityLevels.map((a) => a.replaceAll('_', ' ').toUpperCase()).toList(),
                        [_activityLevel?.replaceAll('_', ' ').toUpperCase() ?? ''],
                        false,
                        (selected) {
                          if (selected.isNotEmpty) {
                            setState(() {
                              _activityLevel = _activityLevels.firstWhere((a) => a.replaceAll('_', ' ').toUpperCase() == selected.first);
                            });
                          }
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          key: ValueKey(_activityLevel),
                          initialValue: _activityLevel?.replaceAll('_', ' ').toUpperCase(),
                          decoration: InputDecoration(
                            labelText: _t('activity'),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => _showSelectionDialog(
                        _t('medicalConditions'),
                        _medicalOptions,
                        _selectedMedical,
                        true,
                        (selected) {
                          setState(() {
                            _selectedMedical = selected;
                            _medicalConditionsController.text = selected.join(', ');
                          });
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _medicalConditionsController,
                          decoration: InputDecoration(
                            labelText: _t('medicalConditions'),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showSelectionDialog(
                        _t('dietaryRestrictions'),
                        _dietaryOptions,
                        _selectedDietary,
                        true,
                        (selected) {
                          setState(() {
                            _selectedDietary = selected;
                            _dietaryRestrictionsController.text = selected.join(', ');
                          });
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _dietaryRestrictionsController,
                          decoration: InputDecoration(
                            labelText: _t('dietaryRestrictions'),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isSaving ? null : _saveSettings,
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    if (_selectedDietary.any((d) => d.toLowerCase().contains('halal'))) ...[
                      // Ramadan Mode Section
                      Text(_t('ramadanSection'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isRamadan
                            ? const Color(0xFF132448).withAlpha(150)
                            : const Color(0xFF161A22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRamadan
                              ? const Color(0xFF00D2FF).withAlpha(80)
                              : Colors.white.withAlpha(15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Text('🌙', style: TextStyle(fontSize: 24)),
                            title: Text(
                              _t('ramadanTitle'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRamadan ? const Color(0xFFFFD166) : Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              _t('ramadanSub'),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            value: isRamadan,
                            activeThumbColor: const Color(0xFF00D2FF),
                            activeTrackColor: const Color(0xFF00D2FF).withAlpha(60),
                            onChanged: (val) async {
                              await RamadanController.instance.setRamadanMode(val);
                              await ReminderManager.syncRemindersWithMode();
                              setState(() {});
                            },
                          ),
                          if (isRamadan) ...[
                            const Divider(color: Colors.white12, height: 1),
                            // Sehri / Suhoor Time Picker
                            ListTile(
                              leading: const Icon(Icons.wb_twilight, color: Color(0xFF00D2FF)),
                              title: Text(
                                _t('suhoorTime'),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D2FF).withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF00D2FF).withAlpha(90)),
                                ),
                                child: Text(
                                  RamadanController.instance.formatTime(RamadanController.instance.suhoorTime),
                                  style: const TextStyle(
                                    color: Color(0xFF00D2FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                final current = RamadanController.instance.suhoorTime;
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: current,
                                );
                                if (picked != null) {
                                  await RamadanController.instance.setSuhoorTime(picked);
                                  await ReminderManager.syncRemindersWithMode();
                                  setState(() {});
                                }
                              },
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            // Iftar Time Picker
                            ListTile(
                              leading: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD166)),
                              title: Text(
                                _t('iftarTime'),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD166).withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFD166).withAlpha(90)),
                                ),
                                child: Text(
                                  RamadanController.instance.formatTime(RamadanController.instance.iftarTime),
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                final current = RamadanController.instance.iftarTime;
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: current,
                                );
                                if (picked != null) {
                                  await RamadanController.instance.setIftarTime(picked);
                                  await ReminderManager.syncRemindersWithMode();
                                  setState(() {});
                                }
                              },
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            // Ramadan Alarms Toggle
                            SwitchListTile(
                              secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF00E676)),
                              title: Text(
                                _t('ramadanReminders'),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              subtitle: Text(
                                _t('ramadanRemindersSub'),
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                              value: RamadanController.instance.remindersEnabled,
                              activeThumbColor: const Color(0xFF00E676),
                              activeTrackColor: const Color(0xFF00E676).withAlpha(60),
                              onChanged: (val) async {
                                await RamadanController.instance.setRemindersEnabled(val);
                                await ReminderManager.syncRemindersWithMode();
                                setState(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ],

                    // Smart Notifications Section
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRamadan
                              ? const Color(0xFFFFD166).withAlpha(40)
                              : const Color(0xFF00E676).withAlpha(40),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active_rounded,
                                    color: isRamadan ? const Color(0xFFFFD166) : const Color(0xFF00E676)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('smartNotifTitle'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _t('smartNotifSub'),
                                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.psychology_alt_outlined, color: Color(0xFF00D2FF)),
                            title: Text(
                              _t('adaptiveReminders'),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            subtitle: Text(
                              _t('adaptiveRemindersSub'),
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            value: _adaptiveReminders,
                            activeThumbColor: const Color(0xFF00D2FF),
                            activeTrackColor: const Color(0xFF00D2FF).withAlpha(60),
                            onChanged: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(ReminderManager.keyAdaptiveReminders, val);
                              await ReminderManager.syncRemindersWithMode();
                              setState(() => _adaptiveReminders = val);
                            },
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.local_fire_department, color: Color(0xFFFF9500)),
                            title: Text(
                              _t('streakAlerts'),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            subtitle: Text(
                              _t('streakAlertsSub'),
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            value: _streakAlerts,
                            activeThumbColor: const Color(0xFFFF9500),
                            activeTrackColor: const Color(0xFFFF9500).withAlpha(60),
                            onChanged: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(ReminderManager.keyStreakAlerts, val);
                              await ReminderManager.syncRemindersWithMode();
                              setState(() => _streakAlerts = val);
                            },
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.shield_outlined, color: Color(0xFFFF3B30)),
                            title: Text(
                              _t('riskAlerts'),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            subtitle: Text(
                              _t('riskAlertsSub'),
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            value: _riskAlerts,
                            activeThumbColor: const Color(0xFFFF3B30),
                            activeTrackColor: const Color(0xFFFF3B30).withAlpha(60),
                            onChanged: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(ReminderManager.keyRiskAlerts, val);
                              setState(() => _riskAlerts = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Health Sync Section
                    ListTile(
                      leading: Icon(Icons.monitor_heart_outlined,
                          color: isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676)),
                      title: Text(
                        _language == 'ur' ? 'ہیلتھ سنک' : 'Health Sync',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _language == 'ur'
                            ? 'سرگرمی، نیند اور دل کی دھڑکن ٹریک کریں'
                            : 'Track activity, sleep & heart rate',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HealthSyncView()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Family Profiles Section
                    ListTile(
                      leading: const Icon(Icons.people_alt_outlined, color: Color(0xFFFFD166)),
                      title: Text(
                        _language == 'ur' ? 'خاندانی پروفائلز' : 'Family Profiles',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _language == 'ur'
                            ? 'بچوں اور بزرگوں کی غذائیت کا انتظام کریں'
                            : 'Manage nutrition for children & elderly parents',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (FamilyViewModel.instance.members.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD166).withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${FamilyViewModel.instance.members.length}',
                                style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FamilyView()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Nearby Clinics & Hospitals Section
                    ListTile(
                      leading: const Icon(Icons.local_hospital_outlined, color: Colors.redAccent),
                      title: Text(
                        _language == 'ur' ? 'قریبی کلینکس اور ہسپتال' : 'Nearby Clinics & Hospitals',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _language == 'ur'
                            ? 'سرکاری و نجی طبی مراکز اور ہنگامی نگہداشت'
                            : 'Find subsidized & emergency medical care near you',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ClinicFinderScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(_t('privacy'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                     ListTile(
                      leading: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                      title: Text(_t('changePassword')),
                      subtitle: Text(_t('changePasswordSub')),
                      onTap: _isSaving ? null : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.shopping_basket_outlined, color: Colors.greenAccent),
                      title: Text(_t('groceryTitle')),
                      subtitle: Text(_t('grocerySub')),
                      onTap: _isSaving ? null : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GroceryView()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      title: Text(_t('export')),
                      subtitle: Text(_t('exportSub')),
                      onTap: _isSaving ? null : _exportPdfReceipt,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Color(0xFFFFD700)),
                      title: Text(_t('delete'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(_t('deleteSub')),
                      onTap: _isSaving ? null : _deleteAccount,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.logout),
                        label: Text(_t('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _logout,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
