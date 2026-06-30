import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.trim().isEmpty) {
    stderr.writeln('缺少 OPENAI_API_KEY 环境变量');
    exitCode = 1;
    return;
  }

  final inputPath =
      _argValue(args, '--input') ??
      'build/basic_knowledge_segment_ai_batches.jsonl';
  final outputPath =
      _argValue(args, '--output') ??
      'build/basic_knowledge_segment_ai_sample_result.json';
  final model = _argValue(args, '--model') ??
      Platform.environment['OPENAI_MODEL'] ??
      'gpt-5-mini';
  final batchCount = int.tryParse(_argValue(args, '--batches') ?? '') ?? 1;
  final dryRun = args.contains('--dry-run');

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('找不到 AI 批处理输入：$inputPath');
    stderr.writeln(
      '请先运行：dart run tool/build_knowledge_segment_ai_batches.dart',
    );
    exitCode = 1;
    return;
  }

  final payloads = inputFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .take(batchCount)
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .toList(growable: false);

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);

  if (dryRun) {
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'dry_run': true,
        'model': model,
        'request_count': payloads.length,
        'requests': [
          for (final payload in payloads) _requestBody(model, payload),
        ],
      }),
    );
    stdout.writeln('Dry run 已写入：${outputFile.path}');
    return;
  }

  final results = <Map<String, Object?>>[];
  for (final payload in payloads) {
    final customId = '${payload['custom_id']}';
    stdout.writeln('请求 $customId ...');
    final response = await _callOpenAI(
      apiKey: apiKey,
      body: _requestBody(model, payload),
    );
    final text = _extractOutputText(response);
    final parsed = _parseItems(text);
    results.add({
      'custom_id': customId,
      'model': response['model'] ?? model,
      'raw_response_id': response['id'],
      'items': parsed,
    });
  }

  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generated_by': 'tool/run_knowledge_segment_ai_sample.dart',
      'model': model,
      'result_count': results.length,
      'results': results,
    }),
  );
  stdout.writeln('AI 样例结果：${outputFile.path}');
}

Map<String, Object?> _requestBody(String model, Map<String, Object?> payload) {
  return {
    'model': model,
    'input': [
      {
        'role': 'system',
        'content':
            '你只输出严格 JSON。不要输出 Markdown、解释、代码块或额外文字。',
      },
      {
        'role': 'user',
        'content': '''
${payload['instruction']}

请把下面 input_candidates 整理成 JSON 对象，格式必须是：
{"items":[{...},{...}]}

input_candidates:
${const JsonEncoder.withIndent('  ').convert(payload['input_candidates'])}
''',
      },
    ],
    'text': {
      'format': {'type': 'json_object'},
    },
    'max_output_tokens': 12000,
  };
}

Future<Map<String, Object?>> _callOpenAI({
  required String apiKey,
  required Map<String, Object?> body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://api.openai.com/v1/responses'),
    );
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
      ..set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OpenAI API ${response.statusCode}: ${_safeErrorMessage(text)}',
      );
    }
    return jsonDecode(text) as Map<String, Object?>;
  } finally {
    client.close(force: true);
  }
}

String _extractOutputText(Map<String, Object?> response) {
  final outputText = response['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText;
  }

  final buffer = StringBuffer();
  final output = response['output'];
  if (output is List) {
    for (final item in output.whereType<Map>()) {
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content.whereType<Map>()) {
        final text = part['text'];
        if (text is String) {
          buffer.write(text);
        }
      }
    }
  }
  final text = buffer.toString().trim();
  if (text.isEmpty) {
    throw const FormatException('响应中没有可解析的文本输出');
  }
  return text;
}

List<Object?> _parseItems(String text) {
  final decoded = jsonDecode(text);
  if (decoded is Map && decoded['items'] is List) {
    return decoded['items'] as List<Object?>;
  }
  if (decoded is List) {
    return decoded;
  }
  throw const FormatException('AI 输出必须是 {"items":[...]} 或数组');
}

String _safeErrorMessage(String text) {
  try {
    final decoded = jsonDecode(text);
    final error = decoded is Map ? decoded['error'] : null;
    if (error is Map && error['message'] != null) {
      return '${error['message']}';
    }
  } catch (_) {
    // Fall through to truncating raw text.
  }
  return text.length <= 500 ? text : text.substring(0, 500);
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
