# Vitapuls — Gizlilik Politikası

**Son güncelleme:** 2026-06-14

## 1. Veri Sorumlusu

Bu uygulama, **[AD SOYAD]** tarafından işletilmektedir. İletişim: [E-POSTA]

## 2. Toplanan Veriler

Vitapuls aşağıdaki kişisel verileri işlemektedir:

| Veri | Amaç | Hukuki Dayanak |
|------|------|----------------|
| Ad, e-posta adresi | Hesap oluşturma ve kimlik doğrulama | KVKK m.5/2-c (sözleşme) |
| Şifreli parola (hash) | Güvenli giriş | KVKK m.5/2-c |
| Semptom ve belirti kayıtları | Kişisel sağlık takibi hizmeti | KVKK m.6/2 + açık rıza |
| İlaç ve kronik hastalık bilgileri | Kişisel sağlık takibi hizmeti | KVKK m.6/2 + açık rıza |
| Profil fotoğrafı (opsiyonel) | Profil görseli | KVKK m.5/2-c |

## 3. Özel Nitelikli Kişisel Veriler

Sağlık verileri (semptomlar, ilaçlar, kronik hastalıklar), 6698 sayılı KVKK kapsamında **özel nitelikli kişisel veri** sayılmaktadır. Bu veriler yalnızca **açık rızanız** ile ve hizmetin sağlanması amacıyla işlenmektedir.

## 4. Veri Saklama Süresi

- Aktif hesap: Hesap silinene kadar veriler saklanır.
- Hesap silinmesi: Siz tarafından talep edildiğinde 30 gün içinde tüm kişisel verileriniz silinir.
- Log kayıtları: 90 gün saklanır, ardından otomatik olarak silinir.

## 5. Veri Güvenliği

- Veriler PostgreSQL veritabanında şifreli bağlantı üzerinden saklanır.
- Parolalar bcrypt hash algoritmasıyla saklanır, hiçbir zaman düz metin olarak tutulmaz.
- API iletişimi JWT token ile korunmaktadır.
- Sunucu erişimi kısıtlı ve güvenli bir ortamda sağlanmaktadır.

## 6. Veri Aktarımı

Verileriniz üçüncü taraflarla paylaşılmaz. Yasal zorunluluk halleri saklıdır.

## 7. Haklarınız (KVKK m.11)

Aşağıdaki haklara sahipsiniz:
- Kişisel verilerinizin işlenip işlenmediğini öğrenme
- İşlenen verileriniz hakkında bilgi talep etme
- Verilerin silinmesini veya yok edilmesini isteme
- İşlemeye itiraz etme

Başvuru için: **[E-POSTA]**

## 8. Çerezler

Uygulama mobil bir uygulamadır ve çerez kullanmaz. Kimlik doğrulaması için cihazda güvenli depolama (flutter_secure_storage) kullanılır.
