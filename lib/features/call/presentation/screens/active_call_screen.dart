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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
                    'End-to-end Encrypted',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Active Call Info
             Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 80,
                  backgroundColor: Color(0xFF333333),
                  child: Icon(Icons.person, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  call?.receiverId ?? call?.callerId ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                 const SizedBox(height: 12),
                Text(
                  callState.status == CallStatus.connected
                    ? _formatDuration(_secondsElapsed)
                    : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Bottom Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      callState.isMuted ? Icons.mic_off : Icons.mic,
                      color: callState.isMuted ? Colors.red : Colors.white,
                      size: 32
                    ),
                    onPressed: () {
                      controller.toggleMute();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      callState.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: callState.isSpeakerOn ? AppColors.primary : Colors.white,
                      size: 32
                    ),
                    onPressed: () {
                      controller.toggleSpeaker();
                    },
                  ),
                  FloatingActionButton(
                    onPressed: () async {
                      await controller.endCall();
                      if (mounted) Navigator.pop(context);
                    },
                    backgroundColor: Colors.red,
                    elevation: 0,
                    child: const Icon(Icons.call_end, color: Colors.white),
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
