import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _adminEmail = 'admin@kabayan.com';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _rememberMe = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please use a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return error.message ?? 'Login failed. Please try again.';
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authMessage(error))));
    }
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await _authService.signIn(email: email, password: password);
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Unable to read the signed-in user.',
        );
      }

      final verificationState = await _authService.getVerificationState(
        uid: uid,
      );
      if (!mounted) return;

      final normalizedEmail = email.toLowerCase();
      if (normalizedEmail == _adminEmail ||
          verificationState?.role == 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin login successful.')),
        );
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
        return;
      }

      if (verificationState == null || !verificationState.isApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete ID and face verification before login.'),
          ),
        );
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.verificationPrototype);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful.')));
      final route = verificationState.role == 'resident'
          ? AppRoutes.residentDashboard
          : AppRoutes.workerDashboard;
      Navigator.of(context).pushReplacementNamed(route);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authMessage(error))));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to verify account status.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(33, 18, 29, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.welcome),
                  icon: const Icon(Icons.arrow_back, color: AppColors.plum),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Welcome back, Ka-Bayan!',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _InputBlock(
              label: 'Email Address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hint: 'juan@email.com',
            ),
            const SizedBox(height: 14),
            _InputBlock(
              label: 'Password',
              controller: _passwordController,
              hint: '••••••••••••',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 19,
                  height: 19,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: _isSubmitting
                        ? null
                        : (value) =>
                              setState(() => _rememberMe = value ?? false),
                    side: const BorderSide(color: AppColors.plum, width: 1.2),
                    activeColor: AppColors.orange,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: AppColors.plum,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isSubmitting ? null : _onForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.plum,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _LoginButton(
              onTap: _isSubmitting ? null : _onLogin,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.signUp),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.plum,
                ),
                child: const Text.rich(
                  TextSpan(
                    text: "Don't have an account?  ",
                    style: TextStyle(color: AppColors.plum, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _InputBlock({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.plum,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 65,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(color: AppColors.plum, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.plum.withValues(alpha: 0.45),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.plum.withValues(alpha: 0.65),
                  width: 0.4,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.plum.withValues(alpha: 0.65),
                  width: 0.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.plum, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _LoginButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 51,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Log in',
                    style: TextStyle(
                      color: Color(0xFFFFFDFF),
                      fontSize: 33 / 2,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
