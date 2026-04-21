import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/verification_complete_screen.dart';

class WorkerTaskBiometricPrototypeScreen extends StatefulWidget {
  const WorkerTaskBiometricPrototypeScreen({super.key});

  @override
  State<WorkerTaskBiometricPrototypeScreen> createState() =>
      _WorkerTaskBiometricPrototypeScreenState();
}

class _WorkerTaskBiometricPrototypeScreenState
    extends State<WorkerTaskBiometricPrototypeScreen> {
  bool _entranceScanPassed = false;
  bool _taskStarted = false;
  bool _taskFinished = false;
  bool _exitScanPassed = false;

  Future<void> _runEntranceScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationCompleteScreen(
          title: 'Entrance Scan',
          instructionTitle: 'Scan your face before starting the task.',
          instructionSubtitle:
              'This confirms the assigned worker is present on-site before work begins.',
          notDetectedLabel: 'Face not detected',
          detectedLabel: 'Start Task',
          onVerified: () {
            if (!mounted) return;
            setState(() {
              _entranceScanPassed = true;
              _taskStarted = true;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _runExitScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationCompleteScreen(
          title: 'Exit Scan',
          instructionTitle: 'Scan your face before completing the task.',
          instructionSubtitle:
              'This confirms the same worker is closing out the job at completion time.',
          notDetectedLabel: 'Face not detected',
          detectedLabel: 'Finish Task',
          onVerified: () {
            if (!mounted) return;
            setState(() {
              _exitScanPassed = true;
              _taskFinished = true;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStartTask = !_taskStarted;
    final canFinishTask = _taskStarted && !_taskFinished;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.deep,
        elevation: 0,
        title: const Text(
          'Worker Task Flow',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biometric checkpoints required by KBSYNC:',
              style: TextStyle(
                color: AppColors.plum,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Entrance scan (before start)',
              passed: _entranceScanPassed,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Exit scan (after finish)',
              passed: _exitScanPassed,
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              text: _taskStarted ? 'Task Started' : 'Run Entrance Scan',
              enabled: canStartTask,
              onTap: _runEntranceScan,
            ),
            const SizedBox(height: 12),
            _PrimaryButton(
              text: _taskFinished ? 'Task Finished' : 'Run Exit Scan',
              enabled: canFinishTask,
              onTap: _runExitScan,
            ),
            const SizedBox(height: 18),
            Text(
              _taskFinished
                  ? 'Task can now be closed and paid.'
                  : _taskStarted
                      ? 'Task is in progress. Exit scan is required to finish.'
                      : 'Task cannot start until entrance scan passes.',
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool passed;

  const _StatusRow({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: passed ? Colors.green : AppColors.plum,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.orange : const Color(0xFFD8BECB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(text),
      ),
    );
  }
}
