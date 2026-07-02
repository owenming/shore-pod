import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shore_pod/data/agent_catalog.dart';
import 'package:shore_pod/main.dart';

Map<String, Object?> loadSeedTablesFromFiles() {
  final raw = File('assets/data/shore_pod_seed.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final tables = decoded['tables'] as Map<String, Object?>;
  return {
    for (final entry in tables.entries)
      entry.key: entry.value is String
          ? jsonDecode(File('${entry.value}').readAsStringSync())
          : entry.value,
  };
}

String _normalizeTestText(String value) {
  return value
      .replaceAll(RegExp("[\\s，,。；;：:、（）()《》“”\"'‘’]"), '')
      .toLowerCase();
}

void main() {
  test('bundled seed contains knowledge cloze blanks', () {
    final tables = loadSeedTablesFromFiles();
    final segmentRows = (tables['basic_knowledge_segment'] as List).cast<Map>();
    final clozeRows = (tables['basic_knowledge_cloze_blank'] as List)
        .cast<Map>();
    final segmentById = {for (final row in segmentRows) '${row['id']}': row};

    expect(clozeRows.length, greaterThan(8000));
    expect(
      clozeRows.every(
        (row) => segmentById.containsKey(row['knowledge_segment_id']),
      ),
      isTrue,
    );
    expect(
      clozeRows.every(
        (row) =>
            '${row['answer_text']}'.isNotEmpty &&
            row['start_offset'] is int &&
            row['end_offset'] is int &&
            (row['start_offset'] as int) < (row['end_offset'] as int),
      ),
      isTrue,
    );

    for (final row in clozeRows.take(200)) {
      final segment = segmentById['${row['knowledge_segment_id']}']!;
      final source = ClozeExercise.fromSegment(
        KnowledgeSegment(
          id: '${segment['id']}',
          topicId: '${segment['basic_knowledge_id']}',
          index: segment['paragraph_index'] as int,
          content: '${segment['content']}',
          details: '${segment['content_details']}',
        ),
      ).source;
      expect(
        source.substring(row['start_offset'] as int, row['end_offset'] as int),
        row['answer_text'],
      );
    }
    for (final row in clozeRows) {
      final segment = segmentById['${row['knowledge_segment_id']}']!;
      final source = ClozeExercise.fromSegment(
        KnowledgeSegment(
          id: '${segment['id']}',
          topicId: '${segment['basic_knowledge_id']}',
          index: segment['paragraph_index'] as int,
          content: '${segment['content']}',
          details: '${segment['content_details']}',
        ),
      ).source;
      final bodyStart = source.contains('\n') ? source.indexOf('\n') + 1 : 0;
      expect(row['start_offset'] as int, greaterThanOrEqualTo(bodyStart));
      expect(
        _normalizeTestText('${segment['content']}'),
        isNot(contains(_normalizeTestText('${row['answer_text']}'))),
      );
    }
  });

  test('bundled seed contains aptitude category hierarchy', () {
    final tables = loadSeedTablesFromFiles();
    final categoryRows = (tables['aptitude_category'] as List).cast<Map>();
    final subcategoryRows = (tables['aptitude_subcategory'] as List)
        .cast<Map>();
    final questionRows = (tables['aptitude_question'] as List).cast<Map>();
    final childTitlesByParent = <String, List<String>>{};
    for (final parent in categoryRows) {
      childTitlesByParent['${parent['category_title']}'] = subcategoryRows
          .where((row) => row['category_id'] == parent['id'])
          .map((row) => '${row['subcategory_title']}')
          .toList(growable: false);
    }

    expect(categoryRows.map((row) => row['category_title']), [
      '判断推理',
      '数量关系',
      '言语理解与表达',
      '资料分析',
    ]);
    expect(childTitlesByParent['判断推理'], [
      '科学推理',
      '图形推理',
      '定义判断',
      '类比推理',
      '逻辑判断',
    ]);
    expect(childTitlesByParent['数量关系'], ['数学运算', '数字推理']);
    expect(childTitlesByParent['言语理解与表达'], ['逻辑填空', '篇章阅读', '语句表达', '阅读理解']);
    expect(childTitlesByParent['资料分析'], ['资料分析']);

    final judgmentCategory = categoryRows.firstWhere(
      (row) => row['category_title'] == '判断推理',
    );
    final definitionSubcategory = subcategoryRows.firstWhere(
      (row) =>
          row['category_id'] == judgmentCategory['id'] &&
          row['subcategory_title'] == '定义判断',
    );
    final scienceSubcategory = subcategoryRows.firstWhere(
      (row) =>
          row['category_id'] == judgmentCategory['id'] &&
          row['subcategory_title'] == '科学推理',
    );
    final graphicSubcategory = subcategoryRows.firstWhere(
      (row) =>
          row['category_id'] == judgmentCategory['id'] &&
          row['subcategory_title'] == '图形推理',
    );
    final analogySubcategory = subcategoryRows.firstWhere(
      (row) =>
          row['category_id'] == judgmentCategory['id'] &&
          row['subcategory_title'] == '类比推理',
    );
    final logicSubcategory = subcategoryRows.firstWhere(
      (row) =>
          row['category_id'] == judgmentCategory['id'] &&
          row['subcategory_title'] == '逻辑判断',
    );
    final definitionRows = questionRows
        .where((row) => row['subcategory_id'] == definitionSubcategory['id'])
        .toList(growable: false);
    final graphicRows = questionRows
        .where((row) => row['subcategory_id'] == graphicSubcategory['id'])
        .toList(growable: false);
    final scienceRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-科学推理')
        .toList(growable: false);
    final graphicSourceRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-图形推理')
        .toList(growable: false);
    final analogyRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-类比推理')
        .toList(growable: false);
    final logicRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-逻辑判断')
        .toList(growable: false);
    final mathRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-数学运算')
        .toList(growable: false);
    final numberReasoningRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-数字推理')
        .toList(growable: false);
    final logicalFillRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-逻辑填空')
        .toList(growable: false);
    final passageReadingRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-篇章阅读')
        .toList(growable: false);
    final sentenceExpressionRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-语句表达')
        .toList(growable: false);
    final readingComprehensionRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-阅读理解')
        .toList(growable: false);
    final dataAnalysisRows = questionRows
        .where((row) => row['source_name'] == '粉笔行测两万五-资料分析')
        .toList(growable: false);
    expect(questionRows.length, 19111);
    expect(definitionRows.length, 1475);
    expect(scienceRows.length, 288);
    expect(graphicRows.length, 1656);
    expect(graphicSourceRows.length, 1656);
    expect(analogyRows.length, 1430);
    expect(logicRows.length, 2130);
    expect(mathRows.length, 2373);
    expect(numberReasoningRows.length, 643);
    expect(logicalFillRows.length, 2379);
    expect(passageReadingRows.length, 589);
    expect(sentenceExpressionRows.length, 529);
    expect(readingComprehensionRows.length, 2189);
    expect(dataAnalysisRows.length, 3430);
    expect(
      questionRows.every(
        (row) => ['A', 'B', 'C', 'D'].contains(row['answer_key']),
      ),
      isTrue,
    );
    expect(
      definitionRows.every(
        (row) =>
            row['category_id'] == judgmentCategory['id'] &&
            row['subcategory_id'] == definitionSubcategory['id'],
      ),
      isTrue,
    );
    expect(
      scienceRows.every(
        (row) =>
            row['category_id'] == judgmentCategory['id'] &&
            row['subcategory_id'] == scienceSubcategory['id'],
      ),
      isTrue,
    );
    expect(
      graphicRows.every(
        (row) =>
            row['category_id'] == judgmentCategory['id'] &&
            row['subcategory_id'] == graphicSubcategory['id'],
      ),
      isTrue,
    );
    expect(
      analogyRows.every(
        (row) =>
            row['category_id'] == judgmentCategory['id'] &&
            row['subcategory_id'] == analogySubcategory['id'],
      ),
      isTrue,
    );
    expect(
      logicRows.every(
        (row) =>
            row['category_id'] == judgmentCategory['id'] &&
            row['subcategory_id'] == logicSubcategory['id'],
      ),
      isTrue,
    );
    expect(definitionRows.first['question_number'], 1);
    expect(definitionRows.first['answer_key'], 'D');
    expect(definitionRows.last['question_number'], 1475);
    expect(definitionRows.last['answer_key'], 'A');
    expect(scienceRows.first['question_number'], 1);
    expect(scienceRows.first['answer_key'], 'C');
    expect(scienceRows.last['question_number'], 288);
    expect(scienceRows.last['answer_key'], 'B');
    expect(graphicRows.first['question_number'], 1);
    expect(graphicRows.first['answer_key'], 'D');
    expect(graphicRows.last['question_number'], 1656);
    expect(graphicRows.last['answer_key'], 'A');
    expect(analogyRows.first['question_number'], 1);
    expect(analogyRows.first['answer_key'], 'D');
    expect(analogyRows.last['question_number'], 1430);
    expect(analogyRows.last['answer_key'], 'C');
    expect(logicRows.first['question_number'], 1);
    expect(logicRows.first['answer_key'], 'D');
    expect(logicRows.last['question_number'], 2130);
    expect(logicRows.last['answer_key'], 'B');
    final scienceImageRows = scienceRows
        .where((row) => '${row['question_image'] ?? ''}'.isNotEmpty)
        .toList(growable: false);
    expect(scienceImageRows.length, 176);
    for (final row in scienceImageRows) {
      final path = '${row['question_image']}';
      expect(path, startsWith('assets/images/aptitude/science_reasoning/'));
      expect(File(path).existsSync(), isTrue);
    }
    expect(
      graphicRows.every(
        (row) => '${row['question_image']}'.startsWith(
          'assets/images/aptitude/graphic_reasoning/',
        ),
      ),
      isTrue,
    );
    for (final row in graphicRows) {
      expect(File('${row['question_image']}').existsSync(), isTrue);
    }
    final pageImageRows = [...numberReasoningRows, ...dataAnalysisRows];
    expect(
      pageImageRows.every((row) => '${row['question_image']}'.isNotEmpty),
      isTrue,
    );
    for (final row in pageImageRows.take(20)) {
      expect(File('${row['question_image']}').existsSync(), isTrue);
    }
    final fallbackImageRows = [...analogyRows, ...logicRows]
        .where(
          (row) => '${row['question_image'] ?? ''}'.startsWith(
            'assets/images/aptitude/text_fallback/',
          ),
        )
        .toList(growable: false);
    expect(fallbackImageRows.length, 4);
    for (final row in fallbackImageRows) {
      expect(File('${row['question_image']}').existsSync(), isTrue);
    }

    final definitionOptionImageRows = definitionRows
        .where(
          (row) =>
              '${row['option_a_image'] ?? ''}'.isNotEmpty ||
              '${row['option_b_image'] ?? ''}'.isNotEmpty ||
              '${row['option_c_image'] ?? ''}'.isNotEmpty ||
              '${row['option_d_image'] ?? ''}'.isNotEmpty,
        )
        .toList(growable: false);
    expect(definitionOptionImageRows.map((row) => row['question_number']), [
      134,
      162,
      210,
      914,
      928,
    ]);
    for (final row in definitionOptionImageRows) {
      for (final key in [
        'option_a_image',
        'option_b_image',
        'option_c_image',
        'option_d_image',
      ]) {
        final path = '${row[key]}';
        expect(path, startsWith('assets/images/aptitude/definition_judgment/'));
        expect(File(path).existsSync(), isTrue);
      }
    }
    final mathOptionImageRows = mathRows
        .where(
          (row) =>
              '${row['option_a_image'] ?? ''}'.isNotEmpty ||
              '${row['option_b_image'] ?? ''}'.isNotEmpty ||
              '${row['option_c_image'] ?? ''}'.isNotEmpty ||
              '${row['option_d_image'] ?? ''}'.isNotEmpty,
        )
        .toList(growable: false);
    expect(mathOptionImageRows.length, 228);
    for (final row in mathOptionImageRows) {
      for (final key in [
        'option_a_image',
        'option_b_image',
        'option_c_image',
        'option_d_image',
      ]) {
        final path = '${row[key]}';
        expect(
          path,
          startsWith(
            'assets/images/aptitude/quantitative_reasoning/math_operations/options/',
          ),
        );
        expect(File(path).existsSync(), isTrue);
      }
    }
  });

  test('compares cloze answers with normalized partial matching', () {
    final exact = compareClozeAnswer(' 理论化、系统化的世界观 ', '理论化系统化的世界观');
    expect(exact.correct, isTrue);

    final close = compareClozeAnswer('系统化世界观', '理论化、系统化的世界观');
    expect(close.partial, isTrue);

    final missed = compareClozeAnswer('方法论', '理论化、系统化的世界观');
    expect(missed.correct, isFalse);
    expect(missed.partial, isFalse);
  });

  testWidgets('renders shore pod home experience', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = AptitudeCatalog.fromSeedTables(
      loadSeedTablesFromFiles().map((key, value) => MapEntry(key, value)),
    );
    debugSetAptitudeCatalogForTesting(catalog);

    await tester.pumpWidget(const ShorePodApp());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('上岸舱'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('常识卡'), findsOneWidget);
    expect(find.text('AI演练'), findsOneWidget);
    expect(find.widgetWithText(HomeShortcutButton, '行测'), findsNothing);
    expect(find.text('今日要做'), findsNothing);
    expect(find.text('常识'), findsOneWidget);
    expect(find.text('时政'), findsNothing);
    expect(find.text('PLUS'), findsNothing);
    expect(find.text('今日推荐'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);

    await tester.tap(find.text('常识'));
    await tester.pumpAndSettle();

    expect(find.text('马克思主义'), findsOneWidget);
    expect(find.text('国防与军队'), findsOneWidget);
    expect(find.text('专题'), findsOneWidget);
    expect(find.text('专题卡片'), findsNothing);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI演练'));
    await tester.pumpAndSettle();

    expect(find.text('AI演练'), findsOneWidget);
    expect(find.text('常识练习'), findsOneWidget);
    expect(find.text('AI常识演练'), findsOneWidget);
    expect(find.text('行测'), findsOneWidget);
    await tester.tap(find.text('行测'));
    await tester.pumpAndSettle();
    expect(find.text('行测练习'), findsOneWidget);
    expect(find.text('AI行测演练'), findsOneWidget);
    expect(find.text('开始演练'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '选择行测'));
    await tester.pumpAndSettle();
    expect(find.text('行测练习模式'), findsOneWidget);
    expect(find.text('刷题模式'), findsOneWidget);
    expect(find.text('背题模式'), findsOneWidget);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable().first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('常识卡'));
    await tester.pumpAndSettle();

    expect(find.text(syncedKnowledgeTopics.first.title), findsOneWidget);
    expect(find.text('知识卡片'), findsNothing);
    expect(find.textContaining('/'), findsWidgets);
    expect(find.text('挖空'), findsNothing);
    await tester.tap(
      find.text(syncedKnowledgeTopics.first.segments.first.content).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('挖空'), findsOneWidget);
  });

  testWidgets('opens aptitude categories and question deck', (tester) async {
    Future<void> pumpUntilFound(Finder finder) async {
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = AptitudeCatalog.fromSeedTables(
      loadSeedTablesFromFiles().map((key, value) => MapEntry(key, value)),
    );
    debugSetAptitudeCatalogForTesting(catalog);
    expect(
      catalog.categories.map((category) => category.title),
      contains('判断推理'),
    );

    await tester.pumpWidget(const ShorePodApp());
    await tester.pumpAndSettle();

    expect(find.text('自定义刷题'), findsNothing);
    expect(find.text('判断推理'), findsWidgets);
    final judgmentRow = find.widgetWithText(HomeAptitudeCategoryRow, '判断推理');
    await tester.tap(
      find.descendant(of: judgmentRow, matching: find.byType(IconButton)).first,
    );
    await pumpUntilFound(find.textContaining('太阳光与水平地面'));

    expect(find.text('1/288'), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.textContaining('太阳光与水平地面'), findsOneWidget);

    final correctOption = find.textContaining('与水平方向成70');
    await tester.ensureVisible(correctOption);
    await tester.tap(correctOption);
    await pumpUntilFound(find.text('回答正确'));

    expect(find.text('回答正确'), findsOneWidget);
  });

  testWidgets('expands aptitude category on the home page', (tester) async {
    Future<void> pumpUntilFound(Finder finder) async {
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = AptitudeCatalog.fromSeedTables(
      loadSeedTablesFromFiles().map((key, value) => MapEntry(key, value)),
    );
    debugSetAptitudeCatalogForTesting(catalog);

    await tester.pumpWidget(const ShorePodApp());
    await tester.pumpAndSettle();

    await pumpUntilFound(find.text('判断推理'));
    expect(find.text('定义判断'), findsNothing);

    await tester.tap(find.text('判断推理'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('定义判断'), findsOneWidget);
    expect(find.text('类比推理'), findsOneWidget);
  });

  testWidgets('opens questions from category arrow and remembers category', (
    tester,
  ) async {
    Future<void> pumpUntilFound(Finder finder) async {
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = AptitudeCatalog.fromSeedTables(
      loadSeedTablesFromFiles().map((key, value) => MapEntry(key, value)),
    );
    debugSetAptitudeCatalogForTesting(catalog);
    await appSettingsController.update(
      appSettingsController.settings.copyWith(latestAptitudeCategoryId: ''),
    );

    await tester.pumpWidget(const ShorePodApp());
    await tester.pumpAndSettle();
    await pumpUntilFound(find.text('判断推理'));
    expect(find.text('继续做题'), findsNothing);

    final judgmentRow = find.widgetWithText(HomeAptitudeCategoryRow, '判断推理');
    await tester.tap(
      find.descendant(of: judgmentRow, matching: find.byType(IconButton)).first,
    );
    await pumpUntilFound(find.textContaining('太阳光与水平'));

    expect(find.text('1/288'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsWidgets);

    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable().first,
    );
    await tester.pumpAndSettle();

    expect(find.text('继续做题'), findsOneWidget);
  });
}
