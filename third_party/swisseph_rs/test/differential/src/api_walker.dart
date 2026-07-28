// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';

const _dartStandardMethods = {
  'toString', 'hashCode', 'noSuchMethod',
  // Systematic divergence: bitflags → extension-type flag sets with contains().
  'contains',
};

enum SymbolKind {
  topLevelGetter,
  topLevelFunction,
  classDecl,
  enumDecl,
  extensionTypeDecl,
  sealedClassDecl,
  constructor,
  method,
  getter,
  operator,
  enumValue,
  field,
}

class PublicSymbol {
  final String qualifiedName;
  final SymbolKind kind;
  final String? docComment;

  const PublicSymbol(this.qualifiedName, this.kind, this.docComment);

  static final _counterpartPattern = RegExp(
    r'Counterpart:\s+(swisseph::|swisseph_ffi::|\(systematic divergence:)',
  );

  bool get hasCounterpart =>
      docComment != null && _counterpartPattern.hasMatch(docComment!);

  /// Whether this symbol kind requires its own Counterpart declaration.
  ///
  /// Constructors, fields, operators, and getters are structurally covered
  /// by their enclosing type's Counterpart (systematic divergences are
  /// documented once in CONTEXT.md, not per-operator).
  bool get requiresCounterpart => switch (kind) {
    SymbolKind.classDecl ||
    SymbolKind.enumDecl ||
    SymbolKind.extensionTypeDecl ||
    SymbolKind.sealedClassDecl ||
    SymbolKind.enumValue ||
    SymbolKind.topLevelFunction ||
    SymbolKind.topLevelGetter => true,
    SymbolKind.method => !_dartStandardMethods.contains(
      qualifiedName.split('.').last,
    ),
    _ => false,
  };

  bool get isOracleMapTarget =>
      kind == SymbolKind.constructor ||
      kind == SymbolKind.method ||
      kind == SymbolKind.topLevelFunction ||
      kind == SymbolKind.topLevelGetter;
}

Future<List<PublicSymbol>> walkPublicApi() async {
  final projectRoot = _findProjectRoot();
  final libPath = '$projectRoot/lib';
  final entryPoint = '$libPath/swisseph_rs.dart';

  if (!File(entryPoint).existsSync()) {
    throw StateError('Library entry point not found: $entryPoint');
  }

  final collection = AnalysisContextCollection(includedPaths: [libPath]);
  final context = collection.contextFor(entryPoint);
  final result = await context.currentSession.getResolvedLibrary(entryPoint);

  if (result is! ResolvedLibraryResult) {
    throw StateError('Failed to resolve library: $result');
  }

  final library = result.element;
  final symbols = <PublicSymbol>[];

  for (final entry in library.exportNamespace.definedNames2.entries) {
    final name = entry.key;
    final element = entry.value;

    if (name.startsWith('_')) continue;

    switch (element) {
      case InterfaceElement():
        _walkInterface(name, element, symbols);
      case TopLevelFunctionElement():
        symbols.add(
          PublicSymbol(
            name,
            SymbolKind.topLevelFunction,
            element.documentationComment,
          ),
        );
      case TopLevelVariableElement():
        symbols.add(
          PublicSymbol(
            name,
            SymbolKind.topLevelGetter,
            element.documentationComment,
          ),
        );
      case PropertyAccessorElement():
        // A top-level variable reaches the export namespace as its *synthetic*
        // getter, and a synthetic element carries no dartdoc — the comment is
        // attached to the variable. Reading the accessor alone reports every
        // documented public constant as undeclared.
        symbols.add(
          PublicSymbol(
            name,
            SymbolKind.topLevelGetter,
            element.documentationComment ??
                element.variable.documentationComment,
          ),
        );
    }
  }

  return symbols;
}

void _walkInterface(
  String typeName,
  InterfaceElement element,
  List<PublicSymbol> symbols,
) {
  final declKind = switch (element) {
    EnumElement() => SymbolKind.enumDecl,
    ExtensionTypeElement() => SymbolKind.extensionTypeDecl,
    ClassElement(isSealed: true) => SymbolKind.sealedClassDecl,
    _ => SymbolKind.classDecl,
  };

  symbols.add(PublicSymbol(typeName, declKind, element.documentationComment));

  for (final ctor in element.constructors) {
    final ctorName = ctor.name;
    if (ctorName != null && ctorName.startsWith('_')) continue;
    if (ctor.isOriginImplicitDefault) continue;
    final qualified = ctorName == null || ctorName == 'new'
        ? '$typeName.new'
        : '$typeName.$ctorName';
    symbols.add(
      PublicSymbol(
        qualified,
        SymbolKind.constructor,
        ctor.documentationComment,
      ),
    );
  }

  for (final method in element.methods) {
    final methodName = method.name;
    if (methodName == null || methodName.startsWith('_')) continue;
    final kind = method.isOperator ? SymbolKind.operator : SymbolKind.method;
    symbols.add(
      PublicSymbol('$typeName.$methodName', kind, method.documentationComment),
    );
  }

  for (final field in element.fields) {
    final fieldName = field.name;
    if (fieldName == null || fieldName.startsWith('_')) continue;
    if (field.isEnumConstant) {
      symbols.add(
        PublicSymbol(
          '$typeName.$fieldName',
          SymbolKind.enumValue,
          field.documentationComment,
        ),
      );
    } else if (field.isOriginDeclaration ||
        field.isOriginDeclaringFormalParameter) {
      symbols.add(
        PublicSymbol(
          '$typeName.$fieldName',
          SymbolKind.field,
          field.documentationComment,
        ),
      );
    }
  }
}

String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find project root (no pubspec.yaml)');
    }
    dir = parent;
  }
}
