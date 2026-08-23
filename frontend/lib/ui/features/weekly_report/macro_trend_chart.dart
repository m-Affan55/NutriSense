import 'package:flutter/material.dart';

class MacroTrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> mealLogs;
  final int dailyCalorieTarget;
  final int dailyProteinTarget;
  final int dailyCarbsTarget;
  final int dailyFatTarget;
  final String language;

  const MacroTrendChart({
    super.key,
    required this.mealLogs,
    required this.dailyCalorieTarget,
    required this.dailyProteinTarget,
    required this.dailyCarbsTarget,
    required this.dailyFatTarget,
    required this.language,
  });

  @override
  State<MacroTrendChart> createState() => _MacroTrendChartState();
}

class _MacroTrendChartState extends State<MacroTrendChart> {
  bool _showCalories = true; // True: Calories, False: Macros
  int _selectedDayIndex = -1; // Index of the day tapped (-1 for none)

  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(MacroTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _processData();
  }

  void _processData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> list = [];

    // Construct last 7 days starting from 6 days ago to today
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toString().substring(0, 10);
      
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;

      for (var meal in widget.mealLogs) {
        final loggedAt = meal['logged_at'] as String?;
        if (loggedAt != null && loggedAt.substring(0, 10) == dateStr) {
          calories += (meal['total_calories'] as num?)?.toDouble() ?? 0.0;
          protein += (meal['total_protein_g'] as num?)?.toDouble() ?? 0.0;
          carbs += (meal['total_carbs_g'] as num?)?.toDouble() ?? 0.0;
          fat += (meal['total_fat_g'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Format weekday
      String dayLabel = _getWeekdayLabel(date.weekday);

      list.add({
        'date': dateStr,
        'label': dayLabel,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      });
    }

    setState(() {
      _chartData = list;
    });
  }

  String _getWeekdayLabel(int weekday) {
    if (widget.language == 'ur') {
      final days = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
      return days[weekday - 1];
    } else {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = widget.language == 'ur' ? 'روزانہ کی غذائی رپورٹ' : 'Daily Intake Trends';
    final calBtn = widget.language == 'ur' ? 'کیلوریز' : 'Calories';
    final macroBtn = widget.language == 'ur' ? 'میکروز' : 'Macros';

    return Card(
      color: const Color(0xFF161A22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withAlpha(10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Toggle Button
                Row(
                  children: [
                    _buildToggleButton(calBtn, _showCalories, () {
                      setState(() {
                        _showCalories = true;
                        _selectedDayIndex = -1;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildToggleButton(macroBtn, !_showCalories, () {
                      setState(() {
                        _showCalories = false;
                        _selectedDayIndex = -1;
                      });
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Chart Display area
            GestureDetector(
              onTapDown: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                // Calculate which bar was tapped
                // The chart container height is 200, offset down by title spacing.
                // Let's match horizontal indices.
                final chartWidth = box.size.width - 32 - 40; // padding and left labels
                final startX = 40.0;
                final step = chartWidth / 7;

                final tappedX = localPos.dx - startX;
                if (tappedX >= 0 && tappedX <= chartWidth) {
                  final idx = (tappedX / step).floor();
                  if (idx >= 0 && idx < 7) {
                    setState(() {
                      _selectedDayIndex = idx;
                    });
                  }
                }
              },
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendChartPainter(
                    data: _chartData,
                    showCalories: _showCalories,
                    selectedDayIndex: _selectedDayIndex,
                    calorieTarget: widget.dailyCalorieTarget,
                    proteinTarget: widget.dailyProteinTarget,
                    carbsTarget: widget.dailyCarbsTarget,
                    fatTarget: widget.dailyFatTarget,
                    theme: theme,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Render Selected Details Tooltip
            if (_selectedDayIndex != -1 && _selectedDayIndex < _chartData.length)
              _buildSelectedIntakeDetails(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? theme.colorScheme.primary : Colors.white.withAlpha(20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? theme.colorScheme.primary : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedIntakeDetails(ThemeData theme) {
    final day = _chartData[_selectedDayIndex];
    final dateStr = day['date'] as String;
    
    final labelColor = Colors.grey.shade400;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: _showCalories
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.language == 'ur' ? 'تاریخ: $dateStr' : 'Date: $dateStr',
                  style: TextStyle(color: labelColor, fontSize: 13),
                ),
                Text(
                  '${(day['calories'] as double).round()} / ${widget.dailyCalorieTarget} kcal',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.language == 'ur' ? 'تاریخ: $dateStr' : 'Date: $dateStr',
                  style: TextStyle(color: labelColor, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSelectedMacroText('P', day['protein'], widget.dailyProteinTarget, Colors.redAccent),
                    _buildSelectedMacroText('C', day['carbs'], widget.dailyCarbsTarget, Colors.blueAccent),
                    _buildSelectedMacroText('F', day['fat'], widget.dailyFatTarget, Colors.amber),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedMacroText(String macro, double consumed, int target, Color color) {
    return Column(
      children: [
        Text(
          '$macro: ${consumed.round()}g / ${target}g',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool showCalories;
  final int selectedDayIndex;
  final int calorieTarget;
  final int proteinTarget;
  final int carbsTarget;
  final int fatTarget;
  final ThemeData theme;

  TrendChartPainter({
    required this.data,
    required this.showCalories,
    required this.selectedDayIndex,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final double leftPadding = 40.0;
    final double bottomPadding = 30.0;
    final double chartHeight = size.height - bottomPadding;
    final double chartWidth = size.width - leftPadding;

    // Calculate maximum value for dynamic Y scaling
    double maxVal = 100;
    if (showCalories) {
      for (var day in data) {
        if (day['calories'] > maxVal) maxVal = day['calories'];
      }
      if (calorieTarget > maxVal) maxVal = calorieTarget.toDouble();
    } else {
      for (var day in data) {
        double totalMacros = day['protein'] + day['carbs'] + day['fat'];
        if (totalMacros > maxVal) maxVal = totalMacros;
      }
      double targetSum = (proteinTarget + carbsTarget + fatTarget).toDouble();
      if (targetSum > maxVal) maxVal = targetSum;
    }
    // Pad maxVal
    maxVal *= 1.2;

    // Draw horizontal grid lines (3 grid lines)
    for (int i = 1; i <= 3; i++) {
      double y = chartHeight - (chartHeight / 3) * i;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      
      // Draw grid text values
      double gridVal = (maxVal / 3) * i;
      final textSpan = TextSpan(
        text: showCalories ? '${gridVal.round()}' : '${gridVal.round()}g',
        style: const TextStyle(color: Colors.white24, fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Step width for days
    double stepX = chartWidth / 7;

    // Draw X labels and Bars
    for (int i = 0; i < 7; i++) {
      final day = data[i];
      double centerX = leftPadding + stepX * i + stepX / 2;

      // Draw X label (Mon, Tue...)
      final textSpan = TextSpan(
        text: day['label'] as String,
        style: TextStyle(
          color: selectedDayIndex == i ? theme.colorScheme.primary : Colors.grey.shade500,
          fontSize: 11,
          fontWeight: selectedDayIndex == i ? FontWeight.bold : FontWeight.normal,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, size.height - 20));

      // Draw active highlight background if selected
      if (selectedDayIndex == i) {
        final highlightPaint = Paint()
          ..color = theme.colorScheme.primary.withAlpha(15)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(leftPadding + stepX * i + 4, 0, leftPadding + stepX * (i + 1) - 4, chartHeight),
            const Radius.circular(8),
          ),
          highlightPaint,
        );
      }

      // Draw Bar(s)
      if (showCalories) {
        double val = day['calories'] as double;
        double barHeight = (val / maxVal) * chartHeight;
        if (barHeight > chartHeight) barHeight = chartHeight;

        paint.color = selectedDayIndex == i 
            ? theme.colorScheme.primary 
            : theme.colorScheme.primary.withAlpha(180);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              centerX - 10,
              chartHeight - barHeight,
              centerX + 10,
              chartHeight,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
      } else {
        // Renders stacked/grouped macro representation
        double protein = day['protein'] as double;
        double carbs = day['carbs'] as double;
        double fat = day['fat'] as double;

        double hProtein = (protein / maxVal) * chartHeight;
        double hCarbs = (carbs / maxVal) * chartHeight;
        double hFat = (fat / maxVal) * chartHeight;

        // Draw side-by-side grouped bars for macro values
        // Protein (red)
        paint.color = Colors.redAccent.withAlpha(selectedDayIndex == i ? 255 : 180);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(centerX - 9, chartHeight - hProtein, centerX - 3, chartHeight),
            const Radius.circular(2),
          ),
          paint,
        );

        // Carbs (blue)
        paint.color = Colors.blueAccent.withAlpha(selectedDayIndex == i ? 255 : 180);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(centerX - 3, chartHeight - hCarbs, centerX + 3, chartHeight),
            const Radius.circular(2),
          ),
          paint,
        );

        // Fat (amber)
        paint.color = Colors.amber.withAlpha(selectedDayIndex == i ? 255 : 180);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(centerX + 3, chartHeight - hFat, centerX + 9, chartHeight),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }

    // Draw horizontal dashed target line for Calorie limit
    if (showCalories) {
      double targetY = chartHeight - (calorieTarget / maxVal) * chartHeight;
      if (targetY >= 0 && targetY <= chartHeight) {
        final targetPaint = Paint()
          ..color = Colors.redAccent.withAlpha(120)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        
        // Draw dashed line
        double dashWidth = 5, dashSpace = 3;
        double startX = leftPadding;
        while (startX < size.width) {
          canvas.drawLine(
            Offset(startX, targetY),
            Offset(startX + dashWidth, targetY),
            targetPaint,
          );
          startX += dashWidth + dashSpace;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.showCalories != showCalories ||
        oldDelegate.selectedDayIndex != selectedDayIndex ||
        oldDelegate.data != data;
  }
}
