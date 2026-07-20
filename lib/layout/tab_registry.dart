// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'tab_definitions.dart';
import 'tab_descriptor.dart';
import '../tabs/ayanamsa/ayanamsa_provider.dart';
import '../tabs/ayanamsa/ayanamsa_tab.dart';
import '../tabs/config/config_tab.dart';
import '../tabs/coordinates/coordinates_tab.dart';
import '../tabs/crossings/crossings_provider.dart';
import '../tabs/crossings/crossings_tab.dart';
import '../tabs/dates/dates_provider.dart';
import '../tabs/dates/dates_tab.dart';
import '../tabs/differential/differential_provider.dart';
import '../tabs/differential/differential_tab.dart';
import '../tabs/eclipses/eclipses_provider.dart';
import '../tabs/eclipses/eclipses_tab.dart';
import '../tabs/heliacal/heliacal_provider.dart';
import '../tabs/heliacal/heliacal_tab.dart';
import '../tabs/houses/houses_provider.dart';
import '../tabs/houses/houses_tab.dart';
import '../tabs/math/math_tab.dart';
import '../tabs/other_bodies/other_bodies_provider.dart';
import '../tabs/other_bodies/other_bodies_tab.dart';
import '../tabs/nodes_apsides/nodes_apsides_provider.dart';
import '../tabs/nodes_apsides/nodes_apsides_tab.dart';
import '../tabs/phenomena/phenomena_provider.dart';
import '../tabs/phenomena/phenomena_tab.dart';
import '../tabs/planetocentric/planetocentric_provider.dart';
import '../tabs/planetocentric/planetocentric_tab.dart';
import '../tabs/planets/planets_provider.dart';
import '../tabs/planets/planets_tab.dart';
import '../tabs/rise_set/rise_set_provider.dart';
import '../tabs/rise_set/rise_set_tab.dart';
import '../tabs/stars/stars_provider.dart';
import '../tabs/stars/stars_tab.dart';
import '../tabs/table_view/table_view_tab.dart';
import '../widgets/ephe_manager/ephe_manager_screen.dart';

final List<TabDescriptor> tabRegistry = [
  TabDescriptor(
    tab: AppTab.planets,
    content: () => const PlanetsTab(),
    traceProvider: planetsTraceProvider,
    flagBarTrailing: () => const PlanetsFormatTrailing(),
  ),
  TabDescriptor(
    tab: AppTab.houses,
    content: () => const HousesTab(),
    traceProvider: housesTraceProvider,
    flagBarTrailing: () => const HousesFormatTrailing(),
  ),
  TabDescriptor(
    tab: AppTab.ayanamsa,
    content: () => const AyanamsaTab(),
    traceProvider: ayanamsaTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.riseSet,
    content: () => const RiseSetTab(),
    traceProvider: riseSetTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.eclipses,
    content: () => const EclipsesTab(),
    traceProvider: eclipsesTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.otherBodies,
    content: () => const OtherBodiesTab(),
    traceProvider: otherBodiesTraceProvider,
    flagBarTrailing: () => const OtherBodiesFormatTrailing(),
  ),
  TabDescriptor(
    tab: AppTab.stars,
    content: () => const StarsTab(),
    traceProvider: starTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.crossings,
    content: () => const CrossingsTab(),
    traceProvider: crossingTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.tableView,
    content: () => const TableViewTab(),
    flagBarTrailing: () => const TableViewFormatTrailing(),
  ),
  TabDescriptor(
    tab: AppTab.dates,
    content: () => const DatesTab(),
    traceProvider: datesTraceProvider,
  ),
  TabDescriptor(tab: AppTab.coordinates, content: () => const CoordinatesTab()),
  TabDescriptor(
    tab: AppTab.nodesApsides,
    content: () => const NodesApsidesTab(),
    traceProvider: nodesApsTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.heliacal,
    content: () => const HeliacalTab(),
    traceProvider: heliacalTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.phenomena,
    content: () => const PhenomenaTab(),
    traceProvider: phenomenaTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.differential,
    content: () => const DifferentialTab(),
    traceProvider: diffTraceProvider,
  ),
  TabDescriptor(
    tab: AppTab.planetocentric,
    content: () => const PlanetoCentricTab(),
    traceProvider: planetocentricTraceProvider,
    flagBarTrailing: () => const PlanetoCentricFormatTrailing(),
  ),
  TabDescriptor(tab: AppTab.math, content: () => const MathTab()),
  TabDescriptor(tab: AppTab.config, content: () => const ConfigTab()),
  TabDescriptor(
    tab: AppTab.ephemerisManager,
    content: () => const EphemerisManagerScreen(),
  ),
];

final Map<AppTab, TabDescriptor> tabDescriptorMap = {
  for (final d in tabRegistry) d.tab: d,
};
