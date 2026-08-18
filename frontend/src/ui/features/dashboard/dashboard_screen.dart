import 'package:flutter/material.dart';
import '../../../../main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriSense', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              NutriSenseApp.of(context).toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Welcome back!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here is your nutrition summary for today.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 24),

            // Daily Calorie Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calories Remaining',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1,450 kcal',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        // Circular progress indicator placeholder
                        SizedBox(
                          height: 70,
                          width: 70,
                          child: CircularProgressIndicator(
                            value: 0.35,
                            strokeWidth: 8,
                            backgroundColor: theme.brightness == Brightness.dark
                                ? const Color(0xFF2E3B2E)
                                : const Color(0xFFE8F5E9),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroIndicator(context, 'Carbs', '45g / 220g', 0.2),
                        _buildMacroIndicator(context, 'Protein', '32g / 130g', 0.25),
                        _buildMacroIndicator(context, 'Fat', '15g / 65g', 0.23),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Hydration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hydration Progress',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '750 ml / 2,500 ml',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        size: 36,
                        color: theme.brightness == Brightness.dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                      ),
                      onPressed: () {
                        // Quick add 250ml water action
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroIndicator(
      BuildContext context, String name, String progress, double percent) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: theme.colorScheme.onSurface.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
          ),
        ),
        const SizedBox(height: 4),
        Text(progress, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(150))),
      ],
    );
  }
}
