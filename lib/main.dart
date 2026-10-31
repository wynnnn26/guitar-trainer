import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.surface,
    ),
  );
  runApp(const GuitarTrainerApp());
}
