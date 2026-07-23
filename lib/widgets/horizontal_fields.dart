// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../core/calculation/horizontal_coords.dart';
import '../core/display_format.dart';
import 'result_card.dart';

/// The horizontal-frame fields for a single-Moment result card, empty when the
/// frame was not computed. Shared by the three body tabs (swe-dashboard/69) so
/// the card view and the export/series rows carry the same quantities.
List<ResultField> horizontalResultFields(
  HorizontalCoords h,
  DisplayFormat fmt,
) => [
  if (h.hasValue) ...[
    ResultField(
      label: 'Azimuth',
      value: formatAngle(h.azimuth, fmt),
      rawValue: h.azimuth,
    ),
    ResultField(
      label: 'True Alt',
      value: formatAngle(h.trueAltitude, fmt),
      rawValue: h.trueAltitude,
    ),
    ResultField(
      label: 'App. Alt',
      value: formatAngle(h.apparentAltitude, fmt),
      rawValue: h.apparentAltitude,
    ),
    ResultField(
      label: 'Zenith Dist',
      value: formatAngle(h.zenithDistance, fmt),
      rawValue: h.zenithDistance,
    ),
  ],
  if (!h.meridianDistance.isNaN)
    ResultField(
      label: 'Meridian Dist',
      value: formatAngle(h.meridianDistance, fmt),
      rawValue: h.meridianDistance,
    ),
];
