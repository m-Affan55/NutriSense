import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../dashboard/dashboard_screen.dart' show CalorieRingPainter;
import '../../../core/swap_service.dart';
import '../../../core/meal_sync_notifier.dart';
import '../../../core/language_controller.dart';

class CoachingScreen extends StatefulWidget {
  const CoachingScreen({super.key});

  @override
  State<CoachingScreen> createState() => CoachingScreenState();
}

class CoachingScreenState extends State<CoachingScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  bool _isLoading = true;
  int _habitScore = 0;
  List<double> _trend = [];
  String _coachingMessage = '';
  List<dynamic> _foodSwaps = [];
  String _language = 'en';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    
    MealSyncNotifier.instance.addListener(loadCoachingData);
    LanguageController.instance.addListener(loadCoachingData);
    loadCoachingData();
  }

  @override
  void dispose() {
    MealSyncNotifier.instance.removeListener(loadCoachingData);
    LanguageController.instance.removeListener(loadCoachingData);
    _ringController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadCoachingData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _language = LanguageController.instance.currentLanguage;
      if (mounted) {
        setState(() {});
      }

      // 1. Fetch Habit Score & Summary
      try {
        final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
        final scoreRes = await http.get(
          Uri.parse('${ApiClient.getBaseUrl()}/coaching/habit-score/${user.id}?offset_minutes=$offsetMinutes&language=$_language'),
          headers: ApiClient.getHeaders(),
        ).timeout(const Duration(seconds: 20));
        
        if (scoreRes.statusCode == 200) {
          final data = jsonDecode(scoreRes.body);
          _habitScore = (data['score'] as num?)?.toInt() ?? 0;
          if (data['trend'] is List) {
            _trend = (data['trend'] as List)
                .map((e) => (e is num) ? e.toDouble() : -1.0)
                .toList();
          }
          _coachingMessage = data['coaching_message']?.toString() ?? '';
        }
      } catch (scoreErr) {
        debugPrint('Habit score fetch error: $scoreErr');
      }

      // 2. Fetch Recent Meals for Food Swaps
      try {
        final today = DateTime.now();
        final sevenDaysAgo = today.subtract(const Duration(days: 7)).toIso8601String();
        
        final mealsRes = await Supabase.instance.client
            .from('meal_logs')
            .select('notes')
            .eq('user_id', user.id)
            .gte('logged_at', sevenDaysAgo)
            .order('logged_at', ascending: false)
            .limit(10);
            
        final recentMealNotes = (mealsRes as List)
            .map((m) => m['notes']?.toString() ?? '')
            .where((n) => n.trim().isNotEmpty && n != 'null')
            .toList();
        
        if (recentMealNotes.isNotEmpty) {
          final swapRes = await http.post(
            Uri.parse('${ApiClient.getBaseUrl()}/coaching/food-swaps'),
            headers: ApiClient.getHeaders(),
            body: jsonEncode({
              'user_id': user.id,
              'recent_meals': recentMealNotes,
              'language': _language,
            }),
          ).timeout(const Duration(seconds: 20));
          
          if (swapRes.statusCode == 200) {
            final data = jsonDecode(swapRes.body);
            _foodSwaps = data['swaps'] ?? [];
          }
        }
      } catch (swapErr) {
        debugPrint('Food swaps fetch error: $swapErr');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _ringController.forward();
        
        // Auto-scroll if navigated from Swap alert
        if (SwapService.highlightNotifier.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('General error in loadCoachingData: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'AI Coaching',
        'consistency': '7-Day Consistency',
        'swaps': 'Recommended Swaps',
        'noSwapsTitle': 'No food swaps needed yet',
        'noSwapsBody': 'Log your recent meals to receive personalized, healthier alternative swaps tailored to your health goals.',
        'insteadOf': 'Instead of',
        'trySwap': 'Try',
        'excellent': 'Excellent',
        'onTrack': 'On Track',
        'needsWork': 'Needs Work',
        'loading': 'Loading...',
        'defaultGoodMsg': 'Great progress! Your daily intake consistency is building strong nutritional momentum. Keep logging your meals to optimize your habit score.',
        'defaultNeedMsg': 'Consistency is key to reaching your dietary targets. Continue logging your breakfast, lunch, and dinner to unlock personalized coaching insights!',
      },
      'ur': {
        'title': 'اے آئی کوچنگ',
        'consistency': '7 دن کا تسلسل',
        'swaps': 'تجویز کردہ متبادل کھانے',
        'noSwapsTitle': 'ابھی تک کسی متبادل کی ضرورت نہیں',
        'noSwapsBody': 'صحت کے اہداف کے مطابق متبادل تجویز حاصل کرنے کے لیے حالیہ کھانے لاگ کریں۔',
        'insteadOf': 'کے بجائے',
        'trySwap': 'استعمال کریں',
        'excellent': 'بہترین',
        'onTrack': 'بہتر ہے',
        'needsWork': 'توجہ درکار ہے',
        'loading': 'لوڈ ہو رہا ہے...',
        'defaultGoodMsg': 'بہت اچھا! روزانہ کھانے پینے کا ریکارڈ رکھنے سے آپ کا تسلسل بہتر ہو رہا ہے۔ اسکور کو مزید بڑھانے کے لیے لاگ کرتے رہیں۔',
        'defaultNeedMsg': 'طبی اہداف حاصل کرنے کے لیے مستقل مزاجی ضروری ہے۔ ذاتی مشورے حاصل کرنے کے لیے اپنے ناشتہ، دوپہر اور رات کا کھانا لاگ کریں۔',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade400;
    if (score >= 50) return Colors.amber.shade400;
    return Colors.red.shade400;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return _t('excellent');
    if (score >= 50) return _t('onTrack');
    return _t('needsWork');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _getScoreColor(_habitScore);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RamadanBackgroundWrapper(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadCoachingData,
                child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Habit Score Ring
                    Center(
                      child: SizedBox(
                        height: 200,
                        width: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ringAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(200, 200),
                                  painter: CalorieRingPainter(
                                    progress: (_habitScore / 100.0) * _ringAnimation.value,
                                    backgroundColor: const Color(0xFF262626),
                                    gradientStart: scoreColor,
                                    gradientEnd: scoreColor.withAlpha(200),
                                  ),
                                );
                              },
                            ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$_habitScore', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: scoreColor)),
                                  Text('/100', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: scoreColor.withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: scoreColor.withAlpha(50)),
                                    ),
                                    child: Text(_getScoreLabel(_habitScore), style: theme.textTheme.labelMedium?.copyWith(color: scoreColor, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // AI Coaching Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _coachingMessage.isNotEmpty
                                  ? _coachingMessage
                                  : (_habitScore >= 50
                                      ? _t('defaultGoodMsg')
                                      : _t('defaultNeedMsg')),
                              style: const TextStyle(height: 1.5, color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Trend Chart
                    Text(_t('consistency'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        size: const Size(double.infinity, 140),
                        painter: _ConsistencyChartPainter(
                          trend: _trend,
                          accent: theme.colorScheme.primary,
                          language: _language,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Food Swaps
                    Text(_t('swaps'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_foodSwaps.isNotEmpty) ...[
                      ValueListenableBuilder<bool>(
                        valueListenable: SwapService.highlightNotifier,
                        builder: (context, isHighlighted, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _foodSwaps.map((swap) => _buildSwapCard(swap, theme, isHighlighted)).toList(),
                          );
                        }
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t('noSwapsTitle'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _t('noSwapsBody'),
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSwapCard(Map<String, dynamic> swap, ThemeData theme, bool isHighlighted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF00E676) : Colors.white10,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: isHighlighted ? [
          BoxShadow(
            color: const Color(0xFF00E676).withAlpha(60),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_t('insteadOf')} ${swap['original_food']}',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.arrow_downward, color: Colors.grey, size: 16),
          ),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_t('trySwap')} ${swap['healthy_swap']}',
                  style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            swap['reason'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyChartPainter extends CustomPainter {
  final List<double> trend;
  final Color accent;
  final String language;

  _ConsistencyChartPainter({
    required this.trend,
    required this.accent,
    required this.language,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    // Find the max value to place the dashed line at the highest bar
    double maxVal = trend.map((v) => v < 0 ? 0.0 : v).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1.0; 

    // Add 10% padding above the highest bar
    final maxDrawVal = maxVal * 1.1; 
    
    final barWidth = size.width / (trend.length * 2 + 1);
    final chartHeight = size.height - 24; // Leave room for labels

    // Dashed line at the height of the max value
    final goalY = chartHeight - (maxVal / maxDrawVal * chartHeight);
    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, goalY), Offset(x + 5, goalY), dashPaint);
    }

    final dayLabels = language == 'ur'
        ? ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < trend.length; i++) {
      final val = trend[i] < 0 ? 0.0 : trend[i];
      final barHeight = (val / maxDrawVal * chartHeight).clamp(4.0, chartHeight);
      final x = barWidth + i * barWidth * 2;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );

      final daysAgo = (trend.length - 1) - i;
      final isToday = daysAgo == 0;
      final d = DateTime.now().subtract(Duration(days: daysAgo));
      final label = dayLabels[d.weekday - 1];

      final barGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: isToday
            ? [accent.withAlpha(120), accent]
            : [Colors.blueAccent.withAlpha(100), Colors.blueAccent],
      );

      final barPaint = Paint()..shader = barGradient.createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      // Label below bar
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isToday ? Colors.white : Colors.white.withAlpha(150), 
            fontSize: 10,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _ConsistencyChartPainter old) => true;
}
