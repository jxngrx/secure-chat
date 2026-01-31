import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/call_controller.dart';
import '../screens/incoming_call_screen.dart';

class CallGlobalListener extends ConsumerWidget {
  final Widget child;

  const CallGlobalListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CallState>(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ringing) {
        // Check if we are the receiver (not caller)
        final controller = ref.read(callControllerProvider.notifier);
        if (!controller.isCaller) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncomingCallScreen()),
            );
        }
      } else if (next.status == CallStatus.connected) {
         // Handle connection if needed
      }
    });

    return child;
  }
}
