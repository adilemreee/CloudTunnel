<div align="center">

# ☁️ CloudTunnel

**Cloudflare Tunnel'larını macOS'ta yönetmek için native bir SwiftUI uygulaması.**

Terminal komutlarıyla boğuşmadan tünel oluştur, başlat, izle ve paylaş.

![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Version](https://img.shields.io/badge/version-1.0.0-brightgreen)
![Localization](https://img.shields.io/badge/i18n-EN%20%C2%B7%20TR-informational)

</div>

---

## İçindekiler

- [Genel Bakış](#genel-bakış)
- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Klavye Kısayolları](#klavye-kısayolları)
- [Proje Yapısı](#proje-yapısı)
- [Mimari](#mimari)
- [Veri & Dosya Konumları](#veri--dosya-konumları)
- [Yol Haritası](#yol-haritası)
- [Katkı](#katkı)

---

## Genel Bakış

CloudTunnel, `cloudflared` CLI'sinin üzerine oturan bir kontrol paneli. Yerel geliştirme
ortamınızı (MAMP siteleri, Docker container'ları, herhangi bir `localhost` portu) tek tıkla
internete açar; çalışan tünelleri menü çubuğundan takip eder, loglarını canlı gösterir ve
ekibinizle paylaşılabilir hale getirir.

Uygulama pencere kapatıldığında da menü çubuğunda çalışmaya devam eder — tünelleriniz
arka planda ayakta kalır.

## Özellikler

| Modül | Ne yapar |
|---|---|
| 📊 **Dashboard** | Aktif tünel, Docker ve hata sayıları; ortam durumu; tek tıkla toplu başlat/durdur |
| 🔗 **Tunnel Management** | `~/.cloudflared` altındaki YAML config'leri tarar, UUID → isim eşler, DNS route yönetir |
| ⚡ **Quick Tunnel** | Hesap gerektirmeyen `trycloudflare.com` tünelleri; public URL otomatik yakalanır |
| 📡 **Port Scanner** | `lsof` tabanlı port taraması, dinleyen servisleri tanır ve doğrudan tünelleştirir |
| 🐳 **Docker** | Container listesi ve port eşlemeleri; container'a tek adımda tünel açma |
| 🖥️ **MAMP** | Site tarama, VHost oluşturma/düzenleme, Apache & MySQL start/stop |
| 📁 **File Share** | Seçtiğin klasörü şık bir HTTP arayüzüyle yayınlar ve tünel arkasına alır |
| 📜 **Live Logs** | `cloudflared` çıktısını gerçek zamanlı pipe ile akıtır, seviye/kaynak filtreleri |
| 🔲 **QR Code** | Public URL'ler için QR kod üretir; mobil cihazdan test etmek için kopyala/kaydet |
| 👥 **Team Sharing** | Tünel setlerini `.cloudtunnel` paketi olarak export/import |
| 🔁 **Domain Migration** | Domain'i tüm config konumlarında tarayıp toplu değiştirir |
| 🕘 **History** | Tünel/servis olaylarının kalıcı log geçmişi |
| 💾 **Backup** | JSON yedekleme, otomatik yedek ve config dosyalarının saklanması |
| 🎛️ **Menu Bar & Touch Bar** | Popover'dan hızlı kontrol, Touch Bar'dan favori tünelleri başlat/durdur |
| 🔔 **Bildirimler** | Tünel açılma/kapanma ve hata durumları için sistem bildirimleri |
| 🌍 **Yerelleştirme** | İngilizce ve Türkçe arayüz |

## Gereksinimler

| Zorunlu | |
|---|---|
| macOS | 14.0 (Sonoma) veya üzeri |
| Xcode | 15.0+ (Swift 5.9) |
| [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) | `brew install cloudflared` |

Opsiyonel — ilgili modülü kullanacaksan:

- **Cloudflare hesabı + `cloudflared login`** — managed (kalıcı) tüneller ve DNS route için
- **Docker Desktop** — Docker modülü için
- **MAMP** (`/Applications/MAMP`) — MAMP modülü için
- **python3** (`/usr/bin/python3`, macOS'ta hazır gelir) — File Share sunucusu için

> `cloudflared` yolu otomatik bulunur (Homebrew, `/usr/local/bin`, `which`); bulunamazsa
> Ayarlar'dan elle girebilirsin.

## Kurulum

```bash
git clone https://github.com/adilemreee/CloudTunnel.git
cd CloudTunnel
open CloudTunnel.xcodeproj
```

Xcode'da `CloudTunnel` şemasını seçip **⌘R** ile çalıştır.

Proje dosyası [XcodeGen](https://github.com/yonaskolb/XcodeGen) ile üretiliyor. `project.yml`
değiştirdiysen yeniden üret:

```bash
xcodegen generate
```

Komut satırından derlemek için:

```bash
xcodebuild -project CloudTunnel.xcodeproj -scheme CloudTunnel -configuration Release build
```

> **Not:** Uygulama sandbox dışında çalışır (`cloudflared`, `docker`, `lsof` ve MAMP
> süreçlerini çalıştırabilmesi için) ve ad-hoc imzalanır.

## Hızlı Başlangıç

**1 · Geçici bir tünel (en hızlı yol)**

`Hızlı Tünel` sekmesine geç → portu yaz (örn. `3000`) → başlat.
Saniyeler içinde bir `https://….trycloudflare.com` adresi alırsın; QR kodunu mobilden okut.

**2 · Kalıcı bir tünel**

```bash
cloudflared login          # bir kez, tarayıcıdan Cloudflare hesabını yetkilendir
```

Ardından `Tüneller` → **Yeni Tünel**: isim, hostname ve yerel port ver. CloudTunnel
tüneli oluşturur, `~/.cloudflared/<uuid>.yml` config'ini yazar ve DNS kaydını yönlendirir.

**3 · Var olan tünellerin**

`~/.cloudflared` içindeki config'ler otomatik taranır (**⇧⌘F** ile yeniden tara) ve
listede isimleriyle görünür.

## Klavye Kısayolları

Tümü Ayarlar → Klavye Kısayolları'ndan değiştirilebilir.

| Kısayol | Eylem |
|---|---|
| `⇧⌘T` | Hızlı tünel başlat |
| `⇧⌘R` / `⇧⌘S` | Tüm tünelleri başlat / durdur |
| `⇧⌘F` | Config dosyalarını yeniden tara |
| `⇧⌘P` | Portları tara |
| `⇧⌘Q` | QR kod oluştur |
| `⌘1` … `⌘5` | Dashboard · Tüneller · Hızlı Tünel · Port Tarayıcı · Loglar |
| `⌘,` | Ayarlar |

## Proje Yapısı

```
CloudTunnel/
├── App/                  CloudTunnelApp.swift — @main, scene & environment kurulumu
├── Core/                 DesignSystem, KeyboardShortcutManager, TouchBarController
├── Models/               Models.swift — tünel, log, navigasyon modelleri
├── Services/             İş mantığı (15 servis)
│   ├── TunnelService         cloudflared süreç yönetimi (managed + quick)
│   ├── DockerService         container listesi & port eşleme
│   ├── MAMPService           site/VHost yönetimi, Apache & MySQL kontrolü
│   ├── FileShareService      python3 tabanlı HTTP sunucu
│   ├── PortScannerService    lsof taraması & servis tanıma
│   ├── LiveLogService        gerçek zamanlı log akışı
│   ├── TeamSharingService    .cloudtunnel export/import
│   ├── DomainMigrationService, BackupService, HistoryService,
│   │   QRCodeService, NetworkService, PortService,
│   │   MenuBarManager, NotificationHelper
├── Views/                Modül başına bir SwiftUI klasörü
└── Resources/            en.lproj · tr.lproj (Localizable.strings)
```

## Mimari

- **SwiftUI + AppKit köprüleri** — arayüz SwiftUI; menü çubuğu (`NSStatusItem`), Touch Bar
  (`NSTouchBar`) ve dosya panelleri için AppKit kullanılır.
- **Servis katmanı** — her yetenek `@MainActor`, `ObservableObject` bir servis; `App`
  seviyesinde `@StateObject` olarak tutulup `environmentObject` ile dağıtılır.
- **Süreç tabanlı entegrasyon** — harici araçlarla iletişim `Process` + pipe üzerinden;
  uzun süren çağrılar `Task.detached` içinde çalışır.
- **Design system** — `CTColors`, tipografi ölçeği ve kart/glass modifier'ları
  `Core/DesignSystem.swift` içinde merkezî.
- **Persistence** — kullanıcı tercihleri `@AppStorage`, geçmiş ve yedekler
  Application Support altında JSON.

## Veri & Dosya Konumları

| Ne | Nerede |
|---|---|
| Tünel config'leri | `~/.cloudflared/*.yml` (Ayarlar'dan değiştirilebilir) |
| Olay geçmişi | `~/Library/Application Support/CloudTunnel/history.json` |
| Yedekler | `~/Library/Application Support/CloudTunnel/Backups/*.json` |
| Paylaşım paketleri | Seçtiğin konuma `*.cloudtunnel` |
| Tercihler | `UserDefaults` (`com.adilemre.CloudTunnel`) |

## Yol Haritası

Ayrıntılı teknik inceleme ve öneriler için [`cloudtunnel_analysis.md`](cloudtunnel_analysis.md).
Öne çıkan başlıklar:

- 🔒 Credential'ları Keychain'e taşımak, Touch ID ile uygulama kilidi, şifreli yedekler
- 📊 Bant genişliği / uptime / latency izleme ve eşik tabanlı uyarılar
- 🌐 Cloudflare API entegrasyonu (DNS ve tünel yönetimi doğrudan API üzerinden)
- 🧩 Servislerin dependency injection'a geçirilmesi ve test edilebilirlik
- 🌍 Kalan hardcoded string'lerin yerelleştirilmesi

## Katkı

Issue ve pull request'ler açık. Kod gönderirken:

1. Mevcut dosya düzenine ve `Core/DesignSystem.swift` içindeki stil token'larına uy.
2. Yeni kullanıcıya görünen metinleri `NSLocalizedString` ile ekle ve **hem** `en.lproj`
   **hem** `tr.lproj` dosyalarını güncelle.
3. `project.yml` değiştirdiysen `xcodegen generate` çalıştır ve üretilen projeyi de gönder.

---

<div align="center">

**CloudTunnel** · [adilemreee](https://github.com/adilemreee) tarafından macOS için yapıldı

</div>
