import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';

class OutgoingCallScreen extends ConsumerWidget {
  final String receiverId;
  final String receiverName;

  const OutgoingCallScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);

    // Auto-dismiss if call ended, rejected, or error
    if (callState.status == CallStatus.rejected ||
        callState.status == CallStatus.ended ||
        callState.status == CallStatus.error ||
        (callState.status == CallStatus.idle && callState.currentCall == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                       // Cancelling call
                      await controller.endCall();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Receiver info
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
                  receiverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Calling...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // End call button
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: FloatingActionButton(
                onPressed: () async {
                  await controller.endCall();
                  if (context.mounted) Navigator.pop(context);
                },
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
