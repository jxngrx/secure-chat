import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/call_controller.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../app.dart';

class CallGlobalListener extends ConsumerWidget {
  final Widget child;

  const CallGlobalListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CallState>(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ringing) {
        // CRITICAL: Only show incoming call screen if we're NOT the caller
        // Check both the isCaller flag and previous state to be safe
        final controller = ref.read(callControllerProvider.notifier);
        final wasInitiating = previous?.status == CallStatus.initiating;
        final isCaller = controller.isCaller;

        // Don't show incoming call screen if:
        // 1. We're marked as the caller
        // 2. Previous status was initiating (we were calling)
        if (!isCaller && !wasInitiating) {
          // Use pushNamed to match FCMService and allow for easier route tracking
          // Note: MaterialPageRoute is fine, but pushNamed is more consistent
          navigatorKey.currentState?.pushNamed(RouteNames.incomingCall);
        }
      } else if (next.status == CallStatus.connecting || next.status == CallStatus.connected) {
         // Auto-transition to ActiveCallScreen when connecting/connected
         // This ensures user sees premium UI during WebRTC setup, not the basic incoming call screen
         if (previous?.status != CallStatus.connecting && previous?.status != CallStatus.connected) {
           navigatorKey.currentState?.pushReplacementNamed(RouteNames.activeCall);
         }
      }
    });

    return child;
  }
}
