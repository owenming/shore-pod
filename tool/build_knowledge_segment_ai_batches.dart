import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final inputPath =
      _argValue(args, '--input') ??
      'build/knowledge_segment_candidates_preview.json';
  final outputPath =
      _argValue(args, '--output') ??
      'build/basic_knowledge_segment_ai_batches.jsonl';
  final batchSize = int.tryParse(_argValue(args, '--batch-size') ?? '') ?? 12;
  final limit = int.tryParse(_argValue(args, '--limit') ?? '');

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('找不到候选块文件：$inputPath');
    stderr.writeln(
      '请先运行：dart run tool/extract_knowledge_segment_candidates.dart',
    );
    exitCode = 1;
    return;
  }

  final data = jsonDecode(inputFile.readAsStringSync()) as Map<String, Object?>;
  final candidates = <Map<String, Object?>>[];
  for (final articleObject in data['articles'] as List<Object?>) {
    final article = articleObject as Map<String, Object?>;
    final articleCandidates = article['candidates'] as List<Object?>;
    for (final candidateObject in articleCandidates) {
      if (limit != null && candidates.length >= limit) {
        break;
      }
      final candidate = candidateObject as Map<String, Object?>;
      candidates.add({
        'source_candidate_id': candidate['id'],
        'basic_knowledge_id': candidate['basic_knowledge_id'],
        'knowledge_title': candidate['knowledge_title'],
        'paragraph_index': candidate['paragraph_index'],
        'topic': candidate['topic'],
        'keywords': candidate['keywords'],
        'raw_text': candidate['raw_text'],
      });
    }
    if (limit != null && candidates.length >= limit) {
      break;
    }
  }

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  final sink = outputFile.openWrite();
  var batchIndex = 0;
  for (var offset = 0; offset < candidates.length; offset += batchSize) {
    final batch = candidates
        .skip(offset)
        .take(batchSize)
        .toList(growable: false);
    final payload = {
      'custom_id':
          'basic-knowledge-segment-${batchIndex.toString().padLeft(4, '0')}',
      'ai_used': false,
      'instruction': _instruction,
      'input_candidates': batch,
      'expected_output_schema': {
        'source_candidate_id': 'string',
        'basic_knowledge_id': 'uuid string',
        'paragraph_index': 'integer',
        'content': '10-40 字精简提纲',
        'content_details': '80-300 字详细描述',
        'questions': [
          {
            'question_text': '单选题题干',
            'option_a': '选项 A',
            'option_b': '选项 B',
            'option_c': '选项 C',
            'option_d': '选项 D',
            'answer_key': 'A/B/C/D',
            'explanation': '答案解析',
          },
        ],
      },
    };
    sink.writeln(jsonEncode(payload));
    batchIndex++;
  }
  await sink.close();

  stdout.writeln('候选块: ${candidates.length}');
  stdout.writeln('批次数: $batchIndex');
  stdout.writeln('AI 批处理输入: ${outputFile.path}');
}

const _instruction = '''
你是专业的公基常识资料编辑和出题老师。你的任务不是机械切段，而是把原始资料整理成适合学习和检索的高质量知识片段，并为每个片段生成 1-3 道单选题。

要求：
1. 相同主题内容合并在同一个片段；
2. 每个片段必须语义完整、表述自然、可独立阅读；
3. content 是该片段的精简提纲，要求短、准、干练，建议 10-40 字；
4. content_details 是该片段的详细描述，要求完整、准确、通顺，建议 80-300 字；
5. questions 必须是数组，每个片段生成 1-3 道单选题；
6. 如果片段事实点、易混点、条件或例外较多，优先生成 2-3 道题；如果片段信息很少，只生成 1 道题；
7. 每道题必须围绕该片段核心事实生成，且只有一个正确答案；
8. 同一卡片内多道题应考查不同角度，避免只是改写同一道题；
9. 保留重要概念、定义、条件、结论、例外和关键事实；
10. 删除无意义的序号、题号、编码、乱码、页码、孤立数字、装饰符号和重复空话；
11. 如果数字是年份、比例、金额、年龄、期限、条款条件等关键信息，必须保留；
12. 不要输出标题层级、Markdown、解释说明；
13. 只返回 JSON 对象数组；
14. 每个输出对象必须保留 source_candidate_id、basic_knowledge_id、paragraph_index，方便回写数据库。
''';

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
