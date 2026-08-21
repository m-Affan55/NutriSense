import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/main_navigation_screen.dart';
import '../settings/settings_view.dart';
import '../meal_scan/manual_log_screen.dart';
import '../../../core/offline_cache.dart';
import '../../../core/sync_service.dart';
import '../../../core/health_service.dart';
import '../../../shared/widgets/custom_toast.dart';

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
  bool _isLoading = true;
  String _language = 'en';

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

    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) return;

      // 1. Get name metadata
      final fullName = user.userMetadata?['full_name'] ?? 'User';
      _userName = fullName;

      // 2. Fetch targets
      final profileRes = await supabase
          .from('health_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _targetCalories = (profileRes['daily_calorie_target'] as num?)?.toInt() ?? 2000;
        _targetProtein = (profileRes['daily_protein_g'] as num?)?.toInt() ?? 130;
        _targetCarbs = (profileRes['daily_carbs_g'] as num?)?.toInt() ?? 220;
        _targetFat = (profileRes['daily_fat_g'] as num?)?.toInt() ?? 65;
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
        calSum += (meal['total_calories'] as num?)?.toInt() ?? 0;
        proteinSum += (meal['total_protein_g'] as num?)?.toInt() ?? 0;
        carbsSum += (meal['total_carbs_g'] as num?)?.toInt() ?? 0;
        fatSum += (meal['total_fat_g'] as num?)?.toInt() ?? 0;
        tempMeals.add({
          'notes': meal['notes'] ?? 'Meal Logged',
          'meal_type': meal['meal_type'] ?? 'breakfast',
          'total_calories': meal['total_calories'] ?? 0,
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

  void _showAddMealOptions() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final optionTitle = _language == 'ur' ? 'غذا شامل کریں' : 'Add Meal Options';
        final scanLabel = _language == 'ur' ? 'غذا اسکین کریں' : 'Scan Meal with AI';
        final manualLabel = _language == 'ur' ? 'خود غذا لاگ کریں' : 'Log Meal Manually';
        
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  optionTitle, 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF00E676)),
                  title: Text(scanLabel, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    MainNavigationScreen.of(context).currentIndex = 1;
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.blueAccent),
                  title: Text(manualLabel, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final reload = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const ManualLogScreen()),
                    );
                    if (reload == true) {
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final weekdaysUr = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
    final monthsUr = [
      'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
      'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
    ];

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
        'addMeal': 'Add Meal',
        'noMeals': 'No meals logged today. Use Scan Meal to log!',
        'hydration': 'Hydration',
        'mlLogged': '$_waterLogged ml logged',
        'goalText': 'Goal: $_waterGoal ml',
        'scanMeal': 'Scan Meal',
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
        'noMeals': 'آج کوئی غذا شامل نہیں کی گئی۔ لاگ کرنے کے لیے غذا اسکین کریں!',
        'hydration': 'پانی کا استعمال',
        'mlLogged': '$_waterLogged ملی لیٹر لاگ کیا گیا',
        'goalText': 'ہدف: $_waterGoal ملی لیٹر',
        'scanMeal': 'غذا اسکین کریں',
        'protein': 'پروٹین',
        'carbs': 'کاربس',
        'fat': 'چربی',
        'of': 'میں سے',
        'kcal': 'کیلوریز',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double waterRatio = (_waterLogged / _waterGoal).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
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
                      const SizedBox(height: 32),

                      // Offline sync badge (only shown when there are pending rows)
                      if (_pendingSyncCount > 0) _buildSyncBadge(theme),
                      if (_pendingSyncCount > 0) const SizedBox(height: 12),

                    // Section B: Calorie Ring progress
                    Builder(
                      builder: (context) {
                        int activeBurn = _activity.activeKcal.toInt();
                        int netCalories = _consumedCalories - activeBurn;
                        if (netCalories < 0) netCalories = 0;
                        double calorieRatio = _targetCalories > 0 ? (netCalories / _targetCalories) : 0.0;
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
                                        gradientEnd: const Color(0xFF00BCD4),
                                      ),
                                    );
                                  },
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$netCalories', style: theme.textTheme.headlineLarge),
                                    Text(
                                      '${_t('of')} $_targetCalories ${_t('kcal')}', 
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    if (activeBurn > 0)
                                      Text(
                                        '(-$activeBurn active)',
                                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMacroPill(context, _t('protein'), '${_consumedProtein}g / ${_targetProtein}g', Colors.redAccent),
                          _buildMacroPill(context, _t('carbs'), '${_consumedCarbs}g / ${_targetCarbs}g', Colors.blueAccent),
                          _buildMacroPill(context, _t('fat'), '${_consumedFat}g / ${_targetFat}g', Colors.amber),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Activity Card (Health Connect / Google Fit)
                      if (_activity != ActivityData.empty) ...[  
                        _buildActivityCard(theme),
                        const SizedBox(height: 24),
                      ],

                      // Section C: Today's Log
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t('todayMeals'), style: theme.textTheme.titleLarge),
                          TextButton.icon(
                            onPressed: _showAddMealOptions,
                            icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                            label: Text(_t('addMeal'), style: TextStyle(color: theme.colorScheme.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      _todayMeals.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text(
                                  _t('noMeals'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120), fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _todayMeals.length,
                              itemBuilder: (context, index) {
                                final meal = _todayMeals[index];
                                final mType = meal['meal_type'] as String;
                                IconData mIcon = Icons.restaurant;
                                if (mType == 'breakfast') mIcon = Icons.wb_twilight;
                                if (mType == 'lunch') mIcon = Icons.wb_sunny;
                                if (mType == 'dinner') mIcon = Icons.nights_stay;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildMealCard(
                                    context,
                                    mType.toUpperCase(),
                                    meal['notes'],
                                    '${meal['total_calories']} kcal',
                                    mIcon,
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),

                      // Section D: Hydration Card
                      Text(_t('hydration'), style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Container(
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0288D1).withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.water_drop, color: Color(0xFF26C6DA), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('mlLogged'),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _t('goalText'),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withAlpha(150),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(waterRatio * 100).toInt()}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF26C6DA),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Color(0xFF0288D1), size: 28),
                                  onPressed: _showHydrationSelector,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 10,
                                width: double.infinity,
                                color: Colors.white.withAlpha(15),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: waterRatio,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0288D1), Color(0xFF26C6DA)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Section E: Quick Log Button (Scan Meal)
                      ScaleTransition(
                        scale: _fabAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withAlpha(50),
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
                                    const Icon(Icons.camera_alt, color: Colors.white),
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
      ),
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

  Widget _buildMealCard(BuildContext context, String type, String desc, String kcal, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(desc, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              Text(kcal, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
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
    return Container(
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
                'Today\'s Activity',
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
              _buildActivityStat(Icons.directions_walk, '${_activity.steps}', 'Steps', Colors.blue.shade300),
              _buildActivityStat(Icons.local_fire_department, '${_activity.activeKcal}', 'Burned', Colors.orange.shade300),
              _buildActivityStat(Icons.bedtime, '${_activity.sleepHours}h', 'Sleep', Colors.purple.shade300),
            ],
          ),
        ],
      ),
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
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
