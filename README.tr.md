# AirPods Quick Mode

Ekran okuyucuyla çalışırken Bluetooth kulaklığın toplantı profilinin daha hızlı tepkisini tercih edenler için küçük bir Windows uygulaması.

Uygulama seçilen kulaklık mikrofonunu açar ve gelen sesi RAM'de atar. Windows böylece toplantılarda kullandığı HFP profiline geçebilir. **Sıfır gecikme garantisi vermez.** Ses kalitesi düşebilir, ses mono olabilir ve pil daha hızlı tükenebilir. İlk donanım denemesi AirPods 3 / Windows 11 25H2 ile yapılmıştır.

## Kurulum

1. GitHub Releases bölümünden Windows ZIP paketini indirin ve tamamen çıkarın.
2. `Setup.cmd` dosyasını normal kullanıcı olarak çalıştırın. Yönetici yetkisi gerekmez.
3. AirPods'u bağlayın. Hızlı mod başlangıçta kapalıdır.

Windows 10/11, .NET Framework 4.8 ve mikrofonu etkin Bluetooth kulaklık gerekir. Windows gizlilik ayarlarında masaüstü uygulamalarına mikrofon izni verin. Windows ARM ve farklı kulaklıklar henüz doğrulanmamıştır.

Kurulum `%LOCALAPPDATA%\AirPodsQuickMode\app` klasörüne yapılır. Başlat menüsüne ve Yüklü uygulamalar'a eklenir. Kullanıcıya özel `AirPodsQuickMode-<kullanıcı SID>` zamanlanmış görevi, oturum açılınca programı başlatır; kapanırsa en geç bir dakika içinde tekrar açar. Pilde de çalışır. Kurum ilkeleri görev oluşturmayı engelleyebilir.

Kurulumsuz kullanım için `Start.cmd` çalıştırın. Bu seçenek otomatik başlangıç eklemez. Ayarlar ve günlükler her iki kullanımda `%LOCALAPPDATA%\AirPodsQuickMode\data` altında tutulur.

Paketler henüz dijital imzalı değildir; Windows itibar uyarısı gösterebilir. ZIP'in SHA-256 değerini yanındaki `.sha256` dosyasıyla karşılaştırabilirsiniz.

## Kullanım

| Kısayol | İşlev |
| --- | --- |
| Ctrl+Alt+F9 | Hızlı modu aç / kapat |
| Ctrl+Alt+F10 | Durumu sesli oku |
| Ctrl+Alt+F11 | Hızlı modu kapat; kısayolları dinlemeye devam et |

`Settings.cmd`, Başlat menüsündeki Settings kısayolu veya sistem tepsisi menüsünden ayarları açın. Mikrofonu, kısayolları, Türkçe/İngilizce dilini ve sesli bildirimleri seçebilirsiniz. Form klavyeyle kullanılabilir ve alanları ekran okuyucu için etiketlidir. Dil değişikliği ayar formu yeniden açılınca görünür. Ayarları kaydetmek hızlı modu kapatır. Başka programın kullandığı kısayol kabul edilmez.

Otomatik seçim için adında AirPods geçen tek bir mikrofon bulunmalıdır. Birden fazla varsa elle seçin. Bilgisayarın kendi mikrofonunu seçmek AirPods profilini değiştirmez. Aygıt listesini yenilemek için kulaklığı bağladıktan sonra ayarları yeniden açın. Eski Windows ses API'si uzun aygıt adlarını kısaltabilir; aynı isimli mikrofonlar bu sürümde ayırt edilemez.

Uygulama ses çıkış aygıtını değiştirmez. Ekran okuyucunuzun çıkışını AirPods olarak ayarlayın. Başka uygulama mikrofonu açık tutuyorsa modu kapatmak kaliteli profile dönmeye yetmeyebilir. Bağlantı kesilirse mod kapanır; tekrar bağlanıp F9 ile açın. Uygulama gerçek Bluetooth profilini veya gecikmeyi ölçmez.

## Gizlilik

Mikrofon sesi dosyaya kaydedilmez, çalınmaz, internete gönderilmez. Telemetri veya ağ bağlantısı yoktur. Mod açıkken Windows mikrofon kullanım göstergesi görünür. Tanılama günlükleri zaman, aygıt adı ve hata bilgisi içerir; paylaşmadan önce kontrol edin. Günlük yaklaşık 1 MB ile sınırlıdır.

## Güncelleme ve kaldırma

Güncellemek için yeni ZIP'i çıkarıp `Setup.cmd` çalıştırın; ayarlar korunur. Elle başlattığınız taşınabilir kopyayı kurulumdan önce kapatın.

Kaldırmak için Windows Yüklü uygulamalar'dan AirPods Quick Mode'u kaldırın veya kurulum klasöründeki `Uninstall.cmd` çalıştırın. Görev ve uygulama dosyaları kaldırılır; ayarlar/günlükler kalır. Bunları da silmek için kaldırmadan önce kurulu `uninstall.ps1` betiğini `-RemoveSettings` parametresiyle çalıştırın.

Sistem tepsisindeki Çıkış programı kapatır; kuruluysa otomatik görev tekrar açar. Günlük kullanımda modu kapatmak için F11 kullanın.

Kaynak kodu derleme ve GitHub Releases akışı için [İngilizce teknik kılavuz](README.md). Lisans: MIT.
