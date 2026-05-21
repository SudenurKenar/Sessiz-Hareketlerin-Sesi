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
      title: 'Sessiz Hareketlerin Sesi',
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
  DateTime _lastUpdate = DateTime.now();

  // Confidence'a göre kaç tekrar gerekli
  int _requiredCount(double confidence) {
    if (confidence >= 0.70) return 2; // Çok emin → hızlı göster
    if (confidence >= 0.50) return 4; // Orta emin → normal
    if (confidence >= 0.30) return 7; // Az emin → çok tekrar lazım
    return 99; // Çok düşük → gösterme
  }

  void _handleResults(List<dynamic> results) {
    final now = DateTime.now();

    if (results.isNotEmpty) {
      final top = results.first;
      final confidence = top.confidence as double;
      final word = (top.className ?? "").trim();

      if (confidence < 0.30 || word.isEmpty) return;

      if (word == _lastConfirmedWord) {
        _sameWordCount++;
      } else {
        _lastConfirmedWord = word;
        _sameWordCount = 1;
      }

      final required = _requiredCount(confidence);
      final cooldown = confidence >= 0.70 ? 500 : 800;

      if (_sameWordCount >= required &&
          now.difference(_lastUpdate).inMilliseconds > cooldown) {
        _lastUpdate = now;
        if (_currentWord != word) {
          setState(() => _currentWord = word);
        }
      }
    } else {
      if (now.difference(_lastUpdate).inMilliseconds > 2500) {
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                children: [
                  Text(
                    "Sessiz Hareketlerin Sesi",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "CANLI TERCÜMAN",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.deepPurpleAccent,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alt Panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
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
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    "Sudenur Kenar & İlayda Kalkan",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}