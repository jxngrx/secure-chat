import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../di/injection_container.dart';
import '../../../../core/utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // Check authentication state and navigate accordingly
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Wait for minimum splash duration (2 seconds) for better UX
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Check if user is authenticated
      final secureStorage = InjectionContainer.resolve<SecureStorage>();
      final localStorage = InjectionContainer.resolve<LocalStorage>();
      
      final authToken = await secureStorage.read(StorageKeys.authToken);
      final sessionId = await secureStorage.read(StorageKeys.sessionId);

      if (authToken != null && authToken.isNotEmpty && sessionId != null && sessionId.isNotEmpty) {
        // User is authenticated, check if they have username
        try {
          final userProfileJson = await localStorage.read(StorageKeys.userProfile);
          if (userProfileJson != null && userProfileJson.isNotEmpty) {
            final userProfile = jsonDecode(userProfileJson) as Map<String, dynamic>;
            final username = userProfile['username'] as String?;
            
            if (mounted) {
              if (username == null || username.isEmpty || username.startsWith('user_')) {
                // User doesn't have a proper username, navigate to username setup
                Logger.d('User is authenticated but has no username, navigating to username setup');
                Navigator.pushReplacementNamed(context, RouteNames.usernameSetup);
              } else {
                // User is fully authenticated with username, navigate to chat list
                Logger.d('User is fully authenticated, navigating to chat list');
                Navigator.pushReplacementNamed(context, RouteNames.chatList);
              }
            }
          } else {
            // No user profile stored, navigate to username setup to be safe
            if (mounted) {
              Logger.d('User is authenticated but no profile found, navigating to username setup');
              Navigator.pushReplacementNamed(context, RouteNames.usernameSetup);
            }
          }
        } catch (e) {
          Logger.e('Error reading user profile in splash screen', e);
          // On error reading profile, navigate to username setup
          if (mounted) {
            Navigator.pushReplacementNamed(context, RouteNames.usernameSetup);
          }
        }
      } else {
        // User is not authenticated, navigate to welcome screen
        if (mounted) {
          Logger.d('User is not authenticated, navigating to welcome screen');
          Navigator.pushReplacementNamed(context, RouteNames.welcome);
        }
      }
    } catch (e) {
      Logger.e('Error checking auth state in splash screen', e);
      // On error, navigate to welcome screen (safe default)
      if (mounted) {
        Navigator.pushReplacementNamed(context, RouteNames.welcome);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929), // Dark blue background
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // App Icon - Rounded square with blue fill and white padlock
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3), // Vibrant blue
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.lock_open,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // App Name
              Text(
                AppStrings.appName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Tagline
              Text(
                AppStrings.splashTagline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB0BEC5), // Light grey
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Loading dots
              const _LoadingDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = (_controller.value + delay) % 1.0;
            final opacity = (animationValue < 0.5)
                ? animationValue * 2
                : 2 - (animationValue * 2);
            final scale = 0.8 + (opacity * 0.2);

            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    100, 181, 246,
                    opacity.clamp(0.0, 1.0),
                  ), // Light blue
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
