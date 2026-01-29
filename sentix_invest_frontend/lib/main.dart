import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: SentixApp()));
}

class SentixApp extends StatelessWidget {
  const SentixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SentixInvest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
