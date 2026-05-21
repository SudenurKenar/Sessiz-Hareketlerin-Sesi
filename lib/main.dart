import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'onnx_helper.dart';

List<CameraDescription> _availableCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _availableCameras = await availableCameras();
  } catch (e) {
    print("ERROR: Kamera listesi alınamadı: $e");
  }
  runApp(const SignLanguageApp());
}

class SignLanguageApp extends StatelessWidget {
  const SignLanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CameraTranslationScreen(),
    );
  }
}

class CameraTranslationScreen extends StatefulWidget {
  const CameraTranslationScreen({super.key});

  @override
  State<CameraTranslationScreen> createState() => _CameraTranslationScreenState();
}

class _CameraTranslationScreenState extends State<CameraTranslationScreen> {
  CameraController? _cameraController;
  final OnnxHelper _onnxHelper = OnnxHelper();

  String _result = "İşaret bekleniyor...";
  bool _isProcessing = false;
  bool _isCameraReady = false;
  CameraLensDirection _lens = CameraLensDirection.back;

  final List<String> _recentPredictions = [];
  static const int _windowSize = 4; // Kararlılık için biriktirilen son 4 tahmin
  int _frameCount = 0;
  static const int _skipFrames = 5; // 👑 Kasılmayı önlemek için her 5 karede bir çıkarım koşturuyoruz (Saniyede ~6 net kare)

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() => _isCameraReady = false);

    await _onnxHelper.initModel();

    if (_cameraController != null) {
      try { await _cameraController!.stopImageStream(); } catch (_) {}
      await _cameraController!.dispose();
      _cameraController = null;
    }

    if (_availableCameras.isEmpty) return;

    final cam = _availableCameras.firstWhere(
      (c) => c.lensDirection == _lens,
      orElse: () => _availableCameras.first,
    );

    final controller = CameraController(
      cam,
      ResolutionPreset.low,  // Performans optimizasyonu için en ideal çözünürlük
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });
    } catch (e) {
      print("ERROR: Kamera başlatılamadı: $e");
      return;
    }

    _cameraController!.startImageStream((CameraImage frame) {
      _frameCount++;
      if (_frameCount % _skipFrames != 0) return;
      if (_isProcessing || !_onnxHelper.isModelLoaded || _cameraController == null) return;

      _isProcessing = true;
      
      // Mikro görev kanalını kullanarak pikselleri hiç kopyalamadan C++ motoruna paslıyoruz
      Future.microtask(() {
        try {
          final prediction = _onnxHelper.processYuv420Image(frame);
          _updateResult(prediction);
        } finally {
          _isProcessing = false;
        }
      });
    });
  }

  /// Kayan pencere oylaması: Kararlılığı zirveye çıkaran mekanizma
  void _updateResult(String? prediction) {
    if (!mounted) return;

    if (prediction != null) {
      _recentPredictions.add(prediction);
      if (_recentPredictions.length > _windowSize) {
        _recentPredictions.removeAt(0);
      }
    } else {
      if (_recentPredictions.isNotEmpty) {
        _recentPredictions.removeAt(0);
      }
    }

    String newResult = "İşaret bekleniyor...";
    if (_recentPredictions.isNotEmpty) {
      final freq = <String, int>{};
      for (final p in _recentPredictions) {
        freq[p] = (freq[p] ?? 0) + 1;
      }
      final best = freq.entries.reduce((a, b) => a.value > b.value ? a : b);
      
      // Eğer aynı kelime havuzda en az 2 kez onaylanmışsa ekrana yansıtılır
      if (best.value >= 2) {
        newResult = best.key;
      }
    }

    if (newResult != _result && mounted) {
      setState(() => _result = newResult);
    }
  }

  void _toggleCamera() {
    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    _recentPredictions.clear();
    _init();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _onnxHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Tam Ekran Kamera Önizleme Alanı
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // Üst Başlık Paneli
          Positioned(
            top: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "CANLI İŞARET DİLİ TERCÜMANI",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      letterSpacing: 1.5, color: Colors.white70),
                ),
              ),
            ),
          ),

          // Kamera Yön Değiştirme Butonu (Ön/Arka)
          Positioned(
            top: 110, right: 20,
            child: FloatingActionButton.small(
              onPressed: _toggleCamera,
              backgroundColor: Colors.deepPurple.withOpacity(0.8),
              child: Icon(
                _lens == CameraLensDirection.back ? Icons.camera_front : Icons.camera_rear,
                color: Colors.white,
              ),
            ),
          ),

          // 👑 KRALİÇEMİZİN İSTEDİĞİ ŞIK ALT PANEL
          Positioned(
            bottom: 50, left: 25, right: 25,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.7), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Canlı Çeviri",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: _result == "İşaret bekleniyor..." ? Colors.white38 : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}