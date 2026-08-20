import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'barcode_scanner_screen.dart';

class ScanMealScreen extends StatefulWidget {
  const ScanMealScreen({super.key});

  @override
  State<ScanMealScreen> createState() => _ScanMealScreenState();
}

class _ScanMealScreenState extends State<ScanMealScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImage;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
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
        _selectedImage = File(image!.path);
      });

      await _uploadAndScanImage();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error selecting image: ${e.toString()}');
      }
    }
  }

  Future<void> _uploadAndScanImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User authentication session not found.');
      }

      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/scan');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['user_id'] = user.id;
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showScanResultDialog(Map<String, dynamic> data) {
    String selectedMealType = 'breakfast';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final warnings = List<String>.from(data['health_warnings'] ?? []);
            final suggestions = List<String>.from(data['suggestions'] ?? []);
            final items = List<dynamic>.from(data['items'] ?? []);

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
                                    data['recognition_confidence'] = 'high'; // Clear the warning if it exists
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
                          child: Image.file(
                            _selectedImage!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      // Standard AI Disclaimer
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withAlpha(100)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange),
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
                        items: const [
                          DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                          DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                          DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                          DropdownMenuItem(value: 'snack', child: Text('Snack / Other')),
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

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('${item['estimated_weight_g']}g • ${item['calories']} kcal'),
                            trailing: Text(
                              'P:${item['protein_g']}g F:${item['fat_g']}g C:${item['carbs_g']}g',
                              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 11),
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
                    await _saveMealLog(data, selectedMealType);
                  },
                  child: const Text('Confirm & Log'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _saveMealLog(Map<String, dynamic> data, String mealType) async {
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
        'total_calories': (data['total_calories'] as num).toInt(),
        'total_protein_g': (data['total_protein_g'] as num).toInt(),
        'total_carbs_g': (data['total_carbs_g'] as num).toInt(),
        'total_fat_g': (data['total_fat_g'] as num).toInt(),
        'notes': data['meal_name'],
      };

      await supabase.from('meal_logs').insert(payload);

      if (mounted) {
        CustomToast.show(context, 'Meal logged successfully!', isError: false);
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
                      'AI Analyzing Meal Plate...',
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
