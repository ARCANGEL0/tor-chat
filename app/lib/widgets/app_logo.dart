import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_assets.dart';
import '../state/theme_controller.dart';

/// The app logo. It is always tinted toward the configured "logo color"
/// (default rgb(93, 59, 133)) via a [BlendMode.color] overlay — the white
/// parts stay white while the purple/indigo parts shift toward the chosen
/// tint. Rebuilds immediately when the theme changes.
class AppLogo extends StatefulWidget {
  final double size;

  const AppLogo({super.key, this.size = 26});

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final logoColor = ThemeController.instance.settings.logoColor ??
        AppSettings.defaultLogoColor;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(Color(logoColor), BlendMode.color),
      child: Image.asset(
        AppAssets.icon,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
