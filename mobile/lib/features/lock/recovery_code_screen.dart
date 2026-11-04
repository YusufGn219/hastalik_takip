import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'recovery_code.dart';

/// Yeni kurtarma kodunu **bir kez** gösterir. Kullanıcı "yazdım" kutusunu
/// işaretleyip "Bitti" diyene kadar geri dönülemez (kod başka yerde saklı değildir).
/// Kod seçilebilir metin değildir (panoya kopyalanıp başka uygulamalara
/// sızmasın diye); kâğıda yazılması istenir.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.code});

  final String code;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _written = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.recoveryCodeTitle), automaticallyImplyLeading: false),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.recoveryCodeBody, style: text.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(
                    formatRecoveryCode(widget.code),
                    key: const Key('kurtarma_kodu'),
                    style: text.headlineSmall?.copyWith(fontFamily: 'monospace', letterSpacing: 2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    key: const Key('kurtarma_yazdim'),
                    value: _written,
                    onChanged: (v) => setState(() => _written = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.recoveryCodeConfirm),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('kurtarma_bitti'),
                    onPressed: _written ? () => Navigator.pop(context) : null,
                    child: Text(l10n.recoveryCodeDone),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
