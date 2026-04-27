import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resumeEmailController = TextEditingController();
  final _authService = FirebaseAuthService();
  String? _selectedRole;
  bool _isSubmitting = false;
  bool _isLoadingResumeVerification = true;
  bool _canResumeVerification = false;
  bool _isResumingVerification = false;
  String? _resumeEmail;

  @override
  void initState() {
    super.initState();
    _loadResumeVerificationState();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _resumeEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadResumeVerificationState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final email = currentUser?.email?.trim();

    if (currentUser == null || email == null || email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _resumeEmail = null;
        _canResumeVerification = false;
        _isLoadingResumeVerification = false;
      });
      return;
    }

    try {
      final verificationState = await _authService.getVerificationState(
        uid: currentUser.uid,
      );
      if (!mounted) return;
      setState(() {
        _resumeEmail = email;
        _canResumeVerification =
            verificationState == null || !verificationState.isApproved;
        _isLoadingResumeVerification = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resumeEmail = email;
        _canResumeVerification = true;
        _isLoadingResumeVerification = false;
      });
    }
  }

  bool _emailsMatch(String typedEmail, String expectedEmail) {
    return typedEmail.trim().toLowerCase() ==
        expectedEmail.trim().toLowerCase();
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please use a valid email address.';
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled in Firebase yet.';
      default:
        return error.message ?? 'Sign up failed. Please try again.';
    }
  }

  String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore permission denied. Check your Firebase rules.';
      case 'unavailable':
        return 'Firebase service unavailable. Try again in a moment.';
      default:
        return error.message ?? 'Firebase error. Please try again.';
    }
  }

  Future<void> _onResumeVerification() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final expectedEmail = _resumeEmail?.trim();
    final typedEmail = _resumeEmailController.text.trim();

    if (currentUser == null || expectedEmail == null || expectedEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to resume verification.')),
      );
      return;
    }

    if (!_emailsMatch(typedEmail, expectedEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type the exact email used for this account.'),
        ),
      );
      return;
    }

    setState(() => _isResumingVerification = true);
    try {
      final verificationState = await _authService.getVerificationState(
        uid: currentUser.uid,
      );
      if (!mounted) return;

      if (verificationState != null && verificationState.isApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification is already complete.')),
        );
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.workerTaskBiometricPrototype);
        return;
      }

      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.verificationPrototype);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isResumingVerification = false);
      }
    }
  }

  Future<void> _onCreateAccount() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields and select a role.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final result = await _authService.signUp(
        fullName: fullName,
        email: email,
        password: password,
        role: _selectedRole!,
      );
      if (!mounted) return;
      final message = result.profileSaved
          ? 'Account created successfully.'
          : 'Account created, but profile sync failed. Enable Firestore API.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.verificationPrototype);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authMessage(error))));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
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
          padding: const EdgeInsets.fromLTRB(32, 18, 30, 24),
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
                    'Create your account',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 46),
            _InputBlock(
              label: 'Full Name',
              hint: 'Juan D. Dela Cruz',
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),
            _InputBlock(
              label: 'Email Address',
              hint: 'juan@email.com',
              controller: _emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _InputBlock(
              label: 'Password',
              hint: '••••••••••••',
              controller: _passwordController,
              textInputAction: TextInputAction.done,
              obscureText: true,
            ),
            const SizedBox(height: 18),
            _RoleSelector(
              selectedRole: _selectedRole,
              enabled: !_isSubmitting,
              onChanged: (role) => setState(() => _selectedRole = role),
            ),
            const SizedBox(height: 36),
            _PrimaryActionButton(
              text: 'Create Account',
              onTap: _isSubmitting ? null : _onCreateAccount,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 18),
            if (_isLoadingResumeVerification)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_canResumeVerification)
              _ResumeVerificationCard(
                emailController: _resumeEmailController,
                expectedEmail: _resumeEmail,
                isLoading: _isResumingVerification,
                onContinue: _isResumingVerification
                    ? null
                    : _onResumeVerification,
              ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.login),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.plum,
                ),
                child: const Text.rich(
                  TextSpan(
                    text: 'Already have an account?  ',
                    style: TextStyle(color: AppColors.plum, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Sign in',
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

class _ResumeVerificationCard extends StatelessWidget {
  final TextEditingController emailController;
  final String? expectedEmail;
  final bool isLoading;
  final VoidCallback? onContinue;

  const _ResumeVerificationCard({
    required this.emailController,
    required this.expectedEmail,
    required this.isLoading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resume verification',
            style: TextStyle(
              color: AppColors.plum,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type the exact email for this account to continue your incomplete verification.',
            style: TextStyle(
              color: AppColors.ink.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _InputBlock(
            label: 'Exact email',
            hint: expectedEmail ?? 'you@example.com',
            controller: emailController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            text: isLoading ? 'Continuing...' : 'Continue verification',
            onTap: onContinue,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String? selectedRole;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            color: AppColors.plum,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                label: 'Worker',
                value: 'worker',
                selected: selectedRole == 'worker',
                enabled: enabled,
                onTap: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleOption(
                label: 'Resident',
                value: 'resident',
                selected: selectedRole == 'resident',
                enabled: enabled,
                onTap: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onTap;

  const _RoleOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.orange
        : AppColors.plum.withValues(alpha: 0.65);
    final textColor = selected ? AppColors.orange : AppColors.plum;
    final fillColor = selected ? const Color(0xFFFFF1E8) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 1.2 : 0.8),
        ),
        child: InkWell(
          onTap: enabled ? () => onTap(value) : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;

  const _InputBlock({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textInputAction,
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
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
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

class _PrimaryActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryActionButton({
    required this.text,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        height: 51,
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
                : Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFFFFFDFF),
                      fontSize: 16,
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
