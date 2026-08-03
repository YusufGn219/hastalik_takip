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

Sağlık verileri (semptomlar, ilaçlar, kronik hastalıklar), 6698 sayılı KVKK kapsamında **özel nitelikli kişisel veri** sayılmaktadır. Bu veriler yalnızca **açık rızanız** ile ve hizmetin sağlanması amacıyla işlenmektedir. Açık rızanız, hesap oluşturma sırasında onay kutucuğu ile alınır ve tarih/saat damgasıyla kaydedilir.

## 4. Veri Saklama Süresi ve Hesap Silme

- **Aktif hesap:** Hesap silinene kadar veriler saklanır.
- **Hesap silme talebi:** Uygulama üzerinden hesap silme talebinde bulunduğunuzda, e-posta adresinize bir onay bağlantısı gönderilir. Bu bağlantıyı onayladığınızda hesabınız derhal **pasif hale getirilir** ve tüm oturum token'larınız geçersiz kılınır.
- **Anonimleştirme (30 gün sonra):** Onaydan 30 gün sonra, kimliğinizi belirleyen bilgileriniz (e-posta, ad-soyad, profil fotoğrafı) kalıcı olarak silinir/anonimleştirilir; hesabınızla bağlantınız artık kurulamaz. Semptom, episode ve ilaç kayıtlarınız bu noktadan sonra **sizinle ilişkilendirilemeyecek şekilde**, ancak kendi içinde tutarlı ve gruplanabilir bir kayıt seti olarak; hizmetin geliştirilmesi, istatistiksel analiz ve yapay zekâ/makine öğrenmesi modellerinin eğitilmesi amacıyla saklanabilir. Bu veriler artık kişisel veri niteliği taşımadığından KVKK kapsamı dışındadır (KVKK m.28).
- **Log kayıtları:** 90 gün saklanır, ardından otomatik olarak silinir.

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
- Verilerin silinmesini veya yok edilmesini isteme (bkz. Madde 4 — silme talebi, 30 gün içinde anonimleştirme ile sonuçlanır)
- İşlemeye itiraz etme

Başvuru için: **[E-POSTA]**

## 8. Çerezler

Uygulama mobil bir uygulamadır ve çerez kullanmaz. Kimlik doğrulaması için cihazda güvenli depolama (flutter_secure_storage) kullanılır.
