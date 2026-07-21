// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tabs/stars/stars_provider.dart';

class StarSearchField extends ConsumerStatefulWidget {
  const StarSearchField({
    super.key,
    required this.onSelect,
    this.hintText = 'Star name or Bayer designation (e.g. Spica, alVir)',
    this.dense = false,
  });

  final void Function(String starName) onSelect;
  final String hintText;
  final bool dense;

  @override
  ConsumerState<StarSearchField> createState() => _StarSearchFieldState();
}

class _StarSearchFieldState extends ConsumerState<StarSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<StarCatalogEntry> _suggestions = [];
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _suggestions = [];
              _selectedIndex = -1;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _selectedIndex = -1;
      });
      return;
    }
    final lower = q.toLowerCase();
    final bayerQ = lower.startsWith(',') ? lower.substring(1) : lower;
    final catalog = ref.read(starCatalogProvider);
    setState(() {
      _suggestions = catalog.where((e) {
        return e.commonName.toLowerCase().contains(lower) ||
            e.bayerDesig.toLowerCase().contains(bayerQ);
      }).toList();
      _selectedIndex = -1;
    });
  }

  void _select(String name) {
    widget.onSelect(name);
    _controller.clear();
    setState(() {
      _suggestions = [];
      _selectedIndex = -1;
    });
  }

  void _submit() {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      _select(_suggestions[_selectedIndex].commonName);
    } else {
      final term = _controller.text.trim();
      if (term.isNotEmpty) _select(term);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_suggestions.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _suggestions.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(
          -1,
          _suggestions.length - 1,
        );
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _suggestions = [];
        _selectedIndex = -1;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.dense
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyLarge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onKeyEvent: _onKeyEvent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: textStyle,
            decoration: InputDecoration(
              hintText: widget.hintText,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: widget.dense ? 8 : 10,
              ),
              border: const OutlineInputBorder(),
              isDense: widget.dense,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _suggestions = [];
                          _selectedIndex = -1;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final entry = _suggestions[index];
                  return ListTile(
                    dense: true,
                    selected: index == _selectedIndex,
                    title: Text(entry.commonName),
                    trailing: Text(
                      entry.bayerDesig,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _select(entry.commonName),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
