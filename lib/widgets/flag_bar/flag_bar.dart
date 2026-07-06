import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/swe_constants.dart';

import '../../core/active_tab_trace.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../core/flag_definitions.dart';
import '../../core/flag_provider.dart';
import '../code_modal.dart';
import 'flag_group.dart';
import 'flag_toggle.dart';

/// The flag bar — coordinate group + composable toggles + hex display.
/// Shows auto-locked flags as informational chips.
class FlagBar extends ConsumerWidget {
  const FlagBar({super.key, this.trailing});

  /// Optional widget inserted between the hex display and Calculate button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagState = ref.watch(flagBarProvider);
    final notifier = ref.read(flagBarProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Coordinate group (mutually exclusive)
            FlagGroupWidget(
              group: coordGroup,
              selectedValue: flagState.coordValue,
              onSelected: notifier.setCoordGroup,
            ),
            const SizedBox(width: 12),
            // Vertical divider
            SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
            const SizedBox(width: 12),
            // Composable toggles
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...flagToggles.map(
                  (def) => FlagToggle(
                    def: def,
                    active: flagState.toggles.contains(def.value),
                    onToggle: () => notifier.toggleFlag(def.value),
                  ),
                ),
                // Show locked flags as disabled informational chips
                if (flagState.lockedFlags != 0)
                  ..._lockedChips(context, flagState.lockedFlags),
              ],
            ),
            const SizedBox(width: 12),
            // Hex display + Calculate button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                flagState.hexDisplay,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.code, size: 18),
              tooltip: 'View tab code',
              visualDensity: VisualDensity.compact,
              onPressed: ref.watch(activeTabTraceProvider) == null
                  ? null
                  : () {
                      final trace = ref.read(activeTabTraceProvider);
                      if (trace == null || trace.entries.isEmpty) return;
                      final emitter = ref.read(selectedEmitterProvider);
                      final code = emitter.emitProgram(trace.entries);
                      showCodeModal(
                        context,
                        code: code,
                        languageLabel: emitter.displayName,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lockedChips(BuildContext context, int lockedFlags) {
    final chips = <Widget>[];
    for (final entry in _lockedFlagLabels.entries) {
      if (lockedFlags & entry.key != 0) {
        chips.add(
          Tooltip(
            message: 'Auto-set by context bar',
            child: InputChip(
              label: Text(entry.value),
              isEnabled: false,
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                Icons.lock,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
    }
    return chips;
  }
}

/// Labels for auto-locked flags (only shown when active).
const _lockedFlagLabels = {
  seFlgSidereal: 'Sidereal',
  seFlgTopoCtr: 'Topocentric',
  seFlgHelCtr: 'Heliocentric',
  seFlgBaryCtr: 'Barycentric',
};
