import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded surface used to group related controls.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor = AppColors.outline,
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: child,
    );
  }
}
