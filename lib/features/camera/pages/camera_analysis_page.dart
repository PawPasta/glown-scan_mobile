import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../premium/widgets/premium_required_view.dart';
import '../services/skin_analysis_api.dart';

class CameraAnalysisPage extends StatefulWidget {
  const CameraAnalysisPage({this.skinAnalysisApi, super.key});
  final SkinAnalysisApi? skinAnalysisApi;

  @override
  State<CameraAnalysisPage> createState() => _CameraAnalysisPageState();
}

enum _CameraStage { scanning, review, analyzing, result, error }

class _CameraAnalysisPageState extends State<CameraAnalysisPage> {
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  static const _stableFramesToCapture = 6;

  FaceDetector? _faceDetector;
  CameraController? _cameraController;
  SkinAnalysisApi? _ownedSkinAnalysisApi;
  SkinAnalysisApi get _skinAnalysisApi =>
      widget.skinAnalysisApi ?? (_ownedSkinAnalysisApi ??= SkinAnalysisApi());
  _CameraStage _stage = _CameraStage.scanning;
  bool _isInitializing = true;
  bool _isProcessingImage = false;
  bool _isCapturing = false;
  int _stableFaceFrames = 0;
  String? _errorMessage;
  XFile? _capturedImage;
  Uint8List? _capturedBytes;
  String? _analysisJson;
  bool _analysisRequiresPremium = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) unawaited(controller.dispose());
    final detector = _faceDetector;
    if (detector != null) unawaited(detector.close());
    _ownedSkinAnalysisApi?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _stage = _CameraStage.scanning;
        _isInitializing = true;
        _errorMessage = null;
        _stableFaceFrames = 0;
      });
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      _setError('Live face scanning is currently available on Android.');
      return;
    }
    try {
      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('No camera is available on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final oldController = _cameraController;
      if (oldController != null) await oldController.dispose();
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      _cameraController = controller;
      await controller.initialize();
      if (!mounted) {
        return;
      }
      await controller.startImageStream(_processCameraImage);
      if (mounted) setState(() => _isInitializing = false);
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (error) {
      _setError('Could not start the camera: $error');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || _isCapturing || _stage != _CameraStage.scanning) {
      return;
    }
    final controller = _cameraController;
    final detector = _faceDetector;
    if (controller == null || detector == null) return;
    final inputImage = _inputImageFromCameraImage(image, controller);
    if (inputImage == null) return;
    _isProcessingImage = true;
    try {
      final faces = await detector.processImage(inputImage);
      if (!mounted || _stage != _CameraStage.scanning) return;
      final validFace =
          faces.length == 1 && _faceIsLargeEnough(faces.single, image);
      _stableFaceFrames = validFace ? _stableFaceFrames + 1 : 0;
      if (_stableFaceFrames >= _stableFramesToCapture) {
        unawaited(_captureAutomatically());
      } else {
        setState(() {});
      }
    } catch (error) {
      _setError('Face detection failed: $error');
    } finally {
      _isProcessingImage = false;
    }
  }

  bool _faceIsLargeEnough(Face face, CameraImage image) =>
      face.boundingBox.width / image.width >= 0.25 &&
      face.boundingBox.height / image.height >= 0.25;

  Future<void> _captureAutomatically() async {
    if (_isCapturing || !mounted) return;
    _isCapturing = true;
    try {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;
      await controller.stopImageStream();
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedImage = image;
        _capturedBytes = bytes;
        _stage = _CameraStage.review;
        _stableFaceFrames = 0;
      });
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (error) {
      _setError('Could not capture the photo: $error');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _retake() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initializeCamera();
      return;
    }
    setState(() {
      _capturedImage = null;
      _capturedBytes = null;
      _analysisJson = null;
      _analysisRequiresPremium = false;
      _errorMessage = null;
      _stage = _CameraStage.scanning;
      _stableFaceFrames = 0;
    });
    try {
      await controller.startImageStream(_processCameraImage);
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    }
  }

  Future<void> _analyze() async {
    final image = _capturedImage;
    if (image == null) return;
    final consent = await _requestConsent();
    if (!consent || !mounted) return;
    setState(() => _stage = _CameraStage.analyzing);
    try {
      var result = await _skinAnalysisApi.analyze(image, consentAccepted: true);
      for (var attempt = 0; !result.isComplete && attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        result = await _skinAnalysisApi.getStatus(result.id);
      }
      if (!result.isComplete) {
        throw const ApiException(
          'Analysis is still running. Check your analysis history in a moment.',
        );
      }
      if (result.status == 'FAILED') {
        throw ApiException(
          'GlowScan AI could not complete this analysis${result.errorCode == null ? '.' : ': ${result.errorCode}'}',
        );
      }
      final json = const JsonEncoder.withIndent('  ').convert(result.result);
      if (!mounted) return;
      setState(() {
        _analysisJson = json;
        _analysisRequiresPremium = result.requiresPremium;
        _stage = _CameraStage.result;
      });
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('GlowScan AI could not analyze this photo: $error');
    }
  }

  Future<bool> _requestConsent() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use your face photo?'),
          content: const Text(
            'GlowScan will store this face photo with Cloudinary and send it to Gemini to create your skin analysis. It is not medical advice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I agree'),
            ),
          ],
        ),
      ) ??
      false;

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
      _isInitializing = false;
      _stage = _CameraStage.error;
    });
  }

  String _cameraErrorMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' =>
      'Camera permission was denied. Allow camera access and try again.',
    'CameraAccessDeniedWithoutPrompt' => 'Camera permission is disabled. Enable it in Android Settings and try again.',
    'CameraAccessRestricted' => 'Camera access is restricted on this device.',
    _ => 'Could not use the camera: $error',
  };

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    if (image.format.group != ImageFormatGroup.nv21 ||
        image.planes.length != 1) {
      return null;
    }
    final orientation = _orientations[controller.value.deviceOrientation];
    if (orientation == null) return null;
    final camera = controller.description;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + orientation) % 360
        : (camera.sensorOrientation - orientation + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format != InputImageFormat.nv21) return null;
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _CameraStage.review => _ReviewView(
      imageBytes: _capturedBytes!,
      onRetake: _retake,
      onAnalyze: _analyze,
    ),
    _CameraStage.analyzing => const _AnalyzingView(),
    _CameraStage.result => _ResultView(
      json: _analysisJson ?? 'null',
      requiresPremium: _analysisRequiresPremium,
      onNewScan: _retake,
    ),
    _CameraStage.error => _ErrorView(
      message: _errorMessage ?? 'The camera is unavailable.',
      onRetry: _initializeCamera,
    ),
    _CameraStage.scanning => _ScanningView(
      controller: _cameraController,
      isInitializing: _isInitializing,
      stableFrames: _stableFaceFrames,
      stableFramesNeeded: _stableFramesToCapture,
    ),
  };
}

class _ScanningView extends StatelessWidget {
  const _ScanningView({
    required this.controller,
    required this.isInitializing,
    required this.stableFrames,
    required this.stableFramesNeeded,
  });
  final CameraController? controller;
  final bool isInitializing;
  final int stableFrames;
  final int stableFramesNeeded;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Face scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Centre one face inside the oval. We will capture it automatically.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (controller != null && controller!.value.isInitialized)
                  CameraPreview(controller!)
                else
                  const ColoredBox(color: AppTheme.sand),
                const CustomPaint(painter: _FaceOvalPainter()),
                if (isInitializing)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatusCard(
          icon: Icons.face_retouching_natural_outlined,
          message: stableFrames == 0
              ? 'Looking for one clear face…'
              : 'Face detected. Hold still…',
          progress: stableFrames / stableFramesNeeded,
        ),
      ],
    ),
  );
}

class _FaceOvalPainter extends CustomPainter {
  const _FaceOvalPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .62,
      height: size.height * .72,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      outside,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = AppTheme.paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.imageBytes,
    required this.onRetake,
    required this.onAnalyze,
  });
  final Uint8List imageBytes;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review your photo',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Use this photo for your skin analysis, or take it again.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(imageBytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAnalyze,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analyze with GlowScan AI'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetake, child: const Text('Retake photo')),
      ],
    ),
  );
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'GlowScan AI is analyzing your skin…',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'This can take a minute. Please keep the app open.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.json,
    required this.requiresPremium,
    required this.onNewScan,
  });
  final String json;
  final bool requiresPremium;
  final VoidCallback onNewScan;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        requiresPremium ? 'Your skin summary' : 'Analysis response',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      if (requiresPremium) ...[
        const Text(
          'Your quality result and overall summary are ready. Upgrade to access detailed metrics and observations.',
        ),
        const SizedBox(height: 16),
        const PremiumRequiredView(
          feature: 'detailed skin insights',
          compact: true,
        ),
        const SizedBox(height: 24),
      ],
      const Text('Raw JSON returned by the API:'),
      const SizedBox(height: 16),
      SelectableText(
        json,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: onNewScan,
        child: const Text('Start a new scan'),
      ),
    ],
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    required this.progress,
  });
  final IconData icon;
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
            Icon(icon, color: AppTheme.deepRose),
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
