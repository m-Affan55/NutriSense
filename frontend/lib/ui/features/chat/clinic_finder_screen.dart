import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
List<_Clinic> _createInitialClinics() => [
  // ── Government (Karachi) ──────────────────────────────────────
  _Clinic(
    name: 'Jinnah Postgraduate Medical Centre (JPMC)',
    address: 'Rafiqui H.J. Shaheed Rd, Karachi',
    phone: '+922199201050',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'General & Emergency',
    lat: 24.8607,
    lng: 67.0105,
  ),
  _Clinic(
    name: 'Civil Hospital Karachi',
    address: 'Baba-e-Urdu Rd, Karachi',
    phone: '+922199215740',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'Multi-specialty',
    lat: 24.8617,
    lng: 67.0082,
  ),
  _Clinic(
    name: 'Liaquat National Hospital (LNH)',
    address: 'Stadium Rd, Karachi',
    phone: '+922134412000',
    type: 'government',
    cost: 'Low Cost',
    specialty: 'Nutrition & Endocrinology',
    lat: 24.8933,
    lng: 67.0756,
  ),
  _Clinic(
    name: 'National Institute of Diabetes & Endocrinology (NIDE)',
    address: 'JPMC Campus, Rafiqui Rd, Karachi',
    phone: '+922199201111',
    type: 'government',
    cost: 'Free',
    specialty: 'Diabetes & Nutrition',
    lat: 24.8605,
    lng: 67.0110,
  ),

  // ── Private (Karachi) ─────────────────────────────────────────
  _Clinic(
    name: 'Aga Khan University Hospital (AKUH)',
    address: 'Stadium Rd, Karachi',
    phone: '+922134864000',
    type: 'private',
    cost: 'High Cost',
    specialty: 'Dietetics & Cardiology',
    lat: 24.8980,
    lng: 67.0800,
  ),
  _Clinic(
    name: 'South City Hospital',
    address: 'Dr. Ziauddin Ahmed Rd, Karachi',
    phone: '+922135205001',
    type: 'private',
    cost: 'Medium Cost',
    specialty: 'Nutrition & Cardiology',
    lat: 24.8438,
    lng: 67.0269,
  ),
  _Clinic(
    name: 'Indus Hospital',
    address: 'Korangi Crossing, Karachi',
    phone: '+922135112709',
    type: 'private',
    cost: 'Free (Charity)',
    specialty: 'Multi-specialty (Free)',
    lat: 24.8330,
    lng: 67.1180,
  ),
  _Clinic(
    name: 'Ziauddin Hospital (Clifton)',
    address: 'Block 6, Clifton, Karachi',
    phone: '+922135862937',
    type: 'private',
    cost: 'Medium Cost',
    specialty: 'Nutrition & Hypertension',
    lat: 24.8140,
    lng: 67.0300,
  ),

  // ── Government (Lahore) ───────────────────────────────────────
  _Clinic(
    name: 'Mayo Hospital Lahore',
    address: 'Hospital Rd, Anarkali Bazaar, Lahore',
    phone: '+924299211120',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'General & Emergency',
    lat: 31.5746,
    lng: 74.3130,
  ),
  _Clinic(
    name: 'Services Hospital Lahore',
    address: 'Jail Rd, Lahore',
    phone: '+924299203402',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'Multi-specialty',
    lat: 31.5414,
    lng: 74.3313,
  ),
  _Clinic(
    name: 'Jinnah Hospital Lahore',
    address: 'Usmani Rd, Faisal Town, Lahore',
    phone: '+924299231400',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'General & Emergency',
    lat: 31.4939,
    lng: 74.3113,
  ),

  // ── Private (Lahore) ──────────────────────────────────────────
  _Clinic(
    name: 'Shaukat Khanum Memorial Hospital',
    address: 'Johar Town, Lahore',
    phone: '+924235905000',
    type: 'private',
    cost: 'Charity / Subsidised',
    specialty: 'Specialized Care & Nutrition',
    lat: 31.4727,
    lng: 74.2693,
  ),

  // ── Islamabad / Rawalpindi ────────────────────────────────────
  _Clinic(
    name: 'Pakistan Institute of Medical Sciences (PIMS)',
    address: 'G-8/3, Islamabad',
    phone: '+92519261170',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'Endocrinology & General',
    lat: 33.7088,
    lng: 73.0560,
  ),
  _Clinic(
    name: 'Holy Family Hospital',
    address: 'Satellite Town, Rawalpindi',
    phone: '+92519290321',
    type: 'government',
    cost: 'Free / Subsidised',
    specialty: 'General & Emergency',
    lat: 33.6338,
    lng: 73.0722,
  ),
  _Clinic(
    name: 'Shifa International Hospital',
    address: 'Pitras Bukhari Rd, H-8/4, Islamabad',
    phone: '+92518464646',
    type: 'private',
    cost: 'High Cost',
    specialty: 'Dietetics & Endocrinology',
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _regionalClinics = _createInitialClinics();
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    try {
      setState(() {
        _locationError = false;
        _isLoading = true;
        _statusMessage = "Accessing GPS location...";
      });

      // 1. Check & Request Location Permission natively
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useFallback("Location permission denied. Showing regional facilities.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useFallback("Location permission permanently denied. Showing regional facilities.");
        return;
      }

      // 2. Check if Location Services (GPS) are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _useFallback("Location services disabled. Showing regional facilities.");
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
        _useFallback("Could not obtain GPS fix. Showing regional facilities.");
        return;
      }

      _userLat = position.latitude;
      _userLng = position.longitude;

      // Dynamically calculate and sort regional clinic distances based on user's real GPS
      _updateRegionalDistances(position.latitude, position.longitude);

      // 4. Fetch dynamic Overpass OpenStreetMap clinics within 7km
      setState(() {
        _statusMessage = "Discovering nearby clinics on OpenStreetMap...";
      });

      await _fetchOverpassClinics(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("[ClinicFinder] Error in location init: $e");
      _useFallback("Could not load dynamic clinics. Showing regional facilities.");
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
      clinic.distance = '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
    _regionalClinics.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
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
      _useFallback("No OSM clinics found in 7km. Showing nearest verified facilities.");
      return;
    }

    final List<_Clinic> fetched = [];
    final Set<String> seenNames = {};

    for (final el in elements) {
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      String name = tags['name'] ?? tags['name:en'] ?? tags['name:ur'] ?? '';

      if (name.trim().isEmpty) {
        final amenity = tags['amenity'] ?? tags['healthcare'] ?? 'Medical Center';
        name = 'Local $amenity';
      }

      final cleanName = name.trim().toLowerCase();
      if (seenNames.contains(cleanName)) continue;
      seenNames.add(cleanName);

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

      final distanceM = Geolocator.distanceBetween(lat, lng, clat, clng);
      final distStr = '${(distanceM / 1000).toStringAsFixed(1)} km';

      // Clinical tier identification for Pakistani & International healthcare
      String type = 'private';
      String cost = 'Medium Cost';
      final lName = name.toLowerCase();

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
        cost = 'Free / Subsidised';
      }

      final street = tags['addr:street'] ?? '';
      final city = tags['addr:city'] ?? '';
      String address = [street, city].where((s) => s.isNotEmpty).join(', ');
      if (address.isEmpty) {
        address = 'Coordinates: ${clat.toStringAsFixed(3)}, ${clng.toStringAsFixed(3)}';
      }

      final phone = tags['phone'] ?? tags['contact:phone'] ?? '';
      final specialty = tags['amenity'] == 'hospital'
          ? 'General Hospital'
          : 'Clinic & Medical Care';

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
      _useFallback("No valid clinic coordinates. Showing nearest verified facilities.");
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
        const SnackBar(content: Text('Phone number not listed for this facility')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Cannot open dialer on this device')),
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
          const SnackBar(content: Text('Cannot open Maps on this device')),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Find Affordable Care',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade500,
                tabs: const [
                  Tab(icon: Icon(Icons.account_balance), text: 'Government (Free)'),
                  Tab(icon: Icon(Icons.local_hospital), text: 'Private'),
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
                              ? 'A critical health pattern was detected. Please consult a physician as soon as possible.'
                              : 'A health pattern was noticed that may conflict with your profile. Consider consulting a healthcare specialist.',
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
                const Row(
                  children: [
                    Icon(Icons.near_me_rounded, color: Color(0xFF00E676), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live GPS Search',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Launch Google Maps to view all verified medical clinics and emergency hospitals near your exact current location.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
                    label: const Text('Open Google Maps Near Me',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Verified Healthcare Directory (Sorted by Proximity):',
              style: TextStyle(
                  color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ...fallbackList.map((clinic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClinicCard(
                  clinic: clinic,
                  theme: theme,
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
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _ClinicCard({
    required this.clinic,
    required this.theme,
    required this.onCall,
    required this.onDirections,
  });

  Color get _costColor {
    if (clinic.cost.contains('Free')) return Colors.green.shade400;
    if (clinic.cost.contains('Low')) return Colors.lightGreen.shade400;
    if (clinic.cost.contains('Medium')) return Colors.amber.shade400;
    return Colors.red.shade300;
  }

  @override
  Widget build(BuildContext context) {
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
                  label:
                      const Text('Call Now', style: TextStyle(fontSize: 12)),
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
                  label: const Text('Directions',
                      style: TextStyle(fontSize: 12)),
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
