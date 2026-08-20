import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../shared/widgets/custom_toast.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
  );
  
  bool _isProcessing = false;
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      final url = Uri.parse('${ApiClient.getBaseUrl()}/scan-barcode');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'barcode': barcode,
          'user_id': user.id,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          _showProductResultDialog(data);
        }
      } else {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to fetch product');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Barcode error: ${e.toString()}');
        controller.start();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  void _showProductResultDialog(Map<String, dynamic> data) {
    String selectedMealType = 'snack';
    final product = data['product'];
    final List<dynamic> warnings = data['allergy_warnings'] ?? [];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1E232E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            title: Row(
              children: [
                const Icon(Icons.qr_code, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product['product_name'] ?? 'Unknown Product',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
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
                    if (product['image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product['image_url'],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(height: 0),
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    if (warnings.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withAlpha(100)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: warnings.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(w.toString(), style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          )).toList(),
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
                            _buildMacroStat('Calories', '${product['calories']}', 'kcal', Colors.orange, theme),
                            _buildMacroStat('Protein', '${product['protein_g']}', 'g', Colors.green, theme),
                            _buildMacroStat('Carbs', '${product['carbs_g']}', 'g', Colors.blue, theme),
                            _buildMacroStat('Fat', '${product['fat_g']}', 'g', Colors.red, theme),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(product['ingredients'] ?? 'Not listed', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(150))),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  controller.start();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Log meal to Supabase
                  try {
                    final user = Supabase.instance.client.auth.currentUser;
                    await Supabase.instance.client.from('meal_logs').insert({
                      'user_id': user!.id,
                      'meal_type': selectedMealType,
                      'name': product['product_name'] ?? 'Packaged Food',
                      'calories': product['calories'],
                      'protein_g': product['protein_g'],
                      'carbs_g': product['carbs_g'],
                      'fat_g': product['fat_g'],
                      'logged_at': DateTime.now().toIso8601String(),
                    });
                    
                    if (mounted) {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // close scanner screen
                      CustomToast.show(context, 'Food logged successfully!', isError: false);
                    }
                  } catch (e) {
                    if (mounted) {
                      CustomToast.show(context, 'Failed to log food');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('Confirm & Log'),
              ),
            ],
          );
        }
      ),
    );
  }
  
  Widget _buildMacroStat(String label, String value, String unit, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                controller.stop();
                _processBarcode(barcodes.first.rawValue!);
              }
            },
          ),
          
          // Overlay UI
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching product info...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
            
          // Target box overlay
          if (!_isProcessing)
            Center(
              child: Container(
                width: 250,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
