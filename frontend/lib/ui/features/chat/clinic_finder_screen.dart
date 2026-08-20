import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────
class _Clinic {
  final String name;
  final String address;
  final String phone;
  final String type; // 'government' | 'private'
  final String cost;
  final String distance;
  final String specialty;
  final double lat;
  final double lng;

  const _Clinic({
    required this.name,
    required this.address,
    required this.phone,
    required this.type,
    required this.cost,
    required this.distance,
    required this.specialty,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────
//  REAL KARACHI CLINICS — curated list
// ─────────────────────────────────────────────────────────────────
const List<_Clinic> _allClinics = [
  // ── Government ───────────────────────────────────────────────
  _Clinic(
    name: 'Jinnah Postgraduate Medical Centre (JPMC)',
    address: 'Rafiqui H.J. Shaheed Rd, Karachi',
    phone: '+922199201050',
    type: 'government',
    cost: 'Free / Subsidised',
    distance: '4.1 km',
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
    distance: '3.8 km',
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
    distance: '5.2 km',
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
    distance: '4.1 km',
    specialty: 'Diabetes & Nutrition',
    lat: 24.8605,
    lng: 67.0110,
  ),

  // ── Private ──────────────────────────────────────────────────
  _Clinic(
    name: 'Aga Khan University Hospital (AKUH)',
    address: 'Stadium Rd, Karachi',
    phone: '+922134864000',
    type: 'private',
    cost: 'High Cost',
    distance: '5.5 km',
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
    distance: '6.2 km',
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
    distance: '9.1 km',
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
    distance: '7.4 km',
    specialty: 'Nutrition & Hypertension',
    lat: 24.8140,
    lng: 67.0300,
  ),
];

// ─────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────
class ClinicFinderScreen extends StatefulWidget {
  /// Pass the risk level so we can surface the right UI tone.
  final String riskLevel; // 'warning' | 'critical'

  const ClinicFinderScreen({super.key, required this.riskLevel});

  @override
  State<ClinicFinderScreen> createState() => _ClinicFinderScreenState();
}

class _ClinicFinderScreenState extends State<ClinicFinderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_Clinic> get _governmentClinics =>
      _allClinics.where((c) => c.type == 'government').toList();

  List<_Clinic> get _privateClinics =>
      _allClinics.where((c) => c.type == 'private').toList();

  Future<void> _call(BuildContext ctx, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
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
        bottom: TabBar(
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
      body: Column(
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
                        ? 'A critical health pattern was detected. Please consult a doctor as soon as possible. NutriSense does not diagnose — only recommend consultation.'
                        : 'A health pattern was noticed that may conflict with your medical conditions. Consider consulting a nutrition specialist or physician.',
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
