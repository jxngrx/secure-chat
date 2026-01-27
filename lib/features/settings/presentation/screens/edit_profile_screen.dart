import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../di/injection_container.dart';
import '../../../user/data/models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isUsernameAvailable = false;
  bool _isCheckingUsername = false;

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  Map<String, dynamic>? _userProfile;
  String? _currentAvatarUrl;

  final ApiService _apiService = ApiService.instance;
  final LocalStorage _localStorage = LocalStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _usernameController.addListener(() {
      _onUsernameChanged();
      setState(() {}); // Update avatar when username changes
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _apiService.getProfile();
      final userModel = UserModel.fromJson(profile);

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _usernameController.text = userModel.username ?? '';
          _currentAvatarUrl = profile['avatarUrl'] as String?;
          _isLoadingProfile = false;
        });

        // Check username availability if username exists
        if (userModel.username != null && userModel.username!.isNotEmpty) {
          _checkUsernameAvailability();
        }
      }
    } catch (e) {
      Logger.e('Error loading profile', e);
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onUsernameChanged() {
    if (_usernameController.text.isNotEmpty) {
      _checkUsernameAvailability();
    } else {
      setState(() {
        _isUsernameAvailable = false;
      });
    }
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();

    if (!Validators.isValidUsername(username)) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    // Don't check if username hasn't changed
    final currentUsername = _userProfile?['username'] as String? ?? '';
    if (username == currentUsername) {
      setState(() {
        _isUsernameAvailable = true;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      // Call API to check username availability
      final isAvailable = await _apiService.checkUsernameAvailability(username);

      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
        });
      }
    } catch (e) {
      Logger.e('Error checking username availability', e);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
          });
        }
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image picker is not available on this platform.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Logger.e('Error picking image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    final username = _usernameController.text.trim();

    if (!Validators.isValidUsername(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid username'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if username changed
    final currentUsername = _userProfile?['username'] as String? ?? '';
    if (username == currentUsername && _selectedImage == null && _selectedImageBytes == null) {
      // No changes
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update username if changed
      if (username != currentUsername) {
        await _apiService.updateUsername(username);

        // Update local storage
        final updatedProfile = await _apiService.getProfile();
        final userModel = UserModel.fromJson(updatedProfile);
        await _localStorage.write(
          StorageKeys.userProfile,
          jsonEncode(userModel.toJson()),
        );
      }

      // TODO: Upload avatar if image selected
      if (_selectedImage != null || _selectedImageBytes != null) {
        // Avatar upload will be implemented later
        Logger.d('Avatar upload not yet implemented');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true); // Return true to indicate profile was updated
      }
    } catch (e) {
      Logger.e('Error updating profile', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Failed to update profile. Please try again.';
        if (e.toString().contains('taken') || e.toString().contains('exists')) {
          errorMessage = 'This username is already taken. Please choose another.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('invalid') || e.toString().contains('validation')) {
          errorMessage = 'Invalid username format. Please use 3-30 alphanumeric characters and underscores.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? const Color(0xFF1B242C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF324D67) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isLoadingProfile)
            TextButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _isLoading
                            ? Colors.grey
                            : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Avatar Section
                  _buildAvatarSection(isDark, surfaceColor),
                  const SizedBox(height: 32),

                  // Username Input
                  _buildUsernameInput(isDark, surfaceColor, borderColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection(bool isDark, Color surfaceColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? surfaceColor : Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                              ? Image.network(
                                  _currentAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildInitialsAvatar(_usernameController.text);
                                  },
                                )
                              : _buildInitialsAvatar(_usernameController.text),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
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
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Text(
            'Change Photo',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

  Widget _buildUsernameInput(bool isDark, Color surfaceColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'USERNAME',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark ? const Color(0xFF92ADC9) : const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _usernameFocusNode.hasFocus
                  ? AppColors.primary
                  : borderColor,
              width: _usernameFocusNode.hasFocus ? 2 : 1,
            ),
            boxShadow: _usernameFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '@',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                  enabled: !_isLoading,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'username',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _isUsernameAvailable
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              )
                            : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isUsernameAvailable)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Username is available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
