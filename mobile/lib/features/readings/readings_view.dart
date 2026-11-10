import '../../data/database/app_database.dart';

/// Ölçümler ekranının bir tür için okuma modeli.
class ReadingsView {
  const ReadingsView({required this.items, required this.unit});

  /// En yeni önce.
  final List<Measurement> items;

  /// Seçili gösterim birimi kodu.
  final String unit;
}
