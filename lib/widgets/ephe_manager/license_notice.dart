import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLicenseSeenKey = 'ephe.licenseSeen';

/// Show the Swiss Ephemeris license notice exactly once, before the first
/// network download. Returns true if user accepted, false if cancelled.
Future<bool> maybeShowLicenseNotice(
  BuildContext context,
  SharedPreferences prefs,
) async {
  if (prefs.getBool(_kLicenseSeenKey) ?? false) return true;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Ephemeris file license'),
      content: const Text(
        'Swiss Ephemeris data files are distributed under the AGPL-3.0 '
        'license by Astrodienst AG. Downloading these files is only '
        'required if you need date ranges outside the bundle. See '
        'https://www.astro.com/swisseph for license terms.\n\n'
        'JPL ephemeris files are public-domain products of the Jet '
        'Propulsion Laboratory.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('I understand'),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await prefs.setBool(_kLicenseSeenKey, true);
    return true;
  }
  return false;
}
