// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/atlas/atlas.dart';
import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';

/// City search over the bundled gazetteer. Replaces the free-text City box:
/// selecting a result writes lat/lon (and the city label) into the Context in
/// one atomic update; the coordinate fields stay hand-editable for override.
///
/// Uses [RawAutocomplete] rather than the inline dropdown of `StarSearchField`
/// so the options float in an overlay — the field keeps a single-line footprint
/// inside the context bar's IntrinsicHeight row.
class LocationSearchField extends ConsumerStatefulWidget {
  const LocationSearchField({super.key});

  @override
  ConsumerState<LocationSearchField> createState() =>
      _LocationSearchFieldState();
}

class _LocationSearchFieldState extends ConsumerState<LocationSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _selfUpdate = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sync() {
    if (_focusNode.hasFocus) return;
    _controller.text = ref.read(contextBarProvider).cityLabel;
  }

  void _select(LocationHit hit) {
    _selfUpdate = true;
    ref
        .read(contextBarProvider.notifier)
        .setLocation(
          latitude: hit.lat,
          longitude: hit.lon,
          cityLabel: hit.label,
        );
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contextBarProvider, (_, _) {
      if (_selfUpdate) {
        _selfUpdate = false;
        return;
      }
      _sync();
    });
    if (_controller.text.isEmpty) _sync();

    final atlas = ref.watch(atlasProvider).valueOrNull;

    return RawAutocomplete<LocationHit>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (hit) => hit.label,
      optionsBuilder: (value) {
        final q = value.text.trim();
        if (q.isEmpty || atlas == null) {
          return const Iterable<LocationHit>.empty();
        }
        return atlas.search(q);
      },
      onSelected: _select,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return labeledField(
          context: context,
          label: 'City',
          controller: controller,
          focusNode: focusNode,
          hint: 'City',
          onCommit: onFieldSubmitted,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        final hits = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  final region = hit.admin1.isEmpty
                      ? hit.country
                      : '${hit.admin1}, ${hit.country}';
                  return ListTile(
                    dense: true,
                    title: Text(hit.name),
                    subtitle: Text(
                      region,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => onSelected(hit),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
