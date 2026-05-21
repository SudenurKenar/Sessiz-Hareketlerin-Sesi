import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İşaret Dili Çevirici',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SignLanguageScreen(),
    );
  }
}

class SignLanguageScreen extends StatefulWidget {
  const SignLanguageScreen({super.key});

  @override
  State<SignLanguageScreen> createState() => _SignLanguageScreenState();
}

class _SignLanguageScreenState extends State<SignLanguageScreen> {
  String _currentWord = "İşaret Bekleniyor...";
  String _lastConfirmedWord = "";
  int _sameWordCount = 0;
  static const int _confirmThreshold = 4; // Kaç kez üst üste görünmeli
  DateTime _lastUpdate = DateTime.now();

  void _handleResults(List<dynamic> results) {
    final now = DateTime.now();

    if (results.isNotEmpty) {
      final top = results.first;
      if (top.confidence > 0.50) {
        final word = top.className ?? "";

        if (word == _lastConfirmedWord) {
          _sameWordCount++;
        } else {
          _lastConfirmedWord = word;
          _sameWordCount = 1;
        }

        // Sadece aynı kelime art arda yeterince görünürse güncelle
        if (_sameWordCount >= _confirmThreshold &&
            now.difference(_lastUpdate).inMilliseconds > 800) {
          _lastUpdate = now;
          if (_currentWord != word) {
            setState(() => _currentWord = word);
          }
        }
      }
    } else {
      // Boş sonuç gelince hemen silme, 2 saniye bekle
      if (now.difference(_lastUpdate).inMilliseconds > 2000) {
        _lastConfirmedWord = "";
        _sameWordCount = 0;
        _lastUpdate = now;
        if (_currentWord != "İşaret Bekleniyor...") {
          setState(() => _currentWord = "İşaret Bekleniyor...");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YOLOView(
            modelPath: 'assets/models/best_float16.tflite',
            task: YOLOTask.detect,
            onResult: _handleResults,
          ),

          // Üst Başlık
          Positioned(
            top: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text(
                  "YOLOv8 CANLI TERCÜMAN",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),

          // Alt Çeviri Paneli
          Positioned(
            bottom: 40, left: 25, right: 25,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "ANLIK ANLAM",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _currentWord,
                      key: ValueKey(_currentWord),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _currentWord == "İşaret Bekleniyor..."
                            ? Colors.white38
                            : Colors.greenAccent,
                      ),
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