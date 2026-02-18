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
      final prevStatus = previous?.status;
      final nextStatus = next.status;

      // --- Incoming Call (Receiver) ---
      if (nextStatus == CallStatus.ringing) {
        final controller = ref.read(callControllerProvider.notifier);
        final isCaller = controller.isCaller;

        // Only show incoming call screen for the receiver
        if (!isCaller) {
          navigatorKey.currentState?.pushNamed(RouteNames.incomingCall);
        }
      }

      // --- Call Connecting / Connected (Both Caller & Receiver) ---
      // Trigger when:
      // - Caller: initiating/ringing → connecting (callee answered)
      // - Receiver: ringing/connecting → connected (Agora joined)
      else if (nextStatus == CallStatus.connecting || nextStatus == CallStatus.connected) {
        final wasAlreadyInCall = prevStatus == CallStatus.connecting ||
            prevStatus == CallStatus.connected;

        if (!wasAlreadyInCall) {
          // Navigate to active call screen for both caller and receiver
          navigatorKey.currentState?.pushReplacementNamed(RouteNames.activeCall);
        }
      }

      // --- Call Ended / Rejected (Both Sides) ---
      // Pop back to root if we're on a call screen
      else if (nextStatus == CallStatus.ended ||
          nextStatus == CallStatus.rejected ||
          nextStatus == CallStatus.error) {
        // Only navigate away if we were in a call state
        final wasInCall = prevStatus == CallStatus.ringing ||
            prevStatus == CallStatus.connecting ||
            prevStatus == CallStatus.connected ||
            prevStatus == CallStatus.initiating;

        if (wasInCall) {
          // Pop all call screens back to root
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
    });

    return child;
  }
}
