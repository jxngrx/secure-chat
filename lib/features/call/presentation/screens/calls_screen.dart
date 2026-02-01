import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/date_utils.dart' as AppDateUtils;
import '../../data/models/call_item_model.dart';
import '../notifiers/call_controller.dart';
import '../../domain/entities/call_entity.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({
    super.key,
    this.showBottomNav = true,
    this.onTabSelected,
  });

  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0; // 0: All, 1: Missed
  int _selectedTab = 0; // 0: Calls, 1: Chats, 2: Settings
  List<CallItemModel> _calls = [];

  @override
  void initState() {
    super.initState();
    // Load calls from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callControllerProvider.notifier).loadCallHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    if (index == _selectedTab) return; // Already on this tab

    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }

    switch (index) {
      case 0: // Calls
        // Already on calls, do nothing
        break;
      case 1: // Chats
        Navigator.pushReplacementNamed(context, RouteNames.chatList);
        break;
      case 2: // Settings
        Navigator.pushReplacementNamed(context, RouteNames.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final callState = ref.watch(callControllerProvider);

    // Convert CallEntity to CallItemModel for display
    final allCalls = callState.calls.map((call) {
      return CallItemModel(
        id: call.id,
        name: 'User ${call.receiverId}', // TODO: Get actual user name
        timestamp: call.startTime,
        type: _mapCallStatusToType(call.status),
        direction: call.callerId == 'current_user' ? CallDirection.outgoing : CallDirection.incoming,
      );
    }).toList();

    final filteredCalls = _selectedFilter == 0
        ? allCalls
        : allCalls.where((call) => call.type == CallType.missed).toList();

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
              child: callState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCalls.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildCallsList(filteredCalls, isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? _buildBottomNavigation(isDark) : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Column(
        children: [
          // Top row with Edit, Filter, and New Call button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              // Filter buttons
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE3E3E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildFilterButton('All', 0, isDark),
                    _buildFilterButton('Missed', 1, isDark),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {}, // TODO: Start new call
                icon: Icon(
                  Icons.add_call,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ],
          ),
          // Title
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Calls',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    fontSize: 17,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, int index, bool isDark) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF636366) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }

  Widget _buildCallsList(List<CallItemModel> calls, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: calls.length,
      itemBuilder: (context, index) {
        return _buildCallItem(calls[index], isDark);
      },
    );
  }

  Widget _buildCallItem(CallItemModel call, bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final timeText = _formatCallTime(call.timestamp);
    final isMissed = call.type == CallType.missed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
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
          onTap: () {}, // TODO: Show call details or initiate call
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(call, isDark),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              call.missedCount != null && call.missedCount! > 1
                                  ? '${call.name} (${call.missedCount})'
                                  : call.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isMissed
                                    ? const Color(0xFFFF3B30)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getCallIcon(call),
                            size: 16,
                            color: isMissed
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF8E8E93),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getCallTypeText(call),
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Info button
                IconButton(
                  onPressed: () {}, // TODO: Show call info
                  icon: Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(CallItemModel call, bool isDark) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: call.avatarUrl == null
                ? _getAvatarColor(call.name)
                : null,
          ),
          child: call.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    call.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: _getAvatarColor(call.name),
                        child: Center(
                          child: Text(
                            _getInitials(call.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    _getInitials(call.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        if (call.type == CallType.incoming && !call.isVideo)
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
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getCallIcon(CallItemModel call) {
    if (call.type == CallType.missed) {
      return Icons.call_missed;
    } else if (call.direction == CallDirection.outgoing) {
      return Icons.call_made;
    } else {
      return Icons.call_received;
    }
  }

  String _getCallTypeText(CallItemModel call) {
    if (call.type == CallType.missed) {
      return 'Missed';
    } else if (call.isVideo) {
      return 'Video';
    } else if (call.direction == CallDirection.outgoing) {
      return 'Outgoing';
    } else {
      return 'Incoming';
    }
  }

  String _formatCallTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return AppDateUtils.DateUtils.formatTime(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(time.toLocal());
    } else {
      return 'Last Week';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call,
            size: 64,
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            'No calls',
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
          _buildNavItem(Icons.call, 'Calls', 0, isDark),
          _buildNavItem(Icons.chat_bubble, 'Chats', 1, isDark),
          _buildNavItem(Icons.settings, 'Settings', 2, isDark),
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
              size: 28,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280)),
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
                    : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280)),
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

  CallType _mapCallStatusToType(String status) {
    switch (status.toLowerCase()) {
      case 'rejected':
      case 'missed':
        return CallType.missed;
      case 'ended':
      case 'answered':
        return CallType.incoming;
      default:
        return CallType.incoming;
    }
  }
}
