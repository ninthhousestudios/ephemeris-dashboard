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
          timeZoneId: hit.tz,
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
        return _LocationOptions(
          hits: options.toList(growable: false),
          onSelected: onSelected,
        );
      },
    );
  }
}

/// The floating suggestion list. Split out so it can track the option the
/// RawAutocomplete keyboard shortcuts highlight (`AutocompleteHighlightedOption`)
/// — a custom optionsViewBuilder must reflect it or arrow-key navigation shows
/// nothing and never scrolls.
class _LocationOptions extends StatefulWidget {
  const _LocationOptions({required this.hits, required this.onSelected});

  final List<LocationHit> hits;
  final AutocompleteOnSelected<LocationHit> onSelected;

  @override
  State<_LocationOptions> createState() => _LocationOptionsState();
}

class _LocationOptionsState extends State<_LocationOptions> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = AutocompleteHighlightedOption.of(context);
    // Row height scales with the text scaler so the two text lines never clip
    // at high zoom; the scroll math below uses the same value.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowHeight = (52.0 * scale).floorToDouble();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollTo(highlighted, rowHeight),
    );

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemExtent: rowHeight,
            itemCount: widget.hits.length,
            itemBuilder: (context, index) {
              final hit = widget.hits[index];
              final region = hit.admin1.isEmpty
                  ? hit.country
                  : '${hit.admin1}, ${hit.country}';
              final isHighlighted = index == highlighted;
              return InkWell(
                onTap: () => widget.onSelected(hit),
                child: Container(
                  color: isHighlighted
                      ? theme.colorScheme.primary.withAlpha(30)
                      : null,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

  void _scrollTo(int index, double rowHeight) {
    if (!_scroll.hasClients) return;
    final target = index * rowHeight;
    final offset = _scroll.offset;
    final viewport = _scroll.position.viewportDimension;
    if (target < offset) {
      _scroll.jumpTo(target);
    } else if (target + rowHeight > offset + viewport) {
      _scroll.jumpTo(
        (target + rowHeight - viewport).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    }
  }
}
