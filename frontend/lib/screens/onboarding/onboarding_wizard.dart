import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../widgets/custom_button.dart';
import '../../services/storage_service.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({Key? key}) : super(key: key);

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: AppConfig.successColor,
              ),
              SizedBox(height: 24),
              Text(
                'Welcome to Bstock!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Your shop has been created successfully. Let\'s get started with managing your inventory and sales.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppConfig.subtextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              CustomButton(
                text: 'Get Started',
                onPressed: () async {
                  await _storage.setOnboardingComplete();
                  if (mounted) {
                    context.go('/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
