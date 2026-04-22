import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('서버에 연결할 수 없습니다',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 6),
            Text(
              message.length > 80 ? '${message.substring(0, 80)}...' : message,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('다시 시도'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
