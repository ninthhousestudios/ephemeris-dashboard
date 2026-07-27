// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tab_definitions.dart';
import 'tab_registry.dart';
import 'responsive_layout.dart';
import '../core/active_tab.dart';
import '../core/persistence.dart';
import '../theme/theme_provider.dart';
import '../widgets/context_bar/context_bar.dart';
import '../widgets/flag_bar/flag_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin {
  late TabController _tabController;

  static final _allTabs = AppTab.values.toList();

  @override
  void initState() {
    super.initState();

    final initialTab = ref.read(activeTabProvider);
    final initialIndex = _allTabs.indexOf(initialTab);

    _tabController = TabController(
      length: _allTabs.length,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _allTabs[_tabController.index];
        ref.read(activeTabProvider.notifier).state = tab;
        ref.read(persistenceProvider).saveTab(tab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppTab>(activeTabProvider, (_, tab) {
      final idx = _allTabs.indexOf(tab);
      if (idx >= 0 && _tabController.index != idx) {
        _tabController.animateTo(idx);
      }
    });
    final selectedTab = ref.watch(activeTabProvider);
    final screenSize = ResponsiveLayout.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ephemeris Dashboard'),
        actions: [
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom out (Ctrl+-)',
            onPressed: () => zoomOut(ref),
          ),
          Builder(
            builder: (context) {
              final scale = ref.watch(scaleFactorProvider);
              return InkWell(
                onTap: () => zoomReset(ref),
                child: Tooltip(
                  message: 'Reset zoom (Ctrl+0)',
                  child: Text(
                    '${(scale * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom in (Ctrl+=)',
            onPressed: () => zoomIn(ref),
          ),
          const SizedBox(width: 4),
          // Theme toggle
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              final current = ref.read(themeProvider);
              final next = switch (current) {
                ThemeMode.dark => ThemeMode.light,
                ThemeMode.light => ThemeMode.system,
                _ => ThemeMode.dark,
              };
              ref.read(themeProvider.notifier).state = next;
              ref.read(persistenceProvider).saveTheme(next);
            },
          ),
        ],
        bottom: screenSize == ScreenSize.mobile
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(
                  46.0 * MediaQuery.textScalerOf(context).scale(1.0),
                ),
                child: _AllTabsBar(controller: _tabController),
              ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ContextBar(),
            if (selectedTab.hasFlags)
              FlagBar(trailing: _buildFlagBarTrailing(selectedTab)),
            _TabContent(tab: selectedTab),
          ],
        ),
      ),
      // Mobile bottom navigation
      bottomNavigationBar: screenSize == ScreenSize.mobile
          ? _MobileTabBar(
              selectedTab: selectedTab,
              onSelected: (tab) {
                ref.read(activeTabProvider.notifier).state = tab;
                final idx = AppTab.values.indexOf(tab);
                if (idx >= 0) _tabController.index = idx;
              },
            )
          : null,
    );
  }

  Widget? _buildFlagBarTrailing(AppTab tab) =>
      tabDescriptorMap[tab]?.flagBarTrailing?.call();
}

class _AllTabsBar extends StatelessWidget implements PreferredSizeWidget {
  const _AllTabsBar({required this.controller});
  final TabController controller;

  static final _allTabs = AppTab.values.toList();
  static final _dividerIndex = AppTab.primaryTabs.length;
  static const _baseHeight = 46.0;

  @override
  Size get preferredSize => const Size.fromHeight(_baseHeight);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final barHeight = _baseHeight * scale;

    return SizedBox(
      height: barHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allTabs.length + 1, // +1 for divider
        itemBuilder: (context, i) {
          // Insert divider at the boundary
          if (i == _dividerIndex) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: barHeight * 0.2,
              ),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
            );
          }
          final tabIndex = i < _dividerIndex ? i : i - 1;
          final tab = _allTabs[tabIndex];
          return _TabButton(tab: tab, index: tabIndex, controller: controller);
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.index,
    required this.controller,
  });
  final AppTab tab;
  final int index;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.index == index;
        final color = selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
        return InkWell(
          onTap: () => controller.animateTo(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab.icon, size: 16, color: color),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab});
  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    return tabDescriptorMap[tab]!.content();
  }
}

class _MobileTabBar extends StatefulWidget {
  const _MobileTabBar({required this.selectedTab, required this.onSelected});
  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelected;

  @override
  State<_MobileTabBar> createState() => _MobileTabBarState();
}

class _MobileTabBarState extends State<_MobileTabBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(_MobileTabBar old) {
    super.didUpdateWidget(old);
    if (old.selectedTab != widget.selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    final idx = AppTab.values.indexOf(widget.selectedTab);
    if (idx < 0 || !_scrollController.hasClients) return;
    // Each item is ~72px wide; scale with zoom
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final itemWidth = 72.0 * scale;
    final viewWidth = _scrollController.position.viewportDimension;
    final target = (idx * itemWidth - viewWidth / 2 + itemWidth / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const allTabs = AppTab.values;
    final dividerIndex = AppTab.primaryTabs.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: allTabs.length + 1, // +1 for divider
            itemBuilder: (context, i) {
              if (i == dividerIndex) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 12,
                  ),
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: theme.dividerColor,
                  ),
                );
              }
              final tabIndex = i < dividerIndex ? i : i - 1;
              final tab = allTabs[tabIndex];
              final selected = tab == widget.selectedTab;
              final color = selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant;

              return InkWell(
                onTap: () => widget.onSelected(tab),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab.icon, size: 20, color: color),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
