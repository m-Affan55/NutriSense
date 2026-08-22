import 'package:flutter/material.dart';
import '../navigation/main_navigation_screen.dart';
import '../../../core/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../shared/widgets/custom_toast.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../../core/health_service.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7;
  bool _isLoading = false;

  // Data
  String? _goal;
  String? _gender;
  double _age = 25;
  double _heightCm = 170;
  double _weightKg = 70;
  double _targetWeightKg = 65;
  String? _activityLevel;
  List<String> _healthConditions = [];
  String? _dietaryPreference;
  String? _budget;

  // Constants based on user prompt
  final List<String> _goals = [
    'Lose weight / Fat loss',
    'Gain muscle / Bulk',
    'Maintain weight & stay healthy',
    'Manage diabetes / blood sugar',
    'General wellness / Just eat better',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];

  final List<String> _activityLevels = [
    'Sedentary (mostly sitting)',
    'Lightly active',
    'Moderately active',
    'Very active',
  ];

  final List<String> _conditionsOptions = [
    'Diabetes / High blood sugar',
    'High blood pressure',
    'Heart-related issues',
    'IBS or digestive problems',
    'Food allergies',
    'None',
  ];

  final List<String> _dietaryOptions = [
    'No restriction',
    'Vegetarian',
    'Halal only',
    'Vegan',
    'Other',
  ];

  final List<String> _budgetOptions = [
    'Under 1500 PKR',
    '1500 – 3000 PKR',
    '3000 – 5000 PKR',
    'Flexible / No strict limit',
  ];

  Future<void> _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Done, send to backend
      setState(() => _isLoading = true);
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('User not logged in');

        final payload = {
          "user_id": user.id,
          "age": _age.toInt(),
          "gender": _gender ?? 'Male',
          "weight_kg": _weightKg,
          "height_cm": _heightCm,
          "goal": _mapGoal(_goal),
          "activity_level": _mapActivity(_activityLevel),
          "medical_conditions": _healthConditions,
          "dietary_restrictions": _dietaryPreference == 'No restriction' || _dietaryPreference == null ? [] : [_dietaryPreference!],
          "daily_budget_pkr": _mapBudget(_budget),
        };

        final url = Uri.parse('${ApiClient.getBaseUrl()}/profile/onboarding');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        } else {
          throw Exception('Failed to save profile: ${response.body}');
        }
      } catch (e) {
        if (!mounted) return;
        CustomToast.show(context, e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _mapGoal(String? goal) {
    if (goal == null) return 'fat_loss';
    if (goal.contains('Fat loss')) return 'fat_loss';
    if (goal.contains('muscle')) return 'muscle_gain';
    return 'maintenance';
  }

  String _mapActivity(String? activity) {
    if (activity == null) return 'sedentary';
    if (activity.contains('Lightly')) return 'lightly_active';
    if (activity.contains('Moderately')) return 'moderately_active';
    if (activity.contains('Very active')) return 'very_active';
    return 'sedentary';
  }

  int _mapBudget(String? budget) {
    if (budget == null) return 1500;
    if (budget.contains('Under 1500')) return 1500;
    if (budget.contains('1500 – 3000')) return 3000;
    if (budget.contains('3000 – 5000')) return 5000;
    return 10000; // flexible
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildGoalPage(),
                  _buildGenderPage(),
                  _buildBodyMetricsPage(),
                  _buildActivityPage(),
                  _buildHealthAndDietPage(),
                  _buildBudgetPage(),
                  _buildHealthSyncPage(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    )
                : null,
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              backgroundColor: Colors.white.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 48), // Balance for the back button
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    bool canProceed = false;
    if (_currentPage == 0 && _goal != null) canProceed = true;
    if (_currentPage == 1 && _gender != null) canProceed = true;
    if (_currentPage == 2) canProceed = true; // sliders always have values
    if (_currentPage == 3 && _activityLevel != null) canProceed = true;
    if (_currentPage == 4 && _healthConditions.isNotEmpty && _dietaryPreference != null) canProceed = true;
    if (_currentPage == 5 && _budget != null) canProceed = true;
    if (_currentPage == 6) canProceed = true; // Final health sync page, always optional

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canProceed && !_isLoading ? _nextPage : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _currentPage == _totalPages - 1 ? 'Finish' : 'Next',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
        ),
      ),
    );
  }

  // --- Pages ---

  Widget _buildGoalPage() {
    return _buildPageWrapper(
      title: 'What is your main goal right now?',
      child: Column(
        children: _goals.map((g) => _buildSelectionCard(
          text: g,
          isSelected: _goal == g,
          onTap: () => setState(() => _goal = g),
        )).toList(),
      ),
    );
  }

  Widget _buildGenderPage() {
    return _buildPageWrapper(
      title: 'What is your gender?',
      child: Column(
        children: _genders.map((g) => _buildSelectionCard(
          text: g,
          isSelected: _gender == g,
          onTap: () => setState(() => _gender = g),
        )).toList(),
      ),
    );
  }

  Widget _buildBodyMetricsPage() {
    return _buildPageWrapper(
      title: 'Basic Body Info',
      child: Column(
        children: [
          _buildNumberInputItem('Age', _age, 'years', (v) => setState(() => _age = v)),
          _buildNumberInputItem('Height', _heightCm, 'cm', (v) => setState(() => _heightCm = v)),
          _buildNumberInputItem('Current Weight', _weightKg, 'kg', (v) => setState(() => _weightKg = v)),
          _buildNumberInputItem('Target Weight', _targetWeightKg, 'kg', (v) => setState(() => _targetWeightKg = v)),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    return _buildPageWrapper(
      title: 'Activity Level',
      child: Column(
        children: _activityLevels.map((a) => _buildSelectionCard(
          text: a,
          isSelected: _activityLevel == a,
          onTap: () => setState(() => _activityLevel = a),
        )).toList(),
      ),
    );
  }

  Widget _buildHealthAndDietPage() {
    return _buildPageWrapper(
      title: 'Health Conditions & Allergies',
      subtitle: 'Do you have any of these conditions or allergies?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditionsOptions.map((c) {
              final isSelected = _healthConditions.contains(c);
              return ChoiceChip(
                label: Text(c, style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                backgroundColor: const Color(0xFF161A22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withAlpha(20),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (c == 'None' && selected) {
                      _healthConditions = ['None'];
                    } else {
                      if (selected) {
                        _healthConditions.remove('None');
                        _healthConditions.add(c);
                      } else {
                        _healthConditions.remove(c);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text('Dietary Preference', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Column(
            children: _dietaryOptions.map((d) => _buildSelectionCard(
              text: d,
              isSelected: _dietaryPreference == d,
              onTap: () => setState(() => _dietaryPreference = d),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetPage() {
    return _buildPageWrapper(
      title: 'Budget',
      subtitle: 'What is your approximate weekly food budget?',
      child: Column(
        children: _budgetOptions.map((b) => _buildSelectionCard(
          text: b,
          isSelected: _budget == b,
          onTap: () => setState(() => _budget = b),
        )).toList(),
      ),
    );
  }

  Widget _buildHealthSyncPage() {
    final theme = Theme.of(context);
    return _buildPageWrapper(
      title: 'Connect Health Apps',
      subtitle: 'NutriSense works best when it can automatically track your steps, calories burned, and sleep!',
      child: Column(
        children: [
          Icon(Icons.health_and_safety, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const Text(
            'We recommend enabling Health Sync so you never have to manually log your daily activity.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                // Try requesting permission natively
                final success = await HealthService.instance.requestPermissions();
                if (!mounted) return;
                if (success) {
                  CustomToast.show(context, 'Health Tracking Enabled!');
                  _nextPage(); // auto advance on success
                } else {
                  throw Exception('Permission denied or app missing');
                }
              } catch (e) {
                if (!mounted) return;
                // If it fails (likely due to missing Health Connect), show prompt
                if (Platform.isAndroid) {
                  _showInstallPrompt(
                    'Health Connect Missing',
                    'You need Google Health Connect installed to sync your fitness data. Would you like to install it now?',
                    'market://details?id=com.google.android.apps.healthdata',
                  );
                } else if (Platform.isIOS) {
                  _showInstallPrompt(
                    'Apple Health Required',
                    'Please ensure Apple Health is set up and permissions are granted in your iPhone settings.',
                    null, // Settings URL could go here, but usually it's built-in
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Enable Auto-Sync', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _nextPage,
            child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
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
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (storeUrl != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) CustomToast.show(context, 'Could not launch store', isError: true);
                }
              },
              child: const Text('Install Now', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildPageWrapper({required String title, String? subtitle, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _buildSelectionCard({required String text, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withAlpha(20) : const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withAlpha(20),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInputItem(String label, double value, String unit, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: TextFormField(
        initialValue: value.toInt().toString(),
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
          suffixText: unit,
          suffixStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          filled: true,
          fillColor: const Color(0xFF161A22),
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
            borderSide: const BorderSide(color: Color(0xFF00E676)),
          ),
        ),
        onChanged: (val) {
          final doubleVal = double.tryParse(val);
          if (doubleVal != null) {
            onChanged(doubleVal);
          }
        },
      ),
    );
  }
}
