import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/utils/logger.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> {
  bool _isRequesting = false;

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      final status = await FCMService.instance.initialize();

      if (status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional) {
        if (mounted) {
          // Permission granted, resume normal flow (go to splash to re-evaluate auth)
          Navigator.pushReplacementNamed(context, RouteNames.splash);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission is required to use the app.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      Logger.e('Error requesting notification permission', e);
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Exit the app if back button is pressed
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1929),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 100,
                  color: Color(0xFF137FEC),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Notifications Required',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please enable notifications to receive calls and messages in real-time. This is essential for the app to function correctly.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFB0BEC5),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _requestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137FEC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isRequesting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Enable Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text(
                    'Exit App',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
