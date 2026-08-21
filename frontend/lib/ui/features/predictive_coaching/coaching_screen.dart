import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../dashboard/dashboard_screen.dart' show CalorieRingPainter;
import '../../../core/swap_service.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    
    loadCoachingData();
  }

  Future<void> loadCoachingData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Habit Score & Summary
      final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      final scoreRes = await http.get(
        Uri.parse('${ApiClient.getBaseUrl()}/coaching/habit-score/${user.id}?offset_minutes=$offsetMinutes'),
      );
      
      if (scoreRes.statusCode == 200) {
        final data = jsonDecode(scoreRes.body);
        _habitScore = data['score'] ?? 0;
        _trend = List<double>.from(data['trend'] ?? []);
        _coachingMessage = data['coaching_message'] ?? '';
      }

      // 2. Fetch Recent Meals for Food Swaps
      final today = DateTime.now();
      final sevenDaysAgo = today.subtract(const Duration(days: 7)).toIso8601String();
      
      final mealsRes = await Supabase.instance.client
          .from('meal_logs')
          .select('notes')
          .eq('user_id', user.id)
          .gte('logged_at', sevenDaysAgo)
          .order('logged_at', ascending: false)
          .limit(10);
          
      final recentMealNotes = mealsRes.map((m) => m['notes'].toString()).toList();
      
      if (recentMealNotes.isNotEmpty) {
        final swapRes = await http.post(
          Uri.parse('${ApiClient.getBaseUrl()}/coaching/food-swaps'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': user.id,
            'recent_meals': recentMealNotes,
          }),
        );
        
        if (swapRes.statusCode == 200) {
          final data = jsonDecode(swapRes.body);
          _foodSwaps = data['swaps'] ?? [];
        }
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
      debugPrint('Error loading coaching data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, 'Failed to load coaching data');
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade400;
    if (score >= 50) return Colors.amber.shade400;
    return Colors.red.shade400;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 50) return 'On Track';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _getScoreColor(_habitScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coaching'),
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
                              _coachingMessage,
                              style: const TextStyle(height: 1.5, color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Trend Chart
                    Text('7-Day Consistency', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        size: const Size(double.infinity, 140),
                        painter: _ConsistencyChartPainter(
                          trend: _trend,
                          accent: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Food Swaps
                    if (_foodSwaps.isNotEmpty) ...[
                      Text('Recommended Swaps', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: SwapService.highlightNotifier,
                        builder: (context, isHighlighted, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _foodSwaps.map((swap) => _buildSwapCard(swap, theme, isHighlighted)).toList(),
                          );
                        }
                      ),
                    ]
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
                'Instead of ${swap['original_food']}',
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
                  'Try ${swap['healthy_swap']}',
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

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }
}

class _ConsistencyChartPainter extends CustomPainter {
  final List<double> trend;
  final Color accent;

  _ConsistencyChartPainter({
    required this.trend,
    required this.accent,
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

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
