import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/call_controller.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../app.dart';

class CallGlobalListener extends ConsumerStatefulWidget {
  final Widget child;

  const CallGlobalListener({super.key, required this.child});

  @override
  ConsumerState<CallGlobalListener> createState() => _CallGlobalListenerState();
}

class _CallGlobalListenerState extends ConsumerState<CallGlobalListener> {
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    AppRouter.routeObserver.currentRoute.addListener(_onRouteChange);

    // Check initial state immediately in case we launched from a Killed state
    // where the call is immediately in 'connecting' status (missed by ref.listen delta)
    Future.microtask(() {
      if (!mounted) return;
      final callState = ref.read(callControllerProvider);
      final currentRoute = AppRouter.routeObserver.currentRoute.value;
      if (callState.status == CallStatus.connecting || callState.status == CallStatus.connected) {
         if (currentRoute != RouteNames.activeCall) {
             navigatorKey.currentState?.pushReplacementNamed(RouteNames.activeCall);
         }
      } else if (callState.status == CallStatus.ringing && !ref.read(callControllerProvider.notifier).isCaller) {
         if (currentRoute != RouteNames.incomingCall) {
             navigatorKey.currentState?.pushNamed(RouteNames.incomingCall);
         }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    AppRouter.routeObserver.currentRoute.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _manageBannerTimer(bool shouldShowBanner, CallStatus status) {
    if (shouldShowBanner && status == CallStatus.connected) {
      if (_bannerTimer == null) {
        _bannerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } else {
      _bannerTimer?.cancel();
      _bannerTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Setup the listener for Call Controller Navigation (Transitions)
    ref.listen<CallState>(callControllerProvider, (previous, next) {
      final prevStatus = previous?.status;
      final nextStatus = next.status;

      // --- Incoming Call (Receiver) ---
      if (nextStatus == CallStatus.ringing && !ref.read(callControllerProvider.notifier).isCaller) {
        final route = AppRouter.routeObserver.currentRoute.value;
        if (route != RouteNames.incomingCall && route != RouteNames.splash) {
          navigatorKey.currentState?.pushNamed(RouteNames.incomingCall);
        }
      }

      // --- Call Connecting / Connected (Both Caller & Receiver) ---
      else if (nextStatus == CallStatus.connecting || nextStatus == CallStatus.connected) {
        final wasAlreadyInCall = prevStatus == CallStatus.connecting || prevStatus == CallStatus.connected;
        if (!wasAlreadyInCall) {
          navigatorKey.currentState?.pushReplacementNamed(RouteNames.activeCall);
        }
      }

      // --- Call Ended / Rejected (Both Sides) ---
      else if (nextStatus == CallStatus.ended || nextStatus == CallStatus.rejected || nextStatus == CallStatus.error) {
        final wasInCall = prevStatus == CallStatus.ringing || prevStatus == CallStatus.connecting ||
                          prevStatus == CallStatus.connected || prevStatus == CallStatus.initiating;
        if (wasInCall) {
          // Robust navigation: Ensure we land on the Home screen regardless of how the app was launched
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            RouteNames.chatList,
            (route) => false,
          );
        }
      }
    });

    // 2. Read the current call state to optionally show the Banner Overlay
    final callState = ref.watch(callControllerProvider);
    final isCallActive = callState.status == CallStatus.connected || callState.status == CallStatus.connecting;

    // We only show the banner if they are in an active call but navigated AWAY from the call screen
    final route = AppRouter.routeObserver.currentRoute.value;
    final isCallScreenActive = route == RouteNames.activeCall ||
                               route == RouteNames.incomingCall ||
                               route == RouteNames.outgoingCall ||
                               route == RouteNames.splash;

    final shouldShowBanner = isCallActive && !isCallScreenActive;
    final shouldShowIncomingBanner = callState.status == CallStatus.ringing &&
                                     !ref.read(callControllerProvider.notifier).isCaller &&
                                     !isCallScreenActive;

    // Manage UI Ticker
    _manageBannerTimer(shouldShowBanner, callState.status);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // The base application UI
          widget.child,

          // The Global Persistent Call Banner overlay (Ongoing Call)
          if (shouldShowBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      // Instantly navigate back to the active call screen
                      navigatorKey.currentState?.pushNamed(RouteNames.activeCall);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.green.shade600,
                      child: Row(
                        children: [
                          const Icon(Icons.call, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap to return to ongoing call',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              int seconds = 0;
                              if (callState.connectedAt != null) {
                                 seconds = DateTime.now().difference(callState.connectedAt!).inSeconds;
                              }
                              final minutes = (seconds / 60).floor();
                              final remainingSeconds = seconds % 60;
                              final timeStr = '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';

                              return Text(
                                callState.status == CallStatus.connected ? timeStr : 'Connecting...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // The Incoming Call Banner overlay
          if (shouldShowIncomingBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFF1C1C1E),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Text(
                                callState.currentCall?.callerName ?? 'Incoming Call',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Voice Call...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Decline Button
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.redAccent),
                          onPressed: () => ref.read(callControllerProvider.notifier).rejectCall(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                          ),
                        ),
                        // Accept Button
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.greenAccent),
                          onPressed: () => ref.read(callControllerProvider.notifier).answerCall(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.greenAccent.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
