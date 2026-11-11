// Adım okumak için gereken "fiziksel aktivite" izni. Alan servisi yalnızca bu
// arayüzü bilir; Android uygulaması `permission_handler` ile, testte sahtesi.

enum StepPermissionState {
  /// İzin verilmiş.
  granted,

  /// Verilmemiş; yeniden sorulabilir.
  denied,

  /// Kullanıcı "bir daha sorma" dedi ya da sistem sormayı engelliyor:
  /// yalnız telefon ayarlarından açılabilir.
  permanentlyDenied,
}

abstract class StepPermission {
  /// Mevcut durum; izin penceresi açmaz.
  Future<StepPermissionState> status();

  /// İzin penceresini açar ve sonucu döner.
  Future<StepPermissionState> request();

  /// Uygulamanın telefon ayarları sayfasını açar.
  Future<void> openSettings();
}
