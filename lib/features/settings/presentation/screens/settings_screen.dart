import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../di/injection_container.dart';
import '../../../user/data/models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.showBottomNav = true,
    this.onTabSelected,
  });

  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 3; // 0: Contacts, 1: Calls, 2: Chats, 3: Settings
  bool _isLoading = true;
  bool _isLoadingDevices = false;
  bool _isLoadingSessions = false;
  
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _sessions = [];
  String? _error;

  final ApiService _apiService = ApiService.instance;
  final SecureStorage _secureStorage = SecureStorage.instance;
  final LocalStorage _localStorage = LocalStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile data when navigating to this screen
    if (!_isLoading && _userProfile == null) {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try to load from local storage first for faster display
      final cachedProfile = await _localStorage.read(StorageKeys.userProfile);
      if (cachedProfile != null && cachedProfile.isNotEmpty) {
        try {
          final profileData = jsonDecode(cachedProfile) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userProfile = profileData;
              _isLoading = false;
            });
          }
        } catch (e) {
          Logger.w('Error parsing cached profile: $e');
        }
      }

      // Load fresh data from API
      final profile = await _apiService.getProfile();
      
      // Update local storage
      final userModel = UserModel.fromJson(profile);
      await _localStorage.write(
        StorageKeys.userProfile,
        jsonEncode(userModel.toJson()),
      );

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }

      // Load devices and sessions in background
      _loadDevices();
      _loadSessions(); // Load sessions to match with devices
    } catch (e) {
      Logger.e('Error loading profile', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load profile. Please try again.';
        });
      }
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final devices = await _apiService.getUserDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoadingDevices = false;
        });
      }
    } catch (e) {
      Logger.e('Error loading devices', e);
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _apiService.getSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
        });
      }
    } catch (e) {
      Logger.e('Error loading sessions', e);
    }
  }

  Future<void> _handleDeleteSession(String sessionId, String deviceModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to logout from "$deviceModel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deactivateSession(sessionId);
      
      // Reload sessions
      await _loadSessions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.e('Error deleting session', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting session. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Clear local data
      await _secureStorage.deleteAll();
      await _localStorage.clear();

      // Navigate to welcome screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.welcome,
          (route) => false,
        );
      }
    } catch (e) {
      Logger.e('Error during logout', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error during logout. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out All Devices'),
        content: const Text(
          'This will log you out from all devices. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deactivateAllSessions();
      
      // Clear local data
      await _secureStorage.deleteAll();
      await _localStorage.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out from all devices'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to welcome screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.welcome,
          (route) => false,
        );
      }
    } catch (e) {
      Logger.e('Error logging out all devices', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleTabChange(int index) {
    if (index == _selectedTab) return; // Already on this tab

    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }

    switch (index) {
      case 0: // Contacts
        Navigator.pushReplacementNamed(context, RouteNames.contacts);
        break;
      case 1: // Calls
        Navigator.pushReplacementNamed(context, RouteNames.calls);
        break;
      case 2: // Chats
        Navigator.pushReplacementNamed(context, RouteNames.chatList);
        break;
      case 3: // Settings
        // Already on settings, do nothing
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView(isDark)
                      : _buildProfileContent(isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? _buildBottomNavigation(isDark) : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight).withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          'Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error loading profile',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfileData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final userModel = _userProfile != null ? UserModel.fromJson(_userProfile!) : null;
    final username = userModel?.username ?? 'No username';
    final phone = userModel?.phone ?? 'No phone';
    final avatarUrl = _userProfile?['avatarUrl'] as String?;

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Profile Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: surfaceColor,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildInitialsAvatar(username);
                                  },
                                )
                              : _buildInitialsAvatar(username),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Navigate to edit profile for avatar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Avatar editing coming soon'),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_a_photo,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name/Username
                  Text(
                    username.startsWith('user_') ? 'User' : username,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Username
                  if (username.isNotEmpty && !username.startsWith('user_'))
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Phone
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                    ),
                  ),
                  // Online Status
                  if (userModel?.isOnline == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Edit Profile Button
                  _buildActionButton(
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        RouteNames.editProfile,
                      );
                      // Reload profile if it was updated
                      if (result == true) {
                        _loadProfileData();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Devices Section
                  _buildSectionHeader(isDark, 'Devices', _devices.length),
                  const SizedBox(height: 8),
                  _buildDevicesSection(isDark, surfaceColor),
                  const SizedBox(height: 24),
                  
                  // Log Out Button
                  _buildActionButton(
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    icon: Icons.logout,
                    title: 'Log Out',
                    color: Colors.red,
                    onTap: _handleLogout,
                  ),
                  const SizedBox(height: 12),
                  
                  // Log Out All Devices Button
                  _buildActionButton(
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    icon: Icons.logout,
                    title: 'Log Out All Devices',
                    color: Colors.red,
                    onTap: _handleLogoutAllDevices,
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = AvatarUtils.getInitials(name);
    final colorValue = AvatarUtils.getColorForName(name);
    
    return Container(
      decoration: BoxDecoration(
        color: Color(colorValue),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(colorValue),
            Color(colorValue).withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDark,
    required Color surfaceColor,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color ?? AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: color ?? AppColors.primary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesSection(bool isDark, Color surfaceColor) {
    if (_isLoadingDevices) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No devices registered',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _devices.map((device) {
          final deviceId = device['deviceId'] as String? ?? '';
          final deviceModel = device['deviceModel'] as String? ?? 'Unknown';
          final platform = device['platform'] as String? ?? 'Unknown';
          final osVersion = device['osVersion'] as String? ?? '';
          final registeredAt = device['registeredAt'] as String?;
          
          // Find session for this device
          final deviceSession = _sessions.firstWhere(
            (session) => session['deviceId'] == deviceId && (session['isActive'] as bool? ?? false),
            orElse: () => <String, dynamic>{},
          );
          
          return _buildDeviceItem(
            isDark: isDark,
            deviceId: deviceId,
            deviceModel: deviceModel,
            platform: platform,
            osVersion: osVersion,
            registeredAt: registeredAt,
            session: deviceSession,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeviceItem({
    required bool isDark,
    required String deviceId,
    required String deviceModel,
    required String platform,
    required String osVersion,
    String? registeredAt,
    required Map<String, dynamic> session,
  }) {
    final sessionId = session['sessionId'] as String?;
    final isActive = session['isActive'] as bool? ?? false;
    final expiresAt = session['expiresAt'] as String?;
    final hasActiveSession = sessionId != null && isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                platform.toLowerCase().contains('ios') ? Icons.phone_iphone : Icons.phone_android,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceModel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$platform $osVersion',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (registeredAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Registered: ${_formatDate(registeredAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasActiveSession && sessionId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _handleDeleteSession(sessionId, deviceModel),
                  tooltip: 'Delete session',
                ),
            ],
          ),
          if (hasActiveSession) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Active session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Expires: ${_formatDate(expiresAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ] else if (sessionId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Inactive session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, y • h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildBottomNavigation(bool isDark) {
    final backgroundColor = isDark ? AppColors.surfaceDark : Colors.white;
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.contacts, 'Contacts', 0, isDark),
          _buildNavItem(Icons.call, 'Calls', 1, isDark),
          _buildNavItem(Icons.chat_bubble, 'Chats', 2, isDark),
          _buildNavItem(Icons.settings, 'Settings', 3, isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => _handleTabChange(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              fill: isSelected ? 1.0 : 0.0,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
