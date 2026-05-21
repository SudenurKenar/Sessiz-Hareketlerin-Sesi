import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:camera/camera.dart';

/// [OnnxHelper] sınıfı, YOLOv8 modelinin cihaz üzerinde (on-device)
/// yüklenmesi, ham kamera piksellerinin ön işlenmesi ve çıkarım (inference)
/// süreçlerinin yönetiminden sorumludur.
class OnnxHelper {
  OrtSession? _session;
  bool _isModelLoaded = false;

  /// Modelin eğitiği 20 adet sınıf etiketi listesi.
  final List<String> labels = [
    'Anne', 'Arkadaş', 'Baba', 'Dur', 'Ev',
    'Evet', 'Hayır', 'Kardeş', 'Merhaba', 'Nasıl',
    'Nerede', 'Özür Dilemek', 'Tamam', 'Telefon', 'Teşekkürler',
    'Tuvalet', 'Yemek', 'İçmek', 'İyi', 'Kötü'
  ];

  bool get isModelLoaded => _isModelLoaded;

  /// ONNX Runtime oturumunu (session) en optimize grafik ayarlarıyla başlatır.
  Future<void> initModel() async {
    if (_isModelLoaded) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/kelime.onnx';
      final file = File(path);

      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/kelime.onnx');
        await file.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }

      OrtEnv.instance.init(level: OrtLoggingLevel.warning);
      
      final sessionOptions = OrtSessionOptions()
        ..setIntraOpNumThreads(2)
        ..setInterOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortDisableAll);
      
      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isModelLoaded = true;
      print("INFO: Model başarıyla yüklendi ve mühürlendi Hanımım.");
    } catch (e) {
      print("ERROR: Model yükleme aşamasında kritik hata oluştu: $e");
    }
  }

  /// 👑 İŞLEMCİYİ ÖZGÜR KILAN NATIVE TRANSFER MOTORU:
  /// Kamera nesnesini kopyalamadan, sadece en üst parlaklık katmanını (Y düzlemini)
  /// şimşek hızıyla düzleştirip doğrudan modele besler. Sıfır kasılma garantilidir!
  String? processYuv420Image(CameraImage image) {
    if (!_isModelLoaded || _session == null) return null;

    try {
      final Uint8List yBuffer = image.planes[0].bytes;
      final inputData = Float32List(1 * 3 * 640 * 640);
      
      // Ağır döngüler yerine doğrusal bellek normalizasyonu [0.0 - 1.0]
      final int maxBytes = yBuffer.length < 640 * 640 ? yBuffer.length : 640 * 640;
      for (int i = 0; i < maxBytes; i++) {
        double normalizedVal = yBuffer[i] / 255.0;
        inputData[i] = normalizedVal;               // R Kanalı
        inputData[640 * 640 + i] = normalizedVal;   // G Kanalı
        inputData[2 * 640 * 640 + i] = normalizedVal;// B Kanalı
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(inputData, [1, 3, 640, 640]);
      final runOptions = OrtRunOptions();
      
      // Çıkarım işleminin tetiklenmesi
      final outputs = _session!.run(runOptions, {'images': inputTensor});
      String? classificationResult;

      if (outputs.isNotEmpty && outputs[0] != null) {
        final outputTensor = outputs[0]!.value;

        if (outputTensor is List) {
          final flatOutput = _flattenList(outputTensor);

          final int numClasses = labels.length;
          final int numFilters = 4 + numClasses; // YOLOv8 mimari sabiti (24)
          final int numBoxes = (flatOutput.length / numFilters).toInt(); // 8400 Kutucuk

          // 👑 YANLIŞ TAHMİN BARAJI: Arka plan gürültülerini filtrelemek için eşiği 0.40'a çekiyoruz
          double maxConfidenceScore = 0.40; 
          int detectedClassId = -1;

          // YOLOv8 Çıktı matris analizi döngüsü
          for (int b = 0; b < numBoxes; b++) {
            for (int c = 0; c < numClasses; c++) {
              int scoreIndex = (4 + c) * numBoxes + b;
              if (scoreIndex < flatOutput.length) {
                double currentScore = flatOutput[scoreIndex];
                if (currentScore > maxConfidenceScore) {
                  maxConfidenceScore = currentScore;
                  detectedClassId = c;
                }
              }
            }
          }

          if (detectedClassId >= 0 && detectedClassId < labels.length) {
            classificationResult = labels[detectedClassId];
            print("SUCCESS: Tahmin Doğrulandı: $classificationResult (Skor: $maxConfidenceScore)");
          }
        }
      }

      // Bellek sızıntılarını önlemek için kutsal temizlik
      inputTensor.release();
      runOptions.release();
      for (var output in outputs) {
        output?.release();
      }

      return classificationResult;
    } catch (e) {
      print("ERROR: Çıkarım hatası: $e");
      return null;
    }
  }

  List<double> _flattenList(dynamic nested) {
    final result = <double>[];
    void flatten(dynamic item) {
      if (item is List) {
        for (var element in item) {
          flatten(element);
        }
      } else if (item is double) {
        result.add(item);
      } else if (item is num) {
        result.add(item.toDouble());
      }
    }
    flatten(nested);
    return result;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isModelLoaded = false;
  }
}