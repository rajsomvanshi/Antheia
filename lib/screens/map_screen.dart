import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';

// ─── Internal data model for a pin derived from a journal entry ───────────────
class _EntryPin {
  final double lat;
  final double lon;
  final String title;
  final String mood;
  final DateTime date;
  final String snippet;

  const _EntryPin({
    required this.lat,
    required this.lon,
    required this.title,
    required this.mood,
    required this.date,
    required this.snippet,
  });
}

// ─── Mood emoji helper ────────────────────────────────────────────────────────
String _moodEmoji(String mood) {
  switch (mood.toLowerCase()) {
    case 'happy':
      return '😊';
    case 'excited':
      return '🤩';
    case 'calm':
      return '😌';
    case 'sad':
      return '😢';
    case 'anxious':
      return '😰';
    case 'angry':
      return '😠';
    case 'grateful':
      return '🙏';
    case 'neutral':
      return '😐';
    default:
      return '📍';
  }
}

// ─── MapScreen ────────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  int _selectedCardIndex = 0;

  // ── Parse entry pins from appState.entries ──────────────────────────────────
  List<_EntryPin> _derivePins(List<JournalEntry> entries) {
    final pins = <_EntryPin>[];
    for (final entry in entries) {
      if (entry.location == null || entry.location!.trim().isEmpty) continue;
      final parts = entry.location!.split(',');
      if (parts.length != 2) continue;
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat == null || lon == null) continue;
      pins.add(_EntryPin(
        lat: lat,
        lon: lon,
        title: entry.title,
        mood: entry.mood.name,
        date: entry.createdAt,
        snippet: entry.content.length > 120
            ? '${entry.content.substring(0, 120)}…'
            : entry.content,
      ));
    }
    return pins;
  }

  // ── Animate map to device location ─────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permission is permanently denied.')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        14.0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  // ── Show bottom sheet for a pin ─────────────────────────────────────────────
  void _showEntrySheet(_EntryPin pin) {
    final emoji = _moodEmoji(pin.mood);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(pin.date);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Mood row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pin.title,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${pin.mood[0].toUpperCase()}${pin.mood.substring(1)}  •  $dateStr',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                  height: 1),
              const SizedBox(height: 16),
              // Snippet
              Text(
                pin.snippet,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>(); // reactive
    final entryPins = _derivePins(appState.entries);
    final hasEntryPins = entryPins.isNotEmpty;
    final demoLocations = appState.locations;
    final hasDemoLocations = demoLocations.isNotEmpty;
    final showEmpty = !hasEntryPins && !hasDemoLocations;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: showEmpty
                  ? _buildEmptyState()
                  : Stack(
                      children: [
                        _buildMap(
                          entryPins: entryPins,
                          hasEntryPins: hasEntryPins,
                          demoLocations: demoLocations,
                        ),
                        // Gradient overlay at top
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF0D0E15)
                                        .withValues(alpha: 0.7),
                                    const Color(0xFF0D0E15)
                                        .withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Floating bottom cards
                        if (hasEntryPins)
                          _buildEntryCards(entryPins)
                        else
                          _buildDemoCards(demoLocations),
                        // Locate-me FAB
                        Positioned(
                          bottom: hasEntryPins
                              ? 160
                              : (hasDemoLocations ? 160 : 24),
                          right: 16,
                          child: _buildLocateButton(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memory Map',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your stories, placed in the world',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _goToMyLocation,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: AppColors.accentPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAP ────────────────────────────────────────────────────────────────────
  Widget _buildMap({
    required List<_EntryPin> entryPins,
    required bool hasEntryPins,
    required List<dynamic> demoLocations,
  }) {
    // Determine initial center
    LatLng center = const LatLng(20.5937, 78.9629); // India default
    if (hasEntryPins) {
      center = LatLng(entryPins.first.lat, entryPins.first.lon);
    } else if (demoLocations.isNotEmpty) {
      final first = demoLocations.first;
      center = LatLng(
        (first.lat as double?) ?? 20.5937,
        (first.lon as double?) ?? 78.9629,
      );
    }

    final markers = hasEntryPins
        ? _buildEntryMarkers(entryPins)
        : _buildDemoMarkers(demoLocations);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: hasEntryPins ? 10.0 : 5.5,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.lumina.flowjournal',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ─── ENTRY MARKERS ──────────────────────────────────────────────────────────
  List<Marker> _buildEntryMarkers(List<_EntryPin> pins) {
    return pins.map((pin) {
      final emoji = _moodEmoji(pin.mood);
      return Marker(
        point: LatLng(pin.lat, pin.lon),
        width: 56,
        height: 56,
        child: GestureDetector(
          onTap: () => _showEntrySheet(pin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentPrimary,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentPrimary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              // Pin tail
              Container(
                width: 3,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ─── DEMO MARKERS ───────────────────────────────────────────────────────────
  List<Marker> _buildDemoMarkers(List<dynamic> locations) {
    return locations.map((loc) {
      final lat = (loc.lat as double?) ?? 0.0;
      final lon = (loc.lon as double?) ?? 0.0;
      return Marker(
        point: LatLng(lat, lon),
        width: 48,
        height: 48,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentSecondary,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentSecondary.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Text('📍', style: TextStyle(fontSize: 18)),
          ),
        ),
      );
    }).toList();
  }

  // ─── LOCATE ME BUTTON ────────────────────────────────────────────────────────
  Widget _buildLocateButton() {
    return GestureDetector(
      onTap: _goToMyLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.navigation_rounded,
          color: AppColors.accentPrimary,
          size: 22,
        ),
      ),
    );
  }

  // ─── ENTRY FLOATING CARDS ───────────────────────────────────────────────────
  Widget _buildEntryCards(List<_EntryPin> pins) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: pins.length,
          itemBuilder: (context, i) {
            final pin = pins[i];
            final emoji = _moodEmoji(pin.mood);
            final dateStr = DateFormat('MMM d, yyyy').format(pin.date);
            final isSelected = _selectedCardIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCardIndex = i);
                _mapController.move(LatLng(pin.lat, pin.lon), 13.0);
                _showEntrySheet(pin);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary.withValues(alpha: 0.6)
                        : AppColors.accentPrimary.withValues(alpha: 0.12),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pin.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      pin.snippet,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── DEMO FLOATING CARDS ────────────────────────────────────────────────────
  Widget _buildDemoCards(List<dynamic> locations) {
    if (locations.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: locations.length,
          itemBuilder: (context, i) {
            final loc = locations[i];
            final isSelected = _selectedCardIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCardIndex = i);
                final lat = (loc.lat as double?) ?? 0.0;
                final lon = (loc.lon as double?) ?? 0.0;
                _mapController.move(LatLng(lat, lon), 12.0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentSecondary.withValues(alpha: 0.6)
                        : AppColors.accentSecondary.withValues(alpha: 0.12),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.name ?? 'Location',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.description ?? 'A memorable place',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Globe emoji
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Text('🗺️', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No memories mapped yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Journal with location enabled to see your stories placed on the map.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded,
                      color: AppColors.accentPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Enable location in journal entries',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
