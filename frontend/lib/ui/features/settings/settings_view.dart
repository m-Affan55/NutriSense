import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../health_sync/health_sync_viewmodel.dart';
import '../family_profiles/family_view.dart';
import '../family_profiles/family_viewmodel.dart';
import '../chat/clinic_finder_screen.dart';
import '../../../core/reminder_manager.dart';
import '../../../core/language_controller.dart';
import '../../../core/swap_service.dart';
import '../../../core/workout_service.dart';
import '../../../core/profile_sync_notifier.dart';
import '../../widgets/terms_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _gender = 'male';
  bool _isLoading = false;
  bool _isSaving = false;
  String _language = 'en';
  bool _isUpdatingLocalization = false;

  // Dirty-state tracking
  bool _hasUnsavedChanges = false;
  // ignore: unused_field
  Map<String, dynamic> _originalValues = {};

  bool _adaptiveReminders = true;
  bool _streakAlerts = true;
  bool _riskAlerts = true;

  final List<String> _goals = ['fat_loss', 'muscle_gain', 'maintenance'];
  final List<String> _activityLevels = ['sedentary', 'lightly_active', 'moderately_active', 'very_active'];
  final List<String> _medicalOptions = [
    'Diabetes / High blood sugar',
    'High blood pressure',
    'Heart-related issues',
    'IBS or digestive problems',
    'Food allergies',
    'None',
  ];
  final List<String> _dietaryOptions = [
    'Halal only',
    'Vegetarian',
    'Vegan',
    'Lactose-Free',
    'Gluten-Free',
    'No restriction',
    'Other',
  ];

  List<String> _selectedMedical = [];
  List<String> _selectedDietary = [];

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_onLanguageChanged);
    _language = LanguageController.instance.currentLanguage;
    _loadProfileData();
    // Wire dirty-state listeners on all text controllers
    _nameController.addListener(_markDirty);
    _ageController.addListener(_markDirty);
    _weightController.addListener(_markDirty);
    _heightController.addListener(_markDirty);
    _budgetController.addListener(_markDirty);
    _medicalConditionsController.addListener(_markDirty);
    _dietaryRestrictionsController.addListener(_markDirty);
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _budgetController.dispose();
    _medicalConditionsController.dispose();
    _dietaryRestrictionsController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
        _updateMedicalAndDietaryText();
      });
    }
  }

  /// Called whenever any editable field changes. Compares against the
  /// original snapshot to avoid marking dirty on programmatic fills.
  void _markDirty() {
    if (_isLoading || _isUpdatingLocalization) return; // ignore changes during initial load or localization updates
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// Snapshot current values as the baseline so we can detect future edits.
  void _snapshotOriginalValues() {
    _originalValues = {
      'name': _nameController.text,
      'age': _ageController.text,
      'weight': _weightController.text,
      'height': _heightController.text,
      'budget': _budgetController.text,
      'goal': _goal,
      'activityLevel': _activityLevel,
      'selectedMedical': List.from(_selectedMedical),
      'selectedDietary': List.from(_selectedDietary),
    };
    if (mounted) setState(() => _hasUnsavedChanges = false);
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _language = LanguageController.instance.currentLanguage;
      final prefs = await SharedPreferences.getInstance();

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
        _gender = healthRes['gender']?.toString() ?? 'male';
        _ageController.text = '${healthRes['age'] ?? ''}';
        _weightController.text = '${healthRes['weight_kg'] ?? ''}';
        _heightController.text = '${healthRes['height_cm'] ?? ''}';
        _budgetController.text = '${healthRes['daily_budget_pkr'] ?? ''}';
        
        final medList = (healthRes['medical_conditions'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final dietList = (healthRes['dietary_restrictions'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _selectedMedical = medList.isEmpty ? [] : medList;
        _selectedDietary = dietList.isEmpty ? [] : dietList;
        
        _updateMedicalAndDietaryText();
        
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
        // Snapshot after load so initial fill doesn't trigger dirty state
        WidgetsBinding.instance.addPostFrameCallback((_) => _snapshotOriginalValues());
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
      await LanguageController.instance.setLanguage(_language);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session invalid');

      // 1. Update user auth metadata name
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );

      // 2. Update health profile targets via backend (recalculates Mifflin-St Jeor TDEE & macros, updates user_cache)
      final payload = {
        'user_id': user.id,
        'age': int.parse(_ageController.text),
        'gender': _gender,
        'weight_kg': double.parse(_weightController.text),
        'height_cm': double.parse(_heightController.text),
        'daily_budget_pkr': int.parse(_budgetController.text),
        'goal': _goal,
        'activity_level': _activityLevel,
        'medical_conditions': _selectedMedical,
        'dietary_restrictions': _selectedDietary,
      };

      bool backendSucceeded = false;
      try {
        final updateUrl = Uri.parse('${ApiClient.getBaseUrl()}/profile/update');
        final response = await http.post(
          updateUrl,
          headers: ApiClient.getHeaders(),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          backendSucceeded = true;
        }
      } catch (backendErr) {
        debugPrint('Backend profile update error (fallback to Supabase direct): $backendErr');
      }

      // 3. Fallback: if backend call was unreachable (offline resilience), save directly to Supabase
      if (!backendSucceeded) {
        final dbPayload = Map<String, dynamic>.from(payload);
        dbPayload.remove('user_id');
        await supabase
            .from('health_profiles')
            .update(dbPayload)
            .eq('user_id', user.id);
      }

      // 4. Invalidate local client-side caches so Workout, Swaps, and Health Metrics regenerate under new conditions
      await WorkoutService.instance.clearPlanCache(userId: user.id);
      await SwapService.invalidateSwapsCache(userId: user.id);
      await HealthSyncViewModel.clearInsightCache(user.id);

      // 5. Broadcast profile update to reactive listeners (Dashboard calorie rings, Coach, Workout, Health Metrics)
      ProfileSyncNotifier.instance.notifyProfileChanged();

      if (mounted) {
        CustomToast.show(context, _t('saved'), isError: false);
        // Reset dirty flag after successful save
        _snapshotOriginalValues();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          _language == 'ur'
              ? 'معلومات محفوظ کرنے میں ناکامی۔ براہ کرم دوبارہ کوشش کریں'
              : 'Failed to save settings. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      SwapService.clearSession();
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
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('delConfirmTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(_t('delConfirmBody'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('delCancelBtn'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delConfirmBtn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        headers: ApiClient.getHeaders(),
        body: jsonEncode({'user_id': user.id}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error during account removal.');
      }

      SwapService.clearSession();
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

  void _updateMedicalAndDietaryText() {
    _isUpdatingLocalization = true;
    try {
      final separator = _language == 'ur' ? '، ' : ', ';
      if (_selectedMedical.isEmpty) {
        _medicalConditionsController.text = _language == 'ur' ? 'کوئی نہیں' : 'None';
      } else {
        _medicalConditionsController.text =
            _selectedMedical.map(_getConditionLabel).join(separator);
      }

      if (_selectedDietary.isEmpty) {
        _dietaryRestrictionsController.text =
            _language == 'ur' ? 'کوئی پابندی نہیں' : 'No restriction';
      } else {
        _dietaryRestrictionsController.text =
            _selectedDietary.map(_getDietaryLabel).join(separator);
      }
    } finally {
      _isUpdatingLocalization = false;
    }
  }

  String _normalizeCondition(String c) {
    final lower = c.toLowerCase();
    if (lower.contains('diabet') || lower.contains('sugar')) return 'diabetes';
    if (lower.contains('pressure') || lower.contains('hypertens')) return 'hypertension';
    if (lower.contains('heart')) return 'heart';
    if (lower.contains('ibs') || lower.contains('digest')) return 'ibs';
    if (lower.contains('allerg')) return 'allergies';
    if (lower.contains('none') || lower.contains('کوئی')) return 'none';
    return lower;
  }

  String _normalizeDietary(String d) {
    final lower = d.toLowerCase();
    if (lower.contains('halal')) return 'halal';
    if (lower.contains('vegetarian')) return 'vegetarian';
    if (lower.contains('vegan')) return 'vegan';
    if (lower.contains('lactose')) return 'lactose';
    if (lower.contains('gluten')) return 'gluten';
    if (lower.contains('no restriction') || lower == 'none' || lower.contains('کوئی')) return 'none';
    if (lower.contains('other')) return 'other';
    return lower;
  }

  String _getGoalLabel(String? g) {
    if (g == null || g.isEmpty) return '';
    final lower = g.toLowerCase();
    if (_language == 'ur') {
      if (lower.contains('fat') || lower.contains('loss') || lower.contains('lose')) {
        return 'وزن میں کمی / چربی گھٹائیں';
      }
      if (lower.contains('muscle') || lower.contains('gain') || lower.contains('bulk')) {
        return 'مسلز بنائیں / طاقت بڑھائیں';
      }
      if (lower.contains('maintain')) {
        return 'وزن اور صحت برقرار رکھیں';
      }
      if (lower.contains('diabet') || lower.contains('sugar')) {
        return 'ذیابیطس / شوگر کنٹرول';
      }
      if (lower.contains('wellness') || lower.contains('better')) {
        return 'عام صحت / بہتر خوراک';
      }
      return 'وزن اور صحت برقرار رکھیں';
    } else {
      if (lower.contains('fat') || lower.contains('loss') || lower.contains('lose')) {
        return 'Fat Loss';
      }
      if (lower.contains('muscle') || lower.contains('gain') || lower.contains('bulk')) {
        return 'Muscle Gain';
      }
      if (lower.contains('maintain')) {
        return 'Maintenance';
      }
      if (lower.contains('diabet') || lower.contains('sugar')) {
        return 'Manage Diabetes';
      }
      if (lower.contains('wellness') || lower.contains('better')) {
        return 'General Wellness';
      }
      return g.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getActivityLabel(String? a) {
    if (a == null || a.isEmpty) return '';
    final lower = a.toLowerCase();
    if (_language == 'ur') {
      if (lower.contains('sedentary')) {
        return 'سست / زیادہ تر بیٹھے رہنے والا';
      }
      if (lower.contains('lightly') || lower.contains('light')) {
        return 'ہلکی سرگرمی';
      }
      if (lower.contains('moderately') || lower.contains('moderate')) {
        return 'معتدل سرگرمی';
      }
      if (lower.contains('very') || lower.contains('active')) {
        return 'بہت زیادہ فعال';
      }
      return a;
    } else {
      if (lower.contains('sedentary')) {
        return 'Sedentary';
      }
      if (lower.contains('lightly') || lower.contains('light')) {
        return 'Lightly Active';
      }
      if (lower.contains('moderately') || lower.contains('moderate')) {
        return 'Moderately Active';
      }
      if (lower.contains('very') || lower.contains('active')) {
        return 'Very Active';
      }
      return a.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getConditionLabel(String c) {
    final lower = c.toLowerCase();
    if (_language == 'ur') {
      if (lower.contains('diabet') || lower.contains('sugar')) {
        return 'ذیابیطس / ہائی بلڈ شوگر';
      }
      if (lower.contains('pressure') || lower.contains('hypertens')) {
        return 'ہائی بلڈ پریشر';
      }
      if (lower.contains('heart')) {
        return 'دل کے امراض';
      }
      if (lower.contains('ibs') || lower.contains('digest')) {
        return 'معدے / ہاضمے کے مسائل (IBS)';
      }
      if (lower.contains('allerg')) {
        return 'کھانے کی اشیاء سے الرجی';
      }
      if (lower == 'none' || lower.contains('کوئی')) {
        return 'کوئی نہیں';
      }
      return c;
    } else {
      if (lower.contains('diabet') || lower.contains('sugar')) {
        return 'Diabetes / High blood sugar';
      }
      if (lower.contains('pressure') || lower.contains('hypertens')) {
        return 'High blood pressure';
      }
      if (lower.contains('heart')) {
        return 'Heart-related issues';
      }
      if (lower.contains('ibs') || lower.contains('digest')) {
        return 'IBS or digestive problems';
      }
      if (lower.contains('allerg')) {
        return 'Food allergies';
      }
      if (lower == 'none') {
        return 'None';
      }
      return c;
    }
  }

  String _getDietaryLabel(String d) {
    final lower = d.toLowerCase();
    if (_language == 'ur') {
      if (lower.contains('halal')) return 'صرف حلال';
      if (lower.contains('vegetarian')) return 'سبزی خور';
      if (lower.contains('vegan')) return 'ویگن';
      if (lower.contains('lactose')) return 'لیکٹوز فری';
      if (lower.contains('gluten')) return 'گلوٹن فری';
      if (lower.contains('no restriction') || lower == 'none' || lower.contains('کوئی')) {
        return 'کوئی پابندی نہیں';
      }
      if (lower.contains('other')) return 'دیگر';
      return d;
    } else {
      if (lower.contains('halal')) return 'Halal only';
      if (lower.contains('vegetarian')) return 'Vegetarian';
      if (lower.contains('vegan')) return 'Vegan';
      if (lower.contains('lactose')) return 'Lactose-Free';
      if (lower.contains('gluten')) return 'Gluten-Free';
      if (lower.contains('no restriction') || lower == 'none') return 'No restriction';
      if (lower.contains('other')) return 'Other';
      return d;
    }
  }

  Future<void> _showSelectionDialog({
    required String title,
    required List<String> options,
    required List<String> selectedOptions,
    required bool isMultiSelect,
    required String Function(String) labelBuilder,
    bool Function(String opt, List<String> selected)? isSelectedChecker,
    required Function(List<String>) onChange,
  }) async {
    List<String> tempSelected = List.from(selectedOptions);
    final isUrdu = _language == 'ur';
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161A22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                title,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              content: Directionality(
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((opt) {
                      final isSelected = isSelectedChecker != null
                          ? isSelectedChecker(opt, tempSelected)
                          : tempSelected.contains(opt);
                      return ListTile(
                        title: Text(
                          labelBuilder(opt),
                          style: TextStyle(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: isUrdu ? 16 : 15,
                            fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
                          ),
                        ),
                        trailing: isMultiSelect
                            ? Icon(
                                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white38,
                              )
                            : (isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null),
                        onTap: () {
                          setDlgState(() {
                            if (isMultiSelect) {
                              final isNone = opt.toLowerCase() == 'none' ||
                                  opt.toLowerCase() == 'no restriction' ||
                                  opt.contains('کوئی');
                              if (isSelected) {
                                if (isSelectedChecker != null) {
                                  tempSelected.removeWhere((s) => isSelectedChecker(opt, [s]));
                                } else {
                                  tempSelected.remove(opt);
                                }
                              } else {
                                if (isNone) {
                                  tempSelected = [opt];
                                } else {
                                  if (isSelectedChecker != null) {
                                    tempSelected.removeWhere((s) =>
                                        s.toLowerCase() == 'none' ||
                                        s.toLowerCase() == 'no restriction' ||
                                        s.contains('کوئی'));
                                  } else {
                                    tempSelected.remove('None');
                                    tempSelected.remove('No restriction');
                                  }
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
              ),
              actions: isMultiSelect
                  ? [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          isUrdu ? 'مکمل' : 'Done',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
                          ),
                        ),
                      ),
                    ]
                  : null,
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
        'termsAndPrivacy': 'Terms & Privacy Policy',
        'termsAndPrivacySub': 'Read our data privacy, terms, and clinical disclaimers.',
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
        'termsAndPrivacy': 'شرائط، پرائیویسی اور پالیسی',
        'termsAndPrivacySub': 'ڈیٹا کا تحفظ، سروس کی شرائط، اور طبی انتباہ پڑھیں۔',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRamadan = RamadanController.instance.isRamadanMode;
    final accentColor = isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E232E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              _language == 'ur' ? 'غیر محفوظ تبدیلیاں' : 'Unsaved Changes',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              _language == 'ur'
                  ? 'آپ کی تبدیلیاں محفوظ نہیں ہوئیں۔ کیا آپ واقعی واپس جانا چاہتے ہیں؟'
                  : 'You have unsaved changes. Are you sure you want to leave without saving?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  _language == 'ur' ? 'رکیں' : 'Stay',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  _language == 'ur' ? 'چھوڑ دیں' : 'Discard',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RamadanBackgroundWrapper(
        child: Stack(
          children: [
            _isLoading
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
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(labelText: _t('fullName'), border: const OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_language),
                      initialValue: _language,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(labelText: _t('language'), border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'en', child: Text('English 🇬🇧', style: GoogleFonts.inter())),
                        DropdownMenuItem(value: 'ur', child: const Text('اردو (Urdu) 🇵🇰', style: TextStyle(fontFamily: 'JameelNooriNastaleeq'))),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() {
                            _language = val;
                            _updateMedicalAndDietaryText();
                          });
                          await LanguageController.instance.setLanguage(val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('language', val);
                          await prefs.setString('app_language', val);
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
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(labelText: _t('age'), border: const OutlineInputBorder()),
                            validator: (val) {
                              if (val == null || val.isEmpty) return _t('required');
                              final valInt = int.tryParse(val);
                              if (valInt == null || valInt < 1 || valInt > 120) {
                                return _language == 'ur' ? 'درست عمر (1-120)' : 'Enter valid age (1-120)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(labelText: _t('weight'), border: const OutlineInputBorder()),
                            validator: (val) {
                              if (val == null || val.isEmpty) return _t('required');
                              final valDouble = double.tryParse(val);
                              if (valDouble == null || valDouble < 10 || valDouble > 400) {
                                return _language == 'ur' ? 'درست وزن (10-400)' : 'Enter valid weight (10-400)';
                              }
                              return null;
                            },
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(labelText: _t('height'), border: const OutlineInputBorder()),
                            validator: (val) {
                              if (val == null || val.isEmpty) return _t('required');
                              final valDouble = double.tryParse(val);
                              if (valDouble == null || valDouble < 50 || valDouble > 280) {
                                return _language == 'ur' ? 'درست قد (50-280)' : 'Enter valid height (50-280)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(8),
                            ],
                            decoration: InputDecoration(labelText: _t('budget'), border: const OutlineInputBorder()),
                            validator: (val) {
                              if (val == null || val.isEmpty) return _t('required');
                              final valInt = int.tryParse(val);
                              if (valInt == null || valInt < 0 || valInt > 1000000) {
                                return _language == 'ur' ? 'درست بجٹ (0-1,000,000)' : 'Enter valid budget (0-1,000,000)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(_t('goalsActivity'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showSelectionDialog(
                        title: _t('goal'),
                        options: _goals,
                        selectedOptions: [_goal ?? ''],
                        isMultiSelect: false,
                        labelBuilder: _getGoalLabel,
                        onChange: (selected) {
                          if (selected.isNotEmpty) {
                            setState(() {
                              _goal = selected.first;
                            });
                            _markDirty();
                          }
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          key: ValueKey('${_goal}_$_language'),
                          initialValue: _getGoalLabel(_goal),
                          textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                          style: _language == 'ur'
                              ? const TextStyle(fontFamily: 'JameelNooriNastaleeq', color: Colors.white, fontSize: 16)
                              : GoogleFonts.inter(color: Colors.white, fontSize: 16),
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
                        title: _t('activity'),
                        options: _activityLevels,
                        selectedOptions: [_activityLevel ?? ''],
                        isMultiSelect: false,
                        labelBuilder: _getActivityLabel,
                        onChange: (selected) {
                          if (selected.isNotEmpty) {
                            setState(() {
                              _activityLevel = selected.first;
                            });
                            _markDirty();
                          }
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          key: ValueKey('${_activityLevel}_$_language'),
                          initialValue: _getActivityLabel(_activityLevel),
                          textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                          style: _language == 'ur'
                              ? const TextStyle(fontFamily: 'JameelNooriNastaleeq', color: Colors.white, fontSize: 16)
                              : GoogleFonts.inter(color: Colors.white, fontSize: 16),
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
                        title: _t('medicalConditions'),
                        options: _medicalOptions,
                        selectedOptions: _selectedMedical,
                        isMultiSelect: true,
                        labelBuilder: _getConditionLabel,
                        isSelectedChecker: (opt, sel) => sel.any((s) => _normalizeCondition(s) == _normalizeCondition(opt)),
                        onChange: (selected) {
                          setState(() {
                            _selectedMedical = selected;
                            _updateMedicalAndDietaryText();
                          });
                          _markDirty();
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _medicalConditionsController,
                          textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                          style: _language == 'ur'
                              ? const TextStyle(fontFamily: 'JameelNooriNastaleeq', color: Colors.white, fontSize: 16)
                              : GoogleFonts.inter(color: Colors.white, fontSize: 16),
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
                        title: _t('dietaryRestrictions'),
                        options: _dietaryOptions,
                        selectedOptions: _selectedDietary,
                        isMultiSelect: true,
                        labelBuilder: _getDietaryLabel,
                        isSelectedChecker: (opt, sel) => sel.any((s) => _normalizeDietary(s) == _normalizeDietary(opt)),
                        onChange: (selected) {
                          setState(() {
                            _selectedDietary = selected;
                            _updateMedicalAndDietaryText();
                          });
                          _markDirty();
                        },
                      ),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _dietaryRestrictionsController,
                          textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                          style: _language == 'ur'
                              ? const TextStyle(fontFamily: 'JameelNooriNastaleeq', color: Colors.white, fontSize: 16)
                              : GoogleFonts.inter(color: Colors.white, fontSize: 16),
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
                          backgroundColor: _hasUnsavedChanges ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.4),
                          foregroundColor: _hasUnsavedChanges ? Colors.white : Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: (_isSaving || !_hasUnsavedChanges) ? null : _saveSettings,
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_t('save'), style: TextStyle(fontWeight: FontWeight.bold, color: _hasUnsavedChanges ? Colors.white : Colors.white54)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    if (_selectedDietary.any((d) => d.toLowerCase().contains('halal'))) ...[
                      // Ramadan Mode Section
                      Text(_t('ramadanSection'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Material(
                      color: isRamadan
                          ? const Color(0xFF132448).withAlpha(150)
                          : const Color(0xFF161A22),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
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
                              secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF00D2FF)),
                              title: Text(
                                _t('ramadanReminders'),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              subtitle: Text(
                                _t('ramadanRemindersSub'),
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                              value: RamadanController.instance.remindersEnabled,
                              activeThumbColor: const Color(0xFF00D2FF),
                              activeTrackColor: const Color(0xFF00D2FF).withAlpha(60),
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
                    Material(
                      color: const Color(0xFF161A22),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
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
                      leading: const Icon(Icons.verified_user_outlined, color: Colors.tealAccent),
                      title: Text(_t('termsAndPrivacy')),
                      subtitle: Text(_t('termsAndPrivacySub')),
                      onTap: () => showTermsAndPrivacyDialog(context),
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
          ],
        ),
      ),
    ),
    );
  }
}
