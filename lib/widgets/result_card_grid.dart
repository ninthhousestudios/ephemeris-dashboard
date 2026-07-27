// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

import '../core/calculation/calc_outcome.dart';

/// Horizontal padding the grid puts around the cards.
const double _gridPadding = 8;

/// Gap between cards, both axes.
const double _gridSpacing = 4;

/// Number of columns the standard card grid uses at [maxWidth].
///
/// Capped at [maxColumns] so a tab whose cards are wide (Dates) can ask for a
/// two-column grid without inventing its own breakpoints.
int resultGridColumns(double maxWidth, {int maxColumns = 3}) {
  final cols = maxWidth > 1200
      ? 3
      : maxWidth > 600
      ? 2
      : 1;
  return cols > maxColumns ? maxColumns : cols;
}

/// Width of one card in a [cols]-column grid inside [maxWidth].
///
/// Exposed for the grouped-card tabs (Heliacal, Rise/Set), which lay their
/// cards out in per-target Wraps with their own breakpoints but size the cards
/// the same way.
double resultCardWidth(double maxWidth, int cols) =>
    (maxWidth - 2 * _gridPadding - (cols - 1) * _gridSpacing) / cols;

/// The responsive card grid every result tab renders into.
///
/// Owns the outcome switch (error text, empty message), the responsive column
/// arithmetic, and the scroll/wrap chrome — so the zoom rules in CLAUDE.md
/// (Wrap + SingleChildScrollView, no fixed aspect ratios, intrinsic card
/// heights) are honoured in one place rather than in every tab.
///
/// Three ways in:
/// - [ResultCardGrid.outcome] — a `CalcOutcome<List<T>>` straight from a
///   results provider; the grid renders the error or the empty message itself.
/// - [ResultCardGrid.items] — an already-resolved list of items.
/// - [ResultCardGrid.cards] — an already-built list of card widgets.
class ResultCardGrid<T> extends StatelessWidget {
  /// Grid over a calculation outcome.
  ///
  /// A failure renders as the error text, an empty list as [emptyMessage]
  /// (which is per-tab: "No bodies selected" is not universal).
  const ResultCardGrid.outcome({
    super.key,
    required CalcOutcome<List<T>> outcome,
    required this.cardBuilder,
    required String emptyMessage,
    this.cardOverlay,
    this.maxColumns = 3,
    this.footer,
  }) : _outcome = outcome,
       _items = null,
       _emptyMessage = emptyMessage;

  /// Grid over an already-resolved list of items.
  const ResultCardGrid.items({
    super.key,
    required List<T> items,
    required this.cardBuilder,
    String emptyMessage = 'No results',
    this.cardOverlay,
    this.maxColumns = 3,
    this.footer,
  }) : _items = items,
       _outcome = null,
       _emptyMessage = emptyMessage;

  /// Grid over an already-built list of card widgets.
  ///
  /// For tabs whose cards are a fixed roster rather than a projection of a
  /// result list (Coordinates, Nodes & Apsides).
  static Widget cards(
    List<Widget> cards, {
    Key? key,
    Widget Function(int index)? cardOverlay,
    int maxColumns = 3,
    Widget? footer,
  }) => ResultCardGrid<Widget>.items(
    key: key,
    items: cards,
    cardBuilder: _identity,
    cardOverlay: cardOverlay,
    maxColumns: maxColumns,
    footer: footer,
  );

  static Widget _identity(Widget card) => card;

  final CalcOutcome<List<T>>? _outcome;
  final List<T>? _items;
  final String _emptyMessage;

  /// Builds one card. The grid supplies the width, so the card must not.
  final Widget Function(T item) cardBuilder;

  /// Optional per-card overlay, pinned to the card's top-right corner — the
  /// remove (✕) button most selectable-body tabs carry. Keyed by row index,
  /// which is the card's identity as far as the grid is concerned.
  final Widget Function(int index)? cardOverlay;

  /// Upper bound on columns. The breakpoints themselves are not per-tab.
  final int maxColumns;

  /// Full-width content rendered below the grid, inside the same scroll view.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final List<T> items;
    switch (_outcome) {
      case CalcError(:final message):
        return Center(child: Text('Calculation error: $message'));
      case CalcOk(value: final value):
        items = value;
      case null:
        items = _items!;
    }
    if (items.isEmpty && footer == null) {
      return Center(child: Text(_emptyMessage));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = resultGridColumns(
          constraints.maxWidth,
          maxColumns: maxColumns,
        );
        final cardWidth = resultCardWidth(constraints.maxWidth, cols);
        final overlay = cardOverlay;

        final grid = Wrap(
          spacing: _gridSpacing,
          runSpacing: _gridSpacing,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: cardWidth,
                child: overlay == null
                    ? cardBuilder(items[i])
                    : Stack(
                        children: [
                          cardBuilder(items[i]),
                          Positioned(top: 4, right: 4, child: overlay(i)),
                        ],
                      ),
              ),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(_gridPadding),
          child: footer == null
              ? grid
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    grid,
                    const SizedBox(height: _gridSpacing),
                    footer!,
                  ],
                ),
        );
      },
    );
  }
}
