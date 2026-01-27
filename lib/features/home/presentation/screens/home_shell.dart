import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../call/presentation/screens/calls_screen.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../contacts/presentation/screens/contacts_list_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialTab = 2,
  });

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _currentIndex;
  late final PageController _pageController;
  late final List<_HomeTabConfig> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    _tabs = [
      _HomeTabConfig(
        label: 'Contacts',
        icon: Icons.contacts,
        child: ContactsListScreen(
          key: const PageStorageKey('contacts_tab'),
          showBottomNav: false,
          onTabSelected: _handleExternalTabRequest,
        ),
      ),
      _HomeTabConfig(
        label: 'Calls',
        icon: Icons.call,
        child: CallsScreen(
          key: const PageStorageKey('calls_tab'),
          showBottomNav: false,
          onTabSelected: _handleExternalTabRequest,
        ),
      ),
      _HomeTabConfig(
        label: 'Chats',
        icon: Icons.chat_bubble,
        child: ChatListScreen(
          key: const PageStorageKey('chats_tab'),
          showBottomNav: false,
          onTabSelected: _handleExternalTabRequest,
        ),
      ),
      _HomeTabConfig(
        label: 'Settings',
        icon: Icons.settings,
        child: SettingsScreen(
          key: const PageStorageKey('settings_tab'),
          showBottomNav: false,
          onTabSelected: _handleExternalTabRequest,
        ),
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        widget.initialTab >= 0 &&
        widget.initialTab < _tabs.length) {
      _pageController.jumpToPage(widget.initialTab);
      setState(() {
        _currentIndex = widget.initialTab;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleExternalTabRequest(int index) {
    _onTabSelected(index);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex || index < 0 || index >= _tabs.length) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (index != _currentIndex) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          children: _tabs
              .map((tab) => _KeepAlivePage(child: tab.child))
              .toList(growable: false),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
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
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final isSelected = _currentIndex == index;
          final color = isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
          return InkWell(
            onTap: () => _onTabSelected(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 26,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                    child: Text(tab.label),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HomeTabConfig {
  const _HomeTabConfig({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
