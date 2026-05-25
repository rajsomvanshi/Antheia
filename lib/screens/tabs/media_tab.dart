import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/app_state.dart';

// ═══════════════════════════════════════════════════════════════
// MediaTab — Photo memories grid from journal entries
// ═══════════════════════════════════════════════════════════════

class MediaTab extends StatelessWidget {
  const MediaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().entries;

    // Collect all photo URLs across all entries
    final photos = <String>[];
    for (final e in entries) {
      if (e.photoUrls.isNotEmpty) {
        photos.addAll(e.photoUrls);
      }
    }

    if (photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No photos yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add photos to your journal entries\nto see them here',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final url = photos[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url.startsWith('http')
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, _) => Container(
                      color: AppColors.bgSecondary,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.bgSecondary,
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
