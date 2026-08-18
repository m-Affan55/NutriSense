import 'package:flutter/material.dart';
import '../navigation/main_navigation_screen.dart';

class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

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

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Done, navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canProceed ? _nextPage : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
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
          _buildSliderItem('Age', _age, 10, 100, 'years', (v) => setState(() => _age = v)),
          _buildSliderItem('Height', _heightCm, 100, 250, 'cm', (v) => setState(() => _heightCm = v)),
          _buildSliderItem('Current Weight', _weightKg, 30, 200, 'kg', (v) => setState(() => _weightKg = v)),
          _buildSliderItem('Target Weight', _targetWeightKg, 30, 200, 'kg', (v) => setState(() => _targetWeightKg = v)),
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

  Widget _buildSliderItem(String label, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${value.toInt()} $unit', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: const Color(0xFF161A22),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
