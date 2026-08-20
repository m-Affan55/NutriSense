import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_client.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'macro_trend_chart.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  bool _isLoading = true;
  String _language = 'en';

  String _summary = '';
  int _healthScore = 0;
  int _daysAdhered = 0;

  int _targetCalories = 2000;
  int _targetProtein = 150;
  int _targetCarbs = 250;
  int _targetFat = 70;
  List<Map<String, dynamic>> _mealLogs = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString('language') ?? 'en';

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch weekly report from AI backend
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/weekly-report?user_id=${user.id}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _summary = data['weekly_summary'] ?? '';
        _healthScore = (data['health_score'] as num?)?.toInt() ?? 0;
        _daysAdhered = (data['days_adhered'] as num?)?.toInt() ?? 0;
      } else {
        throw Exception('Server error: ${response.body}');
      }

      // 2. Fetch target metrics
      final profileRes = await supabase
          .from('health_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _targetCalories = profileRes['daily_calorie_target'] ?? 2000;
        _targetProtein = profileRes['daily_protein_g'] ?? 150;
        _targetCarbs = profileRes['daily_carbs_g'] ?? 250;
        _targetFat = profileRes['daily_fat_g'] ?? 70;
      }

      // 3. Fetch past 7 days of meal logs for the trend chart
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7)).toIso8601String();
      final mealsResponse = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', user.id)
          .gte('logged_at', sevenDaysAgo)
          .order('logged_at', ascending: true);

      _mealLogs = List<Map<String, dynamic>>.from(mealsResponse);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to fetch weekly report: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _language == 'ur' ? 'اے آئی ہفتہ وار رپورٹ' : 'AI Weekly Report';
    final headerTitle = _language == 'ur' ? 'ہفتہ وار رپورٹ کے تجزیات' : 'Weekly Summary Insights';
    final historyTitle = _language == 'ur' ? 'سابقہ ہسٹری' : 'History';
    
    final scoreLabel = _language == 'ur' ? 'ہیلتھ سکور' : 'Health Score';
    final adherenceLabel = _language == 'ur' ? 'اہداف کی تعمیل' : 'Goals Adherence';
    final daysText = _language == 'ur' ? '$_daysAdhered میں سے 7 دن' : '$_daysAdhered out of 7 days';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: theme.colorScheme.primary.withAlpha(15),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(scoreLabel, style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$_healthScore%',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: const Color(0xFF161A22),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(adherenceLabel, style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                    daysText,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MacroTrendChart(
                      mealLogs: _mealLogs,
                      dailyCalorieTarget: _targetCalories,
                      dailyProteinTarget: _targetProtein,
                      dailyCarbsTarget: _targetCarbs,
                      dailyFatTarget: _targetFat,
                      language: _language,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFF161A22),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withAlpha(10)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  headerTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _summary.isEmpty
                                  ? (_language == 'ur'
                                      ? 'رپورٹ تیار کرنے کے لیے براہ کرم کھانا لاگ کرنا جاری رکھیں۔'
                                      : 'No insights available. Keep logging meals to construct a report.')
                                  : _summary,
                              style: TextStyle(
                                fontSize: 14, 
                                height: 1.6, 
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // History Section
                    Text(
                      historyTitle,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildReportHistoryItem(
                      context, 
                      _language == 'ur' ? 'پچھلا ہفتہ' : 'Previous Week', 
                      _language == 'ur' ? 'سکور: 85٪' : 'Score: 85%',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportHistoryItem(BuildContext context, String week, String score) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: theme.colorScheme.onSurface.withAlpha(150)),
        title: Text(week, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(score),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          CustomToast.show(context, _language == 'ur' ? 'تاریخ کا ریکارڈ دستیاب نہیں ہے' : 'Archived logs unavailable', isError: false);
        },
      ),
    );
  }
}
