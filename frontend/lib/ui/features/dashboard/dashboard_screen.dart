import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/main_navigation_screen.dart';
import '../settings/settings_view.dart';
import '../meal_scan/manual_log_screen.dart';

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

    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString('language') ?? 'en';

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
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
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final mealsRes = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', user.id)
          .gte('logged_at', '${todayStr}T00:00:00')
          .lte('logged_at', '${todayStr}T23:59:59');

      int calSum = 0;
      int proteinSum = 0;
      int carbsSum = 0;
      int fatSum = 0;
      List<Map<String, dynamic>> tempMeals = [];

      for (var meal in mealsRes) {
        calSum += (meal['total_calories'] as num).toInt();
        proteinSum += (meal['total_protein_g'] as num).toInt();
        carbsSum += (meal['total_carbs_g'] as num).toInt();
        fatSum += (meal['total_fat_g'] as num).toInt();
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
          .gte('logged_at', '${todayStr}T00:00:00')
          .lte('logged_at', '${todayStr}T23:59:59');

      int waterSum = 0;
      for (var log in waterRes) {
        waterSum += (log['amount_ml'] as num).toInt();
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
      }
    }
  }

  Future<void> _logWater250ml() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('water_logs').insert({
        'user_id': user.id,
        'amount_ml': 250,
      });

      await _loadData();
    } catch (e) {
      debugPrint('Error logging water: $e');
    }
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

  String _t(String key) {
    final translations = {
      'en': {
        'greeting': 'Good Morning, $_userName 👋',
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
        'greeting': 'صبح بخیر، $_userName 👋',
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
    final double calorieRatio = _targetCalories > 0 
        ? (_consumedCalories / _targetCalories).clamp(0.0, 1.0)
        : 0.0;

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
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Section B: Calorie Ring progress
                      Center(
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
                                  Text('$_consumedCalories', style: theme.textTheme.headlineLarge),
                                  Text(
                                    '${_t('of')} $_targetCalories ${_t('kcal')}', 
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                      const SizedBox(height: 32),

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
                                  onPressed: _logWater250ml,
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
