import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shore_pod/data/agent_catalog.dart';
import 'package:shore_pod/main.dart';

void main() {
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

    await tester.pumpWidget(const ShorePodApp());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('上岸舱'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('常识卡'), findsOneWidget);
    expect(find.text('AI演练'), findsOneWidget);
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
    expect(find.text('练习模式'), findsOneWidget);
    expect(find.text('AI真题演练'), findsOneWidget);
    expect(find.text('开始演练'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('常识卡'));
    await tester.pumpAndSettle();

    expect(find.text(syncedKnowledgeTopics.first.title), findsOneWidget);
    expect(find.text('知识卡片'), findsNothing);
    expect(find.textContaining('/'), findsWidgets);
    expect(find.text('挖空'), findsOneWidget);

    await tester.tap(find.text('挖空'));
    await tester.pumpAndSettle();

    expect(find.text('挖空练习'), findsOneWidget);
    expect(find.text('逐空比对'), findsNothing);
  });
}
