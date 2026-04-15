import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/login_screen.dart';
import 'package:kbsync/features/auth/presentation/screens/signup_screen.dart';
import 'package:kbsync/features/onboarding/presentation/screens/loading_screen.dart';
import 'package:kbsync/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:kbsync/features/verification/presentation/screens/verification_document_screen.dart';

class KbSyncApp extends StatelessWidget {
  const KbSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KBSync',
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: AppColors.bg,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.bg,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: AppRoutes.loading,
      routes: {
        AppRoutes.loading: (_) => const LoadingScreen(),
        AppRoutes.welcome: (_) => const NeighborhoodWelcomeScreen(),
        AppRoutes.signUp: (_) => const SignUpScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.verificationDocument: (_) => const VerificationDocumentScreen(),
      },
    );
  }
}

