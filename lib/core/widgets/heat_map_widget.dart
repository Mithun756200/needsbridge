import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

// Tamil Nadu bounds
const _tnCenter = LatLng(11.1271, 78.6569);
const _tnSW = LatLng(8.0, 76.2);
const _tnNE = LatLng(13.6, 80.4);

// Known Tamil Nadu city coordinates for geocoding fallback
const _tnCities = <String, LatLng>{
  'chennai':        LatLng(13.0827, 80.2707),
  'coimbatore':     LatLng(11.0168, 76.9558),
  'madurai':        LatLng(9.9252,  78.1198),
  'tiruchirappalli':LatLng(10.7905, 78.7047),
  'trichy':         LatLng(10.7905, 78.7047),
  'salem':          LatLng(11.6643, 78.1460),
  'tirunelveli':    LatLng(8.7139,  77.7567),
  'vellore':        LatLng(12.9165, 79.1325),
  'erode':          LatLng(11.3410, 77.7172),
  'thoothukudi':    LatLng(8.7642,  78.1348),
  'tuticorin':      LatLng(8.7642,  78.1348),
  'dindigul':       LatLng(10.3624, 77.9695),
  'thanjavur':      LatLng(10.7870, 79.1378),
  'ranipet':        LatLng(12.9279, 79.3329),
  'sivakasi':       LatLng(9.4533,  77.7997),
  'kanchipuram':    LatLng(12.8185, 79.6947),
  'kumbakonam':     LatLng(10.9617, 79.3788),
  'nagapattinam':   LatLng(10.7672, 79.8449),
  'ooty':           LatLng(11.4102, 76.6950),
  'kodaikanal':     LatLng(10.2381, 77.4892),
  'cuddalore':      LatLng(11.7480, 79.7714),
  'villupuram':     LatLng(11.9401, 79.4861),
  'pudukkottai':    LatLng(10.3797, 78.8214),
  'ramanathapuram': LatLng(9.3762,  78.8309),
  'virudhunagar':   LatLng(9.5851,  77.9624),
  'karur':          LatLng(10.9601, 78.0766),
  'namakkal':       LatLng(11.2189, 78.1674),
  'dharmapuri':     LatLng(12.1277, 78.1580),
  'krishnagiri':    LatLng(12.5186, 78.2137),
  'tiruppur':       LatLng(11.1085, 77.3411),
  'hosur':          LatLng(12.7409, 77.8253),
};

LatLng? _resolveLocation(String loc) {
  // Try GPS coords first
  final parts = loc.split(',');
  if (parts.length == 2) {
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  // Try city name match
  final lower = loc.toLowerCase();
  for (final entry in _tnCities.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

// ── HeatMapButton ─────────────────────────────────────────────────────────────
class HeatMapButton extends StatelessWidget {
  const HeatMapButton({super.key});

  void _open(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: const _HeatMapDialogContent(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1F2E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        onPressed: () => _open(context),
        icon: const Icon(Icons.whatshot_rounded, color: Colors.orange),
        label: const Text('View Heat Map', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Dialog Content ────────────────────────────────────────────────────────────
class _HeatMapDialogContent extends ConsumerStatefulWidget {
  const _HeatMapDialogContent();
  @override
  ConsumerState<_HeatMapDialogContent> createState() => _HeatMapDialogContentState();
}

class _HeatMapDialogContentState extends ConsumerState<_HeatMapDialogContent> {
  bool _isHistorical = false;

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final needsAsync = ref.watch(needsProvider);
    return Container(
      color: const Color(0xFF1A1F2E),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(children: [
            const Icon(Icons.whatshot_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(_isHistorical ? 'Historical Risk Zones — Tamil Nadu' : 'Active Issues — Tamil Nadu',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            _legendDot(NbColors.high, 'High'),
            const SizedBox(width: 8),
            _legendDot(NbColors.medium, 'Med'),
            const SizedBox(width: 8),
            _legendDot(NbColors.low, 'Low'),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: ChoiceChip(
              label: const Text('Active Emergencies', textAlign: TextAlign.center),
              selected: !_isHistorical,
              onSelected: (_) => setState(() => _isHistorical = false),
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              label: const Text('Historical Risk Zones', textAlign: TextAlign.center),
              selected: _isHistorical,
              onSelected: (_) => setState(() => _isHistorical = true),
            )),
          ]),
        ),
        SizedBox(
          height: 400,
          child: needsAsync.when(
            data: (needs) {
              final mapped = <Map<String, dynamic>>[];
              int fallbackIdx = 0;
              for (final need in needs) {
                final isResolved = need['status'] == 'Resolved';
                if (_isHistorical && !isResolved) continue;
                if (!_isHistorical && isResolved) continue;
                final loc = need['location']?.toString().trim() ?? '';
                final resolved = loc.isNotEmpty ? _resolveLocation(loc) : null;
                if (resolved != null) {
                  mapped.add({...need, '_lat': resolved.latitude, '_lng': resolved.longitude, '_hasGps': true});
                } else {
                  // Scatter within Tamil Nadu bounds
                  final rng = math.Random((need['id']?.hashCode ?? 0) ^ fallbackIdx);
                  mapped.add({...need,
                    '_lat': 8.5 + rng.nextDouble() * 4.8,
                    '_lng': 76.5 + rng.nextDouble() * 3.5,
                    '_hasGps': false});
                  fallbackIdx++;
                }
              }
              if (mapped.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.map_outlined, color: Colors.white.withAlpha(60), size: 48),
                  const SizedBox(height: 12),
                  const Text('No issues to display.', style: TextStyle(color: Colors.white54)),
                ]));
              }
              return _TamilNaduMap(points: mapped);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text('Tap a marker to navigate • Focused on Tamil Nadu',
                style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

// ── Tamil Nadu Map ────────────────────────────────────────────────────────────
class _TamilNaduMap extends StatefulWidget {
  final List<Map<String, dynamic>> points;
  const _TamilNaduMap({required this.points});
  @override
  State<_TamilNaduMap> createState() => _TamilNaduMapState();
}

class _TamilNaduMapState extends State<_TamilNaduMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _navigate(double lat, double lng, String title) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds(_tnSW, _tnNE),
              padding: const EdgeInsets.all(24),
            ),
            onTap: (_, __) => setState(() => _selected = null),
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.needsbridge.app',
            ),
            Container(color: Colors.black.withAlpha(100)),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => MarkerLayer(
                markers: widget.points.map((p) {
                  final priority = p['priority'] as int? ?? 3;
                  final color = priority == 1 ? NbColors.high : priority == 2 ? NbColors.medium : NbColors.low;
                  final latlng = LatLng(p['_lat'] as double, p['_lng'] as double);
                  final isSelected = _selected?['id'] == p['id'];
                  final size = isSelected ? 28.0 : 20.0;

                  return Marker(
                    point: latlng,
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = p),
                      child: Stack(alignment: Alignment.center, children: [
                        // Pulse ring
                        Container(
                          width: size * 2.5 * (1.0 + _pulse.value * 0.4),
                          height: size * 2.5 * (1.0 + _pulse.value * 0.4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withAlpha((60 - _pulse.value * 30).round().clamp(0, 255)),
                          ),
                        ),
                        // Core dot
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withAlpha(220),
                            border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.5),
                            boxShadow: [BoxShadow(color: color.withAlpha(160), blurRadius: 8, spreadRadius: 2)],
                          ),
                          child: Center(
                            child: Text(
                              priority == 1 ? 'H' : priority == 2 ? 'M' : 'L',
                              style: TextStyle(color: Colors.white, fontSize: isSelected ? 11 : 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        // Info popup when marker tapped
        if (_selected != null)
          Positioned(
            bottom: 12, left: 12, right: 12,
            child: Card(
              color: const Color(0xFF1E2435),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_selected!['title'] ?? '',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () => setState(() => _selected = null)),
                  ]),
                  if (_selected!['location'] != null)
                    Text('📍 ${_selected!['location']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _PriorityPill(_selected!['priority'] as int? ?? 3),
                    const SizedBox(width: 8),
                    if (_selected!['category'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.indigo.withAlpha(80), borderRadius: BorderRadius.circular(6)),
                        child: Text(_selected!['category'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NbColors.info,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _navigate(
                        _selected!['_lat'] as double,
                        _selected!['_lng'] as double,
                        _selected!['title'] ?? '',
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Navigate', style: TextStyle(fontSize: 13)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final int priority;
  const _PriorityPill(this.priority);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      1 => ('HIGH', NbColors.high),
      2 => ('MED',  NbColors.medium),
      _ => ('LOW',  NbColors.low),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
