import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/main_navigation_screen.dart';
import '../settings/settings_view.dart';
import '../meal_scan/manual_log_screen.dart';
import '../../../core/offline_cache.dart';
import '../../../core/sync_service.dart';
import '../../../core/health_service.dart';
import '../../../core/ramadan_controller.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../health_sync/health_sync_view.dart';
import '../family_profiles/family_viewmodel.dart';
import '../family_profiles/family_view.dart';
import '../onboarding/onboarding_view.dart';
import '../../../core/meal_sync_notifier.dart';
import '../../../core/language_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  // Dynamic state
  String _userName = 'User';
  int _targetCalories = 2000;
  int _targetProtein = 130;
  int _targetCarbs = 220;
  int _targetFat = 65;

  int _consumedCalories = 0;
  int _consumedProtein = 0;
  int _consumedCarbs = 0;
  int _consumedFat = 0;

  int _waterLogged = 0;
  final int _waterGoal = 2500;

  List<Map<String, dynamic>> _todayMeals = [];
  final Set<int> _expandedMealIndices = {};
  bool _isLoading = true;
  String _language = 'en';
  bool _needsOnboarding = false;

  // Offline sync badge
  int _pendingSyncCount = 0;

  // Health Connect / Google Fit activity
  ActivityData _activity = ActivityData.empty;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    FamilyViewModel.instance.addListener(_loadData);
    FamilyViewModel.instance.loadMembers();
    MealSyncNotifier.instance.addListener(_loadData);
    LanguageController.instance.addListener(_loadData);

    _loadData();
  }

  @override
  void dispose() {
    FamilyViewModel.instance.removeListener(_loadData);
    MealSyncNotifier.instance.removeListener(_loadData);
    LanguageController.instance.removeListener(_loadData);
    _ringController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _language = LanguageController.instance.currentLanguage;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) return;

      // 1. Get name metadata or active dependent name
      final activeMember = FamilyViewModel.instance.activeMember;
      final fullName = user.userMetadata?['full_name'] ?? 'User';
      _userName = activeMember != null ? activeMember.name : fullName;

      // 2. Fetch targets (per active family member or primary user)
      if (activeMember != null) {
        _targetCalories = activeMember.dailyCalorieTarget;
        _targetProtein = activeMember.dailyProteinG;
        _targetCarbs = activeMember.dailyCarbsG;
        _targetFat = activeMember.dailyFatG;
      } else {
        final profileRes = await supabase
            .from('health_profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (profileRes != null) {
          _needsOnboarding = false;
          _targetCalories = (profileRes['daily_calorie_target'] as num?)?.toInt() ?? 2000;
          _targetProtein = (profileRes['daily_protein_g'] as num?)?.toInt() ?? 130;
          _targetCarbs = (profileRes['daily_carbs_g'] as num?)?.toInt() ?? 220;
          _targetFat = (profileRes['daily_fat_g'] as num?)?.toInt() ?? 65;
        } else {
          _needsOnboarding = true;
        }
      }

      // 3. Fetch today's meals
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();
      
      final mealsRes = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', user.id)
          .gte('logged_at', startOfDay)
          .lte('logged_at', endOfDay);

      int calSum = 0;
      int proteinSum = 0;
      int carbsSum = 0;
      int fatSum = 0;
      List<Map<String, dynamic>> tempMeals = [];

      for (var meal in mealsRes) {
        final fId = meal['family_member_id']?.toString();
        if (activeMember != null) {
          if (fId != activeMember.id) continue;
        } else {
          if (fId != null && fId.isNotEmpty) continue;
        }

        calSum += (meal['total_calories'] as num?)?.toInt() ?? 0;
        proteinSum += (meal['total_protein_g'] as num?)?.toInt() ?? 0;
        carbsSum += (meal['total_carbs_g'] as num?)?.toInt() ?? 0;
        fatSum += (meal['total_fat_g'] as num?)?.toInt() ?? 0;
        tempMeals.add({
          'notes': meal['notes'] ?? 'Meal Logged',
          'meal_type': meal['meal_type'] ?? 'breakfast',
          'total_calories': meal['total_calories'] ?? 0,
          'logged_at': meal['logged_at'] ?? meal['created_at'],
        });
      }

      // 4. Fetch today's water
      final waterRes = await supabase
          .from('water_logs')
          .select()
          .eq('user_id', user.id)
          .gte('logged_at', startOfDay)
          .lte('logged_at', endOfDay);

      int waterSum = 0;
      for (var log in waterRes) {
        waterSum += (log['amount_ml'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _consumedCalories = calSum;
          _consumedProtein = proteinSum;
          _consumedCarbs = carbsSum;
          _consumedFat = fatSum;
          _todayMeals = tempMeals;
          _waterLogged = waterSum;
          _isLoading = false;
        });

        // Trigger calorie ring animation
        _ringController.reset();
        _ringController.forward();
        _fabController.forward();
      }
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, 'Failed to load dashboard data. Please pull down to refresh.', isError: true);
      }
    }

    // Merge offline pending meals (works even if Supabase fetch above threw)
    if (user != null && mounted) {
      try {
        final pendingMeals = kIsWeb ? <Map<String, dynamic>>[] : await OfflineCache.instance.getTodayPendingMeals(user.id);
        final pendingWaterMl = kIsWeb ? 0 : await OfflineCache.instance.getTodayPendingWaterMl(user.id);
        final pendingCount = kIsWeb ? 0 : await OfflineCache.instance.getTotalPendingCount(user.id);
        
        if (mounted) {
          setState(() {
            for (final m in pendingMeals) {
              _consumedCalories += (m['calories'] as int? ?? 0);
              _consumedProtein  += (m['protein_g'] as int? ?? 0);
              _consumedCarbs    += (m['carbs_g'] as int? ?? 0);
              _consumedFat      += (m['fat_g'] as int? ?? 0);
              _todayMeals.add({
                'notes': m['notes'],
                'meal_type': m['meal_type'],
                'total_calories': m['calories'],
                'logged_at': m['logged_at'] ?? DateTime.now().toIso8601String(),
                'pending': true,
              });
            }
            _waterLogged += pendingWaterMl;
            _pendingSyncCount = pendingCount;
          });
        }
      } catch (e) {
        debugPrint('Offline merge error: $e');
      }
    }

    // Fetch health activity (non-blocking — silently fails if not available)
    if (mounted) {
      try {
        final activity = await HealthService.instance.getTodayActivity();
        if (mounted) setState(() => _activity = activity);
      } catch (e) {
        debugPrint('[Dashboard] Health fetch error: $e');
      }
    }
  }

  Future<void> _logWater(int ml) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      if (kIsWeb) {
        await supabase.from('water_logs').insert({
          'user_id': user.id,
          'amount_ml': ml,
        });
      } else {
        // 1. Write to local cache immediately (offline-first)
        await OfflineCache.instance.insertPendingWater(
          userId: user.id,
          amountMl: ml,
        );
        // 2. Sync to Supabase in background
        SyncService.instance.syncPending(user.id);
      }
      await _loadData();
    } catch (e) {
      debugPrint('Error logging water: $e');
    }
  }

  void _showHydrationSelector() {
    final theme = Theme.of(context);
    final customController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final title = _language == 'ur' ? 'پانی کی مقدار لاگ کریں' : 'Log Water Intake';
        final glass = _language == 'ur' ? 'گلاس (250 ملی لیٹر)' : 'Glass (250 ml)';
        final sBottle = _language == 'ur' ? 'چھوٹی بوتل (500 ملی لیٹر)' : 'Small Bottle (500 ml)';
        final lBottle = _language == 'ur' ? 'بڑی بوتل (750 ملی لیٹر)' : 'Large Bottle (750 ml)';
        final container = _language == 'ur' ? 'کنٹینر (1 لیٹر)' : 'Container (1 Liter)';
        final custom = _language == 'ur' ? 'کسٹم مقدار (ملی لیٹر)' : 'Custom Amount (ml)';
        final logBtn = _language == 'ur' ? 'لاگ کریں' : 'Log';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (RamadanController.instance.isRamadanMode) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD166).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD166).withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Text('🌙', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _language == 'ur'
                                      ? 'رمضان ہائیڈریشن ہدف: افطار اور سحری کے درمیان 2.5 لیٹر پانی پیئں۔'
                                  : 'Ramadan Hydration Target: Aim for 2.5L split between Iftar and Sehri.',
                                  style: const TextStyle(color: Color(0xFFFFD166), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD166)),
                          title: Text(
                            _language == 'ur' ? 'افطار کے وقت (500 ملی لیٹر)' : 'Iftar Hydration (500 ml)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _logWater(500);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.nightlight_round, color: Color(0xFF00D2FF)),
                          title: Text(
                            _language == 'ur' ? 'تراویح کے بعد (500 ملی لیٹر)' : 'Post-Taraweeh (500 ml)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _logWater(500);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.wb_twilight, color: Color(0xFF00E676)),
                          title: Text(
                            _language == 'ur' ? 'سحری کے وقت (500 ملی لیٹر)' : 'Sehri Hydration (500 ml)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _logWater(500);
                          },
                        ),
                        const Divider(color: Colors.white12),
                      ],
                      ListTile(
                        leading: const Icon(Icons.local_drink, color: Color(0xFF26C6DA)),
                        title: Text(glass, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _logWater(250);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.water_drop, color: Color(0xFF0288D1)),
                        title: Text(sBottle, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _logWater(500);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.water_drop_outlined, color: Colors.blueAccent),
                        title: Text(lBottle, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _logWater(750);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.opacity, color: Colors.indigoAccent),
                        title: Text(container, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _logWater(1000);
                        },
                      ),
                      const Divider(color: Colors.white10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: custom,
                                hintStyle: const TextStyle(color: Colors.white30),
                                border: const UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              final amount = int.tryParse(customController.text);
                              if (amount != null && amount > 0) {
                                Navigator.pop(sheetContext);
                                _logWater(amount);
                              }
                            },
                            child: Text(logBtn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMealOptions() async {
    final reload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManualLogScreen()),
    );
    if (reload == true) {
      _loadData();
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdaysUr = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
    final monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthsUr = ['جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];

    if (_language == 'ur') {
      return '${weekdaysUr[now.weekday - 1]}، ${now.day} ${monthsUr[now.month - 1]} ${now.year}';
    }
    return '${weekdaysEn[now.weekday - 1]}, ${now.day} ${monthsEn[now.month - 1]} ${now.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return _language == 'ur' ? 'صبح بخیر' : 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return _language == 'ur' ? 'دوپہر بخیر' : 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return _language == 'ur' ? 'شام بخیر' : 'Good Evening';
    } else {
      return _language == 'ur' ? 'شب بخیر' : 'Good Night';
    }
  }

  String _t(String key) {
    final greeting = _getGreeting();
    
    final translations = {
      'en': {
        'greeting': '$greeting, $_userName',
        'todayMeals': 'Today\'s Meals',
        'addMeal': 'Log Meal',
        'noMeals': 'No meals logged today. Tap Log Meal with AI to begin!',
        'hydration': 'Hydration',
        'mlLogged': '$_waterLogged ml logged',
        'goalText': 'Goal: $_waterGoal ml',
        'scanMeal': 'Log Meal with AI',
        'protein': 'Protein',
        'carbs': 'Carbs',
        'fat': 'Fat',
        'of': 'of',
        'kcal': 'kcal',
      },
      'ur': {
        'greeting': '$greeting، $_userName',
        'todayMeals': 'آج کی غذائیں',
        'addMeal': 'غذا شامل کریں',
        'noMeals': 'آج کوئی غذا شامل نہیں کی گئی۔ لاگ کرنے کے لیے غذا لاگ کریں!',
        'hydration': 'پانی کا استعمال',
        'mlLogged': '$_waterLogged ملی لیٹر لاگ کیا گیا',
        'goalText': 'ہدف: $_waterGoal ملی لیٹر',
        'scanMeal': 'غذا لاگ کریں',
        'protein': 'پروٹین',
        'carbs': 'کاربس',
        'fat': 'چربی',
        'of': 'میں سے',
        'kcal': 'کیلوریز',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  Widget _buildOnboardingOverlayPopup(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 48),
          const SizedBox(height: 16),
          Text(
            'Complete Your Profile!',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Let\'s set up your personalized health goals and AI coach. Tap the button below to get started.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingWizardScreen()),
                ).then((_) => _loadData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isRamadan = RamadanController.instance.isRamadanMode;
        final double waterRatio = (_waterLogged / _waterGoal).clamp(0.0, 1.0);

        return Scaffold(
          body: RamadanBackgroundWrapper(
            child: SafeArea(
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section A: Personalized Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('greeting'), 
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(_getFormattedDate(), style: theme.textTheme.bodySmall),
                              ],
                            ),
                            GestureDetector(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                                _loadData();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.primary, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.colorScheme.primary.withAlpha(30),
                                  child: Icon(Icons.person, color: theme.colorScheme.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Family Profiles Switcher Pill Bar
                        _buildFamilyProfileBar(theme, isRamadan),
                        const SizedBox(height: 16),

                        // Offline sync badge (only shown when there are pending rows)
                        if (_pendingSyncCount > 0) _buildSyncBadge(theme),
                        if (_pendingSyncCount > 0) const SizedBox(height: 12),

                        // Ramadan Fasting & Hydration Schedule Card
                        if (isRamadan) _buildRamadanScheduleCard(theme, isRamadan),
                        if (isRamadan) const SizedBox(height: 24),

                      Builder(
                        builder: (context) {
                          int activeBurn = _activity.activeKcal.toInt();
                          // Show what the user actually ate as the main number to avoid confusion
                          int displayCalories = _consumedCalories; 
                          double calorieRatio = _targetCalories > 0 ? (displayCalories / _targetCalories) : 0.0;
                          if (calorieRatio > 1.0) calorieRatio = 1.0;

                          return Center(
                            child: SizedBox(
                              height: 220,
                              width: 220,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _ringAnimation,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(220, 220),
                                        painter: CalorieRingPainter(
                                          progress: calorieRatio * _ringAnimation.value,
                                          backgroundColor: const Color(0xFF262626),
                                          gradientStart: theme.colorScheme.primary,
                                          gradientEnd: isRamadan ? const Color(0xFFFFD166) : const Color(0xFF00BCD4),
                                        ),
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$displayCalories',
                                        style: theme.textTheme.displayMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '${_t('of')} $_targetCalories ${_t('kcal')}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      if (activeBurn > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            '-$activeBurn kcal active',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade300,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Section C: Macro Breakdown Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMacroPill(context, _t('protein'), '$_consumedProtein / ${_targetProtein}g', const Color(0xFFFF5252)),
                          _buildMacroPill(context, _t('carbs'), '$_consumedCarbs / ${_targetCarbs}g', const Color(0xFF448AFF)),
                          _buildMacroPill(context, _t('fat'), '$_consumedFat / ${_targetFat}g', const Color(0xFFFFD700)),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Section D: Today's Activity & Health Connect Stats
                      _buildActivityCard(theme),
                      const SizedBox(height: 32),

                      // Section E: Today's Logged Meals
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t('todayMeals'),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _showAddMealOptions,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(_t('addMeal')),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_todayMeals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              _t('noMeals'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _todayMeals.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final meal = _todayMeals[index];
                            final rawType = meal['meal_type']?.toString().toLowerCase() ?? 'meal';
                            final mealType = isRamadan
                                ? RamadanController.instance.getLocalizedMealName(rawType, _language)
                                : (meal['meal_type']?.toString().toUpperCase() ?? 'MEAL');
                            final notes = meal['notes']?.toString() ?? 'Logged Food';
                            final calories = '${meal['total_calories'] ?? 0} ${_t('kcal')}';
                            
                            IconData mealIcon;
                            if (isRamadan) {
                              switch (rawType) {
                                case 'breakfast':
                                  mealIcon = Icons.nights_stay_outlined;
                                  break;
                                case 'dinner':
                                  mealIcon = Icons.wb_twilight;
                                  break;
                                case 'lunch':
                                  mealIcon = Icons.dinner_dining_outlined;
                                  break;
                                default:
                                  mealIcon = Icons.local_cafe_outlined;
                              }
                            } else {
                              switch (rawType) {
                                case 'breakfast':
                                  mealIcon = Icons.wb_sunny_outlined;
                                  break;
                                case 'lunch':
                                  mealIcon = Icons.lunch_dining_outlined;
                                  break;
                                case 'dinner':
                                  mealIcon = Icons.dinner_dining_outlined;
                                  break;
                                default:
                                  mealIcon = Icons.fastfood_outlined;
                              }
                            }

                            final loggedAt = meal['logged_at'];
                            final isExpanded = _expandedMealIndices.contains(index);

                            return _buildMealCard(
                              context: context,
                              type: mealType,
                              rawType: rawType,
                              desc: notes,
                              kcal: calories,
                              icon: mealIcon,
                              loggedAt: loggedAt,
                              isExpanded: isExpanded,
                              onTap: () {
                                setState(() {
                                  if (_expandedMealIndices.contains(index)) {
                                    _expandedMealIndices.remove(index);
                                  } else {
                                    _expandedMealIndices.add(index);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 32),

                      // Section F: Hydration Tracker
                      Text(
                        _t('hydration'),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(20)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BCD4).withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.water_drop, color: Color(0xFF00BCD4)),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _t('mlLogged'),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          _t('goalText'),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${(waterRatio * 100).toInt()}%',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00BCD4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle, color: Color(0xFF00BCD4), size: 28),
                                      onPressed: _showHydrationSelector,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: waterRatio,
                                minHeight: 8,
                                backgroundColor: const Color(0xFF262626),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Section G: Scan Meal Button
                      ScaleTransition(
                        scale: _fabAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: isRamadan
                                ? const LinearGradient(
                                    colors: [Color(0xFF00D2FF), Color(0xFFFFD166)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isRamadan
                                    ? const Color(0xFF00D2FF).withAlpha(50)
                                    : const Color(0xFF00E676).withAlpha(50),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                MainNavigationScreen.of(context).currentIndex = 1;
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.restaurant, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(_t('scanMeal'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_needsOnboarding && FamilyViewModel.instance.activeMember == null)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Center(
                        child: _buildOnboardingOverlayPopup(theme),
                      ),
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

  Widget _buildMacroPill(BuildContext context, String label, String value, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22).withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required BuildContext context,
    required String type,
    required String rawType,
    required String desc,
    required String kcal,
    required IconData icon,
    required dynamic loggedAt,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    // Format timestamp to 12-hour local time (e.g. 10:00 AM)
    String timeStr = '';
    if (loggedAt != null) {
      try {
        final dt = DateTime.parse(loggedAt.toString()).toLocal();
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        timeStr = '$hour:$minute $period';
      } catch (_) {
        timeStr = '';
      }
    }

    // Localized category name
    String categoryName;
    switch (rawType.toLowerCase()) {
      case 'breakfast':
        categoryName = _language == 'ur' ? 'ناشتہ' : 'Breakfast';
        break;
      case 'lunch':
        categoryName = _language == 'ur' ? 'دوپہر کا کھانا' : 'Lunch';
        break;
      case 'dinner':
        categoryName = _language == 'ur' ? 'رات کا کھانا' : 'Dinner';
        break;
      case 'snack':
      case 'snacks':
        categoryName = _language == 'ur' ? 'اسنیک' : 'Snack';
        break;
      case 'suhoor':
      case 'sehri':
        categoryName = _language == 'ur' ? 'سحری' : 'Suhoor';
        break;
      case 'iftar':
      case 'aftari':
        categoryName = _language == 'ur' ? 'افطاری' : 'Iftar';
        break;
      default:
        categoryName = rawType.isNotEmpty ? (rawType[0].toUpperCase() + rawType.substring(1)) : 'Meal';
    }

    final detailText = timeStr.isNotEmpty
        ? (_language == 'ur' ? '$timeStr پر $categoryName شامل کیا گیا' : '$categoryName added at $timeStr')
        : (_language == 'ur' ? '$categoryName شامل کیا گیا' : '$categoryName logged today');

    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isExpanded ? primaryColor.withAlpha(18) : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? primaryColor.withAlpha(80) : Colors.white.withAlpha(25),
            width: isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: primaryColor.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: primaryColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            kcal,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1218),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  detailText,
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows an amber banner when there are unsynced offline logs.
  Widget _buildSyncBadge(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          SyncService.instance.syncPending(user.id).then((_) => _loadData());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade700.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(Icons.sync, color: Colors.amber.shade400, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_pendingSyncCount item(s) saved offline — tap to sync now',
                style: TextStyle(color: Colors.amber.shade300, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Activity card showing Health Connect / Google Fit stats.
  Widget _buildActivityCard(ThemeData theme) {
    final netCalories = _consumedCalories - _activity.activeKcal;
    final seeMore = _language == 'ur' ? 'مزید دیکھیں' : 'See More';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthSyncView()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_run, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  _language == 'ur' ? 'آج کی سرگرمی' : 'Today\'s Activity',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Net calories chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: netCalories > 0 ? Colors.orange.withAlpha(30) : Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Net: ${netCalories > 0 ? '+' : ''}$netCalories kcal',
                    style: TextStyle(
                      color: netCalories > 0 ? Colors.orange.shade300 : Colors.green.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActivityStat(Icons.directions_walk, '${_activity.steps}', _language == 'ur' ? 'قدم' : 'Steps', Colors.blue.shade300),
                _buildActivityStat(Icons.local_fire_department, '${_activity.activeKcal}', _language == 'ur' ? 'جلائے' : 'Burned', Colors.orange.shade300),
                _buildActivityStat(Icons.favorite, _activity.heartRateBpm > 0 ? '${_activity.heartRateBpm}' : '--', _language == 'ur' ? 'دھڑکن' : 'BPM', Colors.red.shade300),
                _buildActivityStat(Icons.bedtime, '${_activity.sleepHours}h', _language == 'ur' ? 'نیند' : 'Sleep', Colors.purple.shade300),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(seeMore, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, color: theme.colorScheme.primary, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Ramadan Fasting & Timings Card for Sehri and Iftar
  Widget _buildRamadanScheduleCard(ThemeData theme, bool isRamadan) {
    final ramadan = RamadanController.instance;
    final isFasting = ramadan.isCurrentlyFasting();
    final progress = ramadan.getFastingProgress();
    final statusMsg = ramadan.getFastingStatusMessage(_language);
    final suhoorFormatted = ramadan.formatTime(ramadan.suhoorTime);
    final iftarFormatted = ramadan.formatTime(ramadan.iftarTime);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF132448).withAlpha(190),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD166).withAlpha(70), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD166).withAlpha(15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    _language == 'ur' ? 'رمضان فاسٹنگ شیڈول' : 'Ramadan Fasting Tracker',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFD166),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD166).withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD166).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 12, color: Color(0xFFFFD166)),
                          const SizedBox(width: 4),
                          Text(
                            _language == 'ur' ? 'اوقات' : 'Timings',
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sehri & Iftar Time Badges
              Row(
                children: [
                  // Sehri Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2FF).withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00D2FF).withAlpha(60)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wb_twilight, color: Color(0xFF00D2FF), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _language == 'ur' ? 'سحری ختم' : 'Sehri Ends',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            suhoorFormatted,
                            style: const TextStyle(
                              color: Color(0xFF00D2FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Iftar Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD166).withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD166).withAlpha(60)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD166), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _language == 'ur' ? 'افطار کا وقت' : 'Iftar Time',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iftarFormatted,
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Status Countdown & Progress Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusMsg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: isFasting ? progress : 1.0,
                        minHeight: 6,
                        backgroundColor: Colors.white.withAlpha(20),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFasting ? const Color(0xFFFFD166) : const Color(0xFF00E676),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ramadan Hydration Quick Presets
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    _language == 'ur' ? 'فوری پانی لاگ:' : 'Fast Hydration Log:',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildQuickWaterChip('500ml', 500, _language == 'ur' ? 'افطار' : 'Iftar'),
                      _buildQuickWaterChip('250ml', 250, _language == 'ur' ? 'تراویح' : 'Taraweeh'),
                      _buildQuickWaterChip('500ml', 500, _language == 'ur' ? 'سحری' : 'Sehri'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickWaterChip(String amount, int ml, String label) {
    return GestureDetector(
      onTap: () {
        _logWater(ml);
        CustomToast.show(context, '+$amount ($label) logged!', isError: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00BCD4).withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00BCD4).withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop, color: Color(0xFF00BCD4), size: 12),
            const SizedBox(width: 3),
            Text(
              '+$amount',
              style: const TextStyle(
                color: Color(0xFF00BCD4),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyProfileBar(ThemeData theme, bool isRamadan) {
    return ListenableBuilder(
      listenable: FamilyViewModel.instance,
      builder: (context, _) {
        final familyVM = FamilyViewModel.instance;
        final members = familyVM.members;
        final active = familyVM.activeMember;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Primary User "Me" Chip
                  GestureDetector(
                    onTap: () {
                      familyVM.setActiveMember(null);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: active == null
                            ? (isRamadan ? const Color(0xFFFFD166).withAlpha(40) : const Color(0xFF00E676).withAlpha(40))
                            : const Color(0xFF161A22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active == null
                              ? (isRamadan ? const Color(0xFFFFD166) : const Color(0xFF00E676))
                              : Colors.white12,
                          width: active == null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🧑', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            _language == 'ur' ? 'میں' : 'Me',
                            style: TextStyle(
                              color: active == null ? Colors.white : Colors.white60,
                              fontWeight: active == null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Family Dependent Chips
                  ...members.map((m) {
                    final isSelected = active?.id == m.id;
                    return GestureDetector(
                      onTap: () {
                        familyVM.setActiveMember(m);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? m.color.withAlpha(40) : const Color(0xFF161A22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? m.color : Colors.white12,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.relationshipEmoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Add / Manage Family Button
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FamilyView()),
                      );
                      _loadData();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(
                            _language == 'ur' ? 'خاندان' : 'Family',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active Dependent Banner when a family member is selected
            if (active != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active.color.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: active.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _language == 'ur'
                            ? '${active.name} (${active.getLocalizedRelationship(_language)}) • روزانہ کا ہدف: ${active.dailyCalorieTarget} kcal'
                            : 'Tracking for ${active.name} (${active.getLocalizedRelationship(_language)}) • Goal: ${active.dailyCalorieTarget} kcal',
                        style: TextStyle(color: active.color, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActivityStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }
}


class CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color gradientStart;
  final Color gradientEnd;

  CalorieRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
      final activePaint = Paint()
        ..shader = SweepGradient(
          colors: [gradientStart, gradientEnd, gradientStart],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-3.14159 / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class BouncingArrow extends StatefulWidget {
  const BouncingArrow({super.key});

  @override
  State<BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<BouncingArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_controller.value * 10, 0),
          child: child,
        );
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, color: Colors.white, size: 20),
          SizedBox(width: 4),
          Text('Start Here!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
