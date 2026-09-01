import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/language_controller.dart';

// ─────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────
class _Clinic {
  final String name;
  final String address;
  final String phone;
  final String type; // 'government' | 'private'
  final String cost;
  String distance;
  double distanceMeters;
  final String specialty;
  final double lat;
  final double lng;

  _Clinic({
    required this.name,
    required this.address,
    required this.phone,
    required this.type,
    required this.cost,
    this.distance = 'Nearby',
    this.distanceMeters = 0.0,
    required this.specialty,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────
//  VERIFIED REGIONAL CLINICS DIRECTORY (Used as Instant Baseline)
// ─────────────────────────────────────────────────────────────────
List<_Clinic> _createInitialClinics(bool isUrdu) => [
  // ── Government (Karachi) ──────────────────────────────────────
  _Clinic(
    name: isUrdu ? 'جناح پوسٹ گریجویٹ میڈیکل سینٹر (JPMC)' : 'Jinnah Postgraduate Medical Centre (JPMC)',
    address: isUrdu ? 'رفیقی ایچ جے شہید روڈ، کراچی' : 'Rafiqui H.J. Shaheed Rd, Karachi',
    phone: '+922199201050',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'جنرل اور ایمرجنسی' : 'General & Emergency',
    lat: 24.8607,
    lng: 67.0105,
  ),
  _Clinic(
    name: isUrdu ? 'سول ہسپتال کراچی' : 'Civil Hospital Karachi',
    address: isUrdu ? 'بابائے اردو روڈ، کراچی' : 'Baba-e-Urdu Rd, Karachi',
    phone: '+922199215740',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'ملٹی اسپیشلٹی' : 'Multi-specialty',
    lat: 24.8617,
    lng: 67.0082,
  ),
  _Clinic(
    name: isUrdu ? 'لیاقت نیشنل ہسپتال (LNH)' : 'Liaquat National Hospital (LNH)',
    address: isUrdu ? 'اسٹیڈیم روڈ، کراچی' : 'Stadium Rd, Karachi',
    phone: '+922134412000',
    type: 'government',
    cost: isUrdu ? 'کم لاگت' : 'Low Cost',
    specialty: isUrdu ? 'نیوٹریشن اور اینڈو کرائنولوجی' : 'Nutrition & Endocrinology',
    lat: 24.8933,
    lng: 67.0756,
  ),
  _Clinic(
    name: isUrdu ? 'قومی ادارہ برائے ذیابیطس اور اینڈوکرائنولوجی' : 'National Institute of Diabetes & Endocrinology (NIDE)',
    address: isUrdu ? 'جے پی ایم سی کیمپس، رفیقی روڈ، کراچی' : 'JPMC Campus, Rafiqui Rd, Karachi',
    phone: '+922199201111',
    type: 'government',
    cost: isUrdu ? 'مفت' : 'Free',
    specialty: isUrdu ? 'ذیابیطس اور غذائیت' : 'Diabetes & Nutrition',
    lat: 24.8605,
    lng: 67.0110,
  ),

  // ── Private (Karachi) ─────────────────────────────────────────
  _Clinic(
    name: isUrdu ? 'آغا خان یونیورسٹی ہسپتال (AKUH)' : 'Aga Khan University Hospital (AKUH)',
    address: isUrdu ? 'اسٹیڈیم روڈ، کراچی' : 'Stadium Rd, Karachi',
    phone: '+922134864000',
    type: 'private',
    cost: isUrdu ? 'اعلیٰ لاگت' : 'High Cost',
    specialty: isUrdu ? 'ڈائیٹیٹکس اور کارڈیالوجی' : 'Dietetics & Cardiology',
    lat: 24.8980,
    lng: 67.0800,
  ),
  _Clinic(
    name: isUrdu ? 'ساؤتھ سٹی ہسپتال' : 'South City Hospital',
    address: isUrdu ? 'ڈاکٹر ضیاء الدین احمد روڈ، کراچی' : 'Dr. Ziauddin Ahmed Rd, Karachi',
    phone: '+922135205001',
    type: 'private',
    cost: isUrdu ? 'درمیانی لاگت' : 'Medium Cost',
    specialty: isUrdu ? 'غذائیت اور امراض قلب' : 'Nutrition & Cardiology',
    lat: 24.8438,
    lng: 67.0269,
  ),
  _Clinic(
    name: isUrdu ? 'انڈس ہسپتال' : 'Indus Hospital',
    address: isUrdu ? 'کورنگی کراسنگ، کراچی' : 'Korangi Crossing, Karachi',
    phone: '+922135112709',
    type: 'private',
    cost: isUrdu ? 'مفت (خیراتی)' : 'Free (Charity)',
    specialty: isUrdu ? 'ملٹی اسپیشلٹی (مفت)' : 'Multi-specialty (Free)',
    lat: 24.8330,
    lng: 67.1180,
  ),
  _Clinic(
    name: isUrdu ? 'ضیاء الدین ہسپتال (کلفٹن)' : 'Ziauddin Hospital (Clifton)',
    address: isUrdu ? 'بلاک 6، کلفٹن، کراچی' : 'Block 6, Clifton, Karachi',
    phone: '+922135862937',
    type: 'private',
    cost: isUrdu ? 'درمیانی لاگت' : 'Medium Cost',
    specialty: isUrdu ? 'غذائیت اور بلڈ پریشر' : 'Nutrition & Hypertension',
    lat: 24.8140,
    lng: 67.0300,
  ),

  // ── Government (Lahore) ───────────────────────────────────────
  _Clinic(
    name: isUrdu ? 'میو ہسپتال لاہور' : 'Mayo Hospital Lahore',
    address: isUrdu ? 'ہسپتال روڈ، انارکلی بازار، لاہور' : 'Hospital Rd, Anarkali Bazaar, Lahore',
    phone: '+924299211120',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'جنرل اور ایمرجنسی' : 'General & Emergency',
    lat: 31.5746,
    lng: 74.3130,
  ),
  _Clinic(
    name: isUrdu ? 'سروسز ہسپتال لاہور' : 'Services Hospital Lahore',
    address: isUrdu ? 'جیل روڈ، لاہور' : 'Jail Rd, Lahore',
    phone: '+924299203402',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'ملٹی اسپیشلٹی' : 'Multi-specialty',
    lat: 31.5414,
    lng: 74.3313,
  ),
  _Clinic(
    name: isUrdu ? 'جناح ہسپتال لاہور' : 'Jinnah Hospital Lahore',
    address: isUrdu ? 'عثمانی روڈ، فیصل ٹاؤن، لاہور' : 'Usmani Rd, Faisal Town, Lahore',
    phone: '+924299231400',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'جنرل اور ایمرجنسی' : 'General & Emergency',
    lat: 31.4939,
    lng: 74.3113,
  ),

  // ── Private (Lahore) ──────────────────────────────────────────
  _Clinic(
    name: isUrdu ? 'شوکت خانم میموریل ہسپتال' : 'Shaukat Khanum Memorial Hospital',
    address: isUrdu ? 'جوہر ٹاؤن، لاہور' : 'Johar Town, Lahore',
    phone: '+924235905000',
    type: 'private',
    cost: isUrdu ? 'خیراتی / رعایتی' : 'Charity / Subsidised',
    specialty: isUrdu ? 'خصوصی نگہداشت اور غذائیت' : 'Specialized Care & Nutrition',
    lat: 31.4727,
    lng: 74.2693,
  ),

  // ── Islamabad / Rawalpindi ────────────────────────────────────
  _Clinic(
    name: isUrdu ? 'پمز ہسپتال اسلام آباد (PIMS)' : 'Pakistan Institute of Medical Sciences (PIMS)',
    address: isUrdu ? 'جی-8/3، اسلام آباد' : 'G-8/3, Islamabad',
    phone: '+92519261170',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'اینڈو کرائنولوجی اور جنرل' : 'Endocrinology & General',
    lat: 33.7088,
    lng: 73.0560,
  ),
  _Clinic(
    name: isUrdu ? 'ہولی فیملی ہسپتال راولپنڈی' : 'Holy Family Hospital',
    address: isUrdu ? 'سیٹلائٹ ٹاؤن، راولپنڈی' : 'Satellite Town, Rawalpindi',
    phone: '+92519290321',
    type: 'government',
    cost: isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised',
    specialty: isUrdu ? 'جنرل اور ایمرجنسی' : 'General & Emergency',
    lat: 33.6338,
    lng: 73.0722,
  ),
  _Clinic(
    name: isUrdu ? 'شفا انٹرنیشنل ہسپتال' : 'Shifa International Hospital',
    address: isUrdu ? 'پطرس بخاری روڈ، ایچ-8/4، اسلام آباد' : 'Pitras Bukhari Rd, H-8/4, Islamabad',
    phone: '+92518464646',
    type: 'private',
    cost: isUrdu ? 'اعلیٰ لاگت' : 'High Cost',
    specialty: isUrdu ? 'ڈائیٹیٹکس اور اینڈوکرائنولوجی' : 'Dietetics & Endocrinology',
    lat: 33.6765,
    lng: 73.0827,
  ),
];

// ─────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────
class ClinicFinderScreen extends StatefulWidget {
  /// Pass the risk level so we can surface the right UI tone.
  final String riskLevel; // 'warning' | 'critical'

  const ClinicFinderScreen({super.key, this.riskLevel = 'warning'});

  @override
  State<ClinicFinderScreen> createState() => _ClinicFinderScreenState();
}

class _ClinicFinderScreenState extends State<ClinicFinderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _statusMessage = "Finding clinics near you...";

  List<_Clinic> _dynamicClinics = [];
  List<_Clinic> _regionalClinics = [];
  bool _usingDynamic = false;
  bool _locationError = false;
  double? _userLat;
  double? _userLng;

  bool get _isUrdu => LanguageController.instance.isUrdu;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _regionalClinics = _createInitialClinics(_isUrdu);
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    try {
      setState(() {
        _locationError = false;
        _isLoading = true;
        _statusMessage = _isUrdu ? "جی پی ایس لوکیشن چیک کی جا رہی ہے..." : "Accessing GPS location...";
      });

      // 1. Check & Request Location Permission natively
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useFallback(_isUrdu ? "لوکیشن کی اجازت نہیں ملی۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔" : "Location permission denied. Showing regional facilities.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useFallback(_isUrdu ? "لوکیشن مستقل طور پر بند ہے۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔" : "Location permission permanently denied. Showing regional facilities.");
        return;
      }

      // 2. Check if Location Services (GPS) are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _useFallback(_isUrdu ? "لوکیشن سروس بند ہے۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔" : "Location services disabled. Showing regional facilities.");
        return;
      }

      // 3. Fast coordinate acquisition (Try last known position first, then fresh)
      Position? position = await Geolocator.getLastKnownPosition();

      try {
        final freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        position = freshPos;
      } catch (_) {
        // If fresh lock times out indoors, proceed with last known position
      }

      if (position == null) {
        _useFallback(_isUrdu ? "جی پی ایس سگنل نہیں ملا۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔" : "Could not obtain GPS fix. Showing regional facilities.");
        return;
      }

      _userLat = position.latitude;
      _userLng = position.longitude;

      // Dynamically calculate and sort regional clinic distances based on user's real GPS
      _updateRegionalDistances(position.latitude, position.longitude);

      // 4. Fetch dynamic Overpass OpenStreetMap clinics within 7km
      setState(() {
        _statusMessage = _isUrdu ? "قریبی ہسپتال اور کلینک تلاش کیے جا رہے ہیں..." : "Discovering nearby clinics on OpenStreetMap...";
      });

      await _fetchOverpassClinics(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("[ClinicFinder] Error in location init: $e");
      _useFallback(_isUrdu ? "ہسپتال لوڈ کرنے میں خرابی۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔" : "Could not load dynamic clinics. Showing regional facilities.");
    }
  }

  void _updateRegionalDistances(double userLat, double userLng) {
    for (final clinic in _regionalClinics) {
      final distanceM = Geolocator.distanceBetween(
        userLat,
        userLng,
        clinic.lat,
        clinic.lng,
      );
      clinic.distanceMeters = distanceM;
      clinic.distance = _isUrdu
          ? '${(distanceM / 1000).toStringAsFixed(1)} کلومیٹر'
          : '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
    _regionalClinics.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  /// Sanitizes raw OpenStreetMap names so bilingual mixed text is cleanly separated
  String _sanitizeName(Map<String, dynamic> tags, bool isUrdu) {
    final nameEn = tags['name:en']?.toString().trim();
    final nameUr = tags['name:ur']?.toString().trim();
    final rawName = tags['name']?.toString().trim() ?? '';

    if (isUrdu) {
      if (nameUr != null && nameUr.isNotEmpty) return nameUr;

      // If rawName contains Urdu script, extract the clean Urdu portion
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(rawName)) {
        final urduClean = rawName
            .replaceAll(RegExp(r'[a-zA-Z]'), '')
            .replaceAll(RegExp(r'[\/\-—\|\,\.]+\s*$'), '')
            .replaceAll(RegExp(r'^\s*[\/\-—\|\,\.]+'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (urduClean.isNotEmpty) return urduClean;
      }

      // If only English, translate common medical descriptors
      if (rawName.isNotEmpty) {
        String urduTranslated = rawName;
        final dictionary = {
          'Hospital': 'ہسپتال',
          'Clinic': 'کلینک',
          'Doctor': 'ڈاکٹر',
          'Dr.': 'ڈاکٹر',
          'Medical': 'میڈیکل',
          'Center': 'سنٹر',
          'Centre': 'سنٹر',
          'Complex': 'کمپلیکس',
          'Care': 'کیئر',
          'Health': 'ہیلتھ',
          'Pharmacy': 'فارمیسی',
          'General': 'جنرل',
        };
        dictionary.forEach((en, ur) {
          urduTranslated = urduTranslated.replaceAll(RegExp(r'\b' + en + r'\b', caseSensitive: false), ur);
        });
        return urduTranslated.trim();
      }

      final amenity = tags['amenity'] ?? tags['healthcare'] ?? 'hospital';
      return amenity == 'hospital' ? 'قریبی ہسپتال' : 'قریبی کلینک';
    } else {
      // ── ENGLISH MODE ──────────────────────────────────────────
      if (nameEn != null && nameEn.isNotEmpty) return nameEn;

      // If rawName contains English characters, strip out the Urdu script cleanly
      if (RegExp(r'[a-zA-Z]').hasMatch(rawName)) {
        final latinPart = rawName
            .replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]'), '')
            .replaceAll(RegExp(r'[\/\-—\|\,\.]+\s*$'), '')
            .replaceAll(RegExp(r'^\s*[\/\-—\|\,\.]+'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Check if we have a valid name (more than 2 characters)
        if (latinPart.length >= 3) {
          return latinPart;
        }
      }

      // If rawName is purely in Urdu (no English in OSM tags), translate common terms
      if (rawName.isNotEmpty) {
        String enTranslated = rawName;
        final urduToEn = {
          'ڈاکٹر': 'Dr.',
          'ہسپتال': 'Hospital',
          'کلینک': 'Clinic',
          'میڈیکل': 'Medical',
          'سنٹر': 'Center',
          'سینٹر': 'Center',
          'کمپلیکس': 'Complex',
          'شفا': 'Shifa',
          'رفیع': 'Rafi',
          'فیملی': 'Family',
          'ہیلتھ': 'Health',
          'علی': 'Ali',
          'خان': 'Khan',
          'احمد': 'Ahmed',
          'فاطمہ': 'Fatima',
          'جناح': 'Jinnah',
          'سول': 'Civil',
          'خدمات': 'Services',
          'میو': 'Mayo',
        };
        urduToEn.forEach((ur, en) {
          enTranslated = enTranslated.replaceAll(ur, en);
        });

        // Strip single letter glitch prefixes like 's' or 'S'
        enTranslated = enTranslated.replaceAll(RegExp(r'^[a-zA-Z]\s*(?=[A-Z])'), '');
        enTranslated = enTranslated.replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]'), '');
        enTranslated = enTranslated.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (enTranslated.length >= 3) {
          return enTranslated;
        }
      }

      // Default clean fallback
      final amenity = tags['amenity'] ?? tags['healthcare'] ?? 'Medical Center';
      final amenityName = amenity == 'hospital' ? 'Hospital' : (amenity == 'clinic' ? 'Clinic' : 'Medical Center');
      final street = tags['addr:street'] ?? tags['addr:city'] ?? '';
      if (street.isNotEmpty) {
        return '$street $amenityName';
      }
      return 'Local $amenityName';
    }
  }

  /// Sanitizes raw address strings for language consistency
  String _sanitizeAddress(Map<String, dynamic> tags, double clat, double clng, bool isUrdu) {
    final street = tags['addr:street']?.toString() ?? '';
    final city = tags['addr:city']?.toString() ?? '';

    String address = [street, city].where((s) => s.isNotEmpty).join(', ');
    if (address.isNotEmpty) {
      if (isUrdu) {
        return address;
      } else {
        // In English mode, strip Urdu characters from address
        final cleanAddr = address
            .replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'[\,\/\-—]+\s*$'), '')
            .trim();
        if (cleanAddr.length >= 3) return cleanAddr;
      }
    }
    return isUrdu
        ? 'مقام: ${clat.toStringAsFixed(3)}, ${clng.toStringAsFixed(3)}'
        : 'Location: ${clat.toStringAsFixed(3)}, ${clng.toStringAsFixed(3)}';
  }

  Future<void> _fetchOverpassClinics(double lat, double lng) async {
    // Search Node, Way, and Relation with center coordinates within 7km
    final query = '''
[out:json][timeout:12];
(
  nwr["amenity"~"hospital|clinic|doctors"](around:7000, $lat, $lng);
  nwr["healthcare"~"hospital|clinic|doctor"](around:7000, $lat, $lng);
);
out center 30;
''';

    final endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
    ];

    List<dynamic>? elements;

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'NutriSenseHealthApp/1.0',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['elements'] as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            elements = list;
            break; // Succeeded!
          }
        }
      } catch (e) {
        debugPrint("[ClinicFinder] Overpass endpoint $endpoint failed: $e");
      }
    }

    if (elements == null || elements.isEmpty) {
      _useFallback(_isUrdu
          ? "قریبی ہسپتال اوپن اسٹریٹ میپ پر نہیں ملے۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔"
          : "No OSM clinics found in 7km. Showing nearest verified facilities.");
      return;
    }

    final List<_Clinic> fetched = [];
    final Set<String> seenNames = {};

    for (final el in elements) {
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};

      // Extract coordinates: handles both Point Nodes and Way/Relation polygons
      double? clat;
      double? clng;

      if (el['lat'] != null && el['lon'] != null) {
        clat = (el['lat'] as num).toDouble();
        clng = (el['lon'] as num).toDouble();
      } else if (el['center'] != null) {
        clat = (el['center']['lat'] as num?)?.toDouble();
        clng = (el['center']['lon'] as num?)?.toDouble();
      }

      if (clat == null || clng == null) continue;

      // Clean and language-appropriate name & address
      final name = _sanitizeName(tags, _isUrdu);
      final address = _sanitizeAddress(tags, clat, clng, _isUrdu);

      final cleanKey = name.trim().toLowerCase();
      if (seenNames.contains(cleanKey)) continue;
      seenNames.add(cleanKey);

      final distanceM = Geolocator.distanceBetween(lat, lng, clat, clng);
      final distStr = _isUrdu
          ? '${(distanceM / 1000).toStringAsFixed(1)} کلومیٹر'
          : '${(distanceM / 1000).toStringAsFixed(1)} km';

      // Clinical tier identification for Pakistani & International healthcare
      String type = 'private';
      String cost = _isUrdu ? 'درمیانی لاگت' : 'Medium Cost';
      final lName = (tags['name'] ?? '').toString().toLowerCase();

      final isGov = lName.contains('government') ||
          lName.contains('govt') ||
          lName.contains('civil') ||
          lName.contains('jinnah') ||
          lName.contains('mayo') ||
          lName.contains('services') ||
          lName.contains('dhq') ||
          lName.contains('thq') ||
          lName.contains('basic health') ||
          lName.contains('bhu') ||
          lName.contains('rhu') ||
          lName.contains('pims') ||
          tags['operator:type'] == 'government' ||
          tags['fee'] == 'no';

      if (isGov) {
        type = 'government';
        cost = _isUrdu ? 'مفت / رعایتی' : 'Free / Subsidised';
      }

      final phone = tags['phone'] ?? tags['contact:phone'] ?? '';
      final isHospital = tags['amenity'] == 'hospital';
      final specialty = _isUrdu
          ? (isHospital ? 'جنرل ہسپتال' : 'کلینک اور طبی نگہداشت')
          : (isHospital ? 'General Hospital' : 'Clinic & Medical Care');

      fetched.add(_Clinic(
        name: name,
        address: address,
        phone: phone,
        type: type,
        cost: cost,
        distance: distStr,
        distanceMeters: distanceM,
        specialty: specialty,
        lat: clat,
        lng: clng,
      ));
    }

    if (fetched.isEmpty) {
      _useFallback(_isUrdu
          ? "درست لوکیشن نہیں مل سکی۔ تصدیق شدہ ہسپتال دکھائے جا رہے ہیں۔"
          : "No valid clinic coordinates. Showing nearest verified facilities.");
      return;
    }

    fetched.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (mounted) {
      setState(() {
        _dynamicClinics = fetched;
        _usingDynamic = true;
        _isLoading = false;
      });
    }
  }

  void _useFallback(String msg) {
    if (mounted) {
      setState(() {
        _usingDynamic = false;
        _isLoading = false;
        _locationError = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_Clinic> get _governmentClinics {
    final list = _usingDynamic ? _dynamicClinics : _regionalClinics;
    return list.where((c) => c.type == 'government').toList();
  }

  List<_Clinic> get _privateClinics {
    final list = _usingDynamic ? _dynamicClinics : _regionalClinics;
    return list.where((c) => c.type == 'private').toList();
  }

  Future<void> _call(BuildContext ctx, String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(_isUrdu ? 'اس ہسپتال کا فون نمبر درج نہیں ہے' : 'Phone number not listed for this facility'),
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(_isUrdu ? 'اس ڈیوائس پر ڈائلر نہیں کھل سکا' : 'Cannot open dialer on this device'),
          ),
        );
      }
    }
  }

  Future<void> _directions(
      BuildContext ctx, double lat, double lng, String name) async {
    final encoded = Uri.encodeComponent(name);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(_isUrdu ? 'اس ڈیوائس پر گوگل میپس نہیں کھل سکا' : 'Cannot open Maps on this device'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = widget.riskLevel == 'critical';
    final alertColor =
        isCritical ? Colors.red.shade400 : Colors.amber.shade400;
    final alertBg = isCritical
        ? Colors.red.shade900.withAlpha(40)
        : Colors.amber.shade900.withAlpha(40);

    final title = _isUrdu ? 'طبی مراکز اور ہسپتال' : 'Find Affordable Care';
    final govTab = _isUrdu ? 'سرکاری (مفت)' : 'Government (Free)';
    final privTab = _isUrdu ? 'پرائیویٹ' : 'Private';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade500,
                tabs: [
                  Tab(icon: const Icon(Icons.account_balance), text: govTab),
                  Tab(icon: const Icon(Icons.local_hospital), text: privTab),
                ],
              ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(_statusMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          : Column(
              children: [
                // ── Alert Banner ──────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: alertBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: alertColor.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCritical
                            ? Icons.warning_rounded
                            : Icons.health_and_safety,
                        color: alertColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isCritical
                              ? (_isUrdu
                                  ? 'صحت کے متعلق فوری علامات نوٹ کی گئی ہیں۔ براہ کرم جلد از جلد قریبی ڈاکٹر سے رجوع کریں۔'
                                  : 'A critical health pattern was detected. Please consult a physician as soon as possible.')
                              : (_isUrdu
                                  ? 'آپ کے ہیلتھ پروفائل سے مطابقت کے لیے مشورہ دیا جاتا ہے کہ غذائی ماہر یا ڈاکٹر سے رجوع کریں۔'
                                  : 'A health pattern was noticed that may conflict with your profile. Consider consulting a healthcare specialist.'),
                          style: TextStyle(
                              color: alertColor, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab Views ─────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildClinicList(_governmentClinics, theme),
                      _buildClinicList(_privateClinics, theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClinicList(List<_Clinic> clinics, ThemeData theme) {
    if (_locationError || clinics.isEmpty) {
      final isGovernmentTab = _tabController.index == 0;
      final fallbackList = _regionalClinics
          .where((c) => isGovernmentTab ? c.type == 'government' : c.type == 'private')
          .toList();

      final gpsTitle = _isUrdu ? 'براہ راست گوگل میپس سرچ' : 'Live GPS Search';
      final gpsSub = _isUrdu
          ? 'اپنی درست موجودہ لوکیشن پر تمام قریبی ہسپتال اور ایمرجنسی کلینکس دیکھنے کے لیے گوگل میپس کھولیں۔'
          : 'Launch Google Maps to view all verified medical clinics and emergency hospitals near your exact current location.';
      final mapsBtn = _isUrdu ? 'قریبی ہسپتال میپس پر کھولیں' : 'Open Google Maps Near Me';
      final dirHeader = _isUrdu
          ? 'تصدیق شدہ ہسپتالوں کی ڈائرکٹری (فاصلے کے مطابق):'
          : 'Verified Healthcare Directory (Sorted by Proximity):';

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: Color(0xFF00E676), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      gpsTitle,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  gpsSub,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: Text(mapsBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final lat = _userLat;
                      final lng = _userLng;
                      final Uri uri;
                      if (lat != null && lng != null) {
                        uri = Uri.parse('https://www.google.com/maps/search/hospital+clinic/@$lat,$lng,14z');
                      } else {
                        uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=hospital+clinic+near+me');
                      }
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              dirHeader,
              style: const TextStyle(
                  color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ...fallbackList.map((clinic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClinicCard(
                  clinic: clinic,
                  theme: theme,
                  isUrdu: _isUrdu,
                  onCall: () => _call(context, clinic.phone),
                  onDirections: () => _directions(
                      context, clinic.lat, clinic.lng, clinic.name),
                ),
              )),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: clinics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _ClinicCard(
        clinic: clinics[i],
        theme: theme,
        isUrdu: _isUrdu,
        onCall: () => _call(ctx, clinics[i].phone),
        onDirections: () =>
            _directions(ctx, clinics[i].lat, clinics[i].lng, clinics[i].name),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  CARD WIDGET
// ─────────────────────────────────────────────────────────────────
class _ClinicCard extends StatelessWidget {
  final _Clinic clinic;
  final ThemeData theme;
  final bool isUrdu;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _ClinicCard({
    required this.clinic,
    required this.theme,
    required this.isUrdu,
    required this.onCall,
    required this.onDirections,
  });

  Color get _costColor {
    if (clinic.cost.contains('Free') || clinic.cost.contains('مفت')) return Colors.green.shade400;
    if (clinic.cost.contains('Low') || clinic.cost.contains('کم')) return Colors.lightGreen.shade400;
    if (clinic.cost.contains('Medium') || clinic.cost.contains('درمیانی')) return Colors.amber.shade400;
    return Colors.red.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final callText = isUrdu ? 'کال کریں' : 'Call Now';
    final dirText = isUrdu ? 'راستہ دیکھیں' : 'Directions';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_hospital,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clinic.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      clinic.specialty,
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Info chips ───────────────────────────────
          Row(
            children: [
              _InfoChip(
                  icon: Icons.location_on,
                  label: clinic.distance,
                  color: Colors.blue.shade300),
              const SizedBox(width: 8),
              _InfoChip(
                  icon: Icons.attach_money,
                  label: clinic.cost,
                  color: _costColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  clinic.address,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Action buttons ───────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 15),
                  label: Text(callText, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade400,
                    side: BorderSide(
                        color: Colors.green.shade400.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions, size: 15),
                  label: Text(dirText, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.primary.withAlpha(30),
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SMALL CHIP
// ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
