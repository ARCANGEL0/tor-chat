import '../models/app_settings.dart';
import 'bladerunner/bladerunner_template.dart';
import 'cyberpunk/cyberpunk_template.dart';
import 'lain/lain_template.dart';
import 'matrix/matrix_template.dart';
import 'midnight/midnight_template.dart';
import 'theme_style.dart';
import 'theme_template.dart';

final List<ThemeTemplate> themeTemplates = <ThemeTemplate>[
  ThemeTemplate(style: ThemeStyle.def, settings: AppSettings.defaults().copy()),
  ThemeTemplate(style: ThemeStyle.midnight, settings: midnightTemplate()),
  ThemeTemplate(style: ThemeStyle.matrix, settings: matrixTemplate()),
  ThemeTemplate(style: ThemeStyle.lain, settings: lainTemplate()),
  ThemeTemplate(style: ThemeStyle.cyberpunk, settings: cyberpunkTemplate()),
  ThemeTemplate(style: ThemeStyle.bladerunner, settings: bladerunnerTemplate()),
];