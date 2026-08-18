import 'package:flutter/material.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Weekly Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: theme.colorScheme.primary.withAlpha(20),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Summary Insights',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Great job this week! You met your protein target 5 out of 7 days, and stayed within your caloric limit for most days. However, your sodium intake trended slightly higher on the weekend. Consider substituting salt with herbs for upcoming dinners.',
                      style: TextStyle(fontSize: 14, height: 1.5, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'History',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReportHistoryItem(context, 'Week of Aug 10 - Aug 16', 'Score: 92% (Excellent)'),
            _buildReportHistoryItem(context, 'Week of Aug 3 - Aug 9', 'Score: 85% (Good)'),
          ],
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
          // Open details
        },
      ),
    );
  }
}
