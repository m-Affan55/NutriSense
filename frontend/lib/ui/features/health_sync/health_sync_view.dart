import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/health_service.dart';
import '../../../core/ramadan_controller.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../../../core/language_controller.dart';
import 'health_sync_viewmodel.dart';

class HealthSyncView extends StatefulWidget {
  const HealthSyncView({super.key});

  @override
  State<HealthSyncView> createState() => _HealthSyncViewState();
}

class _HealthSyncViewState extends State<HealthSyncView> with TickerProviderStateMixin, WidgetsBindingObserver {
  final HealthSyncViewModel _vm = HealthSyncViewModel();
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    _vm.addListener(_onVmChanged);
    LanguageController.instance.addListener(_loadLanguage);
    _loadLanguage();
    _vm.loadAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _vm.loadAll();
    }
  }

  void _onVmChanged() {
    if (mounted) {
      setState(() {});
      if (!_vm.isLoading) {
        _ringController.reset();
        _ringController.forward();
      }
    }
  }

  void _loadLanguage() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LanguageController.instance.removeListener(_loadLanguage);
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _ringController.dispose();
    super.dispose();
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'Health Sync',
        'subtitle': 'Activity, sleep & vitals tracking',
        'connected': 'Sync Active',
        'syncSource': 'Source',
        'steps': 'Steps',
        'burned': 'Burned',
        'sleep': 'Sleep',
        'heartRate': 'Heart Rate',
        'bpm': 'BPM',
        'weeklySteps': '7-Day Activity Trends',
        'goal': 'Goal',
        'avg': 'Avg',
        'insight': 'Coach Insight',
        'stepGoal': 'Daily Step Goal',
        'quickLog': 'Log / Adjust Activity',
        'save': 'Save',
        'cancel': 'Cancel',
        'today': 'Today',
        'totalBurned': 'Total Burned',
        'avgSleep': 'Avg Sleep',
        'quickAddTitle': 'Update Today\'s Health Stats',
        'stepsHint': 'Steps (e.g. 7500)',
        'caloriesHint': 'Burned Calories (e.g. 450 kcal)',
        'sleepHint': 'Sleep Hours (e.g. 7.5 hrs)',
        'hrHint': 'Heart Rate (e.g. 72 bpm)',
        'logSuccess': 'Activity updated successfully!',
        'syncNow': 'Sync Health Connect',
        'syncSuccess': 'Health data synced successfully!',
        'syncing': 'Connecting & syncing...',
        'syncDenied': 'Health permissions were not granted.',
        'hcMissingTitle': 'Google Health Connect',
        'hcMissingBody': 'Google Health Connect is not enabled on this device. Install or enable it to automatically sync your steps and activity.',
        'installNow': 'Open Play Store',
        'appleHealthTitle': 'Apple Health Required',
        'appleHealthBody': 'Please grant Apple Health permissions in your iPhone Settings.',
      },
      'ur': {
        'title': 'ہیلتھ سنک',
        'subtitle': 'سرگرمی، نیند اور دل کی دھڑکن',
        'connected': 'سنک فعال ہے',
        'syncSource': 'ذریعہ',
        'steps': 'قدم',
        'burned': 'کیلوریز',
        'sleep': 'نیند',
        'heartRate': 'دل کی دھڑکن',
        'bpm': 'بی پی ایم',
        'weeklySteps': '7 روزہ سرگرمی کا رجحان',
        'goal': 'ہدف',
        'avg': 'اوسط',
        'insight': 'کوچ کی بصیرت',
        'stepGoal': 'روزانہ قدموں کا ہدف',
        'quickLog': 'سرگرمی لاگ کریں',
        'save': 'محفوظ کریں',
        'cancel': 'منسوخ',
        'today': 'آج',
        'totalBurned': 'کل جلائی گئیں',
        'avgSleep': 'اوسط نیند',
        'quickAddTitle': 'آج کے ہیلتھ اعداد و شمار درج کریں',
        'stepsHint': 'قدم (مثلاً 7500)',
        'caloriesHint': 'جلائی گئی کیلوریز (مثلاً 450)',
        'sleepHint': 'نیند کے گھنٹے (مثلاً 7.5)',
        'hrHint': 'دل کی دھڑکن (مثلاً 72)',
        'logSuccess': 'سرگرمی کامیابی سے محفوظ ہوگئی!',
        'syncNow': 'گوگل ہیلتھ سنک کریں',
        'syncSuccess': 'ہیلتھ ڈیٹا کامیابی سے سنک ہوگیا!',
        'syncing': 'کنیکٹ اور سنک کیا جا رہا ہے...',
        'syncDenied': 'ہیلتھ کی اجازت نہیں دی گئی۔',
        'hcMissingTitle': 'گوگل ہیلتھ کنیکٹ',
        'hcMissingBody': 'اس ڈیوائس پر گوگل ہیلتھ کنیکٹ فعال نہیں ہے۔ خودکار قدموں کی ٹریکنگ کے لیے اسے انسٹال یا فعال کریں۔',
        'installNow': 'پلے اسٹور کھولیں',
        'appleHealthTitle': 'ایپل ہیلتھ درکار ہے',
        'appleHealthBody': 'براہ کرم آئی فون کی ترتیبات میں ایپل ہیلتھ کی اجازت دیں۔',
      },
    };
    return translations[_language]?[key] ?? key;
  }

  Future<void> _handleManualSync() async {
    CustomToast.show(context, _t('syncing'), isError: false);
    final granted = await _vm.requestConnection();
    if (!mounted) return;
    if (granted) {
      CustomToast.show(context, _t('syncSuccess'), isError: false);
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _showInstallPrompt(
          _t('hcMissingTitle'),
          _t('hcMissingBody'),
          'market://details?id=com.google.android.apps.healthdata',
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        _showInstallPrompt(
          _t('appleHealthTitle'),
          _t('appleHealthBody'),
          null,
        );
      } else {
        CustomToast.show(context, _t('syncDenied'), isError: true);
      }
    }
  }

  void _showInstallPrompt(String title, String message, String? storeUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
        ),
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          if (storeUrl != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
                  if (await canLaunchUrl(webUri)) {
                    await launchUrl(webUri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: Text(_t('installNow'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        final isRamadan = RamadanController.instance.isRamadanMode;
        final theme = Theme.of(context);
        final accentColor = isRamadan ? const Color(0xFFFFD166) : const Color(0xFF00E676);
        final secondaryColor = isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF448AFF);

        return Scaffold(
          body: RamadanBackgroundWrapper(
            child: SafeArea(
              child: _vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _vm.loadAll,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Header with back button, step goal settings, and status badge
                            _buildHeader(theme, accentColor, isRamadan),
                            const SizedBox(height: 20),

                            // 2. Animated Circular Step Ring
                            _buildStepRing(theme, accentColor, secondaryColor),
                            const SizedBox(height: 24),

                            // 3. Four Live Stat Cards (Steps, Active Burn, Heart Rate, Sleep)
                            _buildLiveStatsGrid(theme, isRamadan),
                            const SizedBox(height: 24),

                            // 4. Quick Action Button (Log / Adjust on any device: Android, Windows, Browser)
                            _buildQuickActionButton(theme, accentColor),
                            const SizedBox(height: 24),

                            // 5. 7-Day Activity Trends Bar Chart
                            _buildWeeklyChart(theme, accentColor, isRamadan),
                            const SizedBox(height: 24),

                            // 6. AI Health Coach Insight Card
                            _buildInsightCard(theme, accentColor),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── HEADER ───────────────────────────
  Widget _buildHeader(ThemeData theme, Color accent, bool isRamadan) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: Colors.white70,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _t('title'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _handleManualSync,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _vm.todayActivity.source.isNotEmpty
                                ? _vm.todayActivity.source
                                : _t('connected'),
                            style: TextStyle(
                              color: accent,
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
              const SizedBox(height: 2),
              Text(
                _t('subtitle'),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: Colors.white70),
          tooltip: _t('syncNow'),
          onPressed: _handleManualSync,
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white70),
          tooltip: _t('stepGoal'),
          onPressed: _showStepGoalDialog,
        ),
      ],
    );
  }

  // ─────────────────────── STEP RING ──────────────────────────────
  Widget _buildStepRing(ThemeData theme, Color accent, Color secondary) {
    final progress = _vm.stepProgress.clamp(0.0, 1.5);
    final displayProgress = progress.clamp(0.0, 1.0);
    final isRamadan = RamadanController.instance.isRamadanMode;

    return Center(
      child: SizedBox(
        height: 220,
        width: 220,
        child: AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(220, 220),
              painter: _StepRingPainter(
                progress: displayProgress * _ringAnimation.value,
                accent: accent,
                secondary: secondary,
                isRamadan: isRamadan,
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, color: accent, size: 28),
                const SizedBox(height: 4),
                Text(
                  '${_vm.todayActivity.steps}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _t('steps'),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_t('goal')}: ${_vm.stepGoal}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  // ──────────────────── LIVE STATS GRID ────────────────────────────
  Widget _buildLiveStatsGrid(ThemeData theme, bool isRamadan) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            Icons.directions_walk,
            '${_vm.todayActivity.steps}',
            _t('steps'),
            isRamadan ? const Color(0xFF00D2FF) : Colors.blue.shade300,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            Icons.local_fire_department,
            '${_vm.todayActivity.activeKcal} kcal',
            _t('burned'),
            Colors.orange.shade300,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            Icons.favorite,
            _vm.todayActivity.heartRateBpm > 0 ? '${_vm.todayActivity.heartRateBpm}' : '--',
            _t('bpm'),
            Colors.red.shade300,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            Icons.bedtime,
            '${_vm.todayActivity.sleepHours}h',
            _t('sleep'),
            Colors.purple.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22).withAlpha(170),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50), width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── QUICK LOG ACTION BUTTON ────────────────────────
  Widget _buildQuickActionButton(ThemeData theme, Color accent) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showQuickLogDialog,
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: Text(
          _t('quickLog'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
    );
  }

  // ──────────────────── WEEKLY STEP CHART ─────────────────────────
  Widget _buildWeeklyChart(ThemeData theme, Color accent, bool isRamadan) {
    final weekdays = _language == 'ur'
        ? ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _glassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                _t('weeklySteps'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withAlpha(60)),
                ),
                child: Text(
                  '${_t('avg')}: ${_vm.weeklyAverageSteps}',
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_t('totalBurned')}: ${_vm.weeklyTotalBurned} kcal',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '${_t('avgSleep')}: ${_vm.weeklyAverageSleep}h',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _WeeklyBarChartPainter(
                data: _vm.weeklyHistory,
                goal: _vm.stepGoal,
                accent: accent,
                labels: weekdays,
                isRamadan: isRamadan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────── INSIGHT CARD ────────────────────────────
  Widget _buildInsightCard(ThemeData theme, Color accent) {
    return _glassmorphicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withAlpha(80)),
            ),
            child: Icon(Icons.auto_awesome, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('insight'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _vm.getInsight(_language),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────── GLASSMORPHIC CARD ───────────────────────
  Widget _glassmorphicCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22).withAlpha(170),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: child,
        ),
      ),
    );
  }

  // ──────────────────── QUICK LOG MODAL ───────────────────────────
  void _showQuickLogDialog() {
    final stepsController = TextEditingController(text: '${_vm.todayActivity.steps}');
    final calController = TextEditingController(text: '${_vm.todayActivity.activeKcal}');
    final sleepController = TextEditingController(text: '${_vm.todayActivity.sleepHours}');
    final hrController = TextEditingController(
      text: _vm.todayActivity.heartRateBpm > 0 ? '${_vm.todayActivity.heartRateBpm}' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, color: Color(0xFF00E676), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t('quickAddTitle'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: stepsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _t('stepsHint'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.directions_walk, color: Colors.blueAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: calController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _t('caloriesHint'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sleepController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _t('sleepHint'),
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.bedtime, color: Colors.purpleAccent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: hrController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _t('hrHint'),
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.favorite, color: Colors.redAccent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_t('cancel'), style: const TextStyle(color: Colors.white60)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final steps = int.tryParse(stepsController.text);
                            final kcal = int.tryParse(calController.text);
                            final sleep = double.tryParse(sleepController.text);
                            final hr = int.tryParse(hrController.text);

                            await _vm.updateTodayActivity(
                              steps: steps,
                              activeKcal: kcal,
                              sleepHours: sleep,
                              heartRateBpm: hr,
                            );

                            if (!mounted || !sheetCtx.mounted) return;
                            Navigator.pop(sheetCtx);
                            CustomToast.show(context, _t('logSuccess'), isError: false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
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
  }

  // ──────────────────── STEP GOAL DIALOG ──────────────────────────
  void _showStepGoalDialog() {
    final controller = TextEditingController(text: '${_vm.stepGoal}');
    final isRamadan = RamadanController.instance.isRamadanMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('stepGoal'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '10000',
            hintStyle: const TextStyle(color: Colors.white30),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                _vm.updateStepGoal(val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isRamadan ? const Color(0xFFFFD166) : const Color(0xFF00E676),
              foregroundColor: const Color(0xFF0B101B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _t('save'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0B101B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════

/// Circular step ring with dynamic gradient arc, glow, and background track.
class _StepRingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color secondary;
  final bool isRamadan;

  _StepRingPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
    required this.isRamadan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 14.0;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Foreground arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [secondary, accent],
        stops: const [0.0, 1.0],
      );
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);

      // Glow dot at end
      final dotAngle = -pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final glowPaint = Paint()
        ..color = accent.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(dotCenter, 9, glowPaint);
      canvas.drawCircle(dotCenter, 5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _StepRingPainter old) =>
      old.progress != progress || old.accent != accent || old.isRamadan != isRamadan;
}

/// 7-Day Activity Trend Bar Chart with goal line overlay and weekday labels.
class _WeeklyBarChartPainter extends CustomPainter {
  final List<DailyActivity> data;
  final int goal;
  final Color accent;
  final List<String> labels;
  final bool isRamadan;

  _WeeklyBarChartPainter({
    required this.data,
    required this.goal,
    required this.accent,
    required this.labels,
    required this.isRamadan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxSteps = [goal, ...data.map((d) => d.steps)].reduce(max) * 1.15;
    final barWidth = size.width / (data.length * 2 + 1);
    final chartHeight = size.height - 24;

    // Goal dashed line
    if (maxSteps > 0) {
      final goalY = chartHeight - (goal / maxSteps * chartHeight);
      final dashPaint = Paint()
        ..color = Colors.white.withAlpha(50)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, goalY), Offset(x + 5, goalY), dashPaint);
      }
    }

    for (int i = 0; i < data.length; i++) {
      final barHeight = maxSteps > 0
          ? (data[i].steps / maxSteps * chartHeight).clamp(4.0, chartHeight)
          : 4.0;
      final x = barWidth + i * barWidth * 2;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );

      final isGoalHit = data[i].steps >= goal;
      final barGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: isGoalHit
            ? [accent.withAlpha(120), accent]
            : [
                (isRamadan ? const Color(0xFF00D2FF) : Colors.blueAccent).withAlpha(100),
                (isRamadan ? const Color(0xFF00D2FF) : Colors.blueAccent),
              ],
      );

      final barPaint = Paint()..shader = barGradient.createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      // Day label below
      final labelIndex = (data[i].date.weekday - 1).clamp(0, labels.length - 1);
      final label = labels[labelIndex];
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter old) => true;
}
