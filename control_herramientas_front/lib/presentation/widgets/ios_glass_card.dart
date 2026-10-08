import 'dart:ui';
import 'package:flutter/material.dart';

class IosGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;

  const IosGlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.blur = 12.0,
    this.opacity = 0.65,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF1E222D).withOpacity(opacity);
    final borderColor = Colors.white.withOpacity(0.08);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onTap,
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}

