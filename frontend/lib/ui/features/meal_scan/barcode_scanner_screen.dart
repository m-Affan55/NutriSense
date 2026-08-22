import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../core/swap_service.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'manual_log_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  final TextEditingController _manualBarcodeController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isCameraSupported = false;
  final Set<String> _failedBarcodes = {};
  
  @override
  void initState() {
    super.initState();
    // Only initialize hardware camera scanner on supported mobile OS (Android / iOS / macOS)
    _isCameraSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (_isCameraSupported) {
      try {
        _controller = MobileScannerController(
          formats: const [BarcodeFormat.all],
        );
      } catch (e) {
        _isCameraSupported = false;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/scan-barcode');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'barcode': cleanCode,
          'user_id': user.id,
        }),
      ).timeout(const Duration(seconds: 10));
      
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
        _failedBarcodes.add(cleanCode);
        _showNotFoundDialog(cleanCode);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  void _showNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Product Not Found', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Barcode "$barcode" is not in our database yet. Would you like to describe it with AI?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller?.start();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ManualLogScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Log with AI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  void _showProductResultDialog(Map<String, dynamic> data) {
    String selectedMealType = 'snack';
    final product = data['product'] ?? {};
    final List<dynamic> warnings = data['allergy_warnings'] ?? [];
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161A22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product['product_name'] ?? 'Scanned Food Product',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Allergy Warnings Banner
                  if (warnings.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 6),
                              Text('Health Alert', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...warnings.map((w) => Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text('• $w', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          )),
                        ],
                      ),
                    ),
                    
                  // Meal Category Selector
                  const Text(
                    'Meal Category',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedMealType,
                    dropdownColor: const Color(0xFF1E232E),
                    style: const TextStyle(color: Colors.white),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroStat('Calories', '${product['calories'] ?? 0}', 'kcal', Colors.orange),
                        _buildMacroStat('Protein', '${product['protein_g'] ?? 0}', 'g', const Color(0xFF00E676)),
                        _buildMacroStat('Carbs', '${product['carbs_g'] ?? 0}', 'g', Colors.blueAccent),
                        _buildMacroStat('Fat', '${product['fat_g'] ?? 0}', 'g', Colors.purpleAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _controller?.start();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      await Supabase.instance.client.from('meal_logs').insert({
                        'user_id': user.id,
                        'meal_type': selectedMealType,
                        'notes': product['product_name'] ?? 'Packaged Food',
                        'total_calories': (product['calories'] as num?)?.toInt() ?? 0,
                        'total_protein_g': (product['protein_g'] as num?)?.toInt() ?? 0,
                        'total_carbs_g': (product['carbs_g'] as num?)?.toInt() ?? 0,
                        'total_fat_g': (product['fat_g'] as num?)?.toInt() ?? 0,
                        'logged_at': DateTime.now().toIso8601String(),
                      });
                    }
                    
                    if (mounted) {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context, true); // close scanner screen
                      CustomToast.show(context, 'Food logged successfully!', isError: false);
                      SwapService.checkMealForSwaps(product['product_name'] ?? 'Packaged Food');
                    }
                  } catch (e) {
                    if (mounted) {
                      CustomToast.show(context, 'Failed to log food');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm & Log', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildMacroStat(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeIcon({Color? color, double size = 24}) {
    final c = color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 3.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 2.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 3.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 1.0, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
          Container(width: 2.5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(0.5))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isCameraSupported && _controller != null
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller!,
                  onDetect: (capture) {
                    if (_isProcessing) return;
                    
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      final scannedValue = barcodes.first.rawValue!;
                      if (!_failedBarcodes.contains(scannedValue)) {
                        _processBarcode(scannedValue);
                      }
                    }
                  },
                ),
                
                // Loading Overlay
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
                      width: 260,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00E676), width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: _buildBarcodeIcon(color: theme.colorScheme.primary, size: 64),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter or Scan Barcode',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Query OpenFoodFacts & Gemini allergen database directly by entering any product barcode number below.',
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Barcode Input Field
                  TextField(
                    controller: _manualBarcodeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'e.g. 3017620422003',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(60), letterSpacing: 1),
                      filled: true,
                      fillColor: const Color(0xFF161A22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withAlpha(20))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withAlpha(20))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                    ),
                    onSubmitted: (val) => _processBarcode(val),
                  ),
                  const SizedBox(height: 20),

                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _processBarcode(_manualBarcodeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                          : const Text('Lookup Product & Macros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Quick Sample Barcodes
                  Text(
                    'Quick Test Products:',
                    style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        label: const Text('Nutella Spread (3017620422003)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        backgroundColor: const Color(0xFF161A22),
                        onPressed: () {
                          _manualBarcodeController.text = '3017620422003';
                          _processBarcode('3017620422003');
                        },
                      ),
                      ActionChip(
                        label: const Text('Snickers Bar (5000159461122)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        backgroundColor: const Color(0xFF161A22),
                        onPressed: () {
                          _manualBarcodeController.text = '5000159461122';
                          _processBarcode('5000159461122');
                        },
                      ),
                      ActionChip(
                        label: const Text('Oreo Cookies (7622210449283)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        backgroundColor: const Color(0xFF161A22),
                        onPressed: () {
                          _manualBarcodeController.text = '7622210449283';
                          _processBarcode('7622210449283');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
