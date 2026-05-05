import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/login_screen.dart';
import 'package:kbsync/features/auth/presentation/screens/signup_screen.dart';
import 'package:kbsync/features/auth/presentation/screens/verification_prototype_screen.dart';
import 'package:kbsync/features/auth/presentation/screens/worker_task_biometric_prototype_screen.dart';
import 'package:kbsync/features/onboarding/presentation/screens/loading_screen.dart';
import 'package:kbsync/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:kbsync/features/profile/presentation/screens/profile_screen.dart';
import 'package:kbsync/features/resident/presentation/screens/create_task_screen.dart';
import 'package:kbsync/features/resident/presentation/screens/hirer_map_screen.dart';
import 'package:kbsync/features/resident/presentation/screens/resident_dashboard_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/completion_summary_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/evidence_log_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/nearby_tasks_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/task_available_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/task_scan_screen.dart';
import 'package:kbsync/features/wallet/presentation/screens/cash_in_screen.dart';
import 'package:kbsync/features/wallet/presentation/screens/transfer_screen.dart';
import 'package:kbsync/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:kbsync/features/worker/presentation/screens/worker_dashboard_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_transactions_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_wallet_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_profile_screen.dart';

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
        AppRoutes.verificationPrototype: (_) =>
            const VerificationPrototypeScreen(),
        AppRoutes.workerTaskBiometricPrototype: (_) =>
            const WorkerTaskBiometricPrototypeScreen(),
        // Resident flow
        AppRoutes.residentDashboard: (_) => const ResidentDashboardScreen(),
        AppRoutes.hirerMap: (_) => const HirerMapScreen(),
        AppRoutes.createTask: (_) => const CreateTaskScreen(),
        // Worker flow
        AppRoutes.workerDashboard: (_) => const WorkerDashboardScreen(),
        AppRoutes.nearbyTasks: (_) => const NearbyTasksScreen(),
        AppRoutes.taskAvailable: (_) => const TaskAvailableScreen(),
        AppRoutes.evidenceLog: (_) => const EvidenceLogScreen(),
        AppRoutes.taskScan: (ctx) {
          final args =
              ModalRoute.of(ctx)?.settings.arguments as TaskScanScreenArgs?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Missing scan arguments.')),
            );
          }
          return TaskScanScreen(args: args);
        },
        AppRoutes.completionSummary: (_) => const CompletionSummaryScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.wallet: (_) => const WalletScreen(),
        AppRoutes.walletCashIn: (_) => const CashInScreen(),
        AppRoutes.walletTransfer: (_) => const TransferScreen(),
        AppRoutes.adminTransactions: (_) => const AdminDashboardScreen(),
        AppRoutes.adminWallet: (_) => const AdminWalletScreen(),
        AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
        AppRoutes.adminProfile: (_) => const AdminProfileScreen(),
      },
    );
  }
}
