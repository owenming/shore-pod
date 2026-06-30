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
你是给公基常识 App 做正式题库的资料编辑和命题老师。目标是产出用户真的能刷、能背、能复盘的题，不是展示 AI 生成能力。所有内容都必须像人工整理的教辅题库，克制、准确、可用。

一、先整理知识卡片
1. 相同主题内容合并在同一个片段，不要机械按句切段；
2. content 是卡片标题，必须短、准、像知识点名称，建议 10-40 字；
3. content 不要出现“核心考点”“相关材料”“本段内容”等 AI 痕迹；
4. content_details 是可独立学习的知识卡片，建议 80-300 字；
5. content_details 只保留考试有用的信息：概念、定义、条件、时间、人物、地点、制度、影响、例外、易混点；
6. 删除题号、页码、乱码、装饰符号、重复空话和“复习时重点把握……”这类套话；
7. 年份、比例、金额、年龄、期限、条款条件等关键数字必须保留，不能模糊改写。

二、题目必须像真题/教辅题
1. 每张卡生成 1-2 道单选题；信息很少只出 1 道，不要硬凑；
2. 题干必须考具体事实、定义、对应关系、易混点或例外；
3. 题干不要写“下列关于某某的说法正确的是”这种万能模板，除非这个知识点确实适合判断表述；
4. 优先使用这些题型：
   - “关于【概念/事件/制度】，下列表述正确的是：”
   - “【概念】主要是指：”
   - “【事件/制度】对应的时间/人物/地点/作用是：”
   - “下列哪一项属于/不属于【概念】的特征？”
   - “容易与【概念】混淆的是哪一项？”
5. 不要出离开材料无法判断的题，不要出需要联网核验的新近时政题；
6. 一道题只能有一个无争议正确答案。

三、选项必须可用
1. 四个选项必须同类型、同长度区间、同知识域，不能一个很长三个很短；
2. 干扰项要来自同章节相近概念、相邻朝代、相似制度、相似物理/化学/法律概念，或者对关键条件做小幅错误替换；
3. 干扰项要“像错题选项”，不能像废话；
4. 严禁使用这些 AI 风格选项：
   - “该说法与原始资料中的表述不符”
   - “该内容与本题无关”
   - “该考点主要属于……”
   - “不需要区分时间、人物、地点”
   - “只需记住名称”
   - “以上都不对/以上都正确”（除非原材料就是这种真题）
5. 严禁所有题答案都放 A；答案位置要自然分布在 A/B/C/D。

四、解析必须帮助用户复盘
1. explanation 不能只复制正确选项；
2. explanation 要说明正确项为什么对，必要时点出干扰项错在“时间、对象、条件、范围、因果、概念归属”中的哪一类；
3. 解析控制在 30-120 字，清楚、具体，不要空泛。

五、输出格式
1. 只返回 JSON，不要 Markdown、不要代码块、不要额外说明；
2. 顶层格式必须是 {"items":[...]}；
3. 每个 item 必须保留 source_candidate_id、basic_knowledge_id、paragraph_index；
4. questions 中每题必须包含 question_text、option_a、option_b、option_c、option_d、answer_key、explanation；
5. answer_key 只能是 A/B/C/D。
''';

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
