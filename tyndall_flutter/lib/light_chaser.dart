import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const _ink = Color(0xFF25241D);
const _muted = Color(0xFF77746A);
const _gold = Color(0xFFE7B91E);
const _paper = Color(0xFFF8F6EF);
const _line = Color(0xFFEAE3D0);

class LightChaserSession extends StatefulWidget {
  const LightChaserSession({super.key});

  @override
  State<LightChaserSession> createState() => _LightChaserSessionState();
}

class _LightChaserSessionState extends State<LightChaserSession> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _center;
  Position? _position;
  List<WeatherAnchor> _anchors = [];
  WeatherAnchor? _selectedAnchor;
  bool _loading = false;
  bool _chasing = false;
  bool _found = false;
  double? _distanceMeters;
  String? _error;
  final Set<String> _foundAnchorIds = {};

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _scanNearbyConditions() async {
    setState(() {
      _loading = true;
      _error = null;
      _chasing = false;
      _found = false;
    });
    await _positionSubscription?.cancel();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are turned off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required to find nearby anchors.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final center = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _position = position;
          _center = center;
        });
        _mapController.move(center, 12);
      }
      final anchors = await WeatherAnchorService.fetchNearby(center);
      if (!mounted) return;
      setState(() {
        _anchors = anchors;
        _selectedAnchor = anchors.isEmpty ? null : anchors.first;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectAnchor(WeatherAnchor anchor) {
    setState(() {
      _selectedAnchor = anchor;
      _chasing = false;
      _found = false;
      _distanceMeters = null;
    });
    _positionSubscription?.cancel();
    _mapController.move(anchor.point, 13);
  }

  Future<void> _startChase() async {
    final anchor = _selectedAnchor;
    final position = _position;
    if (anchor == null || position == null) return;
    await _positionSubscription?.cancel();
    setState(() {
      _chasing = true;
      _found = false;
    });
    _updateChasePosition(position);
    if (_found) return;
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
          ),
        ).listen(
          _updateChasePosition,
          onError: (Object error) {
            if (mounted) {
              setState(() => _error = 'Location tracking stopped: $error');
            }
          },
        );
  }

  void _updateChasePosition(Position position) {
    final anchor = _selectedAnchor;
    if (anchor == null || !mounted) return;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      anchor.point.latitude,
      anchor.point.longitude,
    );
    final found = distance <= 100;
    setState(() {
      _position = position;
      _distanceMeters = distance;
      if (found) {
        _found = true;
        _chasing = false;
        _foundAnchorIds.add(anchor.id);
      }
    });
    if (found) _positionSubscription?.cancel();
  }

  Future<void> _openDirections() async {
    final anchor = _selectedAnchor;
    if (anchor == null) return;
    final origin = _position;
    final route = origin == null
        ? '${anchor.point.latitude},${anchor.point.longitude}'
        : '${origin.latitude},${origin.longitude};${anchor.point.latitude},${anchor.point.longitude}';
    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': route,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 18,
                    22,
                    wide ? 32 : 18,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 28),
                      _title(),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 12, child: _mapPanel()),
                            const SizedBox(width: 18),
                            Expanded(flex: 8, child: _conditionsPanel()),
                          ],
                        )
                      else ...[
                        _mapPanel(),
                        const SizedBox(height: 14),
                        _conditionsPanel(),
                      ],
                      const SizedBox(height: 14),
                      _attribution(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.light_mode, color: _ink, size: 23),
      ),
      const SizedBox(width: 11),
      const Text(
        'LUMENMIND',
        style: TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      const Spacer(),
      const Icon(Icons.circle, color: _gold, size: 8),
      const SizedBox(width: 7),
      const Text(
        'LIGHTCHASER',
        style: TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ],
  );

  Widget _title() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Weather signals point to places worth exploring.',
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'LightChaser',
        style: TextStyle(
          color: _ink,
          fontFamily: 'Georgia',
          fontSize: 36,
          height: 1.08,
        ),
      ),
    ],
  );

  Widget _mapPanel() => Container(
    height: 470,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFE7E4D7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center ?? const LatLng(20, 0),
            initialZoom: _center == null ? 2 : 12,
            minZoom: 2,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.lumenmind.app',
              maxNativeZoom: 19,
            ),
            MarkerLayer(markers: _mapMarkers()),
            RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.https('www.openstreetmap.org', '/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_center == null && !_loading)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.48),
                ),
                child: const Center(
                  child: Text(
                    'Find your location to scan nearby conditions',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton.small(
            heroTag: 'scan-location',
            tooltip: _loading
                ? 'Scanning nearby conditions'
                : 'Find nearby anchors',
            onPressed: _loading ? null : _scanNearbyConditions,
            backgroundColor: _gold,
            foregroundColor: _ink,
            child: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
        if (_chasing || _found)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _found ? _gold : _ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _found ? 'LIGHT FOUND' : 'CHASE ACTIVE',
                style: TextStyle(
                  color: _found ? _ink : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  List<Marker> _mapMarkers() {
    final markers = _anchors.map((anchor) {
      final selected = anchor.id == _selectedAnchor?.id;
      final found = _foundAnchorIds.contains(anchor.id);
      return Marker(
        point: anchor.point,
        width: 74,
        height: 76,
        child: GestureDetector(
          onTap: () => _selectAnchor(anchor),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: selected ? 42 : 36,
                height: selected ? 42 : 36,
                decoration: BoxDecoration(
                  color: found ? _ink : _gold,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: selected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _ink.withValues(alpha: 0.2),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  found ? Icons.check : Icons.light_mode,
                  color: found ? _gold : _ink,
                  size: 19,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${anchor.score.round()}%',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
    final position = _position;
    if (position != null) {
      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF326DA8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _conditionsPanel() {
    final selected = _selectedAnchor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _PanelHeading(number: '01', title: 'Nearby anchors'),
                  ),
                  Text(
                    _anchors.isEmpty ? 'NO SCAN' : '${_anchors.length} FOUND',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (_error != null) ...[
                _Notice(icon: Icons.location_off_outlined, text: _error!),
                const SizedBox(height: 12),
              ],
              if (_anchors.isEmpty)
                const _Notice(
                  icon: Icons.wb_cloudy_outlined,
                  text:
                      'Scan your area to compare humidity, dew-point proximity, and visibility.',
                )
              else ...[
                _weatherStats(),
                const SizedBox(height: 14),
                if (selected != null) _selectedAnchorDetails(selected),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : selected == null
                      ? _scanNearbyConditions
                      : _chasing
                      ? _stopChase
                      : _startChase,
                  icon: Icon(
                    _chasing
                        ? Icons.stop_circle_outlined
                        : Icons.directions_walk,
                  ),
                  label: Text(
                    _loading
                        ? 'Scanning nearby conditions...'
                        : _chasing
                        ? 'Stop chase'
                        : selected == null
                        ? 'Find nearby anchors'
                        : 'Chase this anchor',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Open directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_anchors.isNotEmpty) ...[
          const SizedBox(height: 13),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeading(number: '02', title: 'Weather signals'),
                const SizedBox(height: 10),
                const Text(
                  'Candidate score ranks humid, near-saturated, low-visibility conditions. It does not detect aerosols or confirm a Tyndall effect.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _weatherStats() {
    final anchor = _selectedAnchor;
    if (anchor == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _WeatherStat(
            label: 'AIR TEMP',
            value: '${anchor.temperature.round()}°C',
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _WeatherStat(
            label: 'HUMIDITY',
            value: '${anchor.humidity.round()}%',
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _WeatherStat(
            label: 'VISIBILITY',
            value: _formatVisibility(anchor.visibility),
          ),
        ),
      ],
    );
  }

  Widget _selectedAnchorDetails(WeatherAnchor anchor) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Anchor ${_anchors.indexOf(anchor) + 1}',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${anchor.score.round()}% signal',
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Dew-point gap ${anchor.dewPointGap.toStringAsFixed(1)}°C · ${anchor.score >= 65 ? 'Elevated conditions' : 'Some conditions'}',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        if (_distanceMeters != null) ...[
          const SizedBox(height: 6),
          Text(
            _found
                ? 'Anchor reached. Look for a visible beam in a safe public area.'
                : 'Distance ${_formatDistance(_distanceMeters!)} · approach within 100 m to check in.',
            style: TextStyle(
              color: _found ? const Color(0xFF6A5514) : _muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _attribution() => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Icon(Icons.public, size: 15, color: _muted),
      const Text(
        'Map data © OpenStreetMap contributors',
        style: TextStyle(color: _muted, fontSize: 10),
      ),
      const Text('·', style: TextStyle(color: _muted, fontSize: 10)),
      InkWell(
        onTap: () => launchUrl(Uri.https('open-meteo.com', '/')),
        child: const Text(
          'Weather data by Open-Meteo',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ],
  );

  String _formatVisibility(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  void _stopChase() {
    _positionSubscription?.cancel();
    setState(() => _chasing = false);
  }
}

class WeatherAnchor {
  const WeatherAnchor({
    required this.id,
    required this.point,
    required this.temperature,
    required this.humidity,
    required this.dewPoint,
    required this.visibility,
    required this.score,
  });

  final String id;
  final LatLng point;
  final double temperature;
  final double humidity;
  final double dewPoint;
  final double visibility;
  final double score;

  double get dewPointGap => math.max(0, temperature - dewPoint);
}

class WeatherAnchorService {
  static Future<List<WeatherAnchor>> fetchNearby(LatLng center) async {
    const offsets = [
      [0, 0],
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];
    final longitudeScale = math
        .cos(center.latitude * math.pi / 180)
        .abs()
        .clamp(0.2, 1.0);
    final points = offsets.map((offset) {
      final latitude = (center.latitude + offset[0] * 0.025)
          .clamp(-85.0, 85.0)
          .toDouble();
      final longitude = (center.longitude + offset[1] * 0.025 / longitudeScale)
          .clamp(-180.0, 180.0)
          .toDouble();
      return LatLng(latitude, longitude);
    }).toList();
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': points
          .map((point) => point.latitude.toStringAsFixed(4))
          .join(','),
      'longitude': points
          .map((point) => point.longitude.toStringAsFixed(4))
          .join(','),
      'current': 'temperature_2m,relative_humidity_2m,dew_point_2m,visibility',
      'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
        'Weather service returned status ${response.statusCode}.',
      );
    }
    final payload = jsonDecode(response.body);
    final locations = payload is List ? payload : [payload];
    if (locations.length != points.length) {
      throw const FormatException(
        'Weather service returned incomplete nearby data.',
      );
    }
    final anchors = <WeatherAnchor>[];
    for (var index = 0; index < points.length; index++) {
      final location = Map<String, dynamic>.from(locations[index] as Map);
      final current = Map<String, dynamic>.from(location['current'] as Map);
      double read(String key) => (current[key] as num).toDouble();
      final temperature = read('temperature_2m');
      final humidity = read('relative_humidity_2m');
      final dewPoint = read('dew_point_2m');
      final visibility = read('visibility');
      anchors.add(
        WeatherAnchor(
          id: '${points[index].latitude.toStringAsFixed(4)},${points[index].longitude.toStringAsFixed(4)}',
          point: points[index],
          temperature: temperature,
          humidity: humidity,
          dewPoint: dewPoint,
          visibility: visibility,
          score: weatherOpportunityScore(
            humidity: humidity,
            temperature: temperature,
            dewPoint: dewPoint,
            visibility: visibility,
          ),
        ),
      );
    }
    anchors.sort((a, b) => b.score.compareTo(a.score));
    return anchors.take(6).toList(growable: false);
  }
}

double weatherOpportunityScore({
  required double humidity,
  required double temperature,
  required double dewPoint,
  required double visibility,
}) {
  final humiditySignal = (humidity / 100).clamp(0.0, 1.0).toDouble();
  final dewGap = (temperature - dewPoint).clamp(0.0, 10.0).toDouble();
  final dewPointSignal = 1 - dewGap / 10;
  final visibilitySignal =
      1 - (visibility.clamp(0.0, 8000.0).toDouble() / 8000);
  return (humiditySignal * 0.5 +
          dewPointSignal * 0.35 +
          visibilitySignal * 0.15) *
      100;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: const TextStyle(
          color: _gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
