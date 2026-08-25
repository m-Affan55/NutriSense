import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../shared/widgets/custom_toast.dart';
import '../../../core/api_client.dart';
import '../../../core/offline_cache.dart';
import '../../../core/sync_service.dart';
import '../../../core/swap_service.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/reminder_manager.dart';
import '../family_profiles/family_viewmodel.dart';
import '../navigation/main_navigation_screen.dart';
import 'barcode_scanner_screen.dart';

class ManualLogScreen extends StatefulWidget {
  const ManualLogScreen({super.key});

  @override
  State<ManualLogScreen> createState() => _ManualLogScreenState();
}

class _ManualLogScreenState extends State<ManualLogScreen> {
  final _aiFormKey = GlobalKey<FormState>();
  final _manualFormKey = GlobalKey<FormState>();

  // Mode: 'ai' (AI Smart Log) or 'manual' (Custom Macro Log)
  String _loggingMode = 'ai';

  // Controllers
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  String _selectedMealType = 'breakfast';
  String? _selectedFamilyMemberId = FamilyViewModel.instance.activeMember?.id;
  bool _isLogging = false;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _initDefaultMealType();
  }

  void _initDefaultMealType() {
    final isRamadan = RamadanController.instance.isRamadanMode;
    final hour = DateTime.now().hour;

    if (isRamadan) {
      if (hour >= 3 && hour <= 7) {
        _selectedMealType = 'sehri';
      } else if (hour >= 17 && hour <= 20) {
        _selectedMealType = 'iftar';
      } else if (hour > 20 || hour < 3) {
        _selectedMealType = 'dinner';
      } else {
        _selectedMealType = 'snack';
      }
    } else {
      if (hour >= 5 && hour < 11) {
        _selectedMealType = 'breakfast';
      } else if (hour >= 11 && hour < 16) {
        _selectedMealType = 'lunch';
      } else if (hour >= 16 && hour < 22) {
        _selectedMealType = 'dinner';
      } else {
        _selectedMealType = 'snack';
      }
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
      });
    }
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result == true) {
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          try {
            MainNavigationScreen.of(context).currentIndex = 0;
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _saveMealToStorage({
    required String mealName,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    setState(() => _isLogging = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No session found');

      if (kIsWeb) {
        await supabase.from('meal_logs').insert({
          'user_id': user.id,
          'meal_type': _selectedMealType,
          'notes': mealName,
          'total_calories': calories,
          'total_protein_g': proteinG.round(),
          'total_carbs_g': carbsG.round(),
          'total_fat_g': fatG.round(),
          'logged_at': DateTime.now().toUtc().toIso8601String(),
          'family_member_id': _selectedFamilyMemberId,
        });
      } else {
        // Write to local SQLite cache
        await OfflineCache.instance.insertPendingMeal(
          userId: user.id,
          mealType: _selectedMealType,
          notes: mealName,
          calories: calories,
          proteinG: proteinG.round(),
          carbsG: carbsG.round(),
          fatG: fatG.round(),
          familyMemberId: _selectedFamilyMemberId,
        );
        // Sync in background
        SyncService.instance.syncPending(user.id);

        // Train adaptive reminder streaks
        await ReminderManager.recordMealLogged(_selectedMealType, DateTime.now());
        await ReminderManager.updateAndCheckStreak();
      }

      if (mounted) {
        final successMsg = _language == 'ur'
            ? 'غذا محفوظ ہو گئی! ($calories کیلوریز | ${proteinG.round()}g پروٹین)'
            : 'Meal Logged! ($calories kcal • ${proteinG.round()}g P • ${carbsG.round()}g C • ${fatG.round()}g F)';
        CustomToast.show(context, successMsg, isError: false);
        SwapService.checkMealForSwaps(mealName);

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          _nameController.clear();
          _caloriesController.clear();
          _proteinController.clear();
          _carbsController.clear();
          _fatController.clear();
          try {
            MainNavigationScreen.of(context).currentIndex = 0;
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          _language == 'ur'
              ? 'کھانا محفوظ کرنے میں ناکامی۔ براہ کرم نیٹ ورک چیک کریں'
              : 'Failed to save meal. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLogging = false);
      }
    }
  }

  void _saveManualEntry() {
    if (!_manualFormKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final cal = int.tryParse(_caloriesController.text.trim()) ?? 0;
    final pro = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final carb = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0.0;

    _saveMealToStorage(
      mealName: name,
      calories: cal,
      proteinG: pro,
      carbsG: carb,
      fatG: fat,
    );
  }

  void _showManualEntryFallbackDialog(String mealName) {
    final nameController = TextEditingController(text: mealName);
    final calController = TextEditingController();
    final proController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_off, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _language == 'ur' ? 'اے آئی تخمینہ دستیاب نہیں' : 'AI Engine Unavailable',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              _language == 'ur' ? 'براہ کرم دستی طور پر غذائی تفصیلات درج کریں:' : 'Please enter your meal macros manually to log accurately:',
                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Color(0xFF00E676), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? (_language == 'ur' ? 'نام درکار ہے' : 'Name required') : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: calController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _language == 'ur' ? 'کیلوریز (kcal) *' : 'Calories (kcal) *',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFF0D0F14),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? (_language == 'ur' ? 'لازمی ہے' : 'Required') : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: proController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _language == 'ur' ? 'پروٹین (g)' : 'Protein (g)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFF0D0F14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: carbController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _language == 'ur' ? 'کاربس (g)' : 'Carbs (g)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFF0D0F14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: fatController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _language == 'ur' ? 'چربی (g)' : 'Fat (g)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFF0D0F14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final cal = int.tryParse(calController.text.trim()) ?? 0;
                          final pro = double.tryParse(proController.text.trim()) ?? 0.0;
                          final carb = double.tryParse(carbController.text.trim()) ?? 0.0;
                          final fat = double.tryParse(fatController.text.trim()) ?? 0.0;

                          Navigator.pop(ctx);
                          _saveMealToStorage(
                            mealName: nameController.text.trim(),
                            calories: cal,
                            proteinG: pro,
                            carbsG: carb,
                            fatG: fat,
                          );
                        }
                      },
                      child: Text(
                        _language == 'ur' ? 'کھانا محفوظ کریں' : 'Save Meal',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logMealWithAI() async {
    if (!_aiFormKey.currentState!.validate()) return;
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      CustomToast.show(context, _language == 'ur' ? 'براہ کرم کھانے کا نام درج کریں' : 'Please enter your meal name first');
      return;
    }

    setState(() => _isLogging = true);

    // 1. Calculate macros using Gemini AI / USDA backend engine
    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/search-food');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if AI recognized it as food
        final bool isFood = data['is_food'] ?? true;
        if (!isFood) {
          if (mounted) {
            setState(() => _isLogging = false);
            CustomToast.show(
              context,
              _language == 'ur'
                  ? '❌ یہ کھانے کی چیز نہیں لگتی۔ براہ کرم کھانے کا نام درج کریں'
                  : '❌ This doesn\'t seem like a food item. Please enter a valid food or meal name.',
              isError: true,
            );
          }
          return;
        }
        
        final int calories = (data['calories'] as num?)?.toInt() ?? 0;
        final double proteinG = (data['protein_g'] as num?)?.toDouble() ?? 0.0;
        final double carbsG = (data['carbs_g'] as num?)?.toDouble() ?? 0.0;
        final double fatG = (data['fat_g'] as num?)?.toDouble() ?? 0.0;
        final String finalMealName = (data['name'] != null && data['name'].toString().isNotEmpty)
            ? data['name'].toString()
            : query;

        if (mounted) {
          setState(() => _isLogging = false);
          _showAIMacroConfirmationDialog(
            mealName: finalMealName,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
          );
        }
      } else {
        throw Exception('AI server returned ${response.statusCode}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLogging = false);
        _showManualEntryFallbackDialog(query);
      }
    }
  }

  /// Shows an editable confirmation bottom sheet with AI-estimated macros.
  /// User can review, edit, and then save.
  void _showAIMacroConfirmationDialog({
    required String mealName,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    final nameCtrl = TextEditingController(text: mealName);
    final calCtrl = TextEditingController(text: calories.toString());
    final proCtrl = TextEditingController(text: proteinG.round().toString());
    final carbCtrl = TextEditingController(text: carbsG.round().toString());
    final fatCtrl = TextEditingController(text: fatG.round().toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with AI badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF00E676), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _language == 'ur' ? 'AI نے میکروز کا اندازہ لگایا ✓' : 'AI Estimated Macros ✓',
                            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _language == 'ur' ? 'ضرورت ہو تو ترمیم کریں، پھر محفوظ کریں' : 'Review & edit if needed, then save',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Meal name field
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: _language == 'ur' ? 'کھانے کا نام' : 'Meal Name',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF0D0F14),
                    prefixIcon: const Icon(Icons.restaurant_menu, color: Colors.white38, size: 18),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Calories field
                TextFormField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _language == 'ur' ? 'کیلوریز (kcal)' : 'Calories (kcal)',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF0D0F14),
                    prefixIcon: const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                  ),
                  validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? 'Enter a valid number' : null,
                ),
                const SizedBox(height: 12),
                // Macro row: Protein | Carbs
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: proCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _language == 'ur' ? 'پروٹین (g)' : 'Protein (g)',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFF0D0F14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: carbCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _language == 'ur' ? 'کاربس (g)' : 'Carbs (g)',
                          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFF0D0F14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fat field
                TextFormField(
                  controller: fatCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _language == 'ur' ? 'چربی (g)' : 'Fat (g)',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF0D0F14),
                  ),
                ),
                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _language == 'ur' ? 'کھانا محفوظ کریں' : 'Confirm & Save Meal',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final name = nameCtrl.text.trim();
                        final cal = int.tryParse(calCtrl.text.trim()) ?? 0;
                        final pro = double.tryParse(proCtrl.text.trim()) ?? 0.0;
                        final carb = double.tryParse(carbCtrl.text.trim()) ?? 0.0;
                        final fat = double.tryParse(fatCtrl.text.trim()) ?? 0.0;

                        Navigator.pop(ctx);
                        _saveMealToStorage(
                          mealName: name,
                          calories: cal,
                          proteinG: pro,
                          carbsG: carb,
                          fatG: fat,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarcodeIcon({Color? color, double size = 22}) {
    final c = color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 3.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 2.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 3.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 2.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final isRamadan = RamadanController.instance.isRamadanMode;
        final accentColor = isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary;

        // Dynamic meal categories based on Ramadan Mode
        final List<Map<String, dynamic>> mealCategories = isRamadan
            ? [
                {'key': 'sehri', 'en': 'Sehri', 'ur': 'سحری', 'icon': Icons.nightlight_round},
                {'key': 'iftar', 'en': 'Iftar', 'ur': 'افطاری', 'icon': Icons.wb_sunny_outlined},
                {'key': 'dinner', 'en': 'Dinner', 'ur': 'رات کا کھانا', 'icon': Icons.dinner_dining},
                {'key': 'snack', 'en': 'Snack', 'ur': 'اسنیک', 'icon': Icons.cookie_outlined},
              ]
            : [
                {'key': 'breakfast', 'en': 'Breakfast', 'ur': 'ناشتہ', 'icon': Icons.breakfast_dining},
                {'key': 'lunch', 'en': 'Lunch', 'ur': 'دوپہر کا کھانا', 'icon': Icons.lunch_dining},
                {'key': 'dinner', 'en': 'Dinner', 'ur': 'رات کا کھانا', 'icon': Icons.dinner_dining},
                {'key': 'snack', 'en': 'Snack', 'ur': 'اسنیک', 'icon': Icons.cookie_outlined},
              ];

        // Ensure selected meal type is valid for current mode
        if (!mealCategories.any((cat) => cat['key'] == _selectedMealType)) {
          _selectedMealType = mealCategories.first['key'] as String;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _loggingMode == 'ai'
                  ? (_language == 'ur' ? 'غذا لاگ کریں (AI)' : 'Log Meal with AI')
                  : (_language == 'ur' ? 'دستی غذا لاگ کریں' : 'Log Meal Manually'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            automaticallyImplyLeading: Navigator.canPop(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _language == 'ur' ? 'بارکوڈ اسکین کریں' : 'Scan Barcode',
                icon: _buildBarcodeIcon(
                  color: accentColor,
                  size: 22,
                ),
                onPressed: _openBarcodeScanner,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 150),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Mode Switcher Tab Bar ─────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Row(
                    children: [
                      // AI Smart Mode Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _loggingMode = 'ai'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _loggingMode == 'ai' ? accentColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: _loggingMode == 'ai' ? Colors.black : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _language == 'ur' ? 'AI اسمارٹ لاگ' : 'AI Smart Log',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _loggingMode == 'ai' ? Colors.black : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Manual Custom Macros Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _loggingMode = 'manual'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _loggingMode == 'manual' ? accentColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 18,
                                  color: _loggingMode == 'manual' ? Colors.black : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _language == 'ur' ? 'دستی میکروز' : 'Custom Macros',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _loggingMode == 'manual' ? Colors.black : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── AI Smart Log View ─────────────────────────────────────
                if (_loggingMode == 'ai') ...[
                  Form(
                    key: _aiFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Info Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: accentColor.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, color: accentColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _language == 'ur'
                                      ? 'صرف کھانے کا نام لکھیں، AI خود بخود تمام کیلوریز اور میکروز کا حساب لگائے گا!'
                                      : 'Just describe your meal — our AI automatically calculates calories, protein, carbs, and fat!',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(220),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Meal Description Field
                        Text(
                          _language == 'ur' ? 'آپ نے کیا کھایا؟' : 'What did you eat?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          maxLines: 2,
                          textInputAction: TextInputAction.send,
                          onFieldSubmitted: (_) {
                            if (!_isLogging) {
                              if (_nameController.text.trim().isEmpty) {
                                CustomToast.show(
                                  context,
                                  _language == 'ur' ? 'براہ کرم کھانے کا نام درج کریں' : 'Please enter a meal description first',
                                );
                                return;
                              }
                              _logMealWithAI();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: _language == 'ur'
                                ? 'مثلاً: ۲ آلو کے پراٹھے اور ۱ کپ چائے...'
                                : 'e.g. 2 Aloo Parathas and 1 cup Chai, or Chicken Biryani with Raita...',
                            hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFF161A22),
                            contentPadding: const EdgeInsets.all(16),
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
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: IconButton(
                                tooltip: _language == 'ur' ? 'لاگ کریں' : 'Log with AI',
                                icon: _isLogging
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: accentColor,
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: accentColor.withAlpha(30),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.send_rounded, color: accentColor, size: 18),
                                      ),
                                onPressed: _isLogging
                                    ? null
                                    : () {
                                        if (_nameController.text.trim().isEmpty) {
                                          CustomToast.show(
                                            context,
                                            _language == 'ur'
                                                ? 'براہ کرم کھانے کا نام درج کریں'
                                                : 'Please enter a meal description first',
                                          );
                                          return;
                                        }
                                        _logMealWithAI();
                                      },
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (_language == 'ur' ? 'براہ کرم کھانے کا نام درج کریں' : 'Please enter a meal description')
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Quick Suggestion Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isRamadan) ...[
                              _buildQuickChip('Khajoor & Water (2 pcs)', 'کھجور اور پانی'),
                              _buildQuickChip('2 Parathas & Omelette', '۲ پراٹھے اور آملیٹ'),
                              _buildQuickChip('Fruit Chaat & 1 Samosa', 'فروٹ چاٹ اور سموسہ'),
                              _buildQuickChip('Chicken Biryani (1 plate)', 'چکن بریانی'),
                            ] else ...[
                              _buildQuickChip('2 Boiled Eggs & Toast', '۲ انڈے اور ٹوسٹ'),
                              _buildQuickChip('2 Rotis & Daal (1 bowl)', '۲ روٹیاں اور دال'),
                              _buildQuickChip('Chicken Biryani & Raita', 'بریانی اور رائتہ'),
                              _buildQuickChip('1 Cup Chai with Biscuits', 'چائے اور بسکٹ'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Direct Manual Macro Log View ──────────────────────────
                if (_loggingMode == 'manual') ...[
                  Form(
                    key: _manualFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal Name Field
                        Text(
                          _language == 'ur' ? 'کھانے کا نام / تفصیل' : 'Meal Name / Items',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: _language == 'ur' ? 'مثلاً: ہوم میڈ پروٹین شیک' : 'e.g. Homemade Protein Shake, Greek Yogurt',
                            hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFF161A22),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (_language == 'ur' ? 'کھانے کا نام درج کریں' : 'Please enter meal name')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Calories & Protein Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _language == 'ur' ? 'کیلوریز (kcal) *' : 'Calories (kcal) *',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _caloriesController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      hintText: '450',
                                      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                                      filled: true,
                                      fillColor: const Color(0xFF161A22),
                                      prefixIcon: const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return _language == 'ur' ? 'لازمی ہے' : 'Required';
                                      if (int.tryParse(v.trim()) == null) return _language == 'ur' ? 'درست نمبر لکھیں' : 'Valid number';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _language == 'ur' ? 'پروٹین (g)' : 'Protein (g)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _proteinController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: '25.0',
                                      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                                      filled: true,
                                      fillColor: const Color(0xFF161A22),
                                      prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFF00E676), size: 18),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Carbs & Fat Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _language == 'ur' ? 'کاربوہائیڈریٹ (g)' : 'Carbs (g)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _carbsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: '50.0',
                                      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                                      filled: true,
                                      fillColor: const Color(0xFF161A22),
                                      prefixIcon: const Icon(Icons.grain, color: Color(0xFFFFD166), size: 18),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _language == 'ur' ? 'چربی / فیٹ (g)' : 'Fat (g)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _fatController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: '12.0',
                                      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                                      filled: true,
                                      fillColor: const Color(0xFF161A22),
                                      prefixIcon: const Icon(Icons.water_drop, color: Color(0xFFFF7043), size: 18),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Shared: Meal Category Selector ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _language == 'ur' ? 'کھانے کا وقت / قسم' : 'Meal Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isRamadan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00D2FF).withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.nightlight_round, color: Color(0xFF00D2FF), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _language == 'ur' ? 'رمضان موڈ' : 'Ramadan Mode',
                              style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: mealCategories.map((cat) {
                    final key = cat['key'] as String;
                    final label = (_language == 'ur' ? cat['ur'] : cat['en']) as String;
                    final icon = cat['icon'] as IconData;
                    final isSelected = _selectedMealType == key;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMealType = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? accentColor.withAlpha(30) : const Color(0xFF161A22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? accentColor : Colors.white.withAlpha(15),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: isSelected ? accentColor : const Color(0xFF8A94A6), size: 20),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF8A94A6),
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Shared: Family Member Selector ────────────────────────
                if (FamilyViewModel.instance.members.isNotEmpty) ...[
                  Text(
                    _language == 'ur' ? 'کس کے لیے لاگ کر رہے ہیں؟' : 'Logging for',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFamilyChip(null, _language == 'ur' ? 'میری ذات' : 'Myself'),
                        ...FamilyViewModel.instance.members.map((m) => _buildFamilyChip(m.id, m.name)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Action Button ─────────────────────────────────────────
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLogging
                        ? null
                        : (_loggingMode == 'ai' ? _logMealWithAI : _saveManualEntry),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isLogging
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _loggingMode == 'ai'
                                    ? (_language == 'ur' ? 'AI کیلوریز شمار کر رہا ہے...' : 'AI Estimating Macros...')
                                    : (_language == 'ur' ? 'محفوظ کیا جا رہا ہے...' : 'Saving Meal...'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _loggingMode == 'ai' ? Icons.auto_awesome : Icons.check_circle_outline,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _loggingMode == 'ai'
                                    ? (_language == 'ur' ? 'غذا لاگ کریں (AI)' : 'Log Meal with AI')
                                    : (_language == 'ur' ? 'غذا محفوظ کریں' : 'Save Meal Log'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickChip(String textEn, String textUr) {
    final label = _language == 'ur' ? textUr : textEn;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
      backgroundColor: const Color(0xFF161A22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withAlpha(20)),
      ),
      onPressed: () {
        setState(() {
          _nameController.text = textEn;
        });
      },
    );
  }

  Widget _buildFamilyChip(String? memberId, String label) {
    final isSelected = _selectedFamilyMemberId == memberId;
    final activeColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: activeColor.withAlpha(40),
        backgroundColor: const Color(0xFF161A22),
        labelStyle: TextStyle(
          color: isSelected ? activeColor : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? activeColor : Colors.white.withAlpha(20)),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFamilyMemberId = memberId);
          }
        },
      ),
    );
  }
}
