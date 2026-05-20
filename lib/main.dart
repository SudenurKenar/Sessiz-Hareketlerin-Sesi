import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'onnx_helper.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Kameralara ulaşılamadı: $e");
  }
  runApp(const IsaretDiliApp());
}

class IsaretDiliApp extends StatelessWidget {
  const IsaretDiliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const KameraCeviriEkrani(),
    );
  }
}

class KameraCeviriEkrani extends StatefulWidget {
  const KameraCeviriEkrani({super.key});

  @override
  State<KameraCeviriEkrani> createState() => _KameraCeviriEkraniState();
}

class _KameraCeviriEkraniState extends State<KameraCeviriEkrani> {
  CameraController? _cameraController;
  final OnnxHelper _onnxHelper = OnnxHelper();
  String _anlikCeviri = "İşaret bekleniyor...";
  bool _isProcessing = false;
  Timer? _frameTimer; // Windows akışı için zamanlayıcı tahtımız

  @override
  void initState() {
    super.initState();
    _uygulamayiBaslat();
  }

  Future<void> _uygulamayiBaslat() async {
    await _onnxHelper.initModel();
    if (cameras.isEmpty) return;

    // Laptopun ön kamerasını garantilemek için asil bir arayış
    CameraDescription? laptopKamerasi;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front || 
          camera.name.toLowerCase().contains('front') || 
          camera.name.toLowerCase().contains('webcam')) {
        laptopKamerasi = camera;
        break;
      }
    }
    laptopKamerasi ??= cameras.first; // Bulamazsa ilk sıradakine razı olalım

    _cameraController = CameraController(
      laptopKamerasi,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() {});

    // 👑 WINDOWS OPTİMİZASYONU:
    // startImageStream yerine, saniyede ~15 kare yakalayacak asil bir zamanlayıcı kuruyoruz.
    // Bu sayede Windows çökmez ve ONNX arkada tıkır tıkır tahmin yürütür.
    _frameTimer = Timer.periodic(const Duration(milliseconds: 66), (timer) async {
      if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) return;

      try {
        _isProcessing = true;

        // Kameradan anlık bir fotoğraf karesi koparıyoruz
        final XFile imageFile = await _cameraController!.takePicture();
        final bytes = await imageFile.readAsBytes();

        // Çekilen kareyi ONNX'e gönderiyoruz (Genişlik ve yükseklik bilgisini 640 kabul edebiliriz)
        final sonuc = _onnxHelper.processCameraImage([bytes], 640, 480);

        if (sonuc != null) {
          setState(() {
            _anlikCeviri = sonuc;
          });
        }
      } catch (e) {
        print("Kare işlenirken küçük bir hırıltı çıktı: $e");
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel(); // Zamanlayıcıyı dağıtalım
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Webcam Önizlemesi
          Transform.scale(
            scale: 1 / (_cameraController!.value.aspectRatio * MediaQuery.of(context).size.aspectRatio),
            alignment: Alignment.topCenter,
            child: CameraPreview(_cameraController!),
          ),
          
          // Üst Başlık Paneli
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Text("WEBCAM İŞARET DİLİ TERCÜMANI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
          
          // Alt Çeviri Sonuç Kartı
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.deepPurpleAccent, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Canlı Çeviri Sonucu", style: TextStyle(color: Colors.grey.shade400, fontSize: 13, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(_anlikCeviri, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}