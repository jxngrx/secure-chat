import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/call_controller.dart';
import '../../../../core/services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  // Renderers not strictly needed for Audio ONLY, but good for visualization/video expansion
  /*
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final webRTCService = WebRTCService.instance;
    // ... attach streams
  }
  */
  // Skipping renderers for pure audio MVP to avoid black screen confusion

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final call = controller.currentCall;

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
                  callState.status == CallStatus.connected ? '00:00' : 'Connecting...', // TODO: Timer
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
                    icon: const Icon(Icons.mic, color: Colors.white, size: 32),
                    onPressed: () {
                      // Toggle Mute
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white, size: 32),
                    onPressed: () {
                      // Toggle Speaker
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
