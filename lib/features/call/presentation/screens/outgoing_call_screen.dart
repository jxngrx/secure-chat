import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';
import '../../../../core/routing/route_names.dart';

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

    // Auto-dismiss ONLY on terminal states (ended, rejected, error, idle)
    // Do NOT pop on connecting/connected - CallGlobalListener handles navigation to ActiveCallScreen
    if (callState.status == CallStatus.rejected ||
        callState.status == CallStatus.ended ||
        callState.status == CallStatus.error ||
        (callState.status == CallStatus.idle && callState.currentCall == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
             Navigator.pushReplacementNamed(context, RouteNames.chatList);
          }
        }
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    String statusText;
    switch (callState.status) {
      case CallStatus.initiating:
        statusText = 'Calling...';
        break;
      case CallStatus.ringing:
        statusText = 'Ringing...';
        break;
      case CallStatus.connecting:
        statusText = 'Connecting...';
        break;
      default:
        statusText = 'Calling...';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back/cancel
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () async {
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
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                      color: const Color(0xFF1C1C1E),
                    ),
                    child: const Icon(Icons.person, size: 80, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    receiverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  if (callState.status == CallStatus.connecting) ...[
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // End call button
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: GestureDetector(
                  onTap: () async {
                    await controller.endCall();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
