import 'package:flutter/material.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.rose.s400.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: p.rose.s400.withValues(alpha: 0.25)),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: p.rose.s300,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '서버에 연결할 수 없습니다',
              style: AppText.body(
                p,
                size: 15,
                weight: FontWeight.w600,
                color: p.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.length > 80 ? '${message.substring(0, 80)}...' : message,
              style: AppText.body(p, size: 12, color: p.zinc.s400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('다시 시도'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
