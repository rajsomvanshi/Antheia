import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../theme/interaction_system.dart';
import '../../state/memory_state.dart';
import '../../models/models.dart';
import '../memory_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Media Sub-View — Archival Cinema Gallery
//
// Shows both network photos and local cover thumbnails.
// Tapping a media item takes the user directly to the entry.
// ═══════════════════════════════════════════════════════════════

class MediaTab extends StatelessWidget {
  const MediaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<MemoryState>().entries;
    final colors = AppColors.of(context);

    // Collect all photo urls and thumbnail paths
    final List<_PhotoItem> photos = [];
    for (final entry in entries) {
      if (entry.thumbnailPath != null && entry.thumbnailPath!.trim().isNotEmpty) {
        photos.add(_PhotoItem(pathOrUrl: entry.thumbnailPath!, entry: entry));
      }
      for (final url in entry.photoUrls) {
        if (url.trim().isNotEmpty) {
          photos.add(_PhotoItem(pathOrUrl: url, entry: entry));
        }
      }
    }

    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 32, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Your visual archive\nwill grow here.',
              textAlign: TextAlign.center,
              style: AppType.of(context).bodySecondary,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isNetwork = photo.pathOrUrl.startsWith('http://') || photo.pathOrUrl.startsWith('https://');

        Widget imageWidget;
        if (isNetwork) {
          imageWidget = Image.network(
            photo.pathOrUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colors.surface,
              child: Icon(Icons.broken_image_outlined, color: colors.textTertiary),
            ),
          );
        } else {
          final file = File(photo.pathOrUrl);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colors.surface,
                child: Icon(Icons.broken_image_outlined, color: colors.textTertiary),
              ),
            );
          } else {
            imageWidget = Container(
              color: colors.surface,
              child: Icon(Icons.broken_image_outlined, color: colors.textTertiary),
            );
          }
        }

        return GestureDetector(
          onTap: () {
            AppHaptics.subtle();
            Navigator.push(
              context,
              AppTransitions.slideUp(MemoryDetailScreen(entry: photo.entry)),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                // Bottom gradient
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xBB000000)],
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      DateFormat('MMM d').format(photo.entry.createdAt),
                      style: AppType.of(context).small.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoItem {
  final String pathOrUrl;
  final JournalEntry entry;
  const _PhotoItem({required this.pathOrUrl, required this.entry});
}
