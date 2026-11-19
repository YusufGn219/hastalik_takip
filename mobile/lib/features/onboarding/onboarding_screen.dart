// İlk açılışta bir kez gösterilen karşılama sayfası (taslaktaki "Karşılama"
// panosu). Hesap ya da giriş yok; "Başlayalım" ile `onDone` çağrılır, sonrasını
// `StartScreen` yönetir. Taslakta nokta göstergesi "1/2" idi ama ikinci sayfa
// tasarlanmamıştı; var olmayan sayfa için gösterge çizilmez.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Karşılama bitince çağrılır.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final points = [
      l10n.onboardingPoint1,
      l10n.onboardingPoint2,
      l10n.onboardingPoint3,
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          key: const Key('karsilama_logo'),
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.primary600,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: CustomPaint(painter: _PulsePainter()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          l10n.appTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 290),
                          child: Text(
                            l10n.onboardingWelcomeBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: muted, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final p in points)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 1),
                                        child: Icon(Icons.check,
                                            size: 20, color: Color(0xFF1D9E75)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(p,
                                            style: const TextStyle(
                                                fontSize: 14, height: 1.4)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('karsilama_basla'),
                  onPressed: onDone,
                  child: Text(l10n.onboardingLetsStart),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Taslaktaki nabız çizgisi: `M3 12h4l2-5 4 10 2-5h6` (24 birimlik çizim alanı).
class _PulsePainter extends CustomPainter {
  const _PulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(3 * s, 12 * s)
      ..lineTo(7 * s, 12 * s)
      ..lineTo(9 * s, 7 * s)
      ..lineTo(13 * s, 17 * s)
      ..lineTo(15 * s, 12 * s)
      ..lineTo(21 * s, 12 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
