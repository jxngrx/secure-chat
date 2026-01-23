import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../data/models/contact_model.dart';
import '../notifiers/contact_controller.dart';
import '../../domain/entities/contact_entity.dart';

class ContactsListScreen extends ConsumerStatefulWidget {
  const ContactsListScreen({super.key});

  @override
  ConsumerState<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends ConsumerState<ContactsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Contacts, 1: Calls, 2: Chats, 3: Settings

  @override
  void initState() {
    super.initState();
    // Load contacts from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactControllerProvider.notifier).loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    if (index == _selectedTab) return; // Already on this tab

    switch (index) {
      case 0: // Contacts
        // Already on contacts, do nothing
        break;
      case 1: // Calls
        Navigator.pushReplacementNamed(context, RouteNames.calls);
        break;
      case 2: // Chats
        Navigator.pushReplacementNamed(context, RouteNames.chatList);
        break;
      case 3: // Settings
        Navigator.pushReplacementNamed(context, RouteNames.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final contactState = ref.watch(contactControllerProvider);
    final filteredContacts = _getFilteredContacts(contactState.contacts);

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
              child: contactState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredContacts.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildContactsList(filteredContacts, isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }

  List<ContactEntity> _getFilteredContacts(List<ContactEntity> contacts) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return contacts;
    return contacts.where((contact) {
      final phone = contact.phone.toLowerCase();
      final username = contact.username?.toLowerCase() ?? '';
      return phone.contains(query) || username.contains(query);
    }).toList();
  }

  Widget _buildHeader(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contacts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(List<ContactEntity> contacts, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        return _buildContactItem(contacts[index], isDark);
      },
    );
  }

  Widget _buildContactItem(ContactEntity contact, bool isDark) {
    return InkWell(
      onTap: () {}, // TODO: Show contact details or start chat
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppColors.dividerDark.withOpacity(0.5)
                  : AppColors.dividerLight,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(contact, isDark),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.username ?? contact.phone,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ContactEntity contact, bool isDark) {
    final displayName = contact.username ?? contact.phone;
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getAvatarColor(displayName),
          ),
          child: Center(
            child: Text(
              _getInitials(displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (contact.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts,
            size: 64,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
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

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF06B6D4),
    ];
    return colors[name.hashCode % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
  }

}
