import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';
import '../../../../core/services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/constants/app_colors.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startTimerIfConnected();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfConnected() {
    final callState = ref.read(callControllerProvider);
    if (callState.status == CallStatus.connected) {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final call = controller.currentCall;

    // Start timer if call just connected
    if (callState.status == CallStatus.connected && _timer == null) {
      _startTimer();
    }

    // Auto-close if call ended
    if (callState.status == CallStatus.ended || callState.status == CallStatus.rejected || callState.status == CallStatus.error) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/');
       });
       return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Call Ended", style: TextStyle(color: Colors.white))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              const Color(0xFF121212),
              const Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: AppColors.primary.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'End-to-end Encrypted',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Active Call Info
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated pulse effects would go here, but kept simple for stability
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(Icons.person, size: 100, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Builder(
                    builder: (context) {
                      final currentUserId = callState.currentUserId;
                      final isOutgoing = call?.callerId == currentUserId;
                      final otherName = isOutgoing
                          ? (call?.receiverName ?? 'User ${call?.receiverId.substring(call.receiverId.length > 5 ? call.receiverId.length - 5 : 0)}')
                          : (call?.callerName ?? 'User ${call?.callerId.substring(call.callerId.length > 5 ? call.callerId.length - 5 : 0)}');

                      return Text(
                        otherName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: callState.status == CallStatus.connected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      callState.status == CallStatus.connected
                        ? _formatDuration(_secondsElapsed)
                        : callState.status == CallStatus.connecting
                            ? 'Connecting...'
                            : 'Dialing...',
                      style: TextStyle(
                        color: callState.status == CallStatus.connected
                            ? AppColors.primary
                            : Colors.white54,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Bottom Controls
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: callState.isMuted,
                      activeColor: Colors.redAccent,
                      onPressed: () => controller.toggleMute(),
                    ),
                    _buildControlButton(
                      icon: callState.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      isActive: callState.isSpeakerOn,
                      activeColor: AppColors.primary,
                      onPressed: () => controller.toggleSpeaker(),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await controller.endCall();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : Colors.white.withOpacity(0.08),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
