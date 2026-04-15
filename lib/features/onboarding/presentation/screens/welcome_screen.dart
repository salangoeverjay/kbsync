import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class NeighborhoodWelcomeScreen extends StatelessWidget {
  const NeighborhoodWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 402),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 28, 25, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(
                      width: 303,
                      height: 357,
                      child: ColoredBox(color: Color(0x61D9D9D9)),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13),
                    child: SizedBox(
                      width: 320,
                      child: Text(
                        'Welcome to the\nNeighborhood.',
                        style: TextStyle(
                          color: AppColors.deep,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13),
                    child: SizedBox(
                      width: 320,
                      child: Text.rich(
                        TextSpan(
                          text: 'Ka-Bayan Sync',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 23 / 19,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  ' connects you with locals. Offer your skills and build stronger community together.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _WelcomeButton(
                    text: 'Join Ka-Bayan Sync',
                    color: AppColors.plum,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp),
                  ),
                  const SizedBox(height: 16),
                  _WelcomeButton(
                    text: 'I already have an account',
                    color: AppColors.orange,
                    onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _WelcomeButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        height: 51,
        decoration: BoxDecoration(
          color: color,
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
            child: Text(
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
