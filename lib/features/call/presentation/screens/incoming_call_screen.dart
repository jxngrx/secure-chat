import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';

class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final call = controller.currentCall;

    // Auto-dismiss on terminal states
    // Do NOT dismiss on connecting/connected - CallGlobalListener handles navigation
    if (call == null ||
        callState.status == CallStatus.ended ||
        callState.status == CallStatus.rejected ||
        callState.status == CallStatus.error ||
        callState.status == CallStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              const Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Caller info
              Column(
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
                    call.callerName ??
                        'User ${call.callerId.length > 5 ? call.callerId.substring(call.callerId.length - 5) : call.callerId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'INCOMING VOICE CALL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Call controls
              Padding(
                padding: const EdgeInsets.only(bottom: 80, left: 50, right: 50),
                child: callState.status == CallStatus.connecting
                    ? const Column(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Connecting...',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Decline button
                          _buildCallAction(
                            icon: Icons.call_end,
                            label: 'Decline',
                            color: Colors.redAccent,
                            onTap: () async {
                              await controller.rejectCall();
                              // Pop handled by CallGlobalListener
                            },
                          ),

                          // Accept button
                          _buildCallAction(
                            icon: Icons.call,
                            label: 'Accept',
                            color: const Color(0xFF2E7D32),
                            onTap: () async {
                              await controller.answerCall();
                              // Navigation to ActiveCallScreen handled by CallGlobalListener
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
