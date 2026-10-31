import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Common page layout: title, scrollable content, centred with a max width so
/// it looks right on phones, tablets and landscape.
class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.maxWidth = 600,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.caption),
                ],
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
