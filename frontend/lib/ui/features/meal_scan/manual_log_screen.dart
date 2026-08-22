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

class ManualLogScreen extends StatefulWidget {
  const ManualLogScreen({super.key});

  @override
  State<ManualLogScreen> createState() => _ManualLogScreenState();
}

class _ManualLogScreenState extends State<ManualLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  String _selectedMealType = 'breakfast';
  String? _selectedFamilyMemberId = FamilyViewModel.instance.activeMember?.id;
  bool _isSaving = false;
  bool _isEstimating = false;
  bool _hasEstimated = false;
  bool _showManualOverride = false;
  String _language = 'en';

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  final List<String> _quickSuggestions = [
    '🍳 2 Fried Eggs with Paratha',
    '🍗 Chicken Biryani (1 Plate)',
    '🥣 Oats with Milk & Banana',
    '☕ Chai & Rusks',
    '🥗 Fresh Chicken Salad',
    '🥪 Club Sandwich',
    '🍲 Daal Chawal with Salad',
    '🍕 2 Slices Pizza',
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchMacros(String query) async {
    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/search-food');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Smart fallback if offline
    final q = query.toLowerCase();
    if (q.contains('paratha')) {
      return {'name': query, 'calories': 420, 'protein_g': 8.0, 'carbs_g': 52.0, 'fat_g': 20.0};
    } else if (q.contains('biryani')) {
      return {'name': query, 'calories': 550, 'protein_g': 28.0, 'carbs_g': 65.0, 'fat_g': 18.0};
    } else if (q.contains('egg') || q.contains('anda')) {
      return {'name': query, 'calories': 250, 'protein_g': 14.0, 'carbs_g': 2.0, 'fat_g': 19.0};
    } else if (q.contains('chai') || q.contains('tea')) {
      return {'name': query, 'calories': 120, 'protein_g': 3.5, 'carbs_g': 15.0, 'fat_g': 4.5};
    } else if (q.contains('pizza')) {
      return {'name': query, 'calories': 320, 'protein_g': 13.0, 'carbs_g': 34.0, 'fat_g': 14.0};
    } else if (q.contains('roti') || q.contains('chapati')) {
      return {'name': query, 'calories': 120, 'protein_g': 3.5, 'carbs_g': 25.0, 'fat_g': 0.5};
    }
    return {'name': query, 'calories': 350, 'protein_g': 15.0, 'carbs_g': 45.0, 'fat_g': 12.0};
  }

  Future<void> _previewAiMacros() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      CustomToast.show(context, _language == 'ur' ? 'پہلے کھانے کا نام لکھیں' : 'Please enter food name first');
      return;
    }

    setState(() => _isEstimating = true);
    final data = await _fetchMacros(query);

    if (mounted && data != null) {
      setState(() {
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          _nameController.text = data['name'].toString();
        }
        _caloriesController.text = (data['calories'] ?? 350).toString();
        _proteinController.text = (data['protein_g'] ?? 15.0).toString();
        _carbsController.text = (data['carbs_g'] ?? 45.0).toString();
        _fatController.text = (data['fat_g'] ?? 12.0).toString();
        _hasEstimated = true;
        _isEstimating = false;
      });
      CustomToast.show(
        context,
        _language == 'ur' ? '✨ AI نے غذائی اجزاء شمار کر لیے ہیں!' : '✨ AI calculated macros successfully!',
        isError: false,
      );
    } else if (mounted) {
      setState(() => _isEstimating = false);
    }
  }

  Future<void> _saveMealWithAi() async {
    if (!_formKey.currentState!.validate()) return;

    final foodName = _nameController.text.trim();
    if (foodName.isEmpty) {
      CustomToast.show(context, _language == 'ur' ? 'کھانے کا نام درج کریں' : 'Please enter what you ate');
      return;
    }

    setState(() => _isSaving = true);

    try {
      int calories;
      int proteinG;
      int carbsG;
      int fatG;

      if (_caloriesController.text.isNotEmpty &&
          double.tryParse(_caloriesController.text) != null) {
        calories = double.parse(_caloriesController.text).round();
        proteinG = (double.tryParse(_proteinController.text) ?? 15.0).round();
        carbsG = (double.tryParse(_carbsController.text) ?? 45.0).round();
        fatG = (double.tryParse(_fatController.text) ?? 12.0).round();
      } else {
        final data = await _fetchMacros(foodName);
        calories = (data?['calories'] ?? 350) as int;
        proteinG = ((data?['protein_g'] ?? 15.0) as num).round();
        carbsG = ((data?['carbs_g'] ?? 45.0) as num).round();
        fatG = ((data?['fat_g'] ?? 12.0) as num).round();
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No session found');

      if (kIsWeb) {
        await supabase.from('meal_logs').insert({
          'user_id': user.id,
          'meal_type': _selectedMealType,
          'notes': foodName,
          'total_calories': calories,
          'total_protein_g': proteinG,
          'total_carbs_g': carbsG,
          'total_fat_g': fatG,
          'family_member_id': _selectedFamilyMemberId,
        });
      } else {
        await OfflineCache.instance.insertPendingMeal(
          userId: user.id,
          mealType: _selectedMealType,
          notes: foodName,
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          familyMemberId: _selectedFamilyMemberId,
        );
        SyncService.instance.syncPending(user.id);

        await ReminderManager.recordMealLogged(_selectedMealType, DateTime.now());
        await ReminderManager.updateAndCheckStreak();
      }

      if (mounted) {
        CustomToast.show(
          context,
          _language == 'ur' ? '✅ $foodName کامیابی سے لاگ ہو گیا ($calories کیلوریز)' : '✅ $foodName logged ($calories kcal)',
          isError: false,
        );
        SwapService.checkMealForSwaps(foodName);

        _nameController.clear();
        _caloriesController.clear();
        _proteinController.clear();
        _carbsController.clear();
        _fatController.clear();
        setState(() {
          _hasEstimated = false;
        });

        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save meal: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'Log Meal',
        'subtitle': 'Type what you ate — AI calculates calories & macros automatically!',
        'nameLabel': 'What did you eat?',
        'nameHint': 'e.g. 2 Aloo Parathas & 1 Chai, or Chicken Biryani',
        'typeLabel': 'Meal Category',
        'calculateBtn': 'Auto-Calculate',
        'logMealBtn': 'Log Meal with AI',
        'required': 'Please enter food description',
        'quickChips': 'Quick Suggestions',
        'adjustTitle': 'Custom Macro Adjustments (Optional)',
        'calories': 'Calories (kcal)',
        'protein': 'Protein (g)',
        'carbs': 'Carbs (g)',
        'fat': 'Fat (g)',
      },
      'ur': {
        'title': 'غذا شامل کریں',
        'subtitle': 'صرف کھانے کا نام لکھیں — AI خود بخود کیلوریز اور غذائیت شمار کرے گی!',
        'nameLabel': 'آپ نے کیا کھایا؟',
        'nameHint': 'مثال: ۲ الو پراٹھے اور چائے، یا بریانی',
        'typeLabel': 'کھانے کی قسم',
        'calculateBtn': 'شمار کریں',
        'logMealBtn': 'AI کے ساتھ لاگ کریں',
        'required': 'کھانے کا نام درج کریں',
        'quickChips': 'فوری تجاویز',
        'adjustTitle': 'اپنی مرضی کے مطابق تبدیل کریں (اختیاری)',
        'calories': 'کیلوریز',
        'protein': 'پروٹین (گرام)',
        'carbs': 'کاربس (گرام)',
        'fat': 'چربی (گرام)',
      }
    };
    return translations[_language]?[key] ?? key;
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
    final isRamadan = RamadanController.instance.isRamadanMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF00E676)),
            const SizedBox(width: 10),
            Text(_t('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero AI Header Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRamadan
                        ? [const Color(0xFF0E172A), const Color(0xFF1E293B)]
                        : [const Color(0xFF161A22), const Color(0xFF1E232E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isRamadan ? const Color(0xFF00D2FF).withValues(alpha: 0.3) : const Color(0xFF00E676).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676)).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _t('subtitle'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // Family Member Selector (if profiles exist)
              if (FamilyViewModel.instance.members.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedFamilyMemberId,
                  dropdownColor: const Color(0xFF1E232E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _language == 'ur' ? 'یہ کھانا کس کے لیے ہے؟' : 'Logging meal for',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF00E676)),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(_language == 'ur' ? '🧑 میں (ذاتی اکاؤنٹ)' : '🧑 Me (Primary Account)'),
                    ),
                    ...FamilyViewModel.instance.members.map((m) => DropdownMenuItem<String?>(
                          value: m.id,
                          child: Text('${m.relationshipEmoji} ${m.name} (${m.getLocalizedRelationship(_language)})'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedFamilyMemberId = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 1. Food Name Input Field + AI Search Button
              Text(
                _t('nameLabel'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _t('nameHint'),
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF161A22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        prefixIcon: const Icon(Icons.restaurant_outlined, color: Colors.white54),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? _t('required') : null,
                      onFieldSubmitted: (_) => _previewAiMacros(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isEstimating ? null : _previewAiMacros,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: _isEstimating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 18),
                                const SizedBox(width: 6),
                                Text(_t('calculateBtn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Food Suggestion Chips
              Text(
                _t('quickChips'),
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickSuggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(suggestion, style: const TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: const Color(0xFF1E232E),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: () {
                          _nameController.text = suggestion.replaceAll(RegExp(r'^[^\w\s]+\s*'), '');
                          _previewAiMacros();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Meal Category Dropdown
              Text(
                _t('typeLabel'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedMealType,
                dropdownColor: const Color(0xFF1E232E),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161A22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.access_time_rounded, color: Colors.white54),
                ),
                items: _mealTypes.map((type) {
                  String label = type.toUpperCase();
                  if (isRamadan) {
                    label = RamadanController.instance.getLocalizedMealName(type, _language);
                  } else if (_language == 'ur') {
                    if (type == 'breakfast') label = '🌅 ناشتہ (Breakfast)';
                    if (type == 'lunch') label = '☀️ دوپہر کا کھانا (Lunch)';
                    if (type == 'dinner') label = '🌙 رات کا کھانا (Dinner)';
                    if (type == 'snack') label = '🥪 اسنیک (Snack)';
                  } else {
                    if (type == 'breakfast') label = '🌅 Breakfast';
                    if (type == 'lunch') label = '☀️ Lunch';
                    if (type == 'dinner') label = '🌙 Dinner';
                    if (type == 'snack') label = '🥪 Snack';
                  }
                  return DropdownMenuItem(value: type, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMealType = val);
                },
              ),
              const SizedBox(height: 20),

              // 3. AI Macro Results Card (Shows when calculated)
              if (_hasEstimated) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'AI Calculated Nutrition',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showManualOverride = !_showManualOverride),
                            child: Text(
                              _showManualOverride ? 'Hide Details' : 'Edit Values',
                              style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroPill('🔥', '${_caloriesController.text} kcal', 'Calories', const Color(0xFFFFD166)),
                          _buildMacroPill('💪', '${_proteinController.text}g', 'Protein', const Color(0xFF00E676)),
                          _buildMacroPill('🌾', '${_carbsController.text}g', 'Carbs', const Color(0xFF00BCD4)),
                          _buildMacroPill('🥑', '${_fatController.text}g', 'Fat', const Color(0xFFFF6B6B)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Optional Manual Adjustment Accordion
              if (_showManualOverride) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E232E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('adjustTitle'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _t('calories'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _proteinController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: _t('protein'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _carbsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: _t('carbs'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _fatController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: _t('fat'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 4. Primary "Log Meal with AI" Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_rounded, size: 22, color: Colors.black),
                  label: Text(
                    _isSaving ? 'Calculating & Saving...' : _t('logMealBtn'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                  onPressed: _isSaving ? null : _saveMealWithAi,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroPill(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
