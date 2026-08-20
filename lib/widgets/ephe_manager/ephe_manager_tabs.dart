// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

import 'add_star_screen.dart';
import 'ephe_manager_screen.dart';

/// The Ephemeris Manager tab's own subtab shell. Hosts the file manager and the
/// "Add Stars" catalogue tool (and, later, further tools) as subtabs.
///
/// The content is rendered conditionally by index rather than through a
/// `TabBarView`: this whole tab lives inside the app shell's vertical
/// `SingleChildScrollView`, so there is no bounded height for a `TabBarView` to
/// occupy. Each subtab lays out at its intrinsic height and the page scrolls.
class EphemerisManagerTabs extends StatefulWidget {
  const EphemerisManagerTabs({super.key});

  @override
  State<EphemerisManagerTabs> createState() => _EphemerisManagerTabsState();
}

class _EphemerisManagerTabsState extends State<EphemerisManagerTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Ephemeris Manager'),
              Tab(text: 'Add Stars'),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_tabs.index == 0)
          const EphemerisManagerScreen()
        else
          const AddStarScreen(),
      ],
    );
  }
}
