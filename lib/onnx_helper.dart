import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

class OnnxHelper {
  OrtSession? _session;
  bool _isModelLoaded = false;

  final List<String> labels = [
    'Anne', 'Arkadaş', 'Baba', 'Dur', 'Ev',
    'Evet', 'Hayır', 'Kardeş', 'Merhaba', 'Nasıl',
    'Nerede', 'Özür Dilemek', 'Tamam', 'Telefon', 'Teşekkürler',
    'Tuvalet', 'Yemek', 'İçmek', 'İyi', 'Kötü'
  ];

  bool get isModelLoaded => _isModelLoaded;

  Future<void> initModel() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/kelime.onnx';
      final file = File(path);

      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/kelime.onnx');
        await file.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }

      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(File(path), sessionOptions);
      _isModelLoaded = true;
      print("ONNX modeli yüklendi.");
    } catch (e) {
      print("Model yüklenemedi: $e");
    }
  }

  String? processCameraImage(List<Uint8List> planes, int width, int height) {
    if (!_isModelLoaded || _session == null) {
      print("Model yüklü değil!");
      return null;
    }

    try {
      print("=== processCameraImage BAŞLADI ===");
      final bytes = planes[0];

      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        print("Görüntü decode edilemedi!");
        return null;
      }
      print("Görüntü decode edildi: ${image.width}x${image.height}");

      img.Image resized = img.copyResize(image, width: 640, height: 640);

      final inputData = Float32List(1 * 3 * 640 * 640);
      int rIdx = 0, gIdx = 640 * 640, bIdx = 2 * 640 * 640;
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = resized.getPixel(x, y);
          inputData[rIdx++] = pixel.r / 255.0;
          inputData[gIdx++] = pixel.g / 255.0;
          inputData[bIdx++] = pixel.b / 255.0;
        }
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
          inputData, [1, 3, 640, 640]);
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, {'images': inputTensor});

      print("=== ONNX ÇIKTI ===");

      String? sonuc;

      if (outputs.isNotEmpty && outputs[0] != null) {
        final outputTensor = outputs[0]!.value;
        print("Çıktı tipi: ${outputTensor.runtimeType}");

        if (outputTensor is List) {
          final flat = _flattenList(outputTensor);
          print("Düzleştirilmiş uzunluk: ${flat.length}");
          print("İlk 30 değer: ${flat.take(30).toList()}");

          const int stride = 25;
          const double konfidansEsigi = 0.3;

          double enYuksekSkor = konfidansEsigi;
          int enYuksekSinif = -1;

          for (int i = 0; i + stride <= flat.length; i += stride) {
            final objConf = flat[i + 4];
            for (int c = 0; c < labels.length; c++) {
              final clsScore = flat[i + 5 + c] * objConf;
              if (clsScore > enYuksekSkor) {
                enYuksekSkor = clsScore;
                enYuksekSinif = c;
              }
            }
          }

          if (enYuksekSinif >= 0) {
            sonuc = labels[enYuksekSinif];
            print("Tahmin: $sonuc (skor: $enYuksekSkor)");
          } else {
            sonuc = "Tanınamadı";
            print("Hiçbir sınıf eşiği geçemedi.");
          }
        }
      }

      inputTensor.release();
      runOptions.release();
      for (var o in outputs) { o?.release(); }

      return sonuc;

    } catch (e, stack) {
      print("Tahmin hatası: $e");
      print("Stack: $stack");
      return null;
    }
  }

  List<double> _flattenList(dynamic nested) {
    final result = <double>[];
    void flatten(dynamic item) {
      if (item is List) {
        for (var e in item) flatten(e);
      } else if (item is double) {
        result.add(item);
      } else if (item is num) {
        result.add(item.toDouble());
      }
    }
    flatten(nested);
    return result;
  }
}