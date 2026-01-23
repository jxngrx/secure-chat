import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../data/models/country_model.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  // Fixed to India only
  final CountryModel _selectedCountry = CountryModel(
    code: 'IN',
    name: 'India',
    flag: '🇮🇳',
    dialCode: '+91',
  );
  bool _isLoading = false;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _showClearButton = _phoneController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  // Country selection removed - India only

  void _handleContinue() {
    final phoneNumber = _phoneController.text;
    // TODO: Use fullPhoneNumber when sending to API
    // final fullPhoneNumber = '${_selectedCountry.dialCode}${PhoneFormatter.getUnformattedPhone(phoneNumber)}';

    if (!PhoneFormatter.isValidPhoneNumber(phoneNumber, _selectedCountry.dialCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // No gaps in phone number - use as is
        final fullPhoneNumber = '${_selectedCountry.dialCode}$phoneNumber';
        Navigator.pushNamed(
          context,
          RouteNames.otp,
          arguments: fullPhoneNumber,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? const Color(0xFF233648) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Instructional Text
                    _buildInstructionalText(isDark),
                    const SizedBox(height: 40),

                    // Input Group Card
                    _buildInputCard(isDark, surfaceColor),
                    const SizedBox(height: 24),

                    // Validation/Info Note
                    _buildInfoNote(isDark),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // Continue Button (Fixed at bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _buildContinueButton(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cancel Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _handleCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          // Title
          Center(
            child: Text(
              'Your Phone Number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Spacer for balance
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInstructionalText(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Please confirm your country code and enter your phone number.',
        style: TextStyle(
          fontSize: 16,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInputCard(bool isDark, Color surfaceColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phone Input Row (India fixed, no country selector)
          Row(
            children: [
              // Fixed Prefix
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? const Color(0xFF475569).withOpacity(0.5)
                          : const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  _selectedCountry.dialCode,
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
              // Text Field
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    // No formatter - display without gaps
                  ],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Clear Button
              if (_showClearButton)
                IconButton(
                  icon: Icon(
                    Icons.cancel,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  onPressed: () {
                    _phoneController.clear();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'We will send an SMS with a confirmation code to your phone number. Carrier rates may apply.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContinueButton(bool isDark) {
    final phoneDigits = PhoneFormatter.getUnformattedPhone(_phoneController.text);
    final isValid = phoneDigits.length >= 7;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isValid ? AppColors.primary : AppColors.primary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isValid
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isValid && !_isLoading ? _handleContinue : () {},
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Button Text
              Opacity(
                opacity: isValid ? 1.0 : 0.6,
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Loading Spinner
              if (_isLoading)
                Positioned(
                  right: 16,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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

// Phone number formatter removed - no gaps needed

// Country picker removed - India only
