import 'dart:convert';
import 'package:universal_io/io.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../core/swap_service.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/reminder_manager.dart';
import '../family_profiles/family_viewmodel.dart';
import 'barcode_scanner_screen.dart';
import '../../../core/meal_sync_notifier.dart';
import '../../../core/language_controller.dart';

class ScanMealScreen extends StatefulWidget {
  const ScanMealScreen({super.key});

  @override
  State<ScanMealScreen> createState() => _ScanMealScreenState();
}

class _ScanMealScreenState extends State<ScanMealScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _loadingText = 'Analyzing meal...';
  Timer? _loadingTimer;
  XFile? _selectedImage;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_loadLanguage);
    _loadLanguage();
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_loadLanguage);
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _loadLanguage() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? image;
      try {
        image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1080,
        );
      } catch (e) {
        if (source == ImageSource.camera) {
          debugPrint('Camera not supported on this platform, falling back to gallery: $e');
          // Inform the user
          if (mounted) {
            CustomToast.show(
              context,
              'Camera capture not supported on this platform. Selecting from gallery instead.',
              isError: false,
            );
          }
          image = await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1080,
          );
        } else {
          rethrow;
        }
      }

      if (image == null) return;

      setState(() {
        _selectedImage = image;
      });

      await _uploadAndScanImage();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error selecting image: ${e.toString()}');
      }
    }
  }

  void _startLoadingPhases() {
    setState(() {
      _isLoading = true;
      _loadingText = 'Uploading image...';
    });
    
    int phase = 0;
    final phases = [
      'Analyzing image with AI...',
      'Detecting objects & patterns...',
      'Consulting nutrition database...',
      'Finalizing results...'
    ];
    
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || !_isLoading) {
        timer.cancel();
        return;
      }
      if (phase < phases.length) {
        setState(() {
          _loadingText = phases[phase];
        });
        phase++;
      }
    });
  }

  Future<void> _uploadAndScanImage() async {
    if (_selectedImage == null) return;

    _startLoadingPhases();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User authentication session not found.');
      }

      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/scan');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(ApiClient.getHeaders());
      
      request.fields['user_id'] = user.id;
      final bytes = await _selectedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: _selectedImage!.name,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 400 && response.body.contains("NO_FOOD_DETECTED")) {
        throw Exception('No food detected in this image. Please take a clear picture of your meal.');
      }
      if (response.statusCode == 429) {
        throw Exception('Our AI is a bit busy right now. Please try again in a few seconds.');
      }
      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (mounted) {
        _showScanResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Plate analysis failed: ${e.toString()}');
      }
    } finally {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showScanResultDialog(Map<String, dynamic> data) {
    String selectedMealType = 'breakfast';
    String? selectedFamilyMemberId = FamilyViewModel.instance.activeMember?.id;

    final items = List<dynamic>.from(data['items'] ?? []);

    // BUG-09 FIX: Ensure every item has a valid macros_per_100g baseline.
    // For AI-estimated items where the backend returned ai_estimate source,
    // macros_per_100g may be absent. We derive it here so the portion slider
    // always has a non-zero baseline to calculate from.
    for (final item in items) {
      if (item['macros_per_100g'] == null) {
        final double g = (item['estimated_weight_g'] as num?)?.toDouble() ?? 100.0;
        final double safeG = g > 0 ? g : 100.0;
        item['macros_per_100g'] = {
          'calories': ((item['calories'] as num?)?.toDouble() ?? 0.0) / safeG * 100.0,
          'protein_g': ((item['protein_g'] as num?)?.toDouble() ?? 0.0) / safeG * 100.0,
          'carbs_g': ((item['carbs_g'] as num?)?.toDouble() ?? 0.0) / safeG * 100.0,
          'fat_g': ((item['fat_g'] as num?)?.toDouble() ?? 0.0) / safeG * 100.0,
        };
      }
    }

    // BUG-04 FIX: Create controllers ONCE before showDialog, keyed by item index.
    // Previously they were created inside itemBuilder, causing them to be
    // recreated on every setDialogState() call — losing cursor position and leaking memory.
    final Map<int, TextEditingController> gramControllers = {
      for (int i = 0; i < items.length; i++)
        i: TextEditingController(
          text: (items[i]['estimated_weight_g'] as num).toInt().toString(),
        )
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final warnings = List<String>.from(data['health_warnings'] ?? []);
            final suggestions = List<String>.from(data['suggestions'] ?? []);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.restaurant, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['meal_name'] ?? 'Plate Detected',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                    onPressed: () {
                      final controller = TextEditingController(text: data['meal_name'] ?? '');
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E232E),
                          title: const Text('Correct Food Name', style: TextStyle(color: Colors.white)),
                          content: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Beef Siri Paye',
                              hintStyle: TextStyle(color: Colors.white54),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (controller.text.isNotEmpty) {
                                  setDialogState(() {
                                    data['meal_name'] = controller.text;
                                    data['recognition_confidence'] = 'high';
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Preview if captured
                      if (_selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _selectedImage!.path,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      const SizedBox(height: 16),

                      // AI Disclaimer when confidence is low
                      if (data['recognition_confidence'] == 'low')
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('AI is unsure about this food. Tap the pencil icon above to correct it.', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                      // Meal Type Selector
                      const Text(
                        'Select Meal Slot',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMealType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text(RamadanController.instance.isRamadanMode
                                ? RamadanController.instance.getLocalizedMealName('breakfast', _language)
                                : (_language == 'ur' ? 'ناشتہ' : 'Breakfast')),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text(RamadanController.instance.isRamadanMode
                                ? RamadanController.instance.getLocalizedMealName('dinner', _language)
                                : (_language == 'ur' ? 'رات کا کھانا' : 'Dinner')),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text(RamadanController.instance.isRamadanMode
                                ? RamadanController.instance.getLocalizedMealName('lunch', _language)
                                : (_language == 'ur' ? 'دوپہر کا کھانا' : 'Lunch')),
                          ),
                          DropdownMenuItem(
                            value: 'snack',
                            child: Text(RamadanController.instance.isRamadanMode
                                ? RamadanController.instance.getLocalizedMealName('snack', _language)
                                : (_language == 'ur' ? 'اسنیک' : 'Snack / Other')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedMealType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Family Member Selector
                      if (FamilyViewModel.instance.members.isNotEmpty) ...[
                        Text(
                          _language == 'ur' ? 'کس کے لیے لاگ کر رہے ہیں؟' : 'Logging for Family Member',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: selectedFamilyMemberId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF00E676), size: 20),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(_language == 'ur' ? '🧑 میں (ذاتی اکاؤنٹ)' : '🧑 Me (Primary Account)'),
                            ),
                            ...FamilyViewModel.instance.members.map((m) => DropdownMenuItem<String?>(
                                  value: m.id,
                                  child: Text('${m.relationshipEmoji} ${m.name} (${m.getLocalizedRelationship(_language)})'),
                                )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedFamilyMemberId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Macro Summary Card
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMacroStat('Calories', '${data['total_calories']}', 'kcal', Colors.orange, theme),
                              _buildMacroStat('Protein', '${data['total_protein_g']}', 'g', Colors.green, theme),
                              _buildMacroStat('Carbs', '${data['total_carbs_g']}', 'g', Colors.blue, theme),
                              _buildMacroStat('Fat', '${data['total_fat_g']}', 'g', Colors.red, theme),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Health Safety Alerts Banner
                      if (warnings.isNotEmpty) ...[
                        const Text(
                          'Safety Alerts',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                        ),
                        const SizedBox(height: 8),
                        ...warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(25),
                              border: Border.all(color: Colors.red.withAlpha(50)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w,
                                    style: const TextStyle(color: Colors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Items Breakdown
                      const Text(
                        'Items Detected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final displayName = _language == 'ur' && item['local_name'] != null
                              ? item['local_name']
                              : item['name'] ?? 'Ingredient';

                          // BUG-04 FIX: Reuse the pre-created controller from the map.
                          // This avoids recreating controllers on every rebuild,
                          // preserving cursor position and preventing memory leaks.
                          final controller = gramControllers[index]!;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'P:${item['protein_g']}g F:${item['fat_g']}g C:${item['carbs_g']}g',
                                        style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${item['calories']} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            width: 45,
                                            height: 28,
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                                filled: true,
                                                fillColor: theme.colorScheme.surface,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                              onChanged: (val) {
                                                final newGrams = double.tryParse(val);
                                                if (newGrams != null && newGrams > 0) {
                                                  setDialogState(() {
                                                    item['estimated_weight_g'] = newGrams;
                                                    // BUG-09 FIX: macros_per_100g is now guaranteed
                                                    // to be non-null (populated above before showDialog).
                                                    double tCal = 0, tPro = 0, tCarb = 0, tFat = 0;
                                                    for (var i in items) {
                                                      final double g = (i['estimated_weight_g'] as num).toDouble();
                                                      final Map<String, dynamic> macros100g = i['macros_per_100g'] as Map<String, dynamic>;
                                                      final double r = g / 100.0;

                                                      i['calories'] = ((macros100g['calories'] as num).toDouble() * r).round();
                                                      i['protein_g'] = double.parse(((macros100g['protein_g'] as num).toDouble() * r).toStringAsFixed(1));
                                                      i['carbs_g'] = double.parse(((macros100g['carbs_g'] as num).toDouble() * r).toStringAsFixed(1));
                                                      i['fat_g'] = double.parse(((macros100g['fat_g'] as num).toDouble() * r).toStringAsFixed(1));

                                                      tCal += i['calories'];
                                                      tPro += i['protein_g'];
                                                      tCarb += i['carbs_g'];
                                                      tFat += i['fat_g'];
                                                    }
                                                    data['total_calories'] = tCal.round();
                                                    data['total_protein_g'] = double.parse(tPro.toStringAsFixed(1));
                                                    data['total_carbs_g'] = double.parse(tCarb.toStringAsFixed(1));
                                                    data['total_fat_g'] = double.parse(tFat.toStringAsFixed(1));
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text('g', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'AI Suggestions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...suggestions.map((s) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
                          ],
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _saveMealLog(data, selectedMealType, selectedFamilyMemberId);
                  },
                  child: const Text('Confirm & Log'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      // BUG-04 FIX: Dispose all gram controllers when dialog is dismissed,
      // preventing memory leaks across multiple scan sessions.
      for (final c in gramControllers.values) {
        c.dispose();
      }
    });
  }

  Widget _buildMacroStat(String label, String value, String unit, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _saveMealLog(Map<String, dynamic> data, String mealType, [String? familyMemberId]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Auth session is invalid.');

      final payload = {
        'user_id': user.id,
        'meal_type': mealType,
        'food_items': data['items'],
        'total_calories': (data['total_calories'] as num?)?.toInt() ?? 0,
        'total_protein_g': (data['total_protein_g'] as num?)?.toInt() ?? 0,
        'total_carbs_g': (data['total_carbs_g'] as num?)?.toInt() ?? 0,
        'total_fat_g': (data['total_fat_g'] as num?)?.toInt() ?? 0,
        'notes': data['meal_name'],
        'logged_at': DateTime.now().toUtc().toIso8601String(),
        'family_member_id': familyMemberId,
      };

      await supabase.from('meal_logs').insert(payload);

      // Learn adaptive meal pattern and check streak milestones
      await ReminderManager.recordMealLogged(mealType, DateTime.now());
      await ReminderManager.updateAndCheckStreak();

      if (mounted) {
        CustomToast.show(context, 'Meal logged successfully!', isError: false);
        SwapService.checkMealForSwaps(data['meal_name'] ?? 'Scanned Meal');
        MealSyncNotifier.instance.notifyMealChanged();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save meal: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Plate'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      _loadingText,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Identifying food and calculating macros...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 80,
                      color: theme.colorScheme.primary.withAlpha(204),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AI Plate Recognition',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Take a photo of your meal or choose a picture from your gallery. Antigravity AI will instantly recognize food segments, estimate portions, check safety, and log your metrics.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Meal Plate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Barcode'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
