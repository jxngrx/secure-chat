import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../../core/services/device_registration_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/logger.dart';
import '../../../../di/injection_container.dart';

class OtpScreen extends StatefulWidget {
  final String? phoneNumber; // Pass phone number from previous screen

  const OtpScreen({super.key, this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  Timer? _timer;
  int _remainingSeconds = 59;
  bool _showResendButton = false;
  bool _showToast = false;
  bool _isVerifying = false;
  String _maskedPhone = '+1 234 *** **89'; // Default masked phone
  
  // Services
  final ApiService _apiService = ApiService.instance;
  late final DeviceInfoService _deviceInfoService;
  late final LocationService _locationService;
  late final SecureStorage _secureStorage;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _maskedPhone = _maskPhoneNumber(widget.phoneNumber ?? '+1234567890');
    
    // Initialize services
    _deviceInfoService = InjectionContainer.resolve<DeviceInfoService>();
    _locationService = InjectionContainer.resolve<LocationService>();
    _secureStorage = SecureStorage.instance;

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });

    // Add listeners for auto-navigation
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].addListener(() => _onTextChanged(i));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length < 10) return phone;
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 10) return phone;

    // Format: +1 234 *** **89
    final countryCode = cleaned.length > 10 ? '+${cleaned.substring(0, cleaned.length - 10)}' : '+1';
    final areaCode = cleaned.substring(cleaned.length - 10, cleaned.length - 7);
    final lastTwo = cleaned.substring(cleaned.length - 2);

    return '$countryCode $areaCode *** **$lastTwo';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _showResendButton = true;
        });
        timer.cancel();
      }
    });
  }

  void _onTextChanged(int index) {
    final text = _controllers[index].text;

    // Handle paste (multiple characters)
    if (text.length > 1) {
      _handlePaste(text, index);
      return;
    }

    // Move to next field if digit entered
    if (text.isNotEmpty && index < _controllers.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all fields are filled
    if (_isAllFieldsFilled()) {
      _verifyOtp();
    }
  }

  void _handlePaste(String pastedText, int startIndex) {
    final digits = pastedText.replaceAll(RegExp(r'\D'), '').split('');

    for (int i = 0; i < digits.length && (startIndex + i) < _controllers.length; i++) {
      _controllers[startIndex + i].text = digits[i];
    }

    // Focus the last filled field or the last field
    final nextFocusIndex = (startIndex + digits.length - 1).clamp(0, _controllers.length - 1);
    _focusNodes[nextFocusIndex].requestFocus();

    // Show toast notification
    setState(() {
      _showToast = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });

    // Verify if all fields filled
    if (_isAllFieldsFilled()) {
      _verifyOtp();
    }
  }

  bool _isAllFieldsFilled() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    
    final otp = _controllers.map((c) => c.text).join();
    final phoneNumber = widget.phoneNumber;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showError('Phone number is missing');
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    try {
      // Get device info
      final deviceDetails = await _deviceInfoService.getDeviceDetails();
      
      // Get location (optional, non-blocking)
      Map<String, dynamic>? location;
      try {
        location = await _locationService.getCurrentLocation();
      } catch (e) {
        Logger.w('Could not get location for OTP verification: $e');
        // Continue without location
      }

      // Verify OTP via API
      final response = await _apiService.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
        deviceId: deviceDetails.deviceId,
        location: location,
      );

      // Store token and session
      final token = response['token'] as String?;
      final sessionData = response['session'] as Map<String, dynamic>?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (token != null && token.isNotEmpty) {
        await _secureStorage.write(StorageKeys.authToken, token);
      }

      if (sessionData != null) {
        final sessionId = sessionData['sessionId'] as String?;
        final deviceId = sessionData['deviceId'] as String?;
        
        if (sessionId != null) {
          await _secureStorage.write(StorageKeys.sessionId, sessionId);
        }
        if (deviceId != null) {
          await _secureStorage.write(StorageKeys.deviceId, deviceId);
        }
      }

      // Register device if not already registered
      try {
        final deviceRegistrationService = InjectionContainer.resolve<DeviceRegistrationService>();
        await deviceRegistrationService.registerDevice();
        Logger.d('Device registered successfully after OTP verification');
      } catch (e) {
        Logger.w('Error registering device after OTP verification: $e');
        // Continue even if device registration fails
      }

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        // Always navigate to username setup first (for both new and existing users)
        Navigator.pushReplacementNamed(context, RouteNames.usernameSetup);
      }
    } catch (e) {
      Logger.e('Error verifying OTP', e);
      
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        // Show error message
        String errorMessage = 'Invalid OTP. Please try again.';
        if (e.toString().contains('expired')) {
          errorMessage = 'OTP has expired. Please request a new one.';
        } else if (e.toString().contains('attempts')) {
          errorMessage = 'Too many failed attempts. Please request a new OTP.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        }

        _showError(errorMessage);
        
        // Clear OTP fields
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleBackspace(int index, String value) {
    if (value.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleResend() async {
    final phoneNumber = widget.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showError('Phone number is missing');
      return;
    }

    setState(() {
      _remainingSeconds = 59;
      _showResendButton = false;
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    });
    _startTimer();

    // Resend OTP
    try {
      await _apiService.requestOtp(phoneNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.e('Error resending OTP', e);
      if (mounted) {
        String errorMessage = 'Failed to resend OTP. Please try again.';
        if (e.toString().contains('rate limit')) {
          errorMessage = 'Too many requests. Please wait a minute.';
        }
        _showError(errorMessage);
      }
    }
  }

  void _handleEdit() {
    Navigator.pop(context);
  }

  String _formatTimer() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? const Color(0xFF1A2632) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Icon/Hero
                    _buildIcon(),
                    const SizedBox(height: 32),

                    // Text Content
                    _buildTextContent(isDark),
                    const SizedBox(height: 40),

                    // OTP Input Fields
                    _buildOtpInputs(isDark, surfaceColor),
                    const SizedBox(height: 40),

                    // Loading indicator during verification
                    if (_isVerifying)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Verifying...',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Timer / Resend
                    if (!_isVerifying) _buildTimerAndResend(isDark),

                    const SizedBox(height: 100),

                    // Toast Notification
                    if (_showToast) _buildToast(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance spacer
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.lock_person,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }

  Widget _buildTextContent(bool isDark) {
    return Column(
      children: [
        Text(
          'Verification Code',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We sent a code to\n'),
              TextSpan(
                text: _maskedPhone,
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: ' '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: _handleEdit,
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInputs(bool isDark, Color surfaceColor) {
    return Opacity(
      opacity: _isVerifying ? 0.5 : 1.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < 5 ? 8 : 0,
            ),
            child: _OtpInputField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              isDark: isDark,
              surfaceColor: surfaceColor,
              enabled: !_isVerifying,
              onChanged: (value) {
                if (value.isEmpty) {
                  _handleBackspace(index, value);
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimerAndResend(bool isDark) {
    return Column(
      children: [
        if (!_showResendButton)
          Text(
            'Resend code in ${_formatTimer()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        if (_showResendButton) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _handleResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Resend Code',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToast(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedOpacity(
        opacity: _showToast ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Code pasted from messages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color surfaceColor;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _OtpInputField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.surfaceColor,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  State<_OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<_OtpInputField> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hasFocus
              ? AppColors.primary
              : (widget.isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
          width: _hasFocus ? 2 : 1,
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6), // Allow paste
        ],
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
        onTap: () {
          if (!widget.enabled) return;
          // Select all text when tapped
          if (widget.controller.text.isNotEmpty) {
            widget.controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.controller.text.length,
            );
          }
        },
      ),
    );
  }
}
