import 'dart:convert';
import 'dart:io';

import 'package:shore_pod/data/agent_chinese_basic_seed.dart';

void main(List<String> args) {
  final outputPath =
      _argValue(args, '--output') ?? 'assets/data/shore_pod_seed.json';
  final now = DateTime.now().toUtc().toIso8601String();

  final seed = {
    'seed_version': 1,
    'generated_at': now,
    'tables': {
      'basic_knowledge_category': agentChineseBasicKnowledgeCategories,
      'basic_knowledge_info': agentChineseBasicKnowledgeInfos,
      'basic_knowledge_segment': const <Map<String, Object?>>[],
      'basic_knowledge_question': const <Map<String, Object?>>[],
      'basic_current_politics_info': const <Map<String, Object?>>[],
    },
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(seed),
  );

  stdout.writeln('Seed file: ${outputFile.path}');
  stdout.writeln(
    'basic_knowledge_category: ${agentChineseBasicKnowledgeCategories.length}',
  );
  stdout.writeln(
    'basic_knowledge_info: ${agentChineseBasicKnowledgeInfos.length}',
  );
  stdout.writeln('basic_current_politics_info: 0');
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
