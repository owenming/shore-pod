import 'dart:convert';

import 'package:flutter/services.dart';

const bundledSeedAsset = 'assets/data/shore_pod_seed.json';

const bundledSeedTableNames = <String>[
  'basic_knowledge_category',
  'basic_knowledge_info',
  'basic_knowledge_segment',
  'basic_knowledge_question',
  'basic_current_politics_info',
  'aptitude_category',
  'aptitude_subcategory',
  'aptitude_question',
];

Future<Map<String, List<Map<String, Object?>>>> loadBundledSeedTables({
  Iterable<String>? tableNames,
}) async {
  final raw = await rootBundle.loadString(bundledSeedAsset);
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final tables = decoded['tables'] as Map<String, Object?>;
  final names = tableNames ?? bundledSeedTableNames;
  final result = <String, List<Map<String, Object?>>>{};

  for (final name in names) {
    result[name] = await _loadBundledSeedTable(tables[name]);
  }
  return result;
}

Future<List<Map<String, Object?>>> _loadBundledSeedTable(Object? table) async {
  if (table is String) {
    final raw = await rootBundle.loadString(table);
    return _tableRows(jsonDecode(raw));
  }
  return _tableRows(table);
}

List<Map<String, Object?>> _tableRows(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map((row) => Map<String, Object?>.from(row))
      .toList(growable: false);
}
