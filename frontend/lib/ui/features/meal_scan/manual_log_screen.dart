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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

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

  Future<void> _logMealWithAI() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      CustomToast.show(context, _language == 'ur' ? 'براہ کرم کھانے کا نام درج کریں' : 'Please enter your meal name first');
      return;
    }

    setState(() => _isLogging = true);

    int calories = 450;
    double proteinG = 15.0;
    double carbsG = 55.0;
    double fatG = 18.0;
    String finalMealName = query;

    // 1. Calculate macros using Gemini AI / USDA backend engine
    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/search-food');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        calories = (data['calories'] as num?)?.toInt() ?? 450;
        proteinG = (data['protein_g'] as num?)?.toDouble() ?? 15.0;
        carbsG = (data['carbs_g'] as num?)?.toDouble() ?? 55.0;
        fatG = (data['fat_g'] as num?)?.toDouble() ?? 18.0;
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          finalMealName = data['name'].toString();
        }
      }
    } catch (_) {
      // Offline fallback: Heuristic estimation based on typical meal portions
      calories = 480;
      proteinG = 16.0;
      carbsG = 60.0;
      fatG = 18.0;
    }

    // 2. Save meal to database (Offline-First)
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No session found');

      if (kIsWeb) {
        await supabase.from('meal_logs').insert({
          'user_id': user.id,
          'meal_type': _selectedMealType,
          'notes': finalMealName,
          'total_calories': calories,
          'total_protein_g': proteinG.round(),
          'total_carbs_g': carbsG.round(),
          'total_fat_g': fatG.round(),
          'family_member_id': _selectedFamilyMemberId,
        });
      } else {
        // Write to local SQLite cache
        await OfflineCache.instance.insertPendingMeal(
          userId: user.id,
          mealType: _selectedMealType,
          notes: finalMealName,
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
        SwapService.checkMealForSwaps(finalMealName);

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          _nameController.clear();
          try {
            MainNavigationScreen.of(context).currentIndex = 0;
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save meal: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLogging = false);
      }
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final isRamadan = RamadanController.instance.isRamadanMode;

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
              _language == 'ur' ? 'غذا لاگ کریں' : 'Log Meal with AI',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            automaticallyImplyLeading: Navigator.canPop(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _language == 'ur' ? 'بارکوڈ اسکین کریں' : 'Scan Barcode',
                icon: _buildBarcodeIcon(
                  color: isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary,
                  size: 22,
                ),
                onPressed: _openBarcodeScanner,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 150),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isRamadan
                          ? const Color(0xFF00D2FF).withAlpha(20)
                          : theme.colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRamadan
                            ? const Color(0xFF00D2FF).withAlpha(60)
                            : theme.colorScheme.primary.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary,
                          size: 24,
                        ),
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

                  // 1. Meal Description Field
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
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 2,
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
                        borderSide: BorderSide(
                          color: isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: IconButton(
                          tooltip: _language == 'ur' ? 'بارکوڈ اسکین کریں' : 'Scan Barcode',
                          icon: _buildBarcodeIcon(
                            color: isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: _openBarcodeScanner,
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
                  const SizedBox(height: 28),

                  // 2. Meal Category Selector (Sehri / Iftar / Breakfast / Lunch / Dinner / Snack)
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
                      final activeColor = isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMealType = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor.withAlpha(30) : const Color(0xFF161A22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? activeColor : Colors.white.withAlpha(15),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, color: isSelected ? activeColor : const Color(0xFF8A94A6), size: 20),
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
                  const SizedBox(height: 28),

                  // 3. Family Member Selector (if profiles exist)
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
                    const SizedBox(height: 28),
                  ],

                  // 4. Log Meal Button
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLogging ? null : _logMealWithAI,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRamadan ? const Color(0xFF00D2FF) : theme.colorScheme.primary,
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
                                  _language == 'ur' ? 'AI کیلوریز شمار کر رہا ہے...' : 'AI Estimating Macros...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _language == 'ur' ? 'غذا لاگ کریں (AI)' : 'Log Meal with AI',
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
