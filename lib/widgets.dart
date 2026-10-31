import 'package:flutter/material.dart';
import 'models.dart';

class ArrivoColors {
  static const Color primaryBlue = Color(0xFF0051FF);
  static const Color deepBlue = Color(0xFF002D9C);
  static const Color royalBlue = Color(0xFF0A45DF);
  static const Color lightBlueBg = Color(0xFFF3F7FF);
  static const Color chipBlueBg = Color(0xFFDCE8FF);
  static const Color accentOrange = Color(0xFFFF981F);
  static const Color alertRed = Color(0xFFFF3B30);
  static const Color textDark = Color(0xFF0E1B3D);
  static const Color textMuted = Color(0xFF63708C);
}

/// Custom Painter that draws the wavy blue header background matching the design
class WavyHeaderBackground extends StatelessWidget {
  final Widget child;
  const WavyHeaderBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HeaderWavePainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0057FF),
          Color(0xFF0037B8),
          Color(0xFF002486),
        ],
      ).createShader(bgRect);

    final mainPath = Path()
      ..lineTo(0, size.height - 34)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height,
        size.width * 0.52,
        size.height - 18,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height - 38,
        size.width,
        size.height - 14,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(mainPath, gradientPaint);

    // Decorative lighter blue wave overlay on top-left
    final wavePaint = Paint()
      ..color = const Color(0xFF2874FF).withOpacity(0.32)
      ..style = PaintingStyle.fill;

    final topWave = Path()
      ..lineTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.48,
        size.width * 0.46,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.55,
        0,
        size.width * 0.62,
        0,
      )
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(topWave, wavePaint);

    // Subtle globe circle in top-right area
    final globeCenter = Offset(size.width * 0.78, size.height * 0.45);
    final globePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3DA2FF).withOpacity(0.45),
          const Color(0xFF0045D8).withOpacity(0.08),
        ],
      ).createShader(Rect.fromCircle(center: globeCenter, radius: 105));
    canvas.drawCircle(globeCenter, 105, globePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Arrivo Logo with the white "A" + orange swoosh arrow + bold italic "Arrivo"
class ArrivoLogoHeader extends StatelessWidget {
  final double scale;
  const ArrivoLogoHeader({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46 * scale,
          height: 44 * scale,
          child: CustomPaint(
            painter: _ArrivoAPainter(),
          ),
        ),
        SizedBox(width: 6 * scale),
        Text(
          'Arrivo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 33 * scale,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ArrivoAPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw stylized 'A'
    final aPath = Path()
      ..moveTo(size.width * 0.45, size.height * 0.06)
      ..lineTo(size.width * 0.66, size.height * 0.06)
      ..lineTo(size.width * 0.94, size.height * 0.90)
      ..lineTo(size.width * 0.72, size.height * 0.90)
      ..lineTo(size.width * 0.54, size.height * 0.34)
      ..lineTo(size.width * 0.25, size.height * 0.90)
      ..lineTo(size.width * 0.06, size.height * 0.90)
      ..close();
    canvas.drawPath(aPath, whitePaint);

    // Draw orange swoosh arrow across the 'A'
    final orangePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFB72B), Color(0xFFFF8008)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final arrowPath = Path()
      ..moveTo(0, size.height * 0.96)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width * 0.74,
        size.height * 0.45,
      )
      ..lineTo(size.width * 0.68, size.height * 0.35)
      ..lineTo(size.width * 0.98, size.height * 0.42)
      ..lineTo(size.width * 0.80, size.height * 0.66)
      ..lineTo(size.width * 0.77, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.64,
        0,
        size.height * 0.96,
      )
      ..close();

    canvas.drawPath(arrowPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Isometric Cardboard Package Box Widget (used in Header and Package Cards)
class IsometricPackageBox extends StatelessWidget {
  final double size;
  final bool withSpeedLines;

  const IsometricPackageBox({
    super.key,
    this.size = 64,
    this.withSpeedLines = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: withSpeedLines ? size * 1.45 : size,
      height: size,
      child: CustomPaint(
        painter: _IsometricBoxPainter(withSpeedLines: withSpeedLines),
      ),
    );
  }
}

class _IsometricBoxPainter extends CustomPainter {
  final bool withSpeedLines;
  _IsometricBoxPainter({required this.withSpeedLines});

  @override
  void paint(Canvas canvas, Size size) {
    final double boxW = withSpeedLines ? size.width * 0.68 : size.width;
    final double offsetX = withSpeedLines ? size.width * 0.28 : 0;
    final double h = size.height;

    if (withSpeedLines) {
      // Glowing white orbit arc
      final arcPaint = Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      final arcRect = Rect.fromLTWH(
        size.width * 0.08,
        h * 0.56,
        size.width * 0.88,
        h * 0.36,
      );
      canvas.drawArc(arcRect, -0.3, 3.3, false, arcPaint);

      // 3 white speed streaks on left
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(size.width * 0.06, h * 0.46),
        Offset(size.width * 0.30, h * 0.41),
        linePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.01, h * 0.60),
        Offset(size.width * 0.33, h * 0.53),
        linePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.08, h * 0.73),
        Offset(size.width * 0.35, h * 0.66),
        linePaint,
      );
    }

    final Offset topCenter = Offset(offsetX + boxW * 0.50, h * 0.08);
    final Offset topLeft = Offset(offsetX + boxW * 0.12, h * 0.26);
    final Offset topRight = Offset(offsetX + boxW * 0.88, h * 0.26);
    final Offset midCenter = Offset(offsetX + boxW * 0.50, h * 0.45);
    final Offset botLeft = Offset(offsetX + boxW * 0.12, h * 0.74);
    final Offset botCenter = Offset(offsetX + boxW * 0.50, h * 0.92);
    final Offset botRight = Offset(offsetX + boxW * 0.88, h * 0.74);

    // Top face
    final topFace = Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(midCenter.dx, midCenter.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    canvas.drawPath(
      topFace,
      Paint()..color = const Color(0xFFFFCA7A),
    );

    // Left face
    final leftFace = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(midCenter.dx, midCenter.dy)
      ..lineTo(botCenter.dx, botCenter.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()..color = const Color(0xFFE58C2E),
    );

    // Right face
    final rightFace = Path()
      ..moveTo(midCenter.dx, midCenter.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botCenter.dx, botCenter.dy)
      ..close();
    canvas.drawPath(
      rightFace,
      Paint()..color = const Color(0xFFF6A446),
    );

    // Brown packing tape across top & right side
    final tapePaint = Paint()..color = const Color(0xFFB56014);
    final tapePath = Path()
      ..moveTo(offsetX + boxW * 0.27, h * 0.19)
      ..lineTo(offsetX + boxW * 0.37, h * 0.14)
      ..lineTo(offsetX + boxW * 0.75, h * 0.32)
      ..lineTo(offsetX + boxW * 0.75, h * 0.50)
      ..lineTo(offsetX + boxW * 0.64, h * 0.55)
      ..lineTo(offsetX + boxW * 0.64, h * 0.37)
      ..close();
    canvas.drawPath(tapePath, tapePaint);

    // White barcode label on right face
    final labelPath = Path()
      ..moveTo(offsetX + boxW * 0.57, h * 0.63)
      ..lineTo(offsetX + boxW * 0.77, h * 0.54)
      ..lineTo(offsetX + boxW * 0.77, h * 0.71)
      ..lineTo(offsetX + boxW * 0.57, h * 0.80)
      ..close();
    canvas.drawPath(labelPath, Paint()..color = Colors.white);

    // Barcode lines
    final barPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.4;
    for (int i = 0; i < 5; i++) {
      final double bx = offsetX + boxW * (0.60 + i * 0.032);
      final double by = h * (0.67 - i * 0.014);
      canvas.drawLine(Offset(bx, by), Offset(bx, by + h * 0.08), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quick-Action Tile matching the 4 tiles on the Home Screen
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Material(
          color: isDark ? const Color(0xFF1A243B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          shadowColor: ArrivoColors.primaryBlue.withOpacity(0.12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 30,
                    color: ArrivoColors.primaryBlue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : ArrivoColors.textDark,
                    ),
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

/// Package Card matching the screenshot (box thumbnail, title, #TRK, In Transit chip, and 4-step vertical timeline)
class PackageTimelineCard extends StatelessWidget {
  final PackageItem package;
  final String lang;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuAction;

  const PackageTimelineCard({
    super.key,
    required this.package,
    required this.lang,
    required this.onTap,
    required this.onMenuAction,
  });

  String _statusLabel() {
    switch (package.status) {
      case PackageStatus.delivered:
        return AppStrings.tr(lang, 'delivered');
      case PackageStatus.arrivingSoon:
      case PackageStatus.inTransit:
        return AppStrings.tr(lang, 'in_transit');
      case PackageStatus.pickedUp:
        return AppStrings.tr(lang, 'picked_up');
      case PackageStatus.notFound:
        return 'Not Found';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDelivered = package.status == PackageStatus.delivered;
    final isArrivingSoon = package.status == PackageStatus.arrivingSoon;

    final pickedUpEvent = package.events.isNotEmpty
        ? package.events.first
        : const TrackingEvent(
            title: 'Package picked up',
            timestamp: 'Oct 29, 2026 • 10:24 AM',
            location: 'Sorting Hub',
          );
    final transitEvent = package.events.length > 1
        ? package.events[1]
        : const TrackingEvent(
            title: 'In transit',
            timestamp: 'Oct 30, 2026 • 02:17 PM',
            location: 'Regional Hub',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17223B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ArrivoColors.primaryBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: Box image + Name & Number & Chip + 3-dots menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFCFE0FF), Color(0xFFEBF2FF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const IsometricPackageBox(size: 56),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.customName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : ArrivoColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '#${package.trackingNumber}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: ArrivoColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDelivered
                                ? const Color(0xFFDCFCE7)
                                : ArrivoColors.chipBlueBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDelivered
                                    ? Icons.verified_rounded
                                    : Icons.local_shipping_rounded,
                                size: 17,
                                color: isDelivered
                                    ? const Color(0xFF15803D)
                                    : ArrivoColors.primaryBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDelivered
                                      ? const Color(0xFF15803D)
                                      : ArrivoColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: ArrivoColors.textDark,
                    ),
                    onSelected: onMenuAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Rename'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.archive_outlined),
                          title: Text('Archive'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(Icons.delete_outline, color: Colors.red),
                          title:
                              Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Step 1: Package picked up
              _TimelineStepRow(
                isDone: true,
                isPinHighlighted: false,
                showBottomLine: true,
                lineActive: true,
                title: AppStrings.tr(lang, 'picked_up'),
                subtitle: pickedUpEvent.timestamp,
              ),

              // Step 2: In transit
              _TimelineStepRow(
                isDone: isArrivingSoon || isDelivered,
                isPinHighlighted: !isArrivingSoon && !isDelivered,
                showBottomLine: true,
                lineActive: isArrivingSoon || isDelivered,
                title: AppStrings.tr(lang, 'in_transit'),
                subtitle: transitEvent.timestamp,
              ),

              // Step 3: Arriving soon (Highlighted Pin + Blue Banner Card)
              _TimelineStepRow(
                isDone: isDelivered,
                isPinHighlighted: !isDelivered,
                showBottomLine: true,
                lineActive: isDelivered,
                title: AppStrings.tr(lang, 'arriving_soon'),
                subtitle: 'Expected: ${package.eta}',
                highlightBanner: !isDelivered,
              ),

              // Step 4: Delivered
              _TimelineStepRow(
                isDone: isDelivered,
                isPinHighlighted: false,
                showBottomLine: false,
                lineActive: false,
                title: AppStrings.tr(lang, 'delivered'),
                subtitle: isDelivered ? package.eta : null,
                isGreyPending: !isDelivered,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  final bool isDone;
  final bool isPinHighlighted;
  final bool showBottomLine;
  final bool lineActive;
  final String title;
  final String? subtitle;
  final bool highlightBanner;
  final bool isGreyPending;

  const _TimelineStepRow({
    required this.isDone,
    required this.isPinHighlighted,
    required this.showBottomLine,
    required this.lineActive,
    required this.title,
    this.subtitle,
    this.highlightBanner = false,
    this.isGreyPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                if (isPinHighlighted)
                  Container(
                    width: 32,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ArrivoColors.primaryBlue.withOpacity(0.30),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: ArrivoColors.primaryBlue,
                      size: 32,
                    ),
                  )
                else if (isDone)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: ArrivoColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFB8C1D4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Color(0xFFB8C1D4),
                    ),
                  ),
                if (showBottomLine)
                  Expanded(
                    child: Container(
                      width: 2.4,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: lineActive
                          ? ArrivoColors.primaryBlue
                          : const Color(0xFFD5DCEC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showBottomLine ? 12 : 2),
              child: highlightBanner
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF223560)
                            : const Color(0xFFDCE8FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: ArrivoColors.primaryBlue,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: ArrivoColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.local_shipping_rounded,
                            color: ArrivoColors.primaryBlue,
                            size: 28,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isGreyPending
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: isGreyPending
                                ? const Color(0xFF838FA8)
                                : (isDark
                                    ? Colors.white
                                    : ArrivoColors.textDark),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ArrivoColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading Skeleton Widget shown while fetching tracking status
class PackageSkeletonLoader extends StatelessWidget {
  const PackageSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4ECFA),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4ECFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3FC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 46,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FC),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
