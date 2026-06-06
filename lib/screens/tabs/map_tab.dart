import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../../state/memory_state.dart';
import '../../state/preferences_state.dart';
import '../../models/models.dart';
import '../paywall_screen.dart';
import '../memory_detail_screen.dart';
import '../../services/outbox_service.dart';
import '../../services/paywall_service.dart';
import '../../widgets/locked_overlay.dart';
import '../paywall_sheet.dart';

// ═══════════════════════════════════════════════════════════════
// Map Sub-View — Memory Geography
//
// Displaying locations as the physical geography of the user's life.
// Abstract, clean coordinates overlay, complete with semantic geochapters.
// ═══════════════════════════════════════════════════════════════

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSubscription;
  AnimationController? _moveController;
  bool _mapReady = false;
  List<LocationMemory>? _lastLocations;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _startLocationUpdates();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _startLocationUpdates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen((Position pos) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (_) {}
  }

  void _animatedMove(LatLng dest, double zoom) {
    if (!_mapReady) return;
    try {
      final camera = _mapController.camera;
      final latTween = Tween<double>(begin: camera.center.latitude, end: dest.latitude);
      final lngTween = Tween<double>(begin: camera.center.longitude, end: dest.longitude);
      final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);
      
      _moveController?.dispose();
      final ctrl = AnimationController(duration: AppTransitions.long, vsync: this);
      _moveController = ctrl;
      
      final curve = CurvedAnimation(parent: ctrl, curve: AppTransitions.standard);
      ctrl.addListener(() {
        if (!mounted) return;
        _mapController.move(
          LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
          zoomTween.evaluate(curve),
        );
      });
      ctrl.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          ctrl.dispose();
          if (_moveController == ctrl) {
            _moveController = null;
          }
        }
      });
      ctrl.forward();
    } catch (e) {
      debugPrint('[MapTab] Move error: $e');
    }
  }

  void _fitMapToBounds(List<LocationMemory> locations) {
    if (!_mapReady || locations.isEmpty) return;
    try {
      if (locations.length == 1) {
        _animatedMove(LatLng(locations.first.latitude, locations.first.longitude), 14.0);
      } else {
        final points = locations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MapTab] Fit bounds error: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _moveController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final locations = context.watch<MemoryState>().locations;
    final isPremium = context.watch<PreferencesState>().isPremium;
    final displayedLocations = isPremium ? locations : locations.take(5).toList();
    
    // Auto-fit bounds on initial load and when locations change
    if (_mapReady && displayedLocations.isNotEmpty) {
      final currentKeys = displayedLocations.map((l) => '${l.latitude},${l.longitude}').join('|');
      final lastKeys = _lastLocations?.map((l) => '${l.latitude},${l.longitude}').join('|') ?? '';
      if (currentKeys != lastKeys) {
        _lastLocations = List.from(displayedLocations);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fitMapToBounds(displayedLocations);
          }
        });
      }
    }

    final center = _currentLocation ?? (displayedLocations.isNotEmpty
        ? LatLng(
            displayedLocations.map((l) => l.latitude).reduce((a, b) => a + b) / displayedLocations.length,
            displayedLocations.map((l) => l.longitude).reduce((a, b) => a + b) / displayedLocations.length,
          )
        : const LatLng(20.5937, 78.9629));

    final bodyContent = Stack(
      children: [
        // Fullscreen dark map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: _currentLocation != null ? 14.0 : 5.0,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            onMapReady: () {
              setState(() {
                _mapReady = true;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              userAgentPackageName: 'com.lumina.antheia',
              maxZoom: 19,
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            MarkerLayer(
              markers: displayedLocations.map((loc) => Marker(
                point: LatLng(loc.latitude, loc.longitude),
                width: 24,
                height: 24,
                child: GestureDetector(
                  onTap: () => _showMemorySheet(context, loc, colors),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                      border: Border.all(color: colors.bg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
            SimpleAttributionWidget(
              source: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: colors.textSecondary.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),

        // Quiet Location count banner
        if (locations.isNotEmpty)
          Positioned(
            left: 20,
            top: 20,
            child: GestureDetector(
              onTap: isPremium ? null : () => PaywallSheet.show(context, ProFeature.mapView),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.bg.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.hairline, width: 0.5),
                ),
                child: Text(
                  isPremium
                      ? '${locations.length} ${locations.length == 1 ? 'place' : 'places'}'
                      : '${locations.length} places (5 shown) · Unlock Pro',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isPremium ? colors.text : colors.accent,
                  ),
                ),
              ),
            ),
          ),

        // Centered My Location floating coordinates target
        Positioned(
          right: 20,
          bottom: 20,
          child: GestureDetector(
            onTap: () {
              AppHaptics.subtle();
              if (_currentLocation != null) {
                _animatedMove(_currentLocation!, 15.0);
              } else {
                _determinePosition();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.bg.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.hairline, width: 0.5),
              ),
              child: Icon(Icons.my_location_outlined, size: 18, color: colors.text),
            ),
          ),
        ),

        // Geographic Life Chapters Banner (Future Premium Feature Overlay)
        if (locations.isNotEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: isPremium ? null : () => PaywallSheet.show(context, ProFeature.mapView),
                child: Container(
                  margin: const EdgeInsets.only(right: 60), // offset from location button
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.bg.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: colors.hairline, width: 0.5),
                  ),
                  child: Text(
                    isPremium
                        ? 'Geographic Life Chapters are unfolding.'
                        : 'Unlock full life geography & chapters with Antheia Pro →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Empty state overlay
        if (locations.isEmpty)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 42),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.bg.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.hairline, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 28, color: colors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No places yet',
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Journal with location enabled to see your memory map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final paywall = context.watch<PaywallService>();
    final isGated = paywall.checkGate(ProFeature.mapView) != null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: isGated
          ? LockedOverlay(feature: ProFeature.mapView, child: bodyContent)
          : bodyContent,
    );
  }

  void _showMemorySheet(
    BuildContext context,
    LocationMemory loc,
    ResolvedColors colors,
  ) {
    final memoryState = context.read<MemoryState>();
    if (memoryState.entries.isEmpty) return;
    final entry = memoryState.entries.firstWhere(
      (e) => e.latitude == loc.latitude && e.longitude == loc.longitude,
      orElse: () => memoryState.entries.firstWhere(
        (e) => e.title == loc.latestEntry,
        orElse: () => memoryState.entries.first,
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: colors.hairline, width: 0.5),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(loc.icon, size: 20, color: colors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.name,
                                style: TextStyle(
                                  fontFamily: 'Cormorant Garamond',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${loc.entryCount} reflection${loc.entryCount == 1 ? '' : 's'} captured  ·  Latest: ${loc.latestEntry}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showEditLocation(context, entry);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.edit_location_alt_outlined,
                              size: 20, color: colors.textSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            AppTransitions.slideUp(MemoryDetailScreen(entry: entry)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: colors.textFaint),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PaywallScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  void _showEditLocation(BuildContext context, JournalEntry entry) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit location', style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 22,
              color: colors.text,
              fontWeight: FontWeight.w500,
            )),
            const SizedBox(height: 20),
            // Use current location
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.my_location_rounded, color: colors.accent),
              title: Text('Use my current location',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colors.text)),
              onTap: () async {
                Navigator.pop(context);
                final loc = await _captureCurrentLocation();
                if (loc == null) return;
                final updated = entry.copyWith(
                  latitude: loc.lat,
                  longitude: loc.lng,
                  locationLabel: loc.label,
                );
                await context.read<MemoryState>().updateEntry(updated);
                unawaited(OutboxService().processQueue());
                setState(() {});
              },
            ),
            const Divider(),
            // Remove location
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_off_outlined, color: Colors.redAccent),
              title: const Text('Remove location',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final updated = entry.copyWith(
                  clearLocation: true,
                );
                await context.read<MemoryState>().updateEntry(updated);
                unawaited(OutboxService().processQueue());
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<LatLngLabel?> _captureCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final place = placemarks.firstOrNull;
      final label = [place?.locality, place?.administrativeArea]
          .where((s) => s != null && s.isNotEmpty).join(', ');
      return LatLngLabel(pos.latitude, pos.longitude, label);
    } catch (e) {
      return null;
    }
  }
}

class LatLngLabel {
  final double lat, lng;
  final String label;
  LatLngLabel(this.lat, this.lng, this.label);
}
