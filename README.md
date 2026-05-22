# 🤟 Sessiz Hareketlerin Sesi

Gerçek zamanlı işaret dili çeviri uygulaması. YOLOv8 nesne tespiti modeli ve Flutter kullanılarak geliştirilmiştir.

## 📌 Proje Hakkında

Bu uygulama, işitme engelli bireylerin günlük hayatta iletişimini kolaylaştırmak amacıyla geliştirilmiştir. Telefon kamerası aracılığıyla anlık olarak 20 farklı Türk İşaret Dili kelimesini tanıyarak ekranda gösterir.

## ✨ Özellikler

- 📷 Gerçek zamanlı kamera ile anlık işaret tespiti
- 🤖 YOLOv8 tabanlı özel eğitilmiş TFLite modeli
- 🎯 20 farklı TİD kelimesi tanıma
- 📱 Android 7.0+ desteği
- ⚡ Optimize edilmiş algılama algoritması (titreme önleme, gecikme azaltma)

## 🗂️ Tanınan Kelimeler

Anne, Arkadaş, Baba, Dur, Ev, Evet, Hayır, Kardeş, Merhaba, Nasıl, Nerede, Özür Dilemek, Tamam, Telefon, Teşekkürler, Tuvalet, Yemek, İçmek, İyi, Kötü

## 🛠️ Teknolojiler

- **Flutter** — Mobil uygulama geliştirme
- **YOLOv8** — Nesne tespiti modeli
- **TensorFlow Lite** — Mobil model çalıştırma
- **ultralytics_yolo** — Flutter YOLO entegrasyonu
- **Python / Ultralytics** — Model eğitimi ve export

## 📊 Model

- Mimari: YOLOv8n (nano)
- Format: TFLite Float16
- Girdi boyutu: 640x640
- Sınıf sayısı: 20
- Eğitim verisi: Özel çekilmiş işaret dili veri seti

## 📋 Gereksinimler

- Android 7.0+ (API 24)
- 3 GB+ RAM
- Kamera izni

## 👩‍💻 Geliştirenler

**Sudenur Kenar & İlayda Kalkan**

---

> Bu proje, işaret dili farkındalığını artırmak ve engelsiz iletişime katkı sağlamak amacıyla geliştirilmiştir.