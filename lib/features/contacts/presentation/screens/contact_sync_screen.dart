import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/permissions/permission_handler.dart' as AppPermissionHandler;
import '../../../../core/services/api_service.dart';
import '../../../../core/services/contact_service.dart';
import '../../../../core/utils/logger.dart';

class ContactSyncScreen extends StatefulWidget {
  const ContactSyncScreen({super.key});

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final AppPermissionHandler.PermissionHandler _permissionHandler =
      AppPermissionHandler.PermissionHandler.instance;
  final ContactService _contactService = ContactService.instance;
  final ApiService _apiService = ApiService.instance;

  Future<void> _handleAllowAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check current permission status using permission_handler
      final status = await ph.Permission.contacts.status;
      Logger.d('Current contacts permission status: $status');

      // If already granted, sync contacts
      if (status.isGranted) {
        Logger.d('Permission already granted, syncing contacts');
        await _syncContacts();
        return;
      }

      // If permanently denied, show settings dialog
      if (status.isPermanentlyDenied) {
        Logger.d('Permission permanently denied, showing settings dialog');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSettingsDialog();
        }
        return;
      }

      // Request permission - try FlutterContacts first (most reliable)
      bool granted = false;
      
      Logger.d('Requesting contacts permission...');
      
      // Method 1: Try FlutterContacts (recommended for contacts)
      try {
        granted = await FlutterContacts.requestPermission(readonly: true);
        Logger.d('FlutterContacts.requestPermission result: $granted');
      } catch (e) {
        Logger.w('FlutterContacts.requestPermission error: $e');
      }
      
      // Method 2: If not granted, try permission_handler
      if (!granted) {
        try {
          final newStatus = await ph.Permission.contacts.request();
          Logger.d('Permission_handler.request result: $newStatus');
          granted = newStatus.isGranted;
        } catch (e) {
          Logger.w('Permission_handler.request error: $e');
        }
      }

      // Verify final status
      if (granted) {
        final finalStatus = await ph.Permission.contacts.status;
        granted = finalStatus.isGranted;
        Logger.d('Final permission status after request: $finalStatus');
      }

      if (mounted) {
        if (granted) {
          // Permission granted, sync contacts
          Logger.d('Permission granted, syncing contacts');
          await _syncContacts();
        } else {
          // Permission denied
          Logger.w('Permission denied by user');
          setState(() {
            _isLoading = false;
          });
          
          // Check if it's now permanently denied
          final finalStatus = await ph.Permission.contacts.status;
          if (finalStatus.isPermanentlyDenied) {
            _showSettingsDialog();
          } else {
            _showPermissionDeniedMessage();
          }
        }
      }
    } catch (e) {
      Logger.e('Error in _handleAllowAccess', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error requesting permission: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Sync contacts with backend
  Future<void> _syncContacts() async {
    try {
      // Get contacts with phone numbers and names
      final contacts = await _contactService.getContactsWithNames();

      if (contacts.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts found with phone numbers'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          // Navigate anyway (user can sync later)
          _navigateToChatList();
        }
        return;
      }

      // Sync contacts with backend via API (new format with phoneNumber + contactName)
      final syncedContacts = await _apiService.syncContacts(contacts);

      Logger.d('Synced ${syncedContacts.length} contacts with backend');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedContacts.isEmpty
                  ? 'No contacts found using this app'
                  : 'Found ${syncedContacts.length} contact${syncedContacts.length == 1 ? '' : 's'} using this app',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to chat list
        _navigateToChatList();
      }
    } catch (e) {
      Logger.e('Error syncing contacts', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Failed to sync contacts. Please try again.';
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // Navigate anyway (user can sync later from settings)
        _navigateToChatList();
      }
    }
  }

  void _navigateToChatList() {
    Navigator.pushReplacementNamed(context, RouteNames.chatList);
  }

  void _handleSkip() {
    // User skipped, navigate to chat list anyway
    _navigateToChatList();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Contacts permission is required to find your friends. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ph.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacts permission is required to find your friends.'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
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
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Hero Illustration
                    _buildHeroIllustration(),
                    const SizedBox(height: 32),

                    // Header Text
                    _buildHeaderText(isDark),
                    const SizedBox(height: 32),

                    // Value Props List
                    _buildValueProps(isDark, surfaceColor),
                  ],
                ),
              ),
            ),

            // Footer Actions
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroIllustration() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Stack(
        children: [
          // Blur effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          // Icon
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.people,
                size: 64,
                color: AppColors.primary.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderText(bool isDark) {
    return Column(
      children: [
        Text(
          'Connect with People You Know',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 320,
          child: Text(
            'To help you message friends and family, we need access to your contact list.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildValueProps(bool isDark, Color surfaceColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildValuePropItem(
            icon: Icons.person_search,
            title: 'Find Friends Instantly',
            description: 'See who from your contacts is already using the app.',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildValuePropItem(
            icon: Icons.lock,
            title: 'Private & Secure',
            description: 'Your contacts are anonymously hashed and never shared.',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildValuePropItem(
            icon: Icons.sync,
            title: 'Auto-Update',
            description: 'New contacts you add will appear automatically.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildValuePropItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Allow Access Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _handleAllowAccess,
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isLoading)
                      Text(
                        'Allow Access',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    if (_isLoading)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Syncing contacts...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Skip Button
          TextButton(
            onPressed: _isLoading ? null : _handleSkip,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Footer Text
          Text(
            'You can change this anytime in settings.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
