import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';
import '../../../../core/services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Timer? _timer;

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
        setState(() {}); // Simple rebuild to trigger getter re-evaluation
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

    // Handle terminal state UI navigation
    ref.listen<CallStatus>(callControllerProvider.select((s) => s.status), (prev, next) {
      if (next == CallStatus.ended || next == CallStatus.rejected || next == CallStatus.error || next == CallStatus.idle) {
         _timer?.cancel();
         _timer = null;
         if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.chatList,
              (route) => false,
            );
         }
      } else if (next == CallStatus.connected && _timer == null) {
         _startTimer();
      }
    });

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

                      // Safely compute the display name to avoid null-check crashes during Killed-State intent hydration
                      String otherName = 'Connecting...';
                      if (call != null) {
                         if (isOutgoing) {
                            final rawId = call.receiverId;
                            final shortId = rawId.length > 5 ? rawId.substring(rawId.length - 5) : rawId;
                            otherName = call.receiverName ?? 'User $shortId';
                         } else {
                            final rawId = call.callerId;
                            final shortId = rawId.length > 5 ? rawId.substring(rawId.length - 5) : rawId;
                            otherName = call.callerName ?? 'User $shortId';
                         }
                      }

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
                    child: Builder(
                      builder: (context) {
                        int seconds = 0;
                        if (callState.connectedAt != null) {
                           seconds = DateTime.now().difference(callState.connectedAt!).inSeconds;
                        }
                        return Text(
                          callState.status == CallStatus.connected
                            ? _formatDuration(seconds)
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
                        );
                      }
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
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            RouteNames.chatList,
                            (route) => false,
                          );
                        }
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
