import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/call_controller.dart';
import '../screens/incoming_call_screen.dart';
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
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const IncomingCallScreen()),
          );
        }
      } else if (next.status == CallStatus.connected) {
         // Auto-transition to ActiveCallScreen if we just connected
         if (previous?.status != CallStatus.connected) {
           navigatorKey.currentState?.pushReplacementNamed(RouteNames.activeCall);
         }
      }
    });

    return child;
  }
}
