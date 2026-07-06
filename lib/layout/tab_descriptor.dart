import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ephemeris/trace_model.dart';
import 'tab_definitions.dart';

class TabDescriptor {
  TabDescriptor({
    required this.tab,
    required this.content,
    this.traceProvider,
    this.flagBarTrailing,
  });

  final AppTab tab;
  final Widget Function() content;
  final Provider<CallTrace>? traceProvider;
  final Widget Function()? flagBarTrailing;

  String get id => tab.name;
  String get label => tab.label;
  IconData get icon => tab.icon;
  bool get hasFlags => tab.hasFlags;
  bool get isMore => tab.isMore;
}
