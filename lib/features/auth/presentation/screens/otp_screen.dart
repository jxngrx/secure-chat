import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';

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
  String _maskedPhone = '+1 234 *** **89'; // Default masked phone

  @override
  void initState() {
    super.initState();
    _startTimer();
    _maskedPhone = _maskPhoneNumber(widget.phoneNumber ?? '+1234567890');

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

  void _verifyOtp() {
    final otp = _controllers.map((c) => c.text).join();

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Simulate verification
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Navigate to next screen (username setup or chat list)
        Navigator.pushReplacementNamed(context, RouteNames.usernameSetup);
      }
    });
  }

  void _handleBackspace(int index, String value) {
    if (value.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handleResend() {
    setState(() {
      _remainingSeconds = 59;
      _showResendButton = false;
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    });
    _startTimer();
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

                    // Timer / Resend
                    _buildTimerAndResend(isDark),

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
    return Row(
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
            onChanged: (value) {
              if (value.isEmpty) {
                _handleBackspace(index, value);
              }
            },
          ),
        );
      }),
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
  final ValueChanged<String> onChanged;

  const _OtpInputField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.surfaceColor,
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
