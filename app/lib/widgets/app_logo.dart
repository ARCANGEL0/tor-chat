import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_assets.dart';
import '../state/theme_controller.dart';
import '../themes/theme_style.dart';

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
    final tc = ThemeController.instance;
    final isLain =
        ThemeStyle.fromId(tc.settings.themeStyle) == ThemeStyle.lain;
    final image = Image.asset(
      isLain ? AppAssets.wiredLogo : AppAssets.icon,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    if (isLain) return image;
    final logoColor = tc.settings.logoColor ?? AppSettings.defaultLogoColor;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(Color(logoColor), BlendMode.color),
      child: image,
    );
  }
}