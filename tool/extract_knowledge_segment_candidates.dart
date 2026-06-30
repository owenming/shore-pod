import 'dart:convert';
import 'dart:io';

import 'package:shore_pod/data/agent_chinese_basic_seed.dart';

void main(List<String> args) {
  final outputPath =
      _argValue(args, '--output') ??
      'build/knowledge_segment_candidates_preview.json';
  final markdownPath =
      _argValue(args, '--markdown') ??
      'build/knowledge_segment_candidates_preview.md';
  final limitPerArticle =
      int.tryParse(_argValue(args, '--limit-per-article') ?? '') ?? 20;

  final articleResults = <Map<String, Object?>>[];
  var totalCandidateCount = 0;

  for (final info in agentChineseBasicKnowledgeInfos) {
    final id = '${info['id'] ?? ''}';
    final title = '${info['knowledge_title'] ?? '未命名专题'}';
    final content = '${info['knowledge_content'] ?? ''}';
    final candidates = _extractCandidates(
      basicKnowledgeId: id,
      knowledgeTitle: title,
      content: content,
    );

    totalCandidateCount += candidates.length;
    articleResults.add({
      'basic_knowledge_id': id,
      'knowledge_title': title,
      'candidate_count': candidates.length,
      'candidates': candidates
          .map((candidate) => candidate.toJson())
          .toList(growable: false),
      'preview_candidates': candidates
          .take(limitPerArticle)
          .map((candidate) => candidate.toJson())
          .toList(growable: false),
    });
  }

  final output = {
    'generated_by': 'tool/extract_knowledge_segment_candidates.dart',
    'ai_used': false,
    'article_count': agentChineseBasicKnowledgeInfos.length,
    'candidate_count': totalCandidateCount,
    'rules': [
      '按空行和标题层级先形成候选原文块',
      '冒号前短语优先作为 topic',
      '短标题行作为上下文，不直接生成卡片',
      '过滤孤立数字、残缺序号、泛词和装饰符',
      '提取年份、书名号、引号、制度/法律/条约/文化等高价值关键词',
      '只做候选预览，不写入 basic_knowledge_segment',
    ],
    'articles': articleResults,
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  final markdownFile = File(markdownPath);
  markdownFile.parent.createSync(recursive: true);
  markdownFile.writeAsStringSync(_buildMarkdown(articleResults));

  stdout.writeln('文章数: ${agentChineseBasicKnowledgeInfos.length}');
  stdout.writeln('候选块总数: $totalCandidateCount');
  stdout.writeln('JSON 预览: ${outputFile.path}');
  stdout.writeln('Markdown 预览: ${markdownFile.path}');
}

List<_CandidateBlock> _extractCandidates({
  required String basicKnowledgeId,
  required String knowledgeTitle,
  required String content,
}) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u200c', '')
      .replaceAll('\u200d', '')
      .replaceAll('\ufeff', '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  final result = <_CandidateBlock>[];
  final seen = <String>{};
  final buffer = <_LineRef>[];
  var context = knowledgeTitle;

  final lines = normalized.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = _cleanLine(lines[i]);
    if (line.isEmpty) {
      _flushBlock(
        result: result,
        seen: seen,
        basicKnowledgeId: basicKnowledgeId,
        knowledgeTitle: knowledgeTitle,
        context: context,
        lines: buffer,
      );
      buffer.clear();
      continue;
    }

    final heading = _headingFromLine(line);
    if (heading != null && buffer.isEmpty) {
      context = _mergeContext(knowledgeTitle, heading);
      continue;
    }
    if (heading != null) {
      _flushBlock(
        result: result,
        seen: seen,
        basicKnowledgeId: basicKnowledgeId,
        knowledgeTitle: knowledgeTitle,
        context: context,
        lines: buffer,
      );
      buffer.clear();
      context = _mergeContext(knowledgeTitle, heading);
      continue;
    }

    buffer.add(_LineRef(i + 1, line));
  }

  _flushBlock(
    result: result,
    seen: seen,
    basicKnowledgeId: basicKnowledgeId,
    knowledgeTitle: knowledgeTitle,
    context: context,
    lines: buffer,
  );

  return result;
}

void _flushBlock({
  required List<_CandidateBlock> result,
  required Set<String> seen,
  required String basicKnowledgeId,
  required String knowledgeTitle,
  required String context,
  required List<_LineRef> lines,
}) {
  if (lines.isEmpty) {
    return;
  }

  final rawText = lines.map((line) => line.text).join('\n').trim();
  if (_isLowValueRawText(rawText)) {
    return;
  }

  final topic = _topicFromBlock(rawText, context);
  if (topic == null || _isBadTopic(topic)) {
    return;
  }

  final dedupeKey = '$basicKnowledgeId::$topic::${_compactForKey(rawText)}';
  if (!seen.add(dedupeKey)) {
    return;
  }

  final keywords = _keywordsFromText(rawText, topic);
  result.add(
    _CandidateBlock(
      id: '$basicKnowledgeId-candidate-${result.length + 1}',
      basicKnowledgeId: basicKnowledgeId,
      knowledgeTitle: knowledgeTitle,
      paragraphIndex: result.length,
      topic: topic,
      keywords: keywords,
      rawText: rawText,
      sourceStartLine: lines.first.number,
      sourceEndLine: lines.last.number,
    ),
  );
}

String? _topicFromBlock(String rawText, String context) {
  final firstLine = rawText.split('\n').first.trim();
  final colon = RegExp(
    r'^(?:[-—\s]*|[（(]?\d+[）).、]\s*|[（(]?[一二三四五六七八九十]+[）).、]\s*)'
    r'([\u4e00-\u9fa5A-Za-z0-9·《》“”（）()、]{2,44})[:：]',
  ).firstMatch(firstLine);
  if (colon != null) {
    return _normalizeTopic(colon.group(1)!);
  }

  final quoted = RegExp(r'[《“]([^》”]{2,18})[》”]').firstMatch(firstLine);
  if (quoted != null) {
    return _normalizeTopic(quoted.group(1)!);
  }

  final importantTerm = _importantTerms(firstLine).firstOrNull;
  if (importantTerm != null) {
    return _normalizeTopic(importantTerm);
  }

  final shortLead = RegExp(
    r'^(?:[-—\s]*|[（(]?\d+[）).、]\s*|[（(]?[一二三四五六七八九十]+[）).、]\s*)'
    r'([\u4e00-\u9fa5A-Za-z0-9·]{2,24})',
  ).firstMatch(firstLine);
  if (shortLead != null) {
    final lead = _normalizeTopic(shortLead.group(1)!);
    if (!_genericTopicWords.contains(lead)) {
      return lead;
    }
  }

  return _normalizeTopic(context);
}

String? _headingFromLine(String line) {
  final cleaned = _stripLeadingMarker(line);
  if (cleaned.length > 24) {
    return null;
  }
  if (cleaned.contains('：') || cleaned.contains(':')) {
    return null;
  }
  if (_isBadTopic(cleaned)) {
    return null;
  }

  final hasHeadingMarker = RegExp(
    r'^(第\s*[0-9一二三四五六七八九十]+\s*部分|专题[一二三四五六七八九十0-9]+|'
    r'[一二三四五六七八九十]+[、.．]|[（(][一二三四五六七八九十]+[）)]|'
    r'[0-9]+[、.．])',
  ).hasMatch(line);
  final looksLikeTitle = RegExp(
    r'(史|法|学|论|篇|文化|制度|时期|常识|知识|概述|简介|地貌|经济|文学|思想|法规)$',
  ).hasMatch(cleaned);

  if (!hasHeadingMarker && !looksLikeTitle) {
    return null;
  }
  return _normalizeTopic(cleaned);
}

List<String> _keywordsFromText(String rawText, String topic) {
  final keywords = <String>{topic};
  for (final match in RegExp(
    r'(?:公元前\s*)?\d{2,4}\s*年|\d+\s*万年|\d+\s*%|\d+\s*元|\d+\s*个月|\d+\s*日',
  ).allMatches(rawText)) {
    keywords.add(_normalizeTopic(match.group(0)!));
  }
  for (final match in RegExp(r'[《“]([^》”]{2,18})[》”]').allMatches(rawText)) {
    keywords.add(_normalizeTopic(match.group(1)!));
  }
  for (final term in _importantTerms(rawText)) {
    keywords.add(_normalizeTopic(term));
  }

  return keywords
      .where((keyword) => !_isBadTopic(keyword))
      .take(8)
      .toList(growable: false);
}

Iterable<String> _importantTerms(String text) {
  const suffixes = [
    '文化',
    '制度',
    '法',
    '法典',
    '法律',
    '条例',
    '条约',
    '运动',
    '战争',
    '改革',
    '变法',
    '主义',
    '思想',
    '理论',
    '政策',
    '机关',
    '机构',
    '工程',
    '技术',
    '原则',
    '权利',
    '义务',
    '责任',
    '犯罪',
    '刑罚',
    '诉讼',
    '许可',
    '处罚',
    '合同',
    '物权',
    '继承',
    '地貌',
    '气候',
    '能源',
  ];
  final suffixPattern = suffixes.map(RegExp.escape).join('|');
  final matches = RegExp(
    '([\\u4e00-\\u9fa5A-Za-z0-9·]{2,18}(?:$suffixPattern))',
  ).allMatches(text);
  return matches.map((match) => match.group(1)!).where((term) {
    final cleaned = _normalizeTopic(term);
    return !_isBadTopic(cleaned);
  });
}

String _mergeContext(String knowledgeTitle, String heading) {
  if (heading == knowledgeTitle || heading.startsWith(knowledgeTitle)) {
    return heading;
  }
  if (_genericTopicWords.contains(heading)) {
    return knowledgeTitle;
  }
  return '$knowledgeTitle / $heading';
}

String _cleanLine(String line) {
  return line
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[‌‍﻿]'), '')
      .trim()
      .replaceAll(RegExp(r'^[\-\*•·]+'), '')
      .trim();
}

String _stripLeadingMarker(String text) {
  return text
      .replaceFirst(RegExp(r'^第\s*[0-9一二三四五六七八九十]+\s*部分\s*'), '')
      .replaceFirst(RegExp(r'^专题[一二三四五六七八九十0-9]+\s*'), '')
      .replaceFirst(RegExp(r'^[一二三四五六七八九十]+[、.．]\s*'), '')
      .replaceFirst(RegExp(r'^[（(][一二三四五六七八九十]+[）)]\s*'), '')
      .replaceFirst(RegExp(r'^[0-9]+[、.．]\s*'), '')
      .trim();
}

String _normalizeTopic(String text) {
  var normalized = _stripLeadingMarker(text)
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[（(][^（）()]{1,24}[）)]'), '')
      .replaceAll(RegExp(r'[：:；;，,。]+$'), '')
      .replaceAll(RegExp(r'^[（(]+|[）)]+$'), '')
      .trim();
  normalized = normalized
      .split(RegExp(r'(?:是因为|是指|是|为|因|利用|通过|具有|包括|属于)'))
      .first;
  normalized = normalized.replaceAll(RegExp(r'(较为|一种|一个|主要|基本)$'), '').trim();
  return normalized;
}

bool _isLowValueRawText(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  if (compact.length < 18) {
    return true;
  }
  if (RegExp(r'^[0-9一二三四五六七八九十、.．（）()：:\s]+$').hasMatch(text)) {
    return true;
  }
  return false;
}

bool _isBadTopic(String topic) {
  final cleaned = _normalizeTopic(topic);
  if (cleaned.length < 2 || cleaned.length > 28) {
    return true;
  }
  if (_genericTopicWords.contains(cleaned)) {
    return true;
  }
  if (RegExp(r'^[0-9一二三四五六七八九十]+$').hasMatch(cleaned)) {
    return true;
  }
  if (RegExp(r'^[0-9]+[）).、]').hasMatch(cleaned)) {
    return true;
  }
  if (RegExp(r'^[的了和与及或在为是有对中]$').hasMatch(cleaned)) {
    return true;
  }
  if (RegExp(r'^[0-9]+[）)]?[\u4e00-\u9fa5]{0,2}$').hasMatch(cleaned)) {
    return true;
  }
  return false;
}

String _compactForKey(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  return compact.length <= 80 ? compact : compact.substring(0, 80);
}

String _buildMarkdown(List<Map<String, Object?>> articleResults) {
  final buffer = StringBuffer()
    ..writeln('# 知识卡片候选块预览')
    ..writeln()
    ..writeln('> 未调用 AI，未写入 basic_knowledge_segment。')
    ..writeln();

  for (final article in articleResults) {
    buffer
      ..writeln(
        '## ${article['knowledge_title']} '
        '(${article['candidate_count']} 个候选块)',
      )
      ..writeln();
    final candidates = article['preview_candidates'] as List<Object?>;
    for (final candidateJson in candidates.take(8)) {
      final candidate = candidateJson as Map<String, Object?>;
      final rawText = '${candidate['raw_text']}';
      final preview = rawText.length <= 120
          ? rawText
          : '${rawText.substring(0, 120)}...';
      buffer
        ..writeln(
          '- ${candidate['paragraph_index']}. '
          '${candidate['topic']}',
        )
        ..writeln(
          '  - keywords: '
          '${(candidate['keywords'] as List<Object?>).join('、')}',
        )
        ..writeln('  - raw: $preview')
        ..writeln();
    }
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

const _genericTopicWords = {
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '第一部分',
  '第二部分',
  '第三部分',
  '定义',
  '概念',
  '特点',
  '意义',
  '影响',
  '作用',
  '原因',
  '内容',
  '分类',
  '类型',
  '条件',
  '要求',
  '原则',
  '时间',
  '地点',
  '人物',
  '代表',
  '重点',
  '其他',
  '补充',
  '简介',
  '概述',
  '开始',
  '组成',
  '功能',
  '拓展',
  '搭配',
  '一定时期',
};

class _LineRef {
  const _LineRef(this.number, this.text);

  final int number;
  final String text;
}

class _CandidateBlock {
  const _CandidateBlock({
    required this.id,
    required this.basicKnowledgeId,
    required this.knowledgeTitle,
    required this.paragraphIndex,
    required this.topic,
    required this.keywords,
    required this.rawText,
    required this.sourceStartLine,
    required this.sourceEndLine,
  });

  final String id;
  final String basicKnowledgeId;
  final String knowledgeTitle;
  final int paragraphIndex;
  final String topic;
  final List<String> keywords;
  final String rawText;
  final int sourceStartLine;
  final int sourceEndLine;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'basic_knowledge_id': basicKnowledgeId,
      'knowledge_title': knowledgeTitle,
      'paragraph_index': paragraphIndex,
      'topic': topic,
      'keywords': keywords,
      'source_start_line': sourceStartLine,
      'source_end_line': sourceEndLine,
      'raw_text': rawText,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
