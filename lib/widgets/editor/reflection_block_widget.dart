import 'package:flutter/material.dart';
import '../../models/memory_block.dart';
import '../../theme/app_theme.dart';

class ReflectionBlockWidget extends StatelessWidget {
  final ReflectionBlock block;

  const ReflectionBlockWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.accentFaint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              block.content,
              style: AppType.body.copyWith(
                color: AppColors.accent,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
