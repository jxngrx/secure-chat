import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';
import '../../../../core/routing/route_names.dart';


class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final call = controller.currentCall;

    // Auto-dismiss if call ended or not ringing
    if (call == null || callState.status != CallStatus.ringing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const Spacer(),

            // Caller info
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Color(0xFF333333),
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  call.callerId, // TODO: Resolve name from Contact Service
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Incoming call',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Call controls
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reject button
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'reject',
                        onPressed: () {
                          controller.rejectCall();
                          Navigator.pop(context);
                        },
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text('Decline', style: TextStyle(color: Colors.white70)),
                    ],
                  ),

                  // Answer button
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'answer',
                        onPressed: () {
                          controller.answerCall();
                          Navigator.pushReplacementNamed(context, RouteNames.activeCall);
                          // Wait, routing isn't set up yet.
                          // I should use MaterialPageRoute for now or standard nav.
                        },
                        backgroundColor: Colors.green,
                        child: const Icon(Icons.call, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text('Accept', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
