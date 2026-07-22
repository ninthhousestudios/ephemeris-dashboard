// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'tab_definitions.dart';

class TabDescriptor {
  TabDescriptor({
    required this.tab,
    required this.content,
    this.flagBarTrailing,
  });

  final AppTab tab;
  final Widget Function() content;
  final Widget Function()? flagBarTrailing;

  String get id => tab.name;
  String get label => tab.label;
  IconData get icon => tab.icon;
  bool get hasFlags => tab.hasFlags;
  bool get isMore => tab.isMore;
}
