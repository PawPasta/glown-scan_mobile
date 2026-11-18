import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FaceScanGuide extends StatelessWidget {
  const FaceScanGuide({
    required this.preview,
    required this.isInitializing,
    required this.stableFrames,
    required this.stableFramesNeeded,
    required this.detectedFaceBounds,
    required this.isCapturing,
    required this.onTakePhoto,
    super.key,
  });

  final Widget preview;
  final bool isInitializing;
  final int stableFrames;
  final int stableFramesNeeded;
  final Rect? detectedFaceBounds;
  final bool isCapturing;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final faceIsStable = stableFrames >= stableFramesNeeded;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Face scan', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Centre your face inside the guide. Take the photo when you are ready.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  CustomPaint(
                    key: const ValueKey('faceScanGuidePainter'),
                    painter: FaceScanPainter(faceBounds: detectedFaceBounds),
                  ),
                  if (isInitializing)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ScanStatusCard(
            message: detectedFaceBounds == null
                ? 'Looking for one clear face…'
                : faceIsStable
                ? 'Face detected. You can take your photo.'
                : 'Face detected. Hold still…',
            progress: stableFrames / stableFramesNeeded,
          ),
          if (faceIsStable) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('faceScanTakePhotoButton'),
              onPressed: isCapturing ? null : onTakePhoto,
              icon: isCapturing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(isCapturing ? 'Taking photo…' : 'Take photo'),
            ),
          ],
        ],
      ),
    );
  }
}

class FaceScanPainter extends CustomPainter {
  const FaceScanPainter({this.faceBounds});

  final Rect? faceBounds;

  static const faceDetectedColor = Color(0xFF39E66B);

  static Rect guideOvalRect(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: size.width * .86,
    height: size.height * .90,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final oval = guideOvalRect(size);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      outside,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = AppTheme.paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final normalizedBounds = faceBounds;
    if (normalizedBounds != null) {
      final faceRect = Rect.fromLTRB(
        normalizedBounds.left * size.width,
        normalizedBounds.top * size.height,
        normalizedBounds.right * size.width,
        normalizedBounds.bottom * size.height,
      );
      final outline = RRect.fromRectAndRadius(
        faceRect,
        const Radius.circular(24),
      );
      canvas.drawRRect(
        outline,
        Paint()
          ..color = faceDetectedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FaceScanPainter oldDelegate) =>
      faceBounds != oldDelegate.faceBounds;
}

class _ScanStatusCard extends StatelessWidget {
  const _ScanStatusCard({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.sand,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.face_retouching_natural_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress.clamp(0, 1).toDouble()),
      ],
    ),
  );
}
