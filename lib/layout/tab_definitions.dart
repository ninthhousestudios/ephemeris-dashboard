import 'package:flutter/material.dart';

enum AppTab {
  planets('Planets', Icons.public, hasFlags: true),
  houses('Houses', Icons.grid_view, hasFlags: true),
  ayanamsa('Ayanamsa', Icons.rotate_right, hasFlags: false),
  riseSet('Rise/Set', Icons.wb_twilight, hasFlags: false),
  eclipses('Eclipses', Icons.brightness_2, hasFlags: false),
  stars('Stars', Icons.star, hasFlags: true),
  crossings('Crossings', Icons.compare_arrows, hasFlags: true),
  tableView('Table', Icons.table_chart, hasFlags: true),
  // "More" group
  dates('Dates', Icons.calendar_today, hasFlags: false, isMore: true),
  coordinates('Coordinates', Icons.explore, hasFlags: true, isMore: true),
  nodesApsides('Nodes/Apsides', Icons.swap_vert, hasFlags: true, isMore: true),
  heliacal('Heliacal', Icons.visibility, hasFlags: false, isMore: true),
  phenomena('Phenomena', Icons.lens_blur, hasFlags: true, isMore: true),
  differential('Differential', Icons.difference, hasFlags: true, isMore: true),
  planetocentric('Planetocentric', Icons.language, hasFlags: true, isMore: true),
  math('Math', Icons.functions, hasFlags: false, isMore: true),
  config('About', Icons.info_outline, hasFlags: false, isMore: true),
  ephemerisManager('Ephemeris Manager', Icons.folder_special, hasFlags: false, isMore: true);

  const AppTab(this.label, this.icon, {required this.hasFlags, this.isMore = false});

  final String label;
  final IconData icon;
  final bool hasFlags;
  final bool isMore;

  static List<AppTab> get primaryTabs =>
      values.where((t) => !t.isMore).toList();

}
