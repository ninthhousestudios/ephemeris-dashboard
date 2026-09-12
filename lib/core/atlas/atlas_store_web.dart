// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Web has no managed filesystem, so downloaded atlas tiers don't exist there
/// — the web build always falls back to the bundled cities5000. See
/// `atlas_store_io.dart` for the native half of this seam.
Future<String?> loadInstalledAtlasTsv(String epheDir) async => null;
