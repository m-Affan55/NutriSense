import 'dart:convert';
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
  late final MobileScannerController _controller;
  final TextEditingController _manualBarcodeController = TextEditingController();
  
  bool _isProcessing = false;
  bool _torchEnabled = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;
  
  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty || _isProcessing) return;

    // Debounce exact same barcode if scanned within 2 seconds
    final now = DateTime.now();
    if (_lastScannedCode == cleanCode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    _lastScannedCode = cleanCode;
    _lastScanTime = now;
    
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
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          await _showProductResultDialog(data);
        }
      } else if (response.statusCode == 503) {
        if (mounted) {
          await _showServiceBusyDialog(cleanCode);
        }
      } else {
        if (mounted) {
          await _showNotFoundDialog(cleanCode);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        final isTimeout = msg.contains('timeout') || msg.contains('timed out');
        if (isTimeout) {
          await _showTimeoutDialog();
        } else {
          await _showNotFoundDialog(cleanCode);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  Future<void> _showNotFoundDialog(String barcode) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Item Not Recognized', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('We could not automatically identify this item. Would you like to describe what you are eating so AI can calculate the calories and nutrition?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
            child: const Text('Describe Meal with AI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showServiceBusyDialog(String barcode) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.amberAccent, size: 22),
            SizedBox(width: 8),
            Text('AI Service Busy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Our AI identification engine is experiencing temporary peak traffic. You can retry in a moment or describe your meal directly.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
            child: const Text('Describe with AI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimeoutDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text('Connection Timed Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'The AI is taking longer than expected. Please check your internet connection and try again.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showProductResultDialog(Map<String, dynamic> data) async {
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
                        'total_protein_g': (product['protein_g'] as num?)?.toDouble() ?? 0.0,
                        'total_carbs_g': (product['carbs_g'] as num?)?.toDouble() ?? 0.0,
                        'total_fat_g': (product['fat_g'] as num?)?.toDouble() ?? 0.0,
                        'logged_at': DateTime.now().toIso8601String(),
                      });
                    }
                    
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
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

  void _showManualInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBarcodeIcon(color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Enter Barcode Number',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualBarcodeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'e.g. 3017620422003',
                hintStyle: TextStyle(color: Colors.white.withAlpha(60), letterSpacing: 1),
                filled: true,
                fillColor: const Color(0xFF1E232E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withAlpha(20))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx);
                _processBarcode(val);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _processBarcode(_manualBarcodeController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Lookup Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Toggle Flash',
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off, color: _torchEnabled ? Colors.yellow : Colors.white),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            tooltip: 'Type Barcode Manually',
            icon: const Icon(Icons.keyboard, color: Colors.white),
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBarcodeIcon(color: theme.colorScheme.primary, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable or No Hardware Detected',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can still lookup any product barcode by entering its number manually.',
                        style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _showManualInputDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Enter Barcode Manually', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              if (_isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final scannedValue = barcodes.first.rawValue!;
                _processBarcode(scannedValue);
              }
            },
          ),
          
          if (!_isProcessing)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 270,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00E676), width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            height: 1.5,
                            width: 250,
                            color: const Color(0xFF00E676).withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Align barcode inside the frame',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showManualInputDialog,
                icon: const Icon(Icons.keyboard, color: Colors.black),
                label: const Text(
                  'Enter Barcode Manually',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF00E676)),
                      const SizedBox(height: 16),
                      const Text(
                        'Identifying Product...',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI is looking up this barcode.\nThis may take up to 20 seconds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
