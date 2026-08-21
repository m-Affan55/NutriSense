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
import '../../../core/ramadan_controller.dart';

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
  bool _isSaving = false;
  bool _isSearching = false;
  String _language = 'en';

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

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

  Future<void> _searchFoodMacros() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      CustomToast.show(context, 'Please enter a food name first');
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/search-food');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Add the formatted name if we typed something brief
          if (data['name'] != null && data['name'].toString().isNotEmpty) {
            _nameController.text = data['name'].toString();
          }
          _caloriesController.text = data['calories'].toString();
          _proteinController.text = data['protein_g'].toString();
          _carbsController.text = data['carbs_g'].toString();
          _fatController.text = data['fat_g'].toString();
        });
        if (mounted) {
          CustomToast.show(context, 'AI filled macros successfully!', isError: false);
        }
      } else {
        if (mounted) {
          CustomToast.show(context, 'Failed to fetch macros: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Network error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No session found');

      final calories = int.parse(_caloriesController.text);
      final proteinG = int.parse(_proteinController.text);
      final carbsG = int.parse(_carbsController.text);
      final fatG = int.parse(_fatController.text);
      final notes = _nameController.text.trim();

      if (kIsWeb) {
        // SQLite sqflite is not supported on web, push directly
        await supabase.from('meal_logs').insert({
          'user_id': user.id,
          'meal_type': _selectedMealType,
          'notes': notes,
          'total_calories': calories,
          'total_protein_g': proteinG,
          'total_carbs_g': carbsG,
          'total_fat_g': fatG,
        });
      } else {
        // 1. Write to local SQLite cache immediately (works offline)
        await OfflineCache.instance.insertPendingMeal(
          userId: user.id,
          mealType: _selectedMealType,
          notes: notes,
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
        );
        // 2. Sync to Supabase in background (fire-and-forget)
        SyncService.instance.syncPending(user.id);
      }

      if (mounted) {
        CustomToast.show(context, _t('success'), isError: false);
        Navigator.pop(context, true);
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
        'title': 'Log Meal Manually',
        'name': 'Meal Description / Items',
        'type': 'Meal Category',
        'calories': 'Calories (kcal)',
        'protein': 'Protein (g)',
        'carbs': 'Carbohydrates (g)',
        'fat': 'Fat (g)',
        'save': 'Save Meal Log',
        'required': 'Required',
        'numberRequired': 'Please enter a valid number',
        'success': 'Meal logged successfully!',
      },
      'ur': {
        'title': 'خود غذا لاگ کریں',
        'name': 'غذا کی تفصیل / نام',
        'type': 'غذا کی قسم',
        'calories': 'کیلوریز',
        'protein': 'پروٹین (گرام)',
        'carbs': 'کاربوہائیڈریٹ (گرام)',
        'fat': 'چربی (گرام)',
        'save': 'غذا محفوظ کریں',
        'required': 'لازمی',
        'numberRequired': 'براہ کرم درست نمبر درج کریں',
        'success': 'غذا کامیابی کے ساتھ لاگ ہو گئی!',
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _language == 'ur' 
                          ? 'پرو ٹپ: کھانے کا نام لکھیں اور AI کو میکروز بھرنے کے لیے AI Search دبائیں!'
                          : 'Pro tip: Type a food name and hit AI Search to magically fill the macros!',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: _t('name'),
                        border: const OutlineInputBorder(),
                        hintText: _language == 'ur' ? 'مثال کے طور پر: انڈا اور روٹی' : 'e.g. Eggs and toast',
                      ),
                      validator: (val) => val == null || val.isEmpty ? _t('required') : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56, // matches TextFormField default height roughly
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _searchFoodMacros,
                      icon: _isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_language == 'ur' ? 'تلاش کریں' : 'AI Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary.withAlpha(50),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedMealType,
                decoration: InputDecoration(
                  labelText: _t('type'),
                  border: const OutlineInputBorder(),
                ),
                items: _mealTypes.map((type) {
                  final isRamadan = RamadanController.instance.isRamadanMode;
                  String label = type.toUpperCase();
                  if (isRamadan) {
                    label = RamadanController.instance.getLocalizedMealName(type, _language);
                  } else if (_language == 'ur') {
                    if (type == 'breakfast') label = 'ناشتہ';
                    if (type == 'lunch') label = 'دوپہر کا کھانا';
                    if (type == 'dinner') label = 'رات کا کھانا';
                    if (type == 'snack') label = 'اسنیک';
                  }
                  return DropdownMenuItem(value: type, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMealType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('calories'),
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return _t('required');
                  if (int.tryParse(val) == null) return _t('numberRequired');
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _t('protein'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return _t('required');
                        if (int.tryParse(val) == null) return _t('numberRequired');
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _t('carbs'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return _t('required');
                        if (int.tryParse(val) == null) return _t('numberRequired');
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fatController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('fat'),
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return _t('required');
                  if (int.tryParse(val) == null) return _t('numberRequired');
                  return null;
                },
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
                  onPressed: _isSaving ? null : _saveMeal,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
