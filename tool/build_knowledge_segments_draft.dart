import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath =
      _argValue(args, '--input') ??
      'build/knowledge_segment_candidates_preview.json';
  final outputPath =
      _argValue(args, '--output') ??
      'build/basic_knowledge_segments_draft.json';
  final markdownPath =
      _argValue(args, '--markdown') ??
      'build/basic_knowledge_segments_draft.md';
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
  final articles = data['articles'] as List<Object?>;
  final rows = <Map<String, Object?>>[];
  final articleStats = <Map<String, Object?>>[];

  for (final articleObject in articles) {
    final article = articleObject as Map<String, Object?>;
    final title = '${article['knowledge_title']}';
    final candidates =
        (article['candidates'] ?? article['preview_candidates'])
            as List<Object?>;
    var paragraphIndex = 0;
    var validCount = 0;
    var warningCount = 0;

    for (final candidateObject in candidates) {
      if (limit != null && rows.length >= limit) {
        break;
      }
      final candidate = candidateObject as Map<String, Object?>;
      final draft = _buildDraft(candidate, paragraphIndex);
      rows.add(draft);
      paragraphIndex++;

      final issues = draft['issues'] as List<Object?>;
      if (issues.isEmpty) {
        validCount++;
      } else {
        warningCount++;
      }
    }

    articleStats.add({
      'knowledge_title': title,
      'draft_count': paragraphIndex,
      'valid_count': validCount,
      'warning_count': warningCount,
    });

    if (limit != null && rows.length >= limit) {
      break;
    }
  }

  final output = {
    'generated_by': 'tool/build_knowledge_segments_draft.dart',
    'ai_used': false,
    'source': inputPath,
    'row_count': rows.length,
    'article_stats': articleStats,
    'schema_target': 'public.basic_knowledge_segment',
    'fields': [
      'basic_knowledge_id',
      'paragraph_index',
      'content',
      'content_details',
    ],
    'rows': rows,
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  final markdownFile = File(markdownPath);
  markdownFile.parent.createSync(recursive: true);
  markdownFile.writeAsStringSync(_buildMarkdown(rows, articleStats));

  final issueCount = rows
      .where((row) => (row['issues'] as List<Object?>).isNotEmpty)
      .length;
  stdout.writeln('草稿卡片数: ${rows.length}');
  stdout.writeln('需复查: $issueCount');
  stdout.writeln('JSON 草稿: ${outputFile.path}');
  stdout.writeln('Markdown 草稿: ${markdownFile.path}');
}

Map<String, Object?> _buildDraft(
  Map<String, Object?> candidate,
  int paragraphIndex,
) {
  final basicKnowledgeId = '${candidate['basic_knowledge_id']}';
  final knowledgeTitle = '${candidate['knowledge_title']}';
  final topic = _cleanText('${candidate['topic']}');
  final rawText = _cleanRawText('${candidate['raw_text']}');
  final keywords =
      ((candidate['keywords'] ?? const <Object?>[]) as List<Object?>)
          .map((keyword) => _cleanText('$keyword'))
          .where((keyword) => keyword.isNotEmpty)
          .toSet()
          .take(8)
          .toList(growable: false);

  final content = _buildContent(knowledgeTitle, topic, rawText, keywords);
  final contentDetails = _buildContentDetails(topic, rawText);
  final issues = _validateDraft(
    content: content,
    contentDetails: contentDetails,
    rawText: rawText,
  );

  return {
    'basic_knowledge_id': basicKnowledgeId,
    'knowledge_title': knowledgeTitle,
    'paragraph_index': paragraphIndex,
    'content': content,
    'content_details': contentDetails,
    'source_candidate_id': candidate['id'],
    'source_start_line': candidate['source_start_line'],
    'source_end_line': candidate['source_end_line'],
    'source_keywords': keywords,
    'issues': issues,
  };
}

String _buildContent(
  String knowledgeTitle,
  String topic,
  String rawText,
  List<String> keywords,
) {
  final normalizedTopic = _cleanText(topic);
  if (_visibleLength(normalizedTopic) >= 10 &&
      _visibleLength(normalizedTopic) <= 40) {
    return normalizedTopic;
  }

  final suffix = _contentSuffix(knowledgeTitle, rawText, keywords);
  final combined = suffix.isEmpty ? normalizedTopic : '$normalizedTopic$suffix';
  if (_visibleLength(combined) <= 40) {
    return combined;
  }
  return _truncateByVisibleLength(combined, 40);
}

String _contentSuffix(
  String knowledgeTitle,
  String rawText,
  List<String> keywords,
) {
  if (RegExp(r'学派|思想|主张|仁政|无为|法家|儒家|道家|墨家|著作《').hasMatch(rawText)) {
    return '的思想主张';
  }
  if (knowledgeTitle.contains('文学') ||
      RegExp(r'诗|词|曲|小说|散文|戏剧|文学|作品|作者').hasMatch(rawText)) {
    return '的文学常识';
  }
  if (RegExp(r'条约|割|赔款|通商|领事裁判权|协定关税').hasMatch(rawText)) {
    return '的内容与影响';
  }
  if (RegExp(r'战争|战役|起义|会议|运动|成立|标志').hasMatch(rawText)) {
    return '的时间与意义';
  }
  if (RegExp(r'文化|遗址|距今|公元前|考古').hasMatch(rawText)) {
    return '的年代与特征';
  }
  if (RegExp(r'宪法|刑法|民法|行政|诉讼|许可|处罚|复议|赔偿').hasMatch(rawText)) {
    return '的规则要点';
  }
  if (RegExp(r'财政|货币|市场|需求|供给|价值|资本|收入').hasMatch(rawText)) {
    return '的经济考点';
  }
  if (RegExp(r'气压|沸点|电能|电磁|热效率|化学|细胞|基因|地貌|气候').hasMatch(rawText)) {
    return '的原理与应用';
  }
  if (keywords.length >= 2) {
    final keyword = keywords.firstWhere(
      (item) => item != keywords.first,
      orElse: () => '',
    );
    if (keyword.isNotEmpty && _visibleLength(keyword) <= 12) {
      return '与$keyword';
    }
  }
  return '的核心考点';
}

String _buildContentDetails(String topic, String rawText) {
  var details = rawText;
  details = details.replaceFirst(RegExp('^${RegExp.escape(topic)}[:：]?'), '');
  details = details.replaceFirst(RegExp(r'^[：:；;，,。\s]+'), '').trim();
  if (details.isEmpty) {
    details = rawText;
  }
  if (!details.startsWith(topic) && _visibleLength(topic) <= 18) {
    details = '$topic：$details';
  }
  details = _removeMarkdown(details);
  details = details.replaceAll(RegExp(r'\n{2,}'), '\n').trim();

  if (_visibleLength(details) > 300) {
    details = _truncateDetails(details, 300);
  }

  return details;
}

List<String> _validateDraft({
  required String content,
  required String contentDetails,
  required String rawText,
}) {
  final issues = <String>[];
  final contentLength = _visibleLength(content);
  final detailLength = _visibleLength(contentDetails);

  if (contentLength < 6) {
    issues.add('content 偏短');
  }
  if (contentLength > 40) {
    issues.add('content 超过 40 字');
  }
  if (detailLength < 60) {
    issues.add('content_details 偏短');
  }
  if (detailLength > 320) {
    issues.add('content_details 超过 320 字');
  }
  if (RegExp(r'[#*_`>|]').hasMatch(contentDetails)) {
    issues.add('content_details 含 Markdown 或装饰符');
  }
  if (RegExp(r'^[0-9一二三四五六七八九十、.．（）()：:\s]+$').hasMatch(content)) {
    issues.add('content 不是有效标题');
  }
  if (_looksLikeDanglingHeading(contentDetails)) {
    issues.add('content_details 疑似标题残留');
  }

  final keyNumbers = RegExp(
    r'(?:公元前\s*)?\d{2,4}\s*年|\d+\s*万年|\d+\s*%|\d+\s*元|\d+\s*个月',
  ).allMatches(rawText).map((match) => _cleanText(match.group(0)!));
  for (final number in keyNumbers.take(5)) {
    if (!contentDetails.contains(number)) {
      issues.add('可能丢失关键数字：$number');
      break;
    }
  }
  return issues;
}

String _cleanRawText(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[‌‍﻿]'), '')
      .split('\n')
      .map(_cleanText)
      .where((line) => line.isNotEmpty)
      .join('\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

String _cleanText(String text) {
  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\-*•·]+'), '')
      .replaceAll(RegExp(r'[：:；;，,。]+$'), '')
      .trim();
}

String _removeMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'^[#>*`\-]+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'[*_`]+'), '')
      .trim();
}

String _truncateDetails(String text, int maxLength) {
  if (_visibleLength(text) <= maxLength) {
    return text;
  }
  final truncated = _truncateByVisibleLength(text, maxLength);
  final lastPunctuation = truncated.lastIndexOf(RegExp(r'[。；;.!！?？]'));
  if (lastPunctuation >= 80) {
    return truncated.substring(0, lastPunctuation + 1);
  }
  return '$truncated...';
}

String _truncateByVisibleLength(String text, int maxLength) {
  final chars = text.runes.toList();
  if (chars.length <= maxLength) {
    return text;
  }
  return String.fromCharCodes(chars.take(maxLength));
}

int _visibleLength(String text) {
  return text.replaceAll(RegExp(r'\s+'), '').runes.length;
}

bool _looksLikeDanglingHeading(String text) {
  final lines = text.split('\n');
  if (lines.length <= 1) {
    return false;
  }
  final first = lines.first.trim();
  return first.length <= 8 && !first.contains('：') && !first.contains(':');
}

String _buildMarkdown(
  List<Map<String, Object?>> rows,
  List<Map<String, Object?>> articleStats,
) {
  final buffer = StringBuffer()
    ..writeln('# basic_knowledge_segment 草稿预览')
    ..writeln()
    ..writeln('> 未调用 AI，未写入数据库；这是基于候选块的可校验草稿。')
    ..writeln()
    ..writeln('## 汇总')
    ..writeln()
    ..writeln('- 草稿卡片：${rows.length}')
    ..writeln(
      '- 需复查：${rows.where((row) => (row['issues'] as List).isNotEmpty).length}',
    )
    ..writeln();

  for (final stat in articleStats.take(12)) {
    buffer.writeln(
      '- ${stat['knowledge_title']}：${stat['draft_count']} 条，'
      '需复查 ${stat['warning_count']} 条',
    );
  }

  buffer
    ..writeln()
    ..writeln('## 样例')
    ..writeln();

  String? currentTitle;
  var shownInArticle = 0;
  for (final row in rows) {
    final title = '${row['knowledge_title']}';
    if (title != currentTitle) {
      currentTitle = title;
      shownInArticle = 0;
      buffer
        ..writeln()
        ..writeln('### $title')
        ..writeln();
    }
    if (shownInArticle >= 5) {
      continue;
    }
    shownInArticle++;
    buffer
      ..writeln('- ${row['paragraph_index']}. ${row['content']}')
      ..writeln('  - details: ${row['content_details']}')
      ..writeln('  - issues: ${(row['issues'] as List<Object?>).join('、')}')
      ..writeln();
  }
  return buffer.toString();
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
