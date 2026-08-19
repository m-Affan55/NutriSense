import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_view.dart';

import '../../widgets/animated_particles_background.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;

  Future<void> _saveAndContinue() async {
    if (_selectedLanguage == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _selectedLanguage!);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: AnimatedParticlesBackground(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primary.withAlpha(20),
                child: Icon(Icons.spa, size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Select Your Language\nاپنی زبان چنیں',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),

              // Selection Cards
              Row(
                children: [
                  Expanded(
                    child: _LanguageCard(
                      title: 'English',
                      emoji: '🇬🇧',
                      isSelected: _selectedLanguage == 'en',
                      onTap: () => setState(() => _selectedLanguage = 'en'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _LanguageCard(
                      title: 'اردو / Urdu',
                      emoji: '🇵🇰',
                      isSelected: _selectedLanguage == 'ur',
                      onTap: () => setState(() => _selectedLanguage = 'ur'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              
              // Continue Button
              AnimatedOpacity(
                opacity: _selectedLanguage != null ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, const Color(0xFF00BCD4)],
                    ),
                    boxShadow: _selectedLanguage != null ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ] : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectedLanguage != null ? _saveAndContinue : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Text(
                          'Continue',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
        ),
      ),
      ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String title;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.title,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.white.withAlpha(20),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(40),
              blurRadius: 20,
              spreadRadius: -5,
            )
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected ? theme.colorScheme.primary : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
