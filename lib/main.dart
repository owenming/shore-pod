import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/agent_catalog.dart';
import 'data/local_sqlite_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalSqliteStore.instance.bootstrap();
  await appSettingsController.load();
  final knowledgeTables = await LocalSqliteStore.instance
      .knowledgeCatalogTables();
  if (knowledgeTables.isEmpty) {
    await loadBundledKnowledgeSeed();
  } else {
    applyKnowledgeTables(knowledgeTables);
  }
  runApp(const ShorePodApp());
}

final appSettingsController = AppSettingsController();

List<PracticeQuestion> randomQuestionSample(
  List<PracticeQuestion> questions,
  int count,
) {
  final sampleSize = math.min(count, questions.length);
  final shuffled = questions.toList(growable: false)..shuffle(math.Random());
  return shuffled.take(sampleSize).toList(growable: false);
}

class AppSettingsController extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaults();

  AppSettings get settings => _settings;

  Future<void> load() async {
    _settings = await LocalSqliteStore.instance.appSettings();
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = await LocalSqliteStore.instance.saveAppSettings(settings);
    notifyListeners();
  }

  ThemeMode get materialThemeMode {
    switch (_settings.themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Color get seedColor {
    switch (_settings.themeColor) {
      case 'blue':
        return AppColors.blue;
      case 'cyan':
        return AppColors.cyan;
      case 'indigo':
        return AppColors.indigo;
      case 'amber':
        return AppColors.amber;
      case 'orange':
        return AppColors.orange;
      case 'purple':
        return AppColors.purple;
      case 'rose':
        return AppColors.rose;
      case 'red':
        return AppColors.red;
      case 'system':
        return AppColors.indigo;
      case 'green':
      default:
        return AppColors.green;
    }
  }
}

class ShorePodApp extends StatelessWidget {
  const ShorePodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettingsController,
      builder: (context, _) {
        final seedColor = appSettingsController.seedColor;
        return MaterialApp(
          title: '上岸舱',
          debugShowCheckedModeBanner: false,
          themeMode: appSettingsController.materialThemeMode,
          theme: buildAppTheme(seedColor, Brightness.light),
          darkTheme: buildAppTheme(seedColor, Brightness.dark),
          builder: (context, child) {
            return ColoredBox(
              color: AppColors.activeBackground,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: const ShorePodShell(),
        );
      },
    );
  }
}

ThemeData buildAppTheme(Color seedColor, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? AppColors.darkBackground : AppColors.background;
  final surface = dark ? AppColors.darkSurface : AppColors.surface;
  final ink = dark ? AppColors.darkInk : AppColors.ink;
  final muted = dark ? AppColors.darkMuted : AppColors.muted;
  final subtle = dark ? AppColors.darkSubtle : AppColors.subtle;
  final border = dark ? AppColors.darkBorder : AppColors.border;
  final borderStrong = dark
      ? AppColors.darkBorderStrong
      : AppColors.borderStrong;
  final tint = dark
      ? seedColor.withValues(alpha: 0.16)
      : Color.lerp(Colors.white, seedColor, 0.12)!;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: surface,
      primary: seedColor,
      onSurface: ink,
      outline: borderStrong,
      surfaceContainerHighest: tint,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: 'PingFang SC',
    dividerColor: border,
    splashColor: seedColor.withValues(alpha: dark ? 0.16 : 0.08),
    highlightColor: seedColor.withValues(alpha: dark ? 0.10 : 0.05),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: tint,
      elevation: 0,
      height: 58,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? seedColor : subtle, size: 23);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? seedColor : muted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      surfaceTintColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll(
        seedColor.withValues(alpha: dark ? 0.12 : 0.08),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: borderStrong,
        disabledForegroundColor: muted,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: borderStrong),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seedColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderStrong),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      prefixIconColor: seedColor,
      suffixIconColor: subtle,
      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: subtle, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: seedColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(color: muted, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? AppColors.darkSurfaceHigh : AppColors.ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(color: ink, height: 1.48, letterSpacing: 0),
      bodySmall: TextStyle(color: muted, height: 1.45, letterSpacing: 0),
    ),
  );
}

class ShorePodShell extends StatefulWidget {
  const ShorePodShell({super.key});

  @override
  State<ShorePodShell> createState() => _ShorePodShellState();
}

class _ShorePodShellState extends State<ShorePodShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    appSettingsController.addListener(_handleSettingsChanged);
  }

  @override
  void dispose() {
    appSettingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onOpen: _open,
        onSwitchTab: (index) => setState(() => _tab = index),
      ),
      StudyPage(onOpen: _open),
      const AptitudeTabPage(),
      ProfilePage(onOpen: _open),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.activeSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.isDarkActive
                      ? const Color(0x55000000)
                      : const Color(0x140B1F2A),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                selectedIndex: _tab,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '首页',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school_rounded),
                    label: '常识',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    selectedIcon: Icon(Icons.fact_check_rounded),
                    label: '行测',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: '我的',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpen, required this.onSwitchTab});

  final ValueChanged<Widget> onOpen;
  final ValueChanged<int> onSwitchTab;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '上岸舱',
      titleWidget: const HomeBrandHeader(),
      backgroundColor: AppColors.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeBannerCarousel(
            onTap: () {
              _openRecentKnowledgeCards(context);
            },
          ),
          const SizedBox(height: 18),
          HomeShortcutGrid(
            items: [
              HomeShortcutItem(
                icon: Icons.menu_book_rounded,
                label: '常识卡',
                color: AppColors.accent,
                tint: AppColors.accentTint,
                onTap: () {
                  _openRecentKnowledgeCards(context);
                },
              ),
              HomeShortcutItem(
                icon: Icons.auto_stories_rounded,
                label: '专题',
                color: AppColors.green,
                tint: AppColors.greenTint,
                onTap: () => onSwitchTab(1),
              ),
              HomeShortcutItem(
                icon: Icons.bolt_rounded,
                label: 'AI演练',
                color: AppColors.amber,
                tint: AppColors.amberTint,
                onTap: () => onOpen(PracticeHubPage(onOpen: onOpen)),
              ),
              HomeShortcutItem(
                icon: Icons.bookmark_rounded,
                label: '收藏',
                color: AppColors.accent,
                tint: AppColors.accentTint,
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    onOpen(const FavoriteItemsPage());
                  }
                },
              ),
              HomeShortcutItem(
                icon: Icons.sticky_note_2_rounded,
                label: '笔记',
                color: AppColors.amber,
                tint: AppColors.amberTint,
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    onOpen(const MyNotesPage());
                  }
                },
              ),
              HomeShortcutItem(
                icon: Icons.assignment_late_rounded,
                label: '错题本',
                color: AppColors.red,
                tint: AppColors.redTint,
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    onOpen(const WrongQuestionBookPage());
                  }
                },
              ),
              HomeShortcutItem(
                icon: Icons.history_rounded,
                label: '记录',
                color: AppColors.purple,
                tint: AppColors.purpleTint,
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    onOpen(const MyExamAttemptsPage());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          HomeRecommendationCard(
            onTap: () {
              _openRecentKnowledgeCards(context);
            },
          ),
          const SizedBox(height: 24),
          HomeAptitudePracticeSection(onOpen: onOpen),
        ],
      ),
    );
  }

  Future<void> _openRecentKnowledgeCards(BuildContext context) async {
    final topic = await _recentKnowledgeTopic();
    if (!context.mounted) {
      return;
    }
    if (topic == null) {
      showToast(context, '暂无常识卡片');
      return;
    }
    onOpen(KnowledgeCardDeckPage(topic: topic));
  }

  Future<KnowledgeTopic?> _recentKnowledgeTopic() async {
    final latestTopicId = await LocalSqliteStore.instance
        .latestKnowledgeCardTopicId();
    if (latestTopicId != null) {
      for (final topic in syncedKnowledgeTopics) {
        if (topic.id == latestTopicId && topic.segments.isNotEmpty) {
          return topic;
        }
      }
    }
    for (final topic in syncedKnowledgeTopics) {
      if (topic.segments.isNotEmpty) {
        return topic;
      }
    }
    return null;
  }
}

class HomeAptitudePracticeSection extends StatefulWidget {
  const HomeAptitudePracticeSection({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  State<HomeAptitudePracticeSection> createState() =>
      _HomeAptitudePracticeSectionState();
}

class _HomeAptitudePracticeSectionState
    extends State<HomeAptitudePracticeSection> {
  final Set<String> _expandedCategoryIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AptitudeCatalog>(
      future: loadBundledAptitudeCatalog(),
      initialData: _bundledAptitudeCatalog,
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        if (loading && catalog == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (catalog == null || catalog.categories.isEmpty) {
          return const EmptyState(message: '暂无行测类目');
        }
        final latestCategoryId =
            appSettingsController.settings.latestAptitudeCategoryId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '专项',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4B45),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '练习',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (final category in catalog.categories) ...[
              HomeAptitudeCategoryRow(
                category: category,
                expanded: _expandedCategoryIds.contains(category.id),
                current: latestCategoryId == category.id,
                onToggle: () => _toggleCategory(category.id),
                onOpen: () => _openFirstSubcategory(context, catalog, category),
                onContinue: () =>
                    _openFirstSubcategory(context, catalog, category),
              ),
              if (_expandedCategoryIds.contains(category.id)) ...[
                const SizedBox(height: 3),
                for (final subcategory in category.subcategories) ...[
                  HomeAptitudeSubcategoryRow(
                    subcategory: subcategory,
                    onTap: () =>
                        _openSubcategory(catalog, category.id, subcategory),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
              const SizedBox(height: 1),
            ],
          ],
        );
      },
    );
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (!_expandedCategoryIds.remove(categoryId)) {
        _expandedCategoryIds.add(categoryId);
      }
    });
  }

  void _openSubcategory(
    AptitudeCatalog catalog,
    String categoryId,
    AptitudeSubcategoryEntry subcategory,
  ) async {
    await _rememberLatestCategory(categoryId);
    if (!mounted) {
      return;
    }
    widget.onOpen(
      AptitudeQuestionDeckPage(
        title: subcategory.title,
        questions: catalog.questionsForSubcategory(subcategory.id),
      ),
    );
  }

  Future<void> _rememberLatestCategory(String categoryId) async {
    final settings = appSettingsController.settings;
    if (settings.latestAptitudeCategoryId == categoryId) {
      return;
    }
    await appSettingsController.update(
      settings.copyWith(latestAptitudeCategoryId: categoryId),
    );
  }

  void _openFirstSubcategory(
    BuildContext context,
    AptitudeCatalog catalog,
    AptitudeCategoryEntry category,
  ) {
    if (category.subcategories.isEmpty) {
      showToast(context, '这个类目还没有子类目');
      return;
    }
    final subcategory = category.subcategories.firstWhere(
      (entry) => entry.questionCount > 0,
      orElse: () => category.subcategories.first,
    );
    _openSubcategory(catalog, category.id, subcategory);
  }
}

class HomeAptitudeCategoryRow extends StatelessWidget {
  const HomeAptitudeCategoryRow({
    super.key,
    required this.category,
    required this.expanded,
    required this.current,
    required this.onToggle,
    required this.onOpen,
    required this.onContinue,
  });

  final AptitudeCategoryEntry category;
  final bool expanded;
  final bool current;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final showContinue = current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onToggle,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4B45),
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '刷题量：0/${category.questionCount}    正确率：0%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A97AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showContinue) ...[
            TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF4B45),
                backgroundColor: const Color(0xFFFFEAEA),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('继续做题'),
            ),
            const SizedBox(width: 5),
          ],
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.chevron_right_rounded),
            iconSize: 17,
            color: const Color(0xFF9AA3B2),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeAptitudeSubcategoryRow extends StatelessWidget {
  const HomeAptitudeSubcategoryRow({
    super.key,
    required this.subcategory,
    required this.onTap,
  });

  final AptitudeSubcategoryEntry subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 26),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FA),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8A97AF), width: 1.2),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF8A97AF),
                size: 12,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subcategory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '刷题量：0/${subcategory.questionCount}    正确率：0%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A97AF),
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA3B2),
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeBrandHeader extends StatelessWidget {
  const HomeBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '上岸舱',
          style: TextStyle(
            color: AppColors.activeInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: AppColors.activeMuted,
        ),
      ],
    );
  }
}

class HomeBannerCarousel extends StatelessWidget {
  const HomeBannerCarousel({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDarkActive;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF4AB0F6), Color(0xFF8D4FF2)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x44000000) : const Color(0x185F7CDB),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 30,
              top: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '常识学习已就绪',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '刷卡片、练真题，稳稳上岸',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24,
              top: 18,
              bottom: 16,
              child: Container(
                width: 94,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x220F1A2A),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform.scale(
                      scale: 1.48,
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeRecommendationCard extends StatelessWidget {
  const HomeRecommendationCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topic = syncedKnowledgeTopics.isEmpty
        ? null
        : syncedKnowledgeTopics.first;
    final title = topic?.title ?? '常识卡片';
    final segmentTotal = topic?.segments.length ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.activeSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDarkActive
                  ? const Color(0x44000000)
                  : const Color(0x160B1F2A),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1513258496099-48168024aec0?auto=format&fit=crop&w=900&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: Color(0xFF42A7B9));
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF1D4E61).withValues(alpha: 0.86),
                    const Color(0xFF1D4E61).withValues(alpha: 0.38),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '今日推荐',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          segmentTotal == 0
                              ? '继续学习常识卡片'
                              : '$segmentTotal 张卡片 · 点击继续学习',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeShortcutGrid extends StatelessWidget {
  const HomeShortcutGrid({super.key, required this.items});

  final List<HomeShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 10,
        mainAxisExtent: 86,
      ),
      itemBuilder: (context, index) => HomeShortcutButton(item: items[index]),
    );
  }
}

class HomeShortcutItem {
  const HomeShortcutItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final VoidCallback onTap;
}

class HomeShortcutButton extends StatelessWidget {
  const HomeShortcutButton({super.key, required this.item});

  final HomeShortcutItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.isDarkActive
                    ? item.color.withValues(alpha: 0.16)
                    : item.tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.activeInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTodayPanel extends StatelessWidget {
  const HomeTodayPanel({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.progress,
    required this.learned,
    required this.total,
    required this.questionCount,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String headline;
  final String subtitle;
  final double progress;
  final int learned;
  final int total;
  final int questionCount;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.isDarkActive
            ? AppColors.activeSurfaceHigh
            : AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconContainer(
                icon: Icons.school_rounded,
                color: Colors.white,
                tint: Colors.white.withValues(alpha: 0.14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD9E6E2),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HomeMetric(value: '$learned/$total', label: '常识进度'),
              const SizedBox(width: 8),
              HomeMetric(value: '$questionCount', label: '题库题量'),
              const SizedBox(width: 8),
              HomeMetric(value: '${(progress * 100).round()}%', label: '完成率'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text('继续常识'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSecondary,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('AI真题'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF58706A)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeMetric extends StatelessWidget {
  const HomeMetric({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD9E6E2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyPage extends StatefulWidget {
  const StudyPage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  var _categoryId = syncedKnowledgeCategories.first.id;
  var _query = '';
  var _searchOpen = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTopics = topicsForCategory(_categoryId);
    final source = _query.trim().isEmpty
        ? selectedTopics
        : syncedKnowledgeTopics
              .where(
                (topic) =>
                    topic.title.contains(_query.trim()) ||
                    topic.summary.contains(_query.trim()) ||
                    topic.article.contains(_query.trim()) ||
                    topic.segments.any(
                      (segment) =>
                          segment.content.contains(_query.trim()) ||
                          segment.details.contains(_query.trim()),
                    ),
              )
              .toList(growable: false);

    return AppScaffold(
      title: '常识',
      trailing: IconButton(
        tooltip: '搜索',
        onPressed: _toggleSearch,
        icon: Icon(
          _searchOpen ? Icons.close_rounded : Icons.search_rounded,
          color: _query.trim().isEmpty ? AppColors.activeInk : AppColors.accent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _searchOpen
                ? Padding(
                    key: const ValueKey('study-search-dropdown'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: StudySearchDropdown(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        _searchFocusNode.requestFocus();
                      },
                      onCancel: _closeSearch,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('study-search-closed')),
          ),
          if (!_searchOpen && _query.trim().isNotEmpty) ...[
            ActiveSearchBar(
              query: _query.trim(),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 14),
          ],
          StudyCategoryTopicLayout(
            categories: syncedKnowledgeCategories,
            selectedId: _categoryId,
            headerTitle: _query.trim().isEmpty ? '专题' : '搜索结果',
            topics: source,
            onSelected: (id) => setState(() {
              _categoryId = id;
              _searchController.clear();
              _query = '';
            }),
            onTopicTap: (topic) =>
                widget.onOpen(KnowledgeCardDeckPage(topic: topic)),
          ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      _searchController.text = _query;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  void _closeSearch() {
    setState(() => _searchOpen = false);
    _searchFocusNode.unfocus();
  }
}

class StudyCategoryTopicLayout extends StatelessWidget {
  const StudyCategoryTopicLayout({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.headerTitle,
    required this.topics,
    required this.onSelected,
    required this.onTopicTap,
  });

  final List<KnowledgeCategory> categories;
  final String selectedId;
  final String headerTitle;
  final List<KnowledgeTopic> topics;
  final ValueChanged<String> onSelected;
  final ValueChanged<KnowledgeTopic> onTopicTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: KnowledgeCategoryRail(
            categories: categories,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(headerTitle),
              const SizedBox(height: 10),
              if (topics.isEmpty)
                const EmptyState(message: '没有匹配的专题')
              else
                for (final topic in topics) ...[
                  KnowledgeTopicCard(
                    topic: topic,
                    onTap: () => onTopicTap(topic),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class KnowledgeCategoryRail extends StatelessWidget {
  const KnowledgeCategoryRail({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<KnowledgeCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          KnowledgeCategoryRailItem(
            category: categories[i],
            selected: categories[i].id == selectedId,
            onTap: () => onSelected(categories[i].id),
          ),
          if (i != categories.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class KnowledgeCategoryRailItem extends StatelessWidget {
  const KnowledgeCategoryRailItem({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final KnowledgeCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              height: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _aptitudeCategoryDisplayTitle(category.title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : AppColors.activeInk,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeHubPage extends StatefulWidget {
  const PracticeHubPage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  State<PracticeHubPage> createState() => _PracticeHubPageState();
}

enum PracticeSubject { knowledge, aptitude }

class _PracticeHubPageState extends State<PracticeHubPage> {
  var _subject = PracticeSubject.knowledge;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'AI演练',
      child: FutureBuilder<AptitudeCatalog>(
        future: loadBundledAptitudeCatalog(),
        initialData: _bundledAptitudeCatalog,
        builder: (context, snapshot) {
          final aptitudeQuestions =
              snapshot.data?.questions ?? const <AptitudeQuestion>[];
          final total = _subject == PracticeSubject.knowledge
              ? practiceQuestions.length
              : aptitudeQuestions.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PracticeSubjectTabs(
                selected: _subject,
                onSelected: (subject) => setState(() => _subject = subject),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.topCenter,
                child: PracticeGatewayCard(
                  subject: _subject,
                  totalQuestions: total,
                  onPracticeTap: () {
                    if (_subject == PracticeSubject.knowledge) {
                      _showPracticeModeSheet();
                      return;
                    }
                    _showAptitudePracticeModeSheet(aptitudeQuestions);
                  },
                  onAiExamTap: () {
                    if (_subject == PracticeSubject.knowledge) {
                      _showAiExamSheet();
                      return;
                    }
                    _showAptitudeAiExamSheet(aptitudeQuestions);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPracticeModeSheet() async {
    final availableCount = practiceQuestions.length;
    if (availableCount == 0) {
      showToast(context, '暂无可练题目');
      return;
    }
    final maxCount = math.min(100, availableCount);
    var selectedCount = math.min(30, maxCount).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        void openPractice({required bool memorizationMode}) {
          final selectedQuestions = randomQuestionSample(
            practiceQuestions,
            selectedCount.round(),
          );
          Navigator.of(sheetContext).pop();
          widget.onOpen(
            PracticeExamPage(
              title: memorizationMode ? '背题模式' : '刷题模式',
              questions: selectedQuestions,
              instantFeedback: !memorizationMode,
              memorizationMode: memorizationMode,
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return QuestionCountSheet(
              title: '练习模式',
              subtitle: '选择题量后进入刷题或背题',
              count: selectedCount.round(),
              maxCount: maxCount,
              value: selectedCount,
              onChanged: (value) => setDialogState(() => selectedCount = value),
              footer: QuestionModeActionRow(
                onPractice: () => openPractice(memorizationMode: false),
                onMemorize: () => openPractice(memorizationMode: true),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAptitudePracticeModeSheet(
    List<AptitudeQuestion> questions,
  ) async {
    final availableQuestions = questions.isNotEmpty
        ? questions
        : (await loadBundledAptitudeCatalog()).questions;
    final availableCount = availableQuestions.length;
    if (availableCount == 0) {
      showToast(context, '暂无可练题目');
      return;
    }
    final maxCount = math.min(100, availableCount);
    var selectedCount = math.min(30, maxCount).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        void openPractice({required bool memorizationMode}) {
          final selectedQuestions = availableQuestions.toList(growable: false)
            ..shuffle(math.Random());
          Navigator.of(sheetContext).pop();
          widget.onOpen(
            AptitudeQuestionDeckPage(
              title: memorizationMode ? '行测背题模式' : '行测刷题模式',
              questions: selectedQuestions
                  .take(selectedCount.round())
                  .toList(growable: false),
              memorizationMode: memorizationMode,
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return QuestionCountSheet(
              title: '行测练习模式',
              subtitle: '选择题量后进入刷题或背题',
              count: selectedCount.round(),
              maxCount: maxCount,
              value: selectedCount,
              onChanged: (value) => setDialogState(() => selectedCount = value),
              footer: QuestionModeActionRow(
                onPractice: () => openPractice(memorizationMode: false),
                onMemorize: () => openPractice(memorizationMode: true),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAiExamSheet() async {
    final availableCount = practiceQuestions.length;
    if (availableCount == 0) {
      showToast(context, '暂无可练题目');
      return;
    }
    final maxCount = math.min(100, availableCount);
    var selectedCount = math.min(30, maxCount).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        void openExam() {
          final selectedQuestions = randomQuestionSample(
            practiceQuestions,
            selectedCount.round(),
          );
          Navigator.of(sheetContext).pop();
          widget.onOpen(AIExamPage(questions: selectedQuestions));
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return QuestionCountSheet(
              title: 'AI真题演练',
              subtitle: '选择题量后进入统一交卷',
              count: selectedCount.round(),
              maxCount: maxCount,
              value: selectedCount,
              onChanged: (value) => setDialogState(() => selectedCount = value),
              footer: QuestionSheetPrimaryAction(
                onPressed: openExam,
                icon: const Icon(Icons.bolt_rounded),
                label: '开始演练',
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAptitudeAiExamSheet(
    List<AptitudeQuestion> questions,
  ) async {
    final availableCount = questions.length;
    if (availableCount == 0) {
      showToast(context, '暂无可练题目');
      return;
    }
    final maxCount = math.min(100, availableCount);
    var selectedCount = math.min(30, maxCount).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        void openExam() {
          final selectedQuestions = questions.toList(growable: false)
            ..shuffle(math.Random());
          Navigator.of(sheetContext).pop();
          widget.onOpen(
            AptitudeQuestionDeckPage(
              title: 'AI行测演练',
              questions: selectedQuestions
                  .take(selectedCount.round())
                  .toList(growable: false),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return QuestionCountSheet(
              title: 'AI行测演练',
              subtitle: '选择题量后进入行测组卷',
              count: selectedCount.round(),
              maxCount: maxCount,
              value: selectedCount,
              onChanged: (value) => setDialogState(() => selectedCount = value),
              footer: QuestionSheetPrimaryAction(
                onPressed: openExam,
                icon: const Icon(Icons.bolt_rounded),
                label: '开始演练',
              ),
            );
          },
        );
      },
    );
  }
}

class PracticeSubjectTabs extends StatelessWidget {
  const PracticeSubjectTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PracticeSubject selected;
  final ValueChanged<PracticeSubject> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.activeSurfaceHigh,
        border: Border.all(color: AppColors.activeBorderStrong),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PracticeSubjectTab(
              label: '常识',
              selected: selected == PracticeSubject.knowledge,
              onTap: () => onSelected(PracticeSubject.knowledge),
            ),
          ),
          Expanded(
            child: _PracticeSubjectTab(
              label: '行测',
              selected: selected == PracticeSubject.aptitude,
              onTap: () => onSelected(PracticeSubject.aptitude),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSubjectTab extends StatelessWidget {
  const _PracticeSubjectTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.activeMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeGatewayCard extends StatelessWidget {
  const PracticeGatewayCard({
    super.key,
    required this.subject,
    required this.totalQuestions,
    required this.onPracticeTap,
    required this.onAiExamTap,
  });

  final PracticeSubject subject;
  final int totalQuestions;
  final VoidCallback onPracticeTap;
  final VoidCallback onAiExamTap;

  @override
  Widget build(BuildContext context) {
    final knowledge = subject == PracticeSubject.knowledge;
    return AspectRatio(
      aspectRatio: 0.86,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: PracticeGatewayBackgroundPainter()),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: PracticeGatewayDividerPainter()),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: PracticeGatewayPane(
                      symbol: knowledge ? '常' : '行',
                      title: knowledge ? '常识练习' : '行测练习',
                      subtitle: knowledge
                          ? '刷题、背题，按你的节奏掌握知识点'
                          : '按类目刷题，专项突破薄弱题型',
                      metric: '$totalQuestions',
                      metricLabel: '可选题',
                      buttonLabel: knowledge ? '选择练习' : '选择行测',
                      accent: const Color(0xFFFF625F),
                      onTap: onPracticeTap,
                    ),
                  ),
                  Expanded(
                    child: PracticeGatewayPane(
                      symbol: 'AI',
                      title: knowledge ? 'AI常识演练' : 'AI行测演练',
                      subtitle: knowledge ? '按题量组卷，交卷后生成演练结果' : '随机组卷，进入行测真题演练',
                      metric: '$totalQuestions',
                      metricLabel: '真题池',
                      buttonLabel: '开始演练',
                      accent: const Color(0xFF5A55E2),
                      onTap: onAiExamTap,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.activeSurface,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF7B3D)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeGatewayPane extends StatelessWidget {
  const PracticeGatewayPane({
    super.key,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.buttonLabel,
    required this.accent,
    required this.onTap,
  });

  final String symbol;
  final String title;
  final String subtitle;
  final String metric;
  final String metricLabel;
  final String buttonLabel;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                          width: 8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              metric,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            metricLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: accent,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: FittedBox(child: Text(buttonLabel)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PracticeGatewayBackgroundPainter extends CustomPainter {
  const PracticeGatewayBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.width * 0.565;
    final bottom = size.width * 0.485;
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(top, 0)
      ..lineTo(bottom, size.height)
      ..lineTo(0, size.height)
      ..close();
    final rightPath = Path()
      ..moveTo(top, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(bottom, size.height)
      ..close();

    canvas.drawPath(
      leftPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A4B), Color(0xFFFF625F)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      rightPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3468EA), Color(0xFF7451D7)],
        ).createShader(Offset.zero & size),
    );

    _drawRing(canvas, Offset(size.width * 0.29, size.height * 0.55), 52);
    _drawRing(canvas, Offset(size.width * 0.74, size.height * 0.55), 52);
    _drawRing(canvas, Offset(size.width * 0.40, size.height * 0.08), 44);
    _drawRing(canvas, Offset(size.width * 0.89, size.height * 0.08), 44);
    _drawRing(canvas, Offset(size.width * 0.08, size.height * 0.93), 48);
    _drawRing(canvas, Offset(size.width * 0.58, size.height * 0.93), 48);
  }

  void _drawRing(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PracticeGatewayDividerPainter extends CustomPainter {
  const PracticeGatewayDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.width * 0.565;
    final bottom = size.width * 0.485;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(top, -2)
      ..lineTo(bottom, size.height + 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QuestionCountSheet extends StatelessWidget {
  const QuestionCountSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.maxCount,
    required this.value,
    required this.onChanged,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final int count;
  final int maxCount;
  final double value;
  final ValueChanged<double> onChanged;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.activeSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          9,
          18,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.activeBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.activeInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.activeMuted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    '$count/$maxCount 题',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.activeSurfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.activeBorder),
              ),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: value.clamp(1, maxCount.toDouble()),
                      min: 1,
                      max: maxCount.toDouble(),
                      divisions: maxCount > 1 ? maxCount - 1 : null,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.accentTint,
                      label: '$count 题',
                      onChanged: maxCount > 1 ? onChanged : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          '1 题',
                          style: TextStyle(
                            color: AppColors.activeMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$maxCount 题',
                          style: TextStyle(
                            color: AppColors.activeMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            footer,
          ],
        ),
      ),
    );
  }
}

class QuestionModeActionRow extends StatelessWidget {
  const QuestionModeActionRow({
    super.key,
    required this.onPractice,
    required this.onMemorize,
  });

  final VoidCallback onPractice;
  final VoidCallback onMemorize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuestionSheetPrimaryAction(
            onPressed: onPractice,
            icon: const Icon(Icons.flash_on_rounded),
            label: '刷题模式',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onMemorize,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('背题模式'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.activeInk,
                side: BorderSide(color: AppColors.activeBorderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class QuestionSheetPrimaryAction extends StatelessWidget {
  const QuestionSheetPrimaryAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: IconTheme.merge(
          data: const IconThemeData(size: 18, color: Colors.white),
          child: icon,
        ),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    appSettingsController.addListener(_handleSettingsChanged);
    _loadUser();
  }

  @override
  void dispose() {
    appSettingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUser() async {
    final user = await LocalSqliteStore.instance.currentUser();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  Future<void> _openLogin() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PhoneLoginPage()),
    );
    if (changed == true) {
      await _loadUser();
    }
  }

  Future<void> _openEditNickname(AppUser user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditNicknamePage(currentNickname: user.nickname),
      ),
    );
    if (changed == true) {
      await _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return AppScaffold(
      title: '我的',
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: user == null ? _openLogin : null,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: softCardDecoration(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: user == null
                        ? AppColors.accentTint
                        : AppColors.accent,
                    child: Icon(
                      user == null
                          ? Icons.person_add_alt_rounded
                          : Icons.school_rounded,
                      color: user == null ? AppColors.accent : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingUser ? '正在读取档案' : user?.nickname ?? '未登录',
                          style: TextStyle(
                            color: AppColors.activeInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _maskPhone(user.phone),
                            style: TextStyle(color: AppColors.activeMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (user != null)
                    IconButton(
                      tooltip: '修改昵称',
                      onPressed: () => _openEditNickname(user),
                      icon: const Icon(Icons.edit_rounded),
                      color: AppColors.accent,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accentTint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SettingsSection(
            title: '学习',
            children: [
              SettingsActionRow(
                icon: Icons.bookmark_rounded,
                title: '我的收藏',
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    widget.onOpen(const FavoriteItemsPage());
                  }
                },
              ),
              SettingsActionRow(
                icon: Icons.sticky_note_2_rounded,
                title: '我的笔记',
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    widget.onOpen(const MyNotesPage());
                  }
                },
              ),
              SettingsActionRow(
                icon: Icons.fact_check_rounded,
                title: '我的试题',
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    widget.onOpen(const MyExamAttemptsPage());
                  }
                },
              ),
              SettingsActionRow(
                icon: Icons.assignment_late_rounded,
                title: '错题本',
                onTap: () async {
                  if (await ensureLoggedIn(context) && context.mounted) {
                    widget.onOpen(const WrongQuestionBookPage());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SettingsPanel(),
        ],
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length != 11) {
      return phone;
    }
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }
}

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _submitting = false;
  bool _sentCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() {
    final phone = _phoneController.text.trim();
    if (!isValidMainlandPhone(phone)) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    setState(() {
      _sentCode = true;
      _codeController.text = '888888';
    });
    showToast(context, '验证码已发送，本地测试码为 888888');
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!isValidMainlandPhone(phone)) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    if (code != '888888') {
      showToast(context, '验证码不正确');
      return;
    }
    setState(() => _submitting = true);
    try {
      await LocalSqliteStore.instance.registerOrLoginWithPhoneCode(
        phone: phone,
        code: code,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          error.toString().replaceFirst('Invalid argument: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '登录会员中心',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.activeBorderStrong),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 36,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '欢迎回来',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.activeInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后继续使用你的学习档案',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.activeMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 11,
              decoration: loginInputDecoration(
                labelText: '手机号',
                hintText: '请输入 11 位手机号',
                icon: Icons.phone_iphone_rounded,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    decoration: loginInputDecoration(
                      labelText: '验证码',
                      hintText: '6 位验证码',
                      icon: Icons.lock_clock_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 104,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.activeSurface,
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _sendCode,
                    child: Text(_sentCode ? '重发' : '发送'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '提交中...' : '注册并登录'),
            ),
            const SizedBox(height: 14),
            Text(
              '测试验证码：888888',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.activeSubtle,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration loginInputDecoration({
  required String labelText,
  required String hintText,
  required IconData icon,
}) {
  final radius = BorderRadius.circular(12);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    counterText: '',
    prefixIcon: Icon(icon, color: AppColors.accent),
    filled: true,
    fillColor: AppColors.activeSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    labelStyle: TextStyle(color: AppColors.activeMuted),
    hintStyle: TextStyle(color: AppColors.activeSubtle),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.activeBorderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
    ),
  );
}

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key, required this.currentNickname});

  final String currentNickname;

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  late final TextEditingController _nicknameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 2 || nickname.length > 16) {
      showToast(context, '昵称需为 2-16 个字符');
      return;
    }
    setState(() => _saving = true);
    try {
      await LocalSqliteStore.instance.updateNickname(nickname);
      if (!mounted) {
        return;
      }
      showToast(context, '昵称已更新');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          error.toString().replaceFirst('Invalid argument: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '修改昵称',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nicknameController,
            maxLength: 16,
            decoration: InputDecoration(
              labelText: '昵称',
              hintText: '输入 2-16 个字符',
              prefixIcon: Icon(Icons.badge_rounded, color: AppColors.accent),
              filled: true,
              fillColor: AppColors.activeSurface,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存昵称'),
          ),
        ],
      ),
    );
  }
}

class KnowledgeDetailPage extends StatefulWidget {
  const KnowledgeDetailPage({
    super.key,
    required this.topic,
    this.initialIndex = 0,
  });

  final KnowledgeTopic topic;
  final int initialIndex;

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage> {
  final Map<String, String> _notes = {};
  late final PageController _pageController;
  late int _page;
  var _showBack = false;

  @override
  void initState() {
    super.initState();
    final lastIndex = math.max(0, widget.topic.segments.length - 1);
    _page = widget.initialIndex.clamp(0, lastIndex);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = _articleBody();
    final note = _notes[widget.topic.id] ?? '';
    final segments = widget.topic.segments;

    return DetailScaffold(
      title: widget.topic.title,
      trailing: PopupMenuButton<String>(
        tooltip: '更多',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (value) async {
          if (value == 'favorite') {
            final loggedIn = await ensureLoggedIn(context);
            if (!loggedIn) {
              return;
            }
            try {
              await LocalSqliteStore.instance.saveFavoriteItem(
                favoriteType: '专题',
                targetId: widget.topic.id,
                title: widget.topic.title,
                summary: widget.topic.summary,
              );
              if (context.mounted) {
                showToast(context, '已加入收藏');
              }
            } catch (error) {
              if (context.mounted && isLoginRequiredError(error)) {
                await openLoginPage(context);
              } else if (context.mounted) {
                showToast(context, '$error');
              }
            }
            return;
          }
          if (value == 'copy') {
            Clipboard.setData(ClipboardData(text: article));
            showToast(context, '已复制全文');
            return;
          }
          if (value == 'note') {
            final loggedIn = await ensureLoggedIn(context);
            if (loggedIn && context.mounted) {
              _editNote(context);
            }
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'favorite',
            child: Row(
              children: [
                Icon(Icons.bookmark_add_outlined),
                SizedBox(width: 10),
                Text('收藏'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'copy',
            child: Row(
              children: [
                Icon(Icons.copy_rounded),
                SizedBox(width: 10),
                Text('复制全文'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'note',
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded),
                SizedBox(width: 10),
                Text('写笔记'),
              ],
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: segments.isEmpty
                ? TopicArticlePanel(
                    title: widget.topic.title,
                    body: article,
                    note: note,
                    showBack: _showBack,
                    onTap: () => setState(() => _showBack = !_showBack),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: segments.length,
                    onPageChanged: (index) => setState(() {
                      _page = index;
                      _showBack = false;
                    }),
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      return TopicArticlePanel(
                        title: segment.content,
                        body: segment.details.trim().isEmpty
                            ? article
                            : segment.details,
                        note: note,
                        meta: '${index + 1}/${segments.length}',
                        showBack: _showBack,
                        onTap: () => setState(() => _showBack = !_showBack),
                      );
                    },
                  ),
          ),
          if (segments.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < math.min(segments.length, 5); i++)
                  Container(
                    width: i == math.min(_page, 4) ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == math.min(_page, 4)
                          ? AppColors.accent
                          : AppColors.activeBorderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.topic.segments.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KnowledgeCardDeckPage(
                          topic: widget.topic,
                          initialIndex: widget.initialIndex,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.style_rounded),
              label: Text('${widget.topic.segments.length} 张卡片'),
            ),
          ),
        ],
      ),
    );
  }

  String _articleBody() {
    final article = widget.topic.article.trim();
    if (article.isNotEmpty) {
      return article;
    }
    final parts = widget.topic.segments
        .map((segment) => segment.details.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '暂无正文内容';
    }
    return parts.join('\n\n');
  }

  void _editNote(BuildContext context) {
    final controller = TextEditingController(text: _notes[widget.topic.id]);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('文章笔记'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '写下你的速记、易错点或联想'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final loggedIn = await ensureLoggedIn(context);
                if (!loggedIn) {
                  return;
                }
                try {
                  await LocalSqliteStore.instance.saveUserNote(
                    noteType: '文章笔记',
                    targetId: widget.topic.id,
                    title: widget.topic.title,
                    content: controller.text.trim(),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  setState(
                    () => _notes[widget.topic.id] = controller.text.trim(),
                  );
                  Navigator.of(context).pop();
                } catch (error) {
                  if (context.mounted && isLoginRequiredError(error)) {
                    Navigator.of(context).pop();
                    await openLoginPage(context);
                  } else if (context.mounted) {
                    showToast(context, '$error');
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}

class TopicArticlePanel extends StatelessWidget {
  const TopicArticlePanel({
    super.key,
    required this.title,
    required this.body,
    required this.note,
    required this.showBack,
    required this.onTap,
    this.meta,
  });

  final String title;
  final String body;
  final String note;
  final String? meta;
  final bool showBack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: showBack ? 1 : 0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        builder: (context, value, _) {
          final showingBack = value >= 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(value * math.pi);
          final face = _TopicArticleFace(
            key: ValueKey(showingBack),
            title: title,
            body: body,
            note: note,
            meta: meta,
            showBack: showingBack,
          );

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: showingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: face,
                  )
                : face,
          );
        },
      ),
    );
  }
}

class _TopicArticleFace extends StatelessWidget {
  const _TopicArticleFace({
    super.key,
    required this.title,
    required this.body,
    required this.note,
    required this.showBack,
    this.meta,
  });

  final String title;
  final String body;
  final String note;
  final String? meta;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cleanBody = body.trim().isEmpty ? '暂无正文内容' : body.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: softCardDecoration(),
      child: Stack(
        children: [
          if (meta != null)
            Positioned(top: 0, right: 0, child: AppChip(label: meta!)),
          Positioned.fill(
            child: showBack
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: meta == null ? 0 : 72,
                                  ),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: AppColors.activeInk,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  cleanBody,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.68,
                                    color: AppColors.activeInk,
                                  ),
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  LabelBlock(label: '我的笔记', body: note),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.activeInk,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class KnowledgeSegmentDetailPage extends StatelessWidget {
  const KnowledgeSegmentDetailPage({
    super.key,
    required this.topic,
    required this.segment,
  });

  final KnowledgeTopic topic;
  final KnowledgeSegment segment;

  @override
  Widget build(BuildContext context) {
    final questions = practiceQuestions
        .where((question) => question.segmentId == segment.id)
        .toList(growable: false);

    return DetailScaffold(
      title: segment.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: softCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(label: topic.title),
                    const SizedBox(width: 8),
                    AppChip(label: '第 ${segment.index + 1} 张'),
                    const Spacer(),
                    IconButton(
                      tooltip: '复制卡片',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${segment.content}\n\n${segment.details}',
                          ),
                        );
                        showToast(context, '已复制卡片');
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  segment.content,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  segment.details,
                  style: const TextStyle(fontSize: 17, height: 1.72),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('本卡题目'),
          const SizedBox(height: 10),
          Expanded(
            child: questions.isEmpty
                ? const EmptyState(message: '这张卡片暂无题目')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: questions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      return PracticeQuestionListTile(
                        question: question,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PracticeExamPage(
                              title: '单题练习',
                              questions: [question],
                              instantFeedback: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class KnowledgeCardDeckPage extends StatefulWidget {
  const KnowledgeCardDeckPage({
    super.key,
    required this.topic,
    this.initialIndex = 0,
  }) : allTopics = false;

  const KnowledgeCardDeckPage.all({super.key, this.initialIndex = 0})
    : topic = null,
      allTopics = true;

  final KnowledgeTopic? topic;
  final int initialIndex;
  final bool allTopics;

  List<_KnowledgeCardDeckEntry> get _entries {
    final sourceTopics = allTopics
        ? syncedKnowledgeTopics
        : topic == null
        ? const <KnowledgeTopic>[]
        : [topic!];

    return [
      for (final item in sourceTopics)
        for (final segment in item.segments)
          _KnowledgeCardDeckEntry(topic: item, segment: segment),
    ];
  }

  @override
  State<KnowledgeCardDeckPage> createState() => _KnowledgeCardDeckPageState();
}

class _KnowledgeCardDeckEntry {
  const _KnowledgeCardDeckEntry({required this.topic, required this.segment});

  final KnowledgeTopic topic;
  final KnowledgeSegment segment;
}

class _KnowledgeCardDeckPageState extends State<KnowledgeCardDeckPage> {
  late final PageController _controller;
  late int _page;
  final Map<String, String> _cardNotes = {};
  final Map<String, SegmentStatus> _statusOverrides = {};
  final _cardNoteController = TextEditingController();
  final _cardNoteFocusNode = FocusNode();
  var _showBack = false;
  String? _editingNoteSegmentId;
  String? _activeClozeSegmentId;

  @override
  void initState() {
    super.initState();
    _page = _initialPage();
    _controller = PageController(initialPage: _page);
    _loadCardNotes();
    _rememberCurrentTopic();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cardNoteController.dispose();
    _cardNoteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget._entries;
    final progress = entries.isEmpty ? 0.0 : (_page + 1) / entries.length;
    final currentEntry = entries.isEmpty ? null : entries[_page];
    final currentSegment = currentEntry?.segment;
    final currentStatus = currentSegment == null
        ? SegmentStatus.notStarted
        : _statusOverrides[currentSegment.id] ?? currentSegment.status;
    return DetailScaffold(
      title: currentEntry?.topic.title ?? widget.topic?.title ?? '知识卡片',
      child: entries.isEmpty
          ? const EmptyState(message: '暂无知识卡片')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.accentTint,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_page + 1}/${entries.length}',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: entries.length,
                    onPageChanged: (index) {
                      setState(() {
                        _page = index;
                        _showBack = false;
                        _editingNoteSegmentId = null;
                        _activeClozeSegmentId = null;
                      });
                      _rememberCurrentTopic();
                      _cardNoteFocusNode.unfocus();
                    },
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final segment = entry.segment;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: FlipKnowledgeCard(
                          segment: segment,
                          showBack: _showBack && index == _page,
                          inlineCloze:
                              _activeClozeSegmentId == segment.id &&
                              _showBack &&
                              index == _page,
                          onTap:
                              _activeClozeSegmentId == segment.id &&
                                  _showBack &&
                                  index == _page
                              ? null
                              : () => setState(() {
                                  _showBack = !_showBack;
                                  if (!_showBack) {
                                    _activeClozeSegmentId = null;
                                  }
                                }),
                          onToggleCloze: () => setState(() {
                            if (_activeClozeSegmentId == segment.id &&
                                _showBack) {
                              _activeClozeSegmentId = null;
                              return;
                            }
                            _showBack = true;
                            _activeClozeSegmentId = segment.id;
                          }),
                          menu: _buildMoreMenu(context, entry),
                        ),
                      );
                    },
                  ),
                ),
                if (currentSegment != null &&
                    _editingNoteSegmentId == currentSegment.id) ...[
                  const SizedBox(height: 10),
                  CardNoteEditor(
                    controller: _cardNoteController,
                    focusNode: _cardNoteFocusNode,
                    onSave: () => _saveCardNote(currentEntry),
                  ),
                ] else if (currentSegment != null &&
                    (_cardNotes[currentSegment.id]?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  SavedCardNote(
                    note: _cardNotes[currentSegment.id]!,
                    onEdit: () => _startCardNote(currentSegment),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatusButton(
                        icon: Icons.auto_stories_rounded,
                        label: '已学习',
                        color: AppColors.blue,
                        selected: currentStatus == SegmentStatus.learned,
                        onTap: currentSegment == null
                            ? null
                            : () => setState(
                                () => _statusOverrides[currentSegment.id] =
                                    SegmentStatus.learned,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatusButton(
                        icon: Icons.flag_rounded,
                        label: '薄弱',
                        color: AppColors.red,
                        selected: currentStatus == SegmentStatus.weak,
                        onTap: currentSegment == null
                            ? null
                            : () => setState(
                                () => _statusOverrides[currentSegment.id] =
                                    SegmentStatus.weak,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatusButton(
                        icon: Icons.verified_rounded,
                        label: '掌握',
                        color: AppColors.green,
                        selected: currentStatus == SegmentStatus.mastered,
                        onTap: currentSegment == null
                            ? null
                            : () => setState(
                                () => _statusOverrides[currentSegment.id] =
                                    SegmentStatus.mastered,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  int _initialPage() {
    final entries = widget._entries;
    if (entries.isEmpty) {
      return 0;
    }
    final exact = entries.indexWhere(
      (entry) => entry.segment.index == widget.initialIndex,
    );
    if (exact >= 0) {
      return exact;
    }
    return 0;
  }

  Future<void> _loadCardNotes() async {
    final topicIds = widget._entries
        .map((entry) => entry.topic.id)
        .toSet()
        .toList(growable: false);
    final notes = <String, String>{};
    for (final topicId in topicIds) {
      try {
        notes.addAll(
          await LocalSqliteStore.instance.cardNotesForTopic(topicId),
        );
      } catch (error) {
        if (!isLoginRequiredError(error)) {
          rethrow;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _cardNotes
        ..clear()
        ..addAll(notes);
    });
  }

  void _rememberCurrentTopic() {
    final entries = widget._entries;
    if (_page < 0 || _page >= entries.length) {
      return;
    }
    unawaited(
      LocalSqliteStore.instance.saveLatestKnowledgeCardTopic(
        entries[_page].topic.id,
      ),
    );
  }

  Future<void> _saveCardNote(_KnowledgeCardDeckEntry? entry) async {
    if (entry == null) {
      return;
    }
    final segment = entry.segment;
    final note = _cardNoteController.text.trim();
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn) {
      return;
    }
    try {
      await LocalSqliteStore.instance.saveCardNote(
        topicId: entry.topic.id,
        segmentId: segment.id,
        note: note,
      );
    } catch (error) {
      if (mounted && isLoginRequiredError(error)) {
        await openLoginPage(context);
      } else if (mounted) {
        showToast(context, '$error');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (note.isEmpty) {
        _cardNotes.remove(segment.id);
      } else {
        _cardNotes[segment.id] = note;
      }
      _editingNoteSegmentId = null;
    });
    _cardNoteFocusNode.unfocus();
  }

  PopupMenuButton<String> _buildMoreMenu(
    BuildContext context,
    _KnowledgeCardDeckEntry entry,
  ) {
    final segment = entry.segment;
    return PopupMenuButton<String>(
      tooltip: '更多',
      icon: const Icon(Icons.more_horiz_rounded),
      color: AppColors.activeSurface,
      elevation: 5,
      shadowColor: const Color(0x22000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints.tightFor(width: 132),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (value) async {
        if (value == 'favorite') {
          final loggedIn = await ensureLoggedIn(context);
          if (!loggedIn) {
            return;
          }
          try {
            await LocalSqliteStore.instance.saveFavoriteItem(
              favoriteType: '卡片',
              targetId: entry.topic.id,
              targetSubId: segment.id,
              title: segment.content,
              summary: entry.topic.title,
            );
            if (context.mounted) {
              showToast(context, '已加入收藏');
            }
          } catch (error) {
            if (context.mounted && isLoginRequiredError(error)) {
              await openLoginPage(context);
            } else if (context.mounted) {
              showToast(context, '$error');
            }
          }
          return;
        }
        if (value == 'note') {
          final loggedIn = await ensureLoggedIn(context);
          if (loggedIn && context.mounted) {
            _startCardNote(segment);
          }
          return;
        }
        if (value == 'feedback') {
          showToast(context, '已收到错题反馈');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'favorite',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.star_border_rounded,
            label: '收藏',
          ),
        ),
        PopupMenuItem(
          value: 'note',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.edit_note_rounded,
            label: '记笔记',
          ),
        ),
        PopupMenuItem(
          value: 'feedback',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.report_gmailerrorred_rounded,
            label: '错题反馈',
          ),
        ),
      ],
    );
  }

  void _startCardNote(KnowledgeSegment segment) {
    setState(() {
      _editingNoteSegmentId = segment.id;
      _cardNoteController.text = _cardNotes[segment.id] ?? '';
      _cardNoteController.selection = TextSelection.collapsed(
        offset: _cardNoteController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cardNoteFocusNode.requestFocus();
      }
    });
  }
}

class CompactCardMenuItem extends StatelessWidget {
  const CompactCardMenuItem({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.activeInk),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: AppColors.activeInk,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class FlipKnowledgeCard extends StatelessWidget {
  const FlipKnowledgeCard({
    super.key,
    required this.segment,
    required this.showBack,
    required this.inlineCloze,
    required this.onTap,
    required this.onToggleCloze,
    required this.menu,
  });

  final KnowledgeSegment segment;
  final bool showBack;
  final bool inlineCloze;
  final VoidCallback? onTap;
  final VoidCallback onToggleCloze;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final segmentQuestions = practiceQuestions
        .where((question) => question.segmentId == segment.id)
        .toList(growable: false);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: showBack ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final showingBack = value >= 0.5;
        final angle = value * math.pi;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle);
        final face = _FlipKnowledgeCardFace(
          segment: segment,
          questions: segmentQuestions,
          showBack: showingBack,
          inlineCloze: inlineCloze && showingBack,
          onTap: onTap,
          onToggleCloze: onToggleCloze,
          menu: menu,
        );

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: face,
                )
              : face,
        );
      },
    );
  }
}

class _FlipKnowledgeCardFace extends StatelessWidget {
  const _FlipKnowledgeCardFace({
    required this.segment,
    required this.questions,
    required this.showBack,
    required this.inlineCloze,
    required this.onTap,
    required this.onToggleCloze,
    required this.menu,
  });

  final KnowledgeSegment segment;
  final List<PracticeQuestion> questions;
  final bool showBack;
  final bool inlineCloze;
  final VoidCallback? onTap;
  final VoidCallback onToggleCloze;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final clozeExercise = ClozeExercise.fromSegment(segment);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: softCardDecoration(radius: 18).copyWith(
          color: showBack ? AppColors.accentTint : AppColors.activeSurface,
          border: Border.all(
            color: showBack ? AppColors.accent : AppColors.activeBorderStrong,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: questions.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PracticeExamPage(
                              title: '本卡练习',
                              questions: questions,
                              instantFeedback: true,
                            ),
                          ),
                        ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.accent,
                    disabledForegroundColor: AppColors.activeSubtle,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('关联题目'),
                ),
                if (showBack) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: clozeExercise.blanks.isEmpty
                        ? null
                        : onToggleCloze,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.accent,
                      disabledForegroundColor: AppColors.activeSubtle,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(inlineCloze ? '原文' : '挖空'),
                  ),
                ],
                const Spacer(),
                menu,
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: inlineCloze
                            ? InlineClozePractice(exercise: clozeExercise)
                            : Text(
                                showBack
                                    ? knowledgeSegmentDisplayDetails(segment)
                                    : segment.content,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: showBack ? 17 : 30,
                                  fontWeight: showBack
                                      ? FontWeight.w600
                                      : FontWeight.w600,
                                  height: showBack ? 1.68 : 1.28,
                                  color: AppColors.activeInk,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String knowledgeSegmentDisplayDetails(KnowledgeSegment segment) {
  final details = segment.details.trim();
  final title = segment.content.trim();
  if (details.isEmpty || title.isEmpty) {
    return details;
  }

  final titlePrefix = RegExp('^${RegExp.escape(title)}的核心考点[：:]\\s*');
  final genericPrefix = RegExp(r'^[^\n：:]{1,40}的核心考点[：:]\s*');
  return details.replaceFirst(titlePrefix, '').replaceFirst(genericPrefix, '');
}

class ClozeExercise {
  const ClozeExercise({
    required this.title,
    required this.source,
    required this.blanks,
  });

  final String title;
  final String source;
  final List<ClozeBlank> blanks;

  static ClozeExercise fromSegment(KnowledgeSegment segment) {
    final source = _normalizeSourceText(
      segment.details.trim().isEmpty
          ? segment.content
          : '${segment.content}\n${segment.details}',
    );
    final storedBlanks = _storedBlanks(source, segment.clozeBlanks);
    if (storedBlanks.isNotEmpty) {
      return ClozeExercise(
        title: segment.content,
        source: source,
        blanks: storedBlanks,
      );
    }
    return ClozeExercise(
      title: segment.content,
      source: source,
      blanks: const [],
    );
  }

  static String _normalizeSourceText(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static List<ClozeBlank> _storedBlanks(
    String source,
    List<KnowledgeClozeBlank> stored,
  ) {
    final valid = <KnowledgeClozeBlank>[];
    final seenAnswers = <String>{};
    for (final blank in stored) {
      if (blank.start < 0 ||
          blank.end <= blank.start ||
          blank.end > source.length ||
          blank.answer.isEmpty) {
        continue;
      }
      final answerInSource = source.substring(blank.start, blank.end);
      if (answerInSource != blank.answer) {
        continue;
      }
      final normalized = normalizeClozeAnswer(blank.answer);
      if (seenAnswers.contains(normalized)) {
        continue;
      }
      valid.add(blank);
      seenAnswers.add(normalized);
      if (valid.length >= 5) {
        break;
      }
    }
    return [
      for (var i = 0; i < valid.length; i++)
        ClozeBlank(
          index: i + 1,
          start: valid[i].start,
          end: valid[i].end,
          answer: valid[i].answer,
          hint: valid[i].hint,
        ),
    ];
  }

  static List<_ClozeCandidate> _buildCandidates(String source) {
    final candidates = <_ClozeCandidate>[];

    void collect(RegExp pattern, int baseScore, String hint) {
      for (final match in pattern.allMatches(source)) {
        final raw = match.group(1);
        if (raw == null) {
          continue;
        }
        final answer = _cleanAnswer(raw);
        final start = source.indexOf(answer, match.start);
        if (start < 0 || !_isUsefulAnswer(answer)) {
          continue;
        }
        final lengthBonus = math.min(_answerLength(answer), 14);
        final digitBonus = RegExp(r'\d').hasMatch(answer) ? 8 : 0;
        final listBonus = RegExp(r'[、，和与及]').hasMatch(answer) ? 5 : 0;
        candidates.add(
          _ClozeCandidate(
            answer: answer,
            start: start,
            end: start + answer.length,
            score: baseScore + lengthBonus + digitBonus + listBonus,
            hint: hint,
          ),
        );
      }
    }

    collect(
      RegExp(
        r'(?:核心(?:是|在于)|本质(?:是|在于)|理论基础(?:是|为)|基础(?:是|为)|标志(?:是|为|着)|代表(?:是|为))([^，。；;\n]{2,30})',
      ),
      96,
      '核心判断',
    );
    collect(
      RegExp(r'(?:包括|主要(?:有|包括|内容(?:有|是)|特点(?:是|有)|体现为|表现为))([^。；;\n]{2,34})'),
      90,
      '组成要点',
    );
    collect(RegExp(r'(?:发现于|位于|发源于|分布于|迁都|建立在)([^，。；;\n]{2,22})'), 86, '地点线索');
    collect(
      RegExp(r'(?:生活在|发生于|开始于|创立于|建立于|确立于|实行于|首次航行)([^，。；;\n]{2,22})'),
      86,
      '时间线索',
    );
    collect(
      RegExp(
        r'(距今约?\s*\d+\s*万?年|公元前\s*\d+\s*年(?:至|到|—|-|~)?\s*(?:公元前)?\s*\d*\s*年?|[12]\d{3}\s*年(?:\s*\d+\s*月\s*\d+\s*日)?)',
      ),
      82,
      '时间线索',
    );
    collect(RegExp(r'(?:是|为|指|称为|又称)([^，。；;\n]{4,30})'), 74, '定义表述');
    collect(RegExp(r'(?:会|能够|已经|得以)([^，。；;\n]{3,24})'), 66, '能力特征');

    if (candidates.length < 3) {
      final fragments = source.split(RegExp(r'[。；;\n]'));
      var cursor = 0;
      for (final fragment in fragments) {
        final text = _cleanAnswer(fragment);
        final start = source.indexOf(text, cursor);
        cursor = start < 0 ? cursor + fragment.length + 1 : start + text.length;
        if (_isUsefulAnswer(text)) {
          candidates.add(
            _ClozeCandidate(
              answer: text,
              start: start < 0 ? 0 : start,
              end: (start < 0 ? 0 : start) + text.length,
              score: 48 + math.min(_answerLength(text), 10),
              hint: '关键句',
            ),
          );
        }
      }
    }

    return candidates;
  }

  static List<ClozeBlank> _selectBlanks(
    String source,
    List<_ClozeCandidate> candidates,
  ) {
    final targetCount = source.length > 140
        ? 4
        : source.length > 80
        ? 3
        : 2;
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      return b.answer.length.compareTo(a.answer.length);
    });

    final selected = <_ClozeCandidate>[];
    final normalizedAnswers = <String>{};
    for (final candidate in candidates) {
      final normalized = normalizeClozeAnswer(candidate.answer);
      if (normalizedAnswers.contains(normalized)) {
        continue;
      }
      final overlaps = selected.any(
        (item) => candidate.start < item.end && candidate.end > item.start,
      );
      if (overlaps) {
        continue;
      }
      selected.add(candidate);
      normalizedAnswers.add(normalized);
      if (selected.length >= targetCount) {
        break;
      }
    }

    selected.sort((a, b) => a.start.compareTo(b.start));
    return [
      for (var i = 0; i < selected.length; i++)
        ClozeBlank(
          index: i + 1,
          start: selected[i].start,
          end: selected[i].end,
          answer: selected[i].answer,
          hint: selected[i].hint,
        ),
    ];
  }

  static String _cleanAnswer(String value) {
    return value
        .replaceAll(RegExp(r'^[：:，,、\s]+'), '')
        .replaceAll(RegExp(r'[：:，,、。；;\s]+$'), '')
        .trim();
  }

  static bool _isUsefulAnswer(String answer) {
    final normalized = normalizeClozeAnswer(answer);
    final length = normalized.runes.length;
    if (length < 2 || length > 34) {
      return false;
    }
    if (answer.startsWith('该') ||
        answer.startsWith('其') ||
        answer.startsWith('这') ||
        answer.contains('复习时') ||
        answer.contains('容易混淆')) {
      return false;
    }
    return true;
  }

  static int _answerLength(String answer) =>
      normalizeClozeAnswer(answer).length;
}

class ClozeBlank {
  const ClozeBlank({
    required this.index,
    required this.start,
    required this.end,
    required this.answer,
    required this.hint,
  });

  final int index;
  final int start;
  final int end;
  final String answer;
  final String hint;
}

class _ClozeCandidate {
  const _ClozeCandidate({
    required this.answer,
    required this.start,
    required this.end,
    required this.score,
    required this.hint,
  });

  final String answer;
  final int start;
  final int end;
  final int score;
  final String hint;
}

class ClozeCompareResult {
  const ClozeCompareResult({
    required this.userAnswer,
    required this.expectedAnswer,
    required this.score,
  });

  final String userAnswer;
  final String expectedAnswer;
  final double score;

  bool get correct => score >= 0.82;
  bool get partial => !correct && score >= 0.55;

  String get label {
    if (correct) {
      return '答对';
    }
    if (partial) {
      return '接近';
    }
    return '需复习';
  }

  Color get color {
    if (correct) {
      return AppColors.green;
    }
    if (partial) {
      return AppColors.amber;
    }
    return AppColors.red;
  }
}

class ClozePracticePage extends StatefulWidget {
  const ClozePracticePage({super.key, required this.exercise});

  final ClozeExercise exercise;

  @override
  State<ClozePracticePage> createState() => _ClozePracticePageState();
}

class _ClozePracticePageState extends State<ClozePracticePage> {
  late final List<TextEditingController> _controllers;
  Map<int, ClozeCompareResult>? _results;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final _ in widget.exercise.blanks) TextEditingController(),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final correctCount =
        results?.values.where((result) => result.correct).length ?? 0;
    final partialCount =
        results?.values.where((result) => result.partial).length ?? 0;
    return DetailScaffold(
      title: '挖空练习',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: softCardDecoration(radius: 18),
            child: _ClozePassage(exercise: widget.exercise, results: results),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < widget.exercise.blanks.length; i++) ...[
            _ClozeAnswerField(
              blank: widget.exercise.blanks[i],
              controller: _controllers[i],
              result: results?[widget.exercise.blanks[i].index],
              onChanged: (_) {
                if (_results != null) {
                  setState(() => _results = null);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('比对答案'),
          ),
          if (results != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新填写'),
            ),
            const SizedBox(height: 14),
            _ClozeReviewPanel(
              blanks: widget.exercise.blanks,
              results: results,
              correctCount: correctCount,
              partialCount: partialCount,
            ),
          ],
        ],
      ),
    );
  }

  void _submit() {
    playAnswerFeedback();
    final nextResults = <int, ClozeCompareResult>{};
    for (var i = 0; i < widget.exercise.blanks.length; i++) {
      final blank = widget.exercise.blanks[i];
      nextResults[blank.index] = compareClozeAnswer(
        _controllers[i].text,
        blank.answer,
      );
    }
    setState(() => _results = nextResults);
  }

  void _reset() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() => _results = null);
  }
}

class InlineClozePractice extends StatefulWidget {
  const InlineClozePractice({super.key, required this.exercise});

  final ClozeExercise exercise;

  @override
  State<InlineClozePractice> createState() => _InlineClozePracticeState();
}

class _InlineClozePracticeState extends State<InlineClozePractice> {
  var _controllers = <TextEditingController>[];
  Map<int, ClozeCompareResult>? _results;

  @override
  void initState() {
    super.initState();
    _resetControllers();
  }

  @override
  void didUpdateWidget(covariant InlineClozePractice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.source != widget.exercise.source) {
      _disposeControllers();
      _results = null;
      _resetControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final correctCount =
        results?.values.where((result) => result.correct).length ?? 0;
    final partialCount =
        results?.values.where((result) => result.partial).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClozePassage(exercise: widget.exercise, results: results),
        const SizedBox(height: 14),
        for (var i = 0; i < widget.exercise.blanks.length; i++) ...[
          _ClozeAnswerField(
            blank: widget.exercise.blanks[i],
            controller: _controllers[i],
            result: results?[widget.exercise.blanks[i].index],
            onChanged: (_) {
              if (_results != null) {
                setState(() => _results = null);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('比对答案'),
        ),
        if (results != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _resetAnswers,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新填写'),
          ),
          const SizedBox(height: 14),
          _ClozeReviewPanel(
            blanks: widget.exercise.blanks,
            results: results,
            correctCount: correctCount,
            partialCount: partialCount,
          ),
        ],
      ],
    );
  }

  void _resetControllers() {
    _controllers = [
      for (final _ in widget.exercise.blanks) TextEditingController(),
    ];
  }

  void _disposeControllers() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }

  void _submit() {
    playAnswerFeedback();
    final nextResults = <int, ClozeCompareResult>{};
    for (var i = 0; i < widget.exercise.blanks.length; i++) {
      final blank = widget.exercise.blanks[i];
      nextResults[blank.index] = compareClozeAnswer(
        _controllers[i].text,
        blank.answer,
      );
    }
    setState(() => _results = nextResults);
  }

  void _resetAnswers() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() => _results = null);
  }
}

class _ClozePassage extends StatelessWidget {
  const _ClozePassage({required this.exercise, required this.results});

  final ClozeExercise exercise;
  final Map<int, ClozeCompareResult>? results;

  @override
  Widget build(BuildContext context) {
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final blank in exercise.blanks) {
      if (blank.start > cursor) {
        children.add(
          TextSpan(text: exercise.source.substring(cursor, blank.start)),
        );
      }
      final result = results?[blank.index];
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineClozeBlank(blank: blank, result: result),
        ),
      );
      cursor = blank.end;
    }
    if (cursor < exercise.source.length) {
      children.add(TextSpan(text: exercise.source.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: AppColors.activeInk,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.72,
        ),
        children: children,
      ),
    );
  }
}

class _InlineClozeBlank extends StatelessWidget {
  const _InlineClozeBlank({required this.blank, required this.result});

  final ClozeBlank blank;
  final ClozeCompareResult? result;

  @override
  Widget build(BuildContext context) {
    final color = result?.color ?? AppColors.accent;
    final reveal = result != null;
    final answerWidth = (blank.answer.runes.length * 13.0).clamp(72.0, 180.0);
    return Container(
      width: reveal ? null : answerWidth,
      constraints: const BoxConstraints(minWidth: 72),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDarkActive ? 0.18 : 0.10),
        border: Border.all(color: color.withValues(alpha: 0.72), width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        reveal ? '(${blank.index}) ${blank.answer}' : '(${blank.index})',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ClozeAnswerField extends StatelessWidget {
  const _ClozeAnswerField({
    required this.blank,
    required this.controller,
    required this.result,
    required this.onChanged,
  });

  final ClozeBlank blank;
  final TextEditingController controller;
  final ClozeCompareResult? result;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = result?.color ?? AppColors.activeBorderStrong;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: result == null
            ? null
            : Icon(
                result!.correct
                    ? Icons.check_circle_rounded
                    : result!.partial
                    ? Icons.warning_amber_rounded
                    : Icons.cancel_rounded,
                color: result!.color,
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color),
        ),
      ),
    );
  }
}

class _ClozeReviewPanel extends StatelessWidget {
  const _ClozeReviewPanel({
    required this.blanks,
    required this.results,
    required this.correctCount,
    required this.partialCount,
  });

  final List<ClozeBlank> blanks;
  final Map<int, ClozeCompareResult> results;
  final int correctCount;
  final int partialCount;

  @override
  Widget build(BuildContext context) {
    final mastered = correctCount == blanks.length;
    final nearly = !mastered && correctCount + partialCount >= blanks.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mastered
                    ? Icons.verified_rounded
                    : nearly
                    ? Icons.trending_up_rounded
                    : Icons.flag_rounded,
                color: mastered
                    ? AppColors.green
                    : nearly
                    ? AppColors.amber
                    : AppColors.red,
              ),
              const SizedBox(width: 8),
              Text(
                mastered
                    ? '核心信息已掌握'
                    : nearly
                    ? '表述接近，再压准关键词'
                    : '建议回看原卡片',
                style: TextStyle(
                  color: AppColors.activeInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final blank in blanks) ...[
            _ClozeReviewRow(blank: blank, result: results[blank.index]!),
            if (blank != blanks.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ClozeReviewRow extends StatelessWidget {
  const _ClozeReviewRow({required this.blank, required this.result});

  final ClozeBlank blank;
  final ClozeCompareResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.color.withValues(
          alpha: AppColors.isDarkActive ? 0.16 : 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: result.color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppChip(
                label: '空 ${blank.index}',
                selected: true,
                selectedColor: result.color,
              ),
              const SizedBox(width: 8),
              Text(
                result.label,
                style: TextStyle(
                  color: result.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(result.score * 100).round()}%',
                style: TextStyle(
                  color: AppColors.activeMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '你的答案：${result.userAnswer.isEmpty ? '未填写' : result.userAnswer}',
            style: TextStyle(color: AppColors.activeInk, height: 1.45),
          ),
          const SizedBox(height: 4),
          Text(
            '参考答案：${result.expectedAnswer}',
            style: TextStyle(
              color: AppColors.activeInk,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

ClozeCompareResult compareClozeAnswer(
  String userAnswer,
  String expectedAnswer,
) {
  final normalizedUser = normalizeClozeAnswer(userAnswer);
  final normalizedExpected = normalizeClozeAnswer(expectedAnswer);
  if (normalizedUser.isEmpty || normalizedExpected.isEmpty) {
    return ClozeCompareResult(
      userAnswer: userAnswer.trim(),
      expectedAnswer: expectedAnswer,
      score: 0,
    );
  }
  if (normalizedUser == normalizedExpected) {
    return ClozeCompareResult(
      userAnswer: userAnswer.trim(),
      expectedAnswer: expectedAnswer,
      score: 1,
    );
  }

  final shorter = math.min(normalizedUser.length, normalizedExpected.length);
  final longer = math.max(normalizedUser.length, normalizedExpected.length);
  final containment =
      normalizedUser.contains(normalizedExpected) ||
          normalizedExpected.contains(normalizedUser)
      ? shorter / longer
      : 0.0;
  final lcs = _longestCommonSubsequenceLength(
    normalizedUser.runes.toList(growable: false),
    normalizedExpected.runes.toList(growable: false),
  );
  final lcsRatio = lcs / longer;
  final recallRatio = lcs / normalizedExpected.length;
  final score = math.max(containment, math.max(lcsRatio, recallRatio * 0.92));
  return ClozeCompareResult(
    userAnswer: userAnswer.trim(),
    expectedAnswer: expectedAnswer,
    score: score.clamp(0, 1),
  );
}

String normalizeClozeAnswer(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s，。；;、,.!！?？:：“”‘’（）()《》【】\[\]{}·\-—~～]'), '')
      .trim();
}

int _longestCommonSubsequenceLength(List<int> a, List<int> b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  var previous = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    for (var j = 0; j < b.length; j++) {
      current[j + 1] = a[i] == b[j]
          ? previous[j] + 1
          : math.max(previous[j + 1], current[j]);
    }
    previous = current;
  }
  return previous[b.length];
}

class CardNoteEditor extends StatelessWidget {
  const CardNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '卡片笔记',
            style: TextStyle(
              color: AppColors.activeInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '写下这张卡片的速记或易错点',
                  filled: true,
                  fillColor: AppColors.activeBackground,
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 88, 46),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.activeBorderStrong),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.activeBorderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(68, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedCardNote extends StatelessWidget {
  const SavedCardNote({super.key, required this.note, required this.onEdit});

  final String note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                style: TextStyle(
                  color: AppColors.activeInk,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '编辑',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeExamPage extends StatefulWidget {
  const PracticeExamPage({
    super.key,
    required this.title,
    required this.questions,
    this.instantFeedback = true,
    this.memorizationMode = false,
  });

  final String title;
  final List<PracticeQuestion> questions;
  final bool instantFeedback;
  final bool memorizationMode;

  @override
  State<PracticeExamPage> createState() => _PracticeExamPageState();
}

class _PracticeExamPageState extends State<PracticeExamPage> {
  late final PageController _controller;
  var _index = 0;
  var _submitted = false;
  final Map<String, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const DetailScaffold(
        title: '练习',
        child: EmptyState(message: '暂无可练题目'),
      );
    }

    final progress = (_index + 1) / widget.questions.length;
    return DetailScaffold(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.blueTint,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.questions.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final pageQuestion = widget.questions[index];
                return _QuestionPracticeContent(
                  index: index,
                  question: pageQuestion,
                  selected: _answers[pageQuestion.id],
                  reveal:
                      widget.memorizationMode ||
                      _submitted ||
                      (widget.instantFeedback &&
                          _answers[pageQuestion.id] != null),
                  memorizationMode: widget.memorizationMode,
                  submitted: _submitted,
                  onSelect: (answer) {
                    playAnswerFeedback();
                    setState(() => _answers[pageQuestion.id] = answer);
                  },
                );
              },
            ),
          ),
          if (!widget.instantFeedback && !widget.memorizationMode) ...[
            const SizedBox(height: 12),
            QuestionSheetPrimaryAction(
              onPressed: _submitted
                  ? null
                  : () => setState(() => _submitted = true),
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: _submitted
                  ? '得分 ${_score()}/${widget.questions.length}'
                  : '交卷看成绩',
            ),
          ],
          if (_submitted) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PracticeReviewPage(
                    title: '错题解析',
                    questions: widget.questions
                        .where(
                          (question) =>
                              _answers[question.id] != question.answer,
                        )
                        .toList(growable: false),
                    answers: _answers,
                  ),
                ),
              ),
              icon: const Icon(Icons.assignment_late_rounded),
              label: const Text('查看错题解析'),
            ),
          ],
        ],
      ),
    );
  }

  int _score() {
    return widget.questions
        .where((question) => _answers[question.id] == question.answer)
        .length;
  }
}

Future<void> playAnswerFeedback() async {
  final settings = appSettingsController.settings;
  if (settings.soundEnabled) {
    await SystemSound.play(SystemSoundType.click);
  }
  if (settings.hapticEnabled) {
    await HapticFeedback.selectionClick();
  }
}

class _QuestionPracticeContent extends StatelessWidget {
  const _QuestionPracticeContent({
    required this.index,
    required this.question,
    required this.selected,
    required this.reveal,
    required this.memorizationMode,
    required this.submitted,
    required this.onSelect,
  });

  final int index;
  final PracticeQuestion question;
  final String? selected;
  final bool reveal;
  final bool memorizationMode;
  final bool submitted;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final correct = selected == question.answer;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: softCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${index + 1} 题',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  question.question,
                  style: TextStyle(
                    color: AppColors.activeInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++) ...[
            OptionCard(
              label: String.fromCharCode(65 + i),
              text: question.options[i],
              selected: selected == String.fromCharCode(65 + i),
              correct: reveal && question.answer == String.fromCharCode(65 + i),
              wrong:
                  reveal &&
                  selected == String.fromCharCode(65 + i) &&
                  selected != question.answer,
              onTap: submitted || memorizationMode
                  ? null
                  : () => onSelect(String.fromCharCode(65 + i)),
            ),
            const SizedBox(height: 10),
          ],
          if (reveal) ...[
            const SizedBox(height: 10),
            LabelBlock(
              label: memorizationMode
                  ? '答案解析'
                  : correct
                  ? '回答正确'
                  : '解析',
              body: '正确答案：${question.answer}\n${question.explanation}',
            ),
          ],
        ],
      ),
    );
  }
}

class PracticeReviewPage extends StatelessWidget {
  const PracticeReviewPage({
    super.key,
    required this.title,
    required this.questions,
    this.answers = const {},
  });

  final String title;
  final List<PracticeQuestion> questions;
  final Map<String, String> answers;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: title,
      child: questions.isEmpty
          ? const EmptyState(message: '暂无需要复盘的题目')
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = questions[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: softCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${question.question}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '你的答案：${answers[question.id] ?? '未答'}    正确答案：${question.answer}',
                        style: TextStyle(color: AppColors.activeMuted),
                      ),
                      const SizedBox(height: 10),
                      LabelBlock(label: '解析', body: question.explanation),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AIExamAttempt {
  const AIExamAttempt({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.questions,
    required this.answers,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final List<PracticeQuestion> questions;
  final Map<String, String> answers;

  int get answeredCount => answers.length;
  int get correctCount => questions
      .where((question) => answers[question.id] == question.answer)
      .length;
  int get wrongCount => questions.length - correctCount;
}

class AIExamPage extends StatefulWidget {
  const AIExamPage({super.key, required this.questions});

  final List<PracticeQuestion> questions;

  @override
  State<AIExamPage> createState() => _AIExamPageState();
}

class _AIExamPageState extends State<AIExamPage> {
  late final PageController _controller;
  late final DateTime _startedAt;
  var _index = 0;
  var _submitting = false;
  final Map<String, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const DetailScaffold(
        title: 'AI真题演练',
        child: EmptyState(message: '暂无可用题目'),
      );
    }

    return DetailScaffold(
      title: 'AI真题演练',
      trailing: TextButton(
        onPressed: _showAnswerSheet,
        child: Text('${_index + 1}/${widget.questions.length}'),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppChip(
                label: '已答 ${_answers.length}/${widget.questions.length}',
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAnswerSheet,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('答题卡'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.questions.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final pageQuestion = widget.questions[index];
                return _QuestionPracticeContent(
                  index: index,
                  question: pageQuestion,
                  selected: _answers[pageQuestion.id],
                  reveal: false,
                  memorizationMode: false,
                  submitted: false,
                  onSelect: (answer) => _selectAnswer(pageQuestion, answer),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _answers.length == widget.questions.length ? '交卷' : '交卷',
            ),
          ),
        ],
      ),
    );
  }

  void _selectAnswer(PracticeQuestion question, String answer) {
    playAnswerFeedback();
    setState(() => _answers[question.id] = answer);
    if (_index < widget.questions.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) {
          return;
        }
        _controller.nextPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  Future<void> _showAnswerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.activeSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.activeBorderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '答题卡',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < widget.questions.length; i++)
                      AnswerNumberButton(
                        number: i + 1,
                        selected: i == _index,
                        answered: _answers.containsKey(widget.questions[i].id),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _goTo(i);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted) {
      return;
    }
    if (!loggedIn) {
      setState(() => _submitting = false);
      return;
    }
    final now = DateTime.now();
    final attempt = AIExamAttempt(
      id: 'ai-exam-${now.millisecondsSinceEpoch}',
      title: 'AI真题演练',
      createdAt: now,
      questions: widget.questions,
      answers: Map<String, String>.from(_answers),
    );
    final duration = now.difference(_startedAt).inSeconds;
    try {
      await LocalSqliteStore.instance.savePracticeAttemptRecord(
        id: attempt.id,
        title: attempt.title,
        modeType: 'ai_exam',
        totalCount: attempt.questions.length,
        answeredCount: attempt.answeredCount,
        correctCount: attempt.correctCount,
        wrongCount: attempt.wrongCount,
        durationSeconds: duration,
        payloadJson: jsonEncode({
          'questionIds': attempt.questions
              .map((question) => question.id)
              .toList(),
          'answers': attempt.answers,
        }),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      showToast(context, '$error');
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AIExamResultPage(attempt: attempt),
      ),
    );
  }
}

class AIExamResultPage extends StatelessWidget {
  const AIExamResultPage({super.key, required this.attempt});

  final AIExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '考试结果',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryStrip(
            stats: [
              SummaryStat(value: '${attempt.correctCount}', label: '答对'),
              SummaryStat(value: '${attempt.wrongCount}', label: '答错'),
              SummaryStat(
                value: '${attempt.answeredCount}/${attempt.questions.length}',
                label: '已答',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('答题卡'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < attempt.questions.length; i++)
                ResultNumberButton(
                  number: i + 1,
                  correct:
                      attempt.answers[attempt.questions[i].id] ==
                      attempt.questions[i].answer,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AIExamReviewPager(attempt: attempt, initialIndex: i),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AIExamReviewPager extends StatefulWidget {
  const AIExamReviewPager({
    super.key,
    required this.attempt,
    this.initialIndex = 0,
  });

  final AIExamAttempt attempt;
  final int initialIndex;

  @override
  State<AIExamReviewPager> createState() => _AIExamReviewPagerState();
}

class _AIExamReviewPagerState extends State<AIExamReviewPager> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '试题解析',
      trailing: Text(
        '${_index + 1}/${widget.attempt.questions.length}',
        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
      ),
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.attempt.questions.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final question = widget.attempt.questions[index];
          final userAnswer = widget.attempt.answers[question.id] ?? '未答';
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${question.question}',
                  style: TextStyle(
                    color: AppColors.activeInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < question.options.length; i++) ...[
                  OptionCard(
                    label: String.fromCharCode(65 + i),
                    text: question.options[i],
                    selected: userAnswer == String.fromCharCode(65 + i),
                    correct: question.answer == String.fromCharCode(65 + i),
                    wrong:
                        userAnswer == String.fromCharCode(65 + i) &&
                        userAnswer != question.answer,
                    onTap: null,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                LabelBlock(
                  label: '答案',
                  body: '你的答案：$userAnswer\n正确答案：${question.answer}',
                ),
                const SizedBox(height: 10),
                LabelBlock(label: '解析', body: question.explanation),
              ],
            ),
          );
        },
      ),
    );
  }
}

AIExamAttempt? aiAttemptFromRow(Map<String, Object?> row) {
  final payload = row['payload_json'];
  if (payload == null || '$payload'.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode('$payload') as Map<String, Object?>;
    final ids = (decoded['questionIds'] as List<Object?>)
        .map((item) => '$item')
        .toList(growable: false);
    final questionById = {
      for (final question in practiceQuestions) question.id: question,
    };
    final questions = ids
        .map((id) => questionById[id])
        .whereType<PracticeQuestion>()
        .toList(growable: false);
    final rawAnswers = decoded['answers'] as Map<String, Object?>? ?? {};
    final answers = {
      for (final entry in rawAnswers.entries) entry.key: '${entry.value}',
    };
    return AIExamAttempt(
      id: '${row['id']}',
      title: '${row['title'] ?? 'AI真题演练'}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse('${row['created_time']}') ?? 0,
      ),
      questions: questions,
      answers: answers,
    );
  } catch (_) {
    return null;
  }
}

String formatShortDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

class ReviewListPage extends StatelessWidget {
  const ReviewListPage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final segments = syncedKnowledgeTopics
        .expand((topic) => topic.segments.map((segment) => (topic, segment)))
        .where(
          (item) =>
              item.$2.status == SegmentStatus.learned ||
              item.$2.status == SegmentStatus.weak,
        )
        .toList(growable: false);

    return DetailScaffold(
      title: '间隔复习',
      child: segments.isEmpty
          ? const EmptyState(message: '暂无到期复习')
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: segments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = segments[index];
                return TaskRowCard(
                  icon: Icons.refresh_rounded,
                  color: item.$2.status == SegmentStatus.weak
                      ? AppColors.red
                      : AppColors.blue,
                  tint: item.$2.status == SegmentStatus.weak
                      ? AppColors.tintFor(AppColors.red)
                      : AppColors.tintFor(AppColors.blue),
                  title: item.$1.title,
                  subtitle: item.$2.content,
                  meta: statusLabel(item.$2.status),
                  onTap: () => onOpen(
                    KnowledgeDetailPage(
                      topic: item.$1,
                      initialIndex: item.$2.index,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SpecialTrainingPage extends StatelessWidget {
  const SpecialTrainingPage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '专项训练',
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: syncedKnowledgeCategories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final category = syncedKnowledgeCategories[index];
          final questions = questionsForModule(category.id);
          final topics = topicsForCategory(category.id);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: softCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconContainer(
                      icon: category.icon,
                      color: colorForKey(category.colorKey),
                      tint: tintForKey(category.colorKey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${topics.length} 个专题 · ${questions.length} 道题',
                            style: TextStyle(color: AppColors.activeMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: questions.isEmpty
                      ? null
                      : () => onOpen(
                          PracticeExamPage(
                            title: '${category.title}专项训练',
                            questions: questions,
                            instantFeedback: true,
                          ),
                        ),
                  child: const Text('去做题'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WrongQuestionBookPage extends StatefulWidget {
  const WrongQuestionBookPage({super.key});

  @override
  State<WrongQuestionBookPage> createState() => _WrongQuestionBookPageState();
}

class _WrongQuestionBookPageState extends State<WrongQuestionBookPage> {
  var _allowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAccess());
  }

  Future<void> _ensureAccess() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted) {
      return;
    }
    if (!loggedIn) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _allowed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const DetailScaffold(
        title: '错题本',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final wrongQuestions = practiceQuestions.take(3).toList(growable: false);

    return DetailScaffold(
      title: '错题本',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryStrip(
            stats: [
              SummaryStat(value: '${wrongQuestions.length}', label: '总错题'),
              const SummaryStat(value: '1', label: '多次错'),
              const SummaryStat(value: '0', label: '已掌握'),
            ],
          ),
          const SizedBox(height: 16),
          const HorizontalChips(
            labels: [
              ChipData(id: 'all', label: '全部'),
              ChipData(id: 'due', label: '待复习'),
              ChipData(id: 'multi', label: '多次错'),
              ChipData(id: 'done', label: '已掌握'),
            ],
            selectedId: 'all',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: wrongQuestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = wrongQuestions[index];
                return TaskRowCard(
                  icon: Icons.assignment_late_rounded,
                  color: AppColors.red,
                  tint: AppColors.tintFor(AppColors.red),
                  title: question.module,
                  subtitle: question.question,
                  meta: '未掌握',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PracticeReviewPage(
                        title: '错题重练',
                        questions: [question],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FavoriteItemsPage extends StatefulWidget {
  const FavoriteItemsPage({super.key});

  @override
  State<FavoriteItemsPage> createState() => _FavoriteItemsPageState();
}

class _FavoriteItemsPageState extends State<FavoriteItemsPage> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <Map<String, Object?>>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted) {
      return;
    }
    if (!loggedIn) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _future = LocalSqliteStore.instance.favoriteItemRows();
    });
  }

  void _reload() => unawaited(_load());

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '我的收藏',
      child: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = (snapshot.data ?? const <Map<String, Object?>>[])
              .map(_favoriteEntryFromRow)
              .whereType<_ResolvedListEntry>()
              .toList(growable: false);
          if (entries.isEmpty) {
            return const EmptyState(message: '暂无收藏内容');
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ActionListCard(
                title: entry.title,
                subtitle: entry.subtitle,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => entry.page)),
                trailing: IconButton(
                  tooltip: '取消收藏',
                  onPressed: () async {
                    await LocalSqliteStore.instance.removeFavoriteItem(
                      entry.id,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    showToast(context, '已取消收藏');
                    _reload();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MyNotesPage extends StatefulWidget {
  const MyNotesPage({super.key});

  @override
  State<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <Map<String, Object?>>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted) {
      return;
    }
    if (!loggedIn) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _future = LocalSqliteStore.instance.userNoteRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '我的笔记',
      child: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = (snapshot.data ?? const <Map<String, Object?>>[])
              .map(_noteEntryFromRow)
              .whereType<_ResolvedListEntry>()
              .toList(growable: false);
          if (entries.isEmpty) {
            return const EmptyState(message: '暂无笔记内容');
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ActionListCard(
                title: entry.title,
                subtitle: entry.subtitle,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => entry.page)),
              );
            },
          );
        },
      ),
    );
  }
}

class _ResolvedListEntry {
  const _ResolvedListEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final String id;
  final String title;
  final String subtitle;
  final Widget page;
}

class _ResolvedSegment {
  const _ResolvedSegment({required this.topic, required this.segment});

  final KnowledgeTopic topic;
  final KnowledgeSegment segment;
}

class ActionListCard extends StatelessWidget {
  const ActionListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: softCardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.activeInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.activeMuted),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.activeSubtle,
                ),
          ],
        ),
      ),
    );
  }
}

_ResolvedListEntry? _favoriteEntryFromRow(Map<String, Object?> row) {
  final id = _rowString(row, 'id');
  final type = _rowString(row, 'favorite_type');
  final targetId = _rowString(row, 'target_id');
  final targetSubId = _rowString(row, 'target_sub_id');
  final title = _rowString(row, 'title');
  final summary = _rowString(row, 'summary');

  final segment = _resolveSegment(
    targetId: targetId,
    targetSubId: targetSubId,
    title: title,
  );
  if (segment != null) {
    return _ResolvedListEntry(
      id: id,
      title: segment.segment.content,
      subtitle: '${type.isEmpty ? '卡片' : type} · ${segment.topic.title}',
      page: KnowledgeCardDeckPage(
        topic: segment.topic,
        initialIndex: segment.segment.index,
      ),
    );
  }

  final topic = _resolveTopic(targetId.isEmpty ? title : targetId);
  if (topic != null) {
    return _ResolvedListEntry(
      id: id,
      title: topic.title,
      subtitle:
          '${type.isEmpty ? '专题' : type} · ${summary.isEmpty ? topic.summary : summary}',
      page: KnowledgeDetailPage(topic: topic),
    );
  }

  final question = _resolveQuestion(targetId.isEmpty ? title : targetId);
  if (question != null) {
    return _ResolvedListEntry(
      id: id,
      title: question.module,
      subtitle: '${type.isEmpty ? '题目' : type} · ${question.question}',
      page: PracticeReviewPage(title: '收藏题目', questions: [question]),
    );
  }

  return null;
}

_ResolvedListEntry? _noteEntryFromRow(Map<String, Object?> row) {
  final id = _rowString(row, 'id');
  final type = _rowString(row, 'note_type');
  final targetId = _rowString(row, 'target_id');
  final targetSubId = _rowString(row, 'target_sub_id');
  final title = _rowString(row, 'title');
  final content = _rowString(row, 'content');
  final updatedAt = _formatRowTime(_rowInt(row, 'update_time'));

  final segment = _resolveSegment(
    targetId: targetId,
    targetSubId: targetSubId,
    title: title,
  );
  if (segment != null) {
    return _ResolvedListEntry(
      id: id,
      title: segment.segment.content,
      subtitle: '$type · $updatedAt · $content',
      page: KnowledgeCardDeckPage(
        topic: segment.topic,
        initialIndex: segment.segment.index,
      ),
    );
  }

  final topic = _resolveTopic(targetId.isEmpty ? title : targetId);
  if (topic != null) {
    return _ResolvedListEntry(
      id: id,
      title: topic.title,
      subtitle: '$type · $updatedAt · $content',
      page: KnowledgeDetailPage(topic: topic),
    );
  }

  final question = _resolveQuestion(targetId.isEmpty ? title : targetId);
  if (question != null) {
    return _ResolvedListEntry(
      id: id,
      title: question.module,
      subtitle: '$type · $updatedAt · $content',
      page: PracticeReviewPage(title: '笔记题目', questions: [question]),
    );
  }

  return null;
}

KnowledgeTopic? _resolveTopic(String value) {
  final query = value.trim();
  if (query.isEmpty) {
    return null;
  }
  for (final topic in syncedKnowledgeTopics) {
    if (topic.id == query || topic.title == query) {
      return topic;
    }
  }
  for (final topic in syncedKnowledgeTopics) {
    if (topic.title.contains(query) || query.contains(topic.title)) {
      return topic;
    }
  }
  return null;
}

_ResolvedSegment? _resolveSegment({
  required String targetId,
  required String targetSubId,
  required String title,
}) {
  final topic = _resolveTopic(targetId);
  final topics = topic == null ? syncedKnowledgeTopics : [topic];
  final queries = [
    targetSubId.trim(),
    title.trim(),
    targetId.trim(),
  ].where((value) => value.isNotEmpty).toList(growable: false);

  for (final item in topics) {
    for (final segment in item.segments) {
      for (final query in queries) {
        if (segment.id == query ||
            segment.content == query ||
            segment.content.contains(query) ||
            segment.details.contains(query) ||
            query.contains(segment.content)) {
          return _ResolvedSegment(topic: item, segment: segment);
        }
      }
    }
  }
  return null;
}

PracticeQuestion? _resolveQuestion(String value) {
  final query = value.trim();
  if (query.isEmpty) {
    return null;
  }
  for (final question in practiceQuestions) {
    if (question.id == query || question.question == query) {
      return question;
    }
  }
  for (final question in practiceQuestions) {
    if (question.question.contains(query) ||
        query.contains(question.question)) {
      return question;
    }
  }
  return null;
}

String _rowString(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}

int _rowInt(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _formatRowTime(int value) {
  if (value <= 0) {
    return '最近';
  }
  return formatShortDateTime(DateTime.fromMillisecondsSinceEpoch(value));
}

Future<AptitudeCatalog>? _bundledAptitudeCatalogFuture;
AptitudeCatalog? _bundledAptitudeCatalog;

Future<AptitudeCatalog> loadBundledAptitudeCatalog() {
  final catalog = _bundledAptitudeCatalog;
  if (catalog != null) {
    return Future.value(catalog);
  }
  return _bundledAptitudeCatalogFuture ??= _readBundledAptitudeCatalog();
}

Future<AptitudeCatalog> _readBundledAptitudeCatalog() async {
  final tables = await LocalSqliteStore.instance.aptitudeCatalogTables();
  final catalog = AptitudeCatalog.fromSeedTables(tables);
  if (catalog.categories.isNotEmpty) {
    _bundledAptitudeCatalog = catalog;
  }
  return catalog;
}

void debugSetAptitudeCatalogForTesting(AptitudeCatalog catalog) {
  _bundledAptitudeCatalog = catalog;
  _bundledAptitudeCatalogFuture = Future.value(catalog);
}

List<Map<String, Object?>> _aptitudeSeedRows(
  Map<String, Object?> tables,
  String tableName,
) {
  final raw = tables[tableName];
  if (raw is! List) {
    return const <Map<String, Object?>>[];
  }
  return raw
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry('$key', value as Object?)))
      .toList(growable: false);
}

class AptitudeCatalog {
  const AptitudeCatalog({required this.categories, required this.questions});

  final List<AptitudeCategoryEntry> categories;
  final List<AptitudeQuestion> questions;

  factory AptitudeCatalog.fromSeedTables(Map<String, Object?> tables) {
    final categoryRows = _aptitudeSeedRows(tables, 'aptitude_category');
    final subcategoryRows = _aptitudeSeedRows(tables, 'aptitude_subcategory');
    final questionRows = _aptitudeSeedRows(tables, 'aptitude_question');

    final questions =
        questionRows.map(AptitudeQuestion.fromRow).toList(growable: false)
          ..sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
    final questionCountBySubcategory = <String, int>{};
    for (final question in questions) {
      questionCountBySubcategory.update(
        question.subcategoryId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final subcategoriesByCategory = <String, List<AptitudeSubcategoryEntry>>{};
    for (final row in subcategoryRows) {
      final entry = AptitudeSubcategoryEntry.fromRow(
        row,
        questionCount: questionCountBySubcategory[_rowString(row, 'id')] ?? 0,
      );
      subcategoriesByCategory
          .putIfAbsent(entry.categoryId, () => <AptitudeSubcategoryEntry>[])
          .add(entry);
    }
    for (final entries in subcategoriesByCategory.values) {
      entries.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final categories =
        categoryRows
            .map(
              (row) => AptitudeCategoryEntry.fromRow(
                row,
                subcategories:
                    subcategoriesByCategory[_rowString(row, 'id')] ??
                    const <AptitudeSubcategoryEntry>[],
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AptitudeCatalog(categories: categories, questions: questions);
  }

  List<AptitudeQuestion> questionsForSubcategory(String subcategoryId) {
    return questions
        .where((question) => question.subcategoryId == subcategoryId)
        .toList(growable: false);
  }
}

class AptitudeCategoryEntry {
  const AptitudeCategoryEntry({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.subcategories,
  });

  final String id;
  final String title;
  final int sortOrder;
  final List<AptitudeSubcategoryEntry> subcategories;

  factory AptitudeCategoryEntry.fromRow(
    Map<String, Object?> row, {
    required List<AptitudeSubcategoryEntry> subcategories,
  }) {
    return AptitudeCategoryEntry(
      id: _rowString(row, 'id'),
      title: _rowString(row, 'category_title'),
      sortOrder: _rowInt(row, 'sort_order'),
      subcategories: subcategories,
    );
  }

  int get questionCount => subcategories.fold(
    0,
    (sum, subcategory) => sum + subcategory.questionCount,
  );
}

String _aptitudeCategoryDisplayTitle(String title) {
  return title == '言语理解与表达' ? '言语理解' : title;
}

class AptitudeSubcategoryEntry {
  const AptitudeSubcategoryEntry({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.sortOrder,
    required this.questionCount,
  });

  final String id;
  final String categoryId;
  final String title;
  final int sortOrder;
  final int questionCount;

  factory AptitudeSubcategoryEntry.fromRow(
    Map<String, Object?> row, {
    required int questionCount,
  }) {
    return AptitudeSubcategoryEntry(
      id: _rowString(row, 'id'),
      categoryId: _rowString(row, 'category_id'),
      title: _rowString(row, 'subcategory_title'),
      sortOrder: _rowInt(row, 'sort_order'),
      questionCount: questionCount,
    );
  }
}

class AptitudeQuestion {
  const AptitudeQuestion({
    required this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.questionNumber,
    required this.questionText,
    required this.questionImage,
    required this.options,
    required this.answerKey,
    required this.explanation,
    required this.sourceName,
    required this.sourcePage,
  });

  final String id;
  final String categoryId;
  final String subcategoryId;
  final int questionNumber;
  final String questionText;
  final String questionImage;
  final List<AptitudeOption> options;
  final String answerKey;
  final String explanation;
  final String sourceName;
  final int sourcePage;

  factory AptitudeQuestion.fromRow(Map<String, Object?> row) {
    return AptitudeQuestion(
      id: _rowString(row, 'id'),
      categoryId: _rowString(row, 'category_id'),
      subcategoryId: _rowString(row, 'subcategory_id'),
      questionNumber: _rowInt(row, 'question_number'),
      questionText: _rowString(row, 'question_text'),
      questionImage: _rowString(row, 'question_image'),
      options: const ['A', 'B', 'C', 'D']
          .map(
            (label) => AptitudeOption(
              label: label,
              text: _rowString(row, 'option_${label.toLowerCase()}'),
              imagePath: _rowString(row, 'option_${label.toLowerCase()}_image'),
            ),
          )
          .toList(growable: false),
      answerKey: _rowString(row, 'answer_key'),
      explanation: _rowString(row, 'explanation'),
      sourceName: _rowString(row, 'source_name'),
      sourcePage: _rowInt(row, 'source_page'),
    );
  }
}

class AptitudeOption {
  const AptitudeOption({
    required this.label,
    required this.text,
    required this.imagePath,
  });

  final String label;
  final String text;
  final String imagePath;

  bool get hasImage => imagePath.isNotEmpty;

  String get displayText {
    if (text == label) {
      return '';
    }
    if (hasImage && text.startsWith('图片选项')) {
      return '';
    }
    return text;
  }
}

class AptitudeCategoryPage extends StatefulWidget {
  const AptitudeCategoryPage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<AptitudeCategoryPage> createState() => _AptitudeCategoryPageState();
}

class _AptitudeCategoryPageState extends State<AptitudeCategoryPage> {
  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '行测',
      child: AptitudeCategoryBrowser(
        initialCategoryId: widget.initialCategoryId,
      ),
    );
  }
}

class AptitudeTabPage extends StatelessWidget {
  const AptitudeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(title: '行测', child: AptitudeCategoryBrowser());
  }
}

class AptitudeCategoryBrowser extends StatefulWidget {
  const AptitudeCategoryBrowser({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<AptitudeCategoryBrowser> createState() =>
      _AptitudeCategoryBrowserState();
}

class _AptitudeCategoryBrowserState extends State<AptitudeCategoryBrowser> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AptitudeCatalog>(
      future: loadBundledAptitudeCatalog(),
      initialData: _bundledAptitudeCatalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data;
        if (catalog == null || catalog.categories.isEmpty) {
          return const EmptyState(message: '暂无行测类目');
        }
        final selectedCategory = _selectedCategory(catalog);
        return _AptitudeCategoryTopicLayout(
          catalog: catalog,
          selectedCategory: selectedCategory,
          onSelected: (id) => setState(() => _selectedCategoryId = id),
          onSubcategoryTap: (subcategory) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AptitudeQuestionDeckPage(
                title: subcategory.title,
                questions: catalog.questionsForSubcategory(subcategory.id),
              ),
            ),
          ),
        );
      },
    );
  }

  AptitudeCategoryEntry _selectedCategory(AptitudeCatalog catalog) {
    final selectedId = _selectedCategoryId;
    if (selectedId != null) {
      for (final category in catalog.categories) {
        if (category.id == selectedId) {
          return category;
        }
      }
    }
    for (final category in catalog.categories) {
      if (category.questionCount > 0) {
        _selectedCategoryId = category.id;
        return category;
      }
    }
    _selectedCategoryId = catalog.categories.first.id;
    return catalog.categories.first;
  }
}

class _AptitudeCategoryTopicLayout extends StatelessWidget {
  const _AptitudeCategoryTopicLayout({
    required this.catalog,
    required this.selectedCategory,
    required this.onSelected,
    required this.onSubcategoryTap,
  });

  final AptitudeCatalog catalog;
  final AptitudeCategoryEntry selectedCategory;
  final ValueChanged<String> onSelected;
  final ValueChanged<AptitudeSubcategoryEntry> onSubcategoryTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: _AptitudeCategoryRail(
            categories: catalog.categories,
            selectedId: selectedCategory.id,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('子类目'),
              const SizedBox(height: 10),
              if (selectedCategory.subcategories.isEmpty)
                const EmptyState(message: '这个类目还没有子类目')
              else
                for (final subcategory in selectedCategory.subcategories) ...[
                  _AptitudeSubcategoryCard(
                    subcategory: subcategory,
                    onTap: () => onSubcategoryTap(subcategory),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AptitudeCategoryRail extends StatelessWidget {
  const _AptitudeCategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AptitudeCategoryEntry> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _AptitudeCategoryRailItem(
            category: categories[i],
            selected: categories[i].id == selectedId,
            onTap: () => onSelected(categories[i].id),
          ),
          if (i != categories.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AptitudeCategoryRailItem extends StatelessWidget {
  const _AptitudeCategoryRailItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final AptitudeCategoryEntry category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 3,
              height: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : AppColors.activeInk,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AptitudeSubcategoryCard extends StatelessWidget {
  const _AptitudeSubcategoryCard({
    required this.subcategory,
    required this.onTap,
  });

  final AptitudeSubcategoryEntry subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = subcategory.questionCount == 0 ? 0.0 : 0.0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: softCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subcategory.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.activeInk,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.activeBorder,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '0/${subcategory.questionCount}',
                  style: TextStyle(
                    color: AppColors.activeInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.activeSubtle,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AptitudeQuestionDeckPage extends StatefulWidget {
  const AptitudeQuestionDeckPage({
    super.key,
    required this.title,
    required this.questions,
    this.memorizationMode = false,
  });

  final String title;
  final List<AptitudeQuestion> questions;
  final bool memorizationMode;

  @override
  State<AptitudeQuestionDeckPage> createState() =>
      _AptitudeQuestionDeckPageState();
}

class _AptitudeQuestionDeckPageState extends State<AptitudeQuestionDeckPage> {
  late final PageController _controller;
  final Map<String, String> _answers = {};
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return DetailScaffold(
        title: widget.title,
        child: const EmptyState(message: '这个类目的题目还没导入'),
      );
    }

    final progress = (_index + 1) / widget.questions.length;
    return DetailScaffold(
      title: widget.title,
      trailing: _buildQuestionMenu(widget.questions[_index]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.blueTint,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.questions.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                return _AptitudeQuestionContent(
                  question: question,
                  selected: _answers[question.id],
                  memorizationMode: widget.memorizationMode,
                  onSelect: (answer) {
                    playAnswerFeedback();
                    setState(() => _answers[question.id] = answer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuButton<String> _buildQuestionMenu(AptitudeQuestion question) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      icon: const Icon(Icons.more_horiz_rounded),
      color: AppColors.activeSurface,
      elevation: 5,
      shadowColor: const Color(0x22000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints.tightFor(width: 132),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (value) async {
        if (value == 'favorite') {
          await _saveQuestionFavorite(question);
          return;
        }
        if (value == 'note') {
          await _editQuestionNote(question);
          return;
        }
        if (value == 'feedback') {
          showToast(context, '已收到错题反馈');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'favorite',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.star_border_rounded,
            label: '收藏',
          ),
        ),
        PopupMenuItem(
          value: 'note',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.edit_note_rounded,
            label: '记笔记',
          ),
        ),
        PopupMenuItem(
          value: 'feedback',
          height: 38,
          padding: EdgeInsets.zero,
          child: CompactCardMenuItem(
            icon: Icons.report_gmailerrorred_rounded,
            label: '错题反馈',
          ),
        ),
      ],
    );
  }

  Future<void> _saveQuestionFavorite(AptitudeQuestion question) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn) {
      return;
    }
    try {
      await LocalSqliteStore.instance.saveFavoriteItem(
        favoriteType: '行测题目',
        targetId: question.id,
        title: '${widget.title} · 第 ${question.questionNumber} 题',
        summary: question.questionText,
      );
      if (mounted) {
        showToast(context, '已加入收藏');
      }
    } catch (error) {
      if (mounted && isLoginRequiredError(error)) {
        await openLoginPage(context);
      } else if (mounted) {
        showToast(context, '$error');
      }
    }
  }

  Future<void> _editQuestionNote(AptitudeQuestion question) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) {
      return;
    }
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('题目笔记'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '写下解题思路、易错点或公式'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await LocalSqliteStore.instance.saveUserNote(
                    noteType: '行测题目',
                    targetId: question.id,
                    title: '${widget.title} · 第 ${question.questionNumber} 题',
                    content: controller.text.trim(),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
                    showToast(context, '笔记已保存');
                  }
                } catch (error) {
                  if (dialogContext.mounted && isLoginRequiredError(error)) {
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      await openLoginPage(context);
                    }
                  } else if (mounted) {
                    showToast(context, '$error');
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }
}

class _AptitudeQuestionContent extends StatelessWidget {
  const _AptitudeQuestionContent({
    required this.question,
    required this.selected,
    required this.memorizationMode,
    required this.onSelect,
  });

  final AptitudeQuestion question;
  final String? selected;
  final bool memorizationMode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final reveal = memorizationMode || selected != null;
    final correct = selected == question.answerKey;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: softCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${question.questionNumber} 题',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  question.questionText,
                  style: TextStyle(
                    color: AppColors.activeInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.48,
                  ),
                ),
                if (question.questionImage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      question.questionImage,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final option in question.options) ...[
            _AptitudeOptionCard(
              option: option,
              selected: selected == option.label,
              correct: reveal && question.answerKey == option.label,
              wrong:
                  reveal &&
                  selected == option.label &&
                  selected != question.answerKey,
              onTap: reveal || memorizationMode
                  ? null
                  : () => onSelect(option.label),
            ),
            const SizedBox(height: 10),
          ],
          if (reveal) ...[
            const SizedBox(height: 8),
            LabelBlock(
              label: memorizationMode
                  ? '答案解析'
                  : correct
                  ? '回答正确'
                  : '解析',
              body: '正确答案：${question.answerKey}\n${question.explanation}',
            ),
            if (question.sourceName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '来源：${question.sourceName} · 第 ${question.sourcePage} 页',
                style: TextStyle(color: AppColors.activeMuted, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AptitudeOptionCard extends StatelessWidget {
  const _AptitudeOptionCard({
    required this.option,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final AptitudeOption option;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? AppColors.green
        : wrong
        ? AppColors.red
        : selected
        ? AppColors.blue
        : AppColors.activeBorderStrong;
    final labelColor = correct || wrong || selected
        ? Colors.white
        : AppColors.activeInk;
    final tint = correct
        ? AppColors.tintFor(AppColors.green)
        : wrong
        ? AppColors.tintFor(AppColors.red)
        : selected
        ? AppColors.blueTint
        : AppColors.activeSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected || correct || wrong ? tint : AppColors.activeSurface,
          border: Border.all(
            color: selected || correct || wrong
                ? color
                : AppColors.activeBorderStrong,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                option.label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.displayText.isNotEmpty)
                    Text(
                      option.displayText,
                      style: TextStyle(
                        color: AppColors.activeInk,
                        fontWeight: FontWeight.w700,
                        height: 1.42,
                      ),
                    ),
                  if (option.hasImage) ...[
                    if (option.displayText.isNotEmpty)
                      const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        option.imagePath,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyExamAttemptsPage extends StatefulWidget {
  const MyExamAttemptsPage({super.key});

  @override
  State<MyExamAttemptsPage> createState() => _MyExamAttemptsPageState();
}

class _MyExamAttemptsPageState extends State<MyExamAttemptsPage> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const <Map<String, Object?>>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!mounted) {
      return;
    }
    if (!loggedIn) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _future = LocalSqliteStore.instance.practiceAttemptRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '我的试题',
      child: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? const <Map<String, Object?>>[];
          final attempts = rows
              .map(aiAttemptFromRow)
              .whereType<AIExamAttempt>()
              .toList(growable: false);
          if (attempts.isEmpty) {
            return const EmptyState(message: '暂无考试记录');
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: attempts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              return TaskRowCard(
                icon: Icons.fact_check_rounded,
                color: AppColors.accent,
                tint: AppColors.accentTint,
                title: attempt.title,
                subtitle:
                    '${formatShortDateTime(attempt.createdAt)} · ${attempt.questions.length} 题',
                meta: '${attempt.correctCount}/${attempt.questions.length}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AIExamReviewPager(attempt: attempt),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LearningReportPage extends StatelessWidget {
  const LearningReportPage({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final total = totalSegmentCount();
    final learned = learnedTotalCount();
    final score = total == 0 ? 0 : ((learned / total) * 100).round();

    return DetailScaffold(
      title: '学习报告',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.isDarkActive
                  ? AppColors.activeSurfaceHigh
                  : AppColors.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('学习分', style: TextStyle(color: Color(0xFFC9D8CE))),
                const SizedBox(height: 8),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '已学 $learned / $total 篇，建议优先补齐薄弱点与待复习。',
                  style: const TextStyle(color: Color(0xFFE7EFE9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SummaryStrip(
            stats: [
              SummaryStat(value: '$learned', label: '已学'),
              SummaryStat(value: '${masteredSegmentCount()}', label: '掌握'),
              SummaryStat(value: '${weakSegmentCount()}', label: '待补齐'),
            ],
          ),
          const SizedBox(height: 22),
          const SectionTitle('模块能力'),
          const SizedBox(height: 10),
          Expanded(child: ModuleProgressList(onOpen: onOpen)),
        ],
      ),
    );
  }
}

class PracticeAttemptHistoryPage extends StatelessWidget {
  const PracticeAttemptHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailScaffold(
      title: '历史记录',
      child: EmptyState(message: '暂无演练记录'),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailScaffold(
      title: '联系我们',
      child: EmptyState(message: '暂无联系信息'),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailScaffold(
      title: '设置与数据管理',
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: SettingsPanel(),
      ),
    );
  }
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  AppSettings _settings = appSettingsController.settings;
  bool _checkingData = false;
  bool _resettingData = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await LocalSqliteStore.instance.appSettings();
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  Future<void> _updateSettings(AppSettings settings) async {
    await appSettingsController.update(settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = appSettingsController.settings);
  }

  Future<void> _chooseThemeMode() async {
    final selected = await _showChoiceSheet(
      title: '主题模式',
      selectedId: _settings.themeMode,
      choices: const [
        ChoiceOption(id: 'light', title: '明亮模式', subtitle: '始终使用浅色界面'),
        ChoiceOption(id: 'dark', title: '深色模式', subtitle: '跟随系统夜间环境更护眼'),
        ChoiceOption(id: 'system', title: '跟随系统', subtitle: '随设备外观自动切换'),
      ],
    );
    if (selected != null) {
      await _updateSettings(_settings.copyWith(themeMode: selected));
    }
  }

  Future<void> _chooseThemeColor() async {
    final selected = await _showChoiceSheet(
      title: '主题色彩',
      selectedId: _settings.themeColor,
      choices: const [
        ChoiceOption(
          id: 'system',
          title: '系统默认',
          subtitle: '使用上岸舱默认靛蓝色',
          color: AppColors.indigo,
        ),
        ChoiceOption(
          id: 'green',
          title: '青绿色',
          subtitle: '沉稳、学习感更强',
          color: AppColors.green,
        ),
        ChoiceOption(
          id: 'blue',
          title: '蓝色',
          subtitle: '更清爽的效率工具感',
          color: AppColors.blue,
        ),
        ChoiceOption(
          id: 'cyan',
          title: '湖蓝色',
          subtitle: '更清透的背诵氛围',
          color: AppColors.cyan,
        ),
        ChoiceOption(
          id: 'indigo',
          title: '靛蓝色',
          subtitle: '更专注的刷题感',
          color: AppColors.indigo,
        ),
        ChoiceOption(
          id: 'amber',
          title: '琥珀色',
          subtitle: '更温暖的提醒色',
          color: AppColors.amber,
        ),
        ChoiceOption(
          id: 'orange',
          title: '橙色',
          subtitle: '更有冲刺感',
          color: AppColors.orange,
        ),
        ChoiceOption(
          id: 'purple',
          title: '紫色',
          subtitle: '更轻盈的会员感',
          color: AppColors.purple,
        ),
        ChoiceOption(
          id: 'rose',
          title: '玫红色',
          subtitle: '更醒目的重点标记',
          color: AppColors.rose,
        ),
      ],
    );
    if (selected != null) {
      await _updateSettings(_settings.copyWith(themeColor: selected));
    }
  }

  Future<String?> _showChoiceSheet({
    required String title,
    required String selectedId,
    required List<ChoiceOption> choices,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Material(
              color: AppColors.activeSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.activeBorderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.activeInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: choices.length,
                        itemBuilder: (context, index) {
                          final choice = choices[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: SizedBox(
                              width: 32,
                              child: Icon(
                                choice.id == selectedId
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: choice.id == selectedId
                                    ? AppColors.accent
                                    : AppColors.activeSubtle,
                              ),
                            ),
                            title: Text(
                              choice.title,
                              style: TextStyle(
                                color: AppColors.activeInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              choice.subtitle,
                              style: TextStyle(color: AppColors.activeMuted),
                            ),
                            trailing: choice.color == null
                                ? null
                                : ColorDot(color: choice.color!),
                            onTap: () =>
                                Navigator.of(sheetContext).pop(choice.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleSound(bool value) async {
    await _updateSettings(_settings.copyWith(soundEnabled: value));
    if (value) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _toggleHaptic(bool value) async {
    await _updateSettings(_settings.copyWith(hapticEnabled: value));
    if (value) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> _checkDataUpdate() async {
    if (_checkingData) {
      return;
    }
    setState(() => _checkingData = true);
    try {
      final result = await LocalSqliteStore.instance.checkBundledDataUpdate();
      final tables = await LocalSqliteStore.instance.knowledgeCatalogTables();
      if (tables.isNotEmpty) {
        applyKnowledgeTables(tables);
      }
      await appSettingsController.load();
      if (!mounted) {
        return;
      }
      setState(() => _settings = appSettingsController.settings);
      showToast(
        context,
        '数据已是最新：${result.contentCount} 篇内容，${result.questionCount} 道题',
      );
    } finally {
      if (mounted) {
        setState(() => _checkingData = false);
      }
    }
  }

  Future<void> _resetLearningData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('恢复初始数据'),
          content: const Text('会清空学习记录、笔记、收藏、错题和演练记录，账号和昵称会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认恢复'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || _resettingData) {
      return;
    }
    setState(() => _resettingData = true);
    try {
      await LocalSqliteStore.instance.resetLearningData();
      final tables = await LocalSqliteStore.instance.knowledgeCatalogTables();
      if (tables.isNotEmpty) {
        applyKnowledgeTables(tables);
      } else {
        resetKnowledgeToFallback();
      }
      if (mounted) {
        showToast(context, '已恢复初始学习数据');
      }
    } finally {
      if (mounted) {
        setState(() => _resettingData = false);
      }
    }
  }

  void _showVersionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('软件版本'),
          content: const Text('当前版本：1.0.0+1\n已是最新版本。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: '设置',
          children: [
            SettingsActionRow(
              icon: Icons.light_mode_rounded,
              title: '主题模式：${_themeModeLabel(_settings.themeMode)}',
              onTap: _chooseThemeMode,
            ),
            SettingsActionRow(
              icon: Icons.palette_rounded,
              title: '主题色彩',
              subtitle: '当前：${_themeColorLabel(_settings.themeColor)}',
              onTap: _chooseThemeColor,
            ),
            SettingsSwitchRow(
              icon: Icons.volume_up_rounded,
              title: '音效',
              value: _settings.soundEnabled,
              onChanged: _toggleSound,
            ),
            SettingsSwitchRow(
              icon: Icons.vibration_rounded,
              title: '震动',
              value: _settings.hapticEnabled,
              onChanged: _toggleHaptic,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: '关于',
          children: [
            SettingsActionRow(
              icon: Icons.sync_rounded,
              title: '检查数据更新',
              subtitle: _checkingData
                  ? '正在检查本地内置题库'
                  : _lastDataCheckLabel(_settings.lastDataCheckTime),
              onTap: _checkingData ? null : _checkDataUpdate,
            ),
            SettingsActionRow(
              icon: Icons.restore_rounded,
              title: '恢复初始数据',
              subtitle: _resettingData ? '正在恢复' : null,
              onTap: _resettingData ? null : _resetLearningData,
            ),
            SettingsActionRow(
              icon: Icons.system_update_alt_rounded,
              title: '检查软件版本',
              onTap: _showVersionDialog,
            ),
          ],
        ),
      ],
    );
  }

  String _themeModeLabel(String value) {
    switch (value) {
      case 'dark':
        return '深色模式';
      case 'system':
        return '跟随系统';
      case 'light':
      default:
        return '明亮模式';
    }
  }

  String _themeColorLabel(String value) {
    switch (value) {
      case 'green':
        return '青绿色';
      case 'blue':
        return '蓝色';
      case 'cyan':
        return '湖蓝色';
      case 'indigo':
        return '靛蓝色';
      case 'amber':
        return '琥珀色';
      case 'orange':
        return '橙色';
      case 'purple':
        return '紫色';
      case 'rose':
        return '玫红色';
      case 'red':
        return '红色';
      case 'system':
      default:
        return '系统默认';
    }
  }

  String _lastDataCheckLabel(int time) {
    if (time <= 0) {
      return '手动检查数据更新';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(time);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '上次检查：$month-$day $hour:$minute';
  }
}

class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color? color;
}

class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.activeBorderStrong),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.activeInk,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: AppColors.activeBorder),
          ],
        ],
      ),
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            IconContainer(
              icon: icon,
              color: AppColors.accent,
              tint: AppColors.accentTint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.activeInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.activeMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.activeSubtle),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            IconContainer(
              icon: icon,
              color: AppColors.accent,
              tint: AppColors.accentTint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.activeInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.activeMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SettingsPillSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class SettingsPillSwitch extends StatelessWidget {
  const SettingsPillSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppColors.accentTint : AppColors.activeSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: value ? AppColors.accent : AppColors.activeBorderStrong,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.activeSubtle,
            shape: BoxShape.circle,
          ),
          child: value
              ? const Icon(Icons.circle, size: 7, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class ModuleProgressList extends StatelessWidget {
  const ModuleProgressList({super.key, required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in syncedKnowledgeCategories.take(5)) ...[
          Builder(
            builder: (context) {
              final topics = topicsForCategory(category.id);
              final segments = topics
                  .expand((topic) => topic.segments)
                  .toList();
              final learned = segments
                  .where(
                    (segment) => segment.status != SegmentStatus.notStarted,
                  )
                  .length;
              final progress = segments.isEmpty
                  ? 0.0
                  : learned / segments.length;
              return ModuleProgressCard(
                category: category,
                progress: progress,
                meta: '${topics.length} 专题 · $learned/${segments.length} 篇',
                onTap: topics.isEmpty
                    ? null
                    : () => onOpen(KnowledgeDetailPage(topic: topics.first)),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class StudyOverviewPanel extends StatelessWidget {
  const StudyOverviewPanel({
    super.key,
    required this.category,
    required this.topicCount,
    required this.segmentCount,
    required this.learnedCount,
    required this.questionCount,
  });

  final KnowledgeCategory category;
  final int topicCount;
  final int segmentCount;
  final int learnedCount;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final color = colorForKey(category.colorKey);
    final tint = tintForKey(category.colorKey);
    final progress = segmentCount == 0 ? 0.0 : learnedCount / segmentCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconContainer(icon: category.icon, color: color, tint: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: AppColors.activeInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.activeMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.activeBorder,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  value: '$topicCount',
                  label: '专题',
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniStat(
                  value: '$learnedCount/$segmentCount',
                  label: '进度',
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniStat(
                  value: '$questionCount',
                  label: '题目',
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.activeSurfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.activeMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class KnowledgeCategoryTabs extends StatelessWidget {
  const KnowledgeCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<KnowledgeCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            CategoryTab(
              category: categories[i],
              selected: categories[i].id == selectedId,
              onTap: () => onSelected(categories[i].id),
            ),
            if (i != categories.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class CategoryTab extends StatelessWidget {
  const CategoryTab({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final KnowledgeCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topics = topicsForCategory(category.id);
    final color = AppColors.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 92),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.activeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.activeBorderStrong,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.activeInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${topics.length} 专题',
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.82)
                    : AppColors.activeMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        Text(
          meta,
          style: TextStyle(
            color: AppColors.activeMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ActiveSearchBar extends StatelessWidget {
  const ActiveSearchBar({
    super.key,
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索：$query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.activeInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '清空搜索',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class StudySearchDropdown extends StatelessWidget {
  const StudySearchDropdown({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.activeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.activeBorderStrong),
              boxShadow: appSoftShadows(opacity: 0.45),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: '搜索专题、正文、关键词',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: '清空',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    );
                  },
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(44, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class CategoryIntro extends StatelessWidget {
  const CategoryIntro({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final category = syncedKnowledgeCategories.firstWhere(
      (item) => item.id == categoryId,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(),
      child: Row(
        children: [
          IconContainer(
            icon: category.icon,
            color: colorForKey(category.colorKey),
            tint: tintForKey(category.colorKey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.description,
                  style: TextStyle(color: AppColors.activeMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KnowledgeTopicCard extends StatelessWidget {
  const KnowledgeTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final KnowledgeTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final learned = learnedSegmentCount(topic);
    final progress = topic.segments.isEmpty
        ? 0.0
        : learned / topic.segments.length;
    final color = AppColors.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: softCardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.activeInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppColors.activeBorder,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$learned/${topic.segments.length}',
                        style: TextStyle(
                          color: AppColors.activeInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.activeSubtle,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KnowledgeSegmentSwipeCard extends StatelessWidget {
  const KnowledgeSegmentSwipeCard({
    super.key,
    required this.segment,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final KnowledgeSegment segment;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final questionCount = practiceQuestions
        .where((question) => question.segmentId == segment.id)
        .length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: softCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppChip(label: '卡片 ${index + 1}/$total', selected: true),
                const SizedBox(width: 8),
                AppChip(label: '$questionCount 题'),
                const Spacer(),
                const Icon(Icons.open_in_new_rounded, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              segment.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  knowledgeSegmentDisplayDetails(segment),
                  style: TextStyle(
                    color: AppColors.activeInk,
                    height: 1.62,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '点击查看详情',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeQuestionListTile extends StatelessWidget {
  const PracticeQuestionListTile({
    super.key,
    required this.question,
    required this.onTap,
  });

  final PracticeQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softCardDecoration(),
        child: Row(
          children: [
            IconContainer(
              icon: Icons.quiz_rounded,
              color: AppColors.accent,
              tint: AppColors.accentTint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${question.module} · 答案 ${question.answer}',
                    style: TextStyle(color: AppColors.activeMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class MainMissionCard extends StatelessWidget {
  const MainMissionCard({
    super.key,
    required this.title,
    required this.headline,
    required this.subtitle,
    required this.progress,
    required this.badge,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String headline;
  final String subtitle;
  final double progress;
  final String badge;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconContainer(
                icon: icon,
                color: AppColors.accent,
                tint: AppColors.accentTint,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.activeMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      headline,
                      style: TextStyle(
                        color: AppColors.activeInk,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              AppChip(label: badge),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.activeBorder,
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(color: AppColors.activeMuted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class PracticeModeCard extends StatelessWidget {
  const PracticeModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    this.color,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final Color? color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(),
      child: Row(
        children: [
          IconContainer(
            icon: icon,
            color: color ?? AppColors.accent,
            tint: tint ?? AppColors.accentTint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(color: AppColors.activeMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class ModuleProgressCard extends StatelessWidget {
  const ModuleProgressCard({
    super.key,
    required this.category,
    required this.progress,
    required this.meta,
    this.onTap,
  });

  final KnowledgeCategory category;
  final double progress;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorForKey(category.colorKey);
    final tint = tintForKey(category.colorKey);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softCardDecoration(),
        child: Row(
          children: [
            IconContainer(icon: category.icon, color: color, tint: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(meta, style: TextStyle(color: AppColors.activeMuted)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: AppColors.activeBorder,
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? AppColors.green
        : wrong
        ? AppColors.red
        : selected
        ? AppColors.accent
        : AppColors.activeBorderStrong;
    final labelColor = correct || wrong || selected
        ? Colors.white
        : AppColors.activeInk;
    final tint = correct
        ? AppColors.tintFor(AppColors.green)
        : wrong
        ? AppColors.tintFor(AppColors.red)
        : selected
        ? AppColors.accentTint
        : AppColors.activeSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected || correct || wrong ? tint : AppColors.activeSurface,
          border: Border.all(
            color: selected || correct || wrong
                ? color
                : AppColors.activeBorderStrong,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppColors.activeInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnswerNumberButton extends StatelessWidget {
  const AnswerNumberButton({
    super.key,
    required this.number,
    required this.selected,
    required this.answered,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected || answered
        ? AppColors.accent
        : AppColors.activeBorderStrong;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered ? AppColors.accentTint : AppColors.activeSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: selected || answered
                ? AppColors.accent
                : AppColors.activeInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ResultNumberButton extends StatelessWidget {
  const ResultNumberButton({
    super.key,
    required this.number,
    required this.correct,
    required this.onTap,
  });

  final int number;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.green : AppColors.red;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: correct
              ? AppColors.tintFor(AppColors.green)
              : AppColors.tintFor(AppColors.red),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Text(
          '$number',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.stats});

  final List<SummaryStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: softCardDecoration(),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(child: stats[i]),
            if (i != stats.length - 1)
              Container(width: 1, height: 42, color: AppColors.activeBorder),
          ],
        ],
      ),
    );
  }
}

class SummaryStat extends StatelessWidget {
  const SummaryStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.activeInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.activeMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class TaskRowCard extends StatelessWidget {
  const TaskRowCard({
    super.key,
    required this.color,
    required this.tint,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
  });

  final Color color;
  final Color tint;
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: softCardDecoration(),
        child: Row(
          children: [
            IconContainer(icon: icon, color: color, tint: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.activeMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              meta,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.activeSubtle),
          ],
        ),
      ),
    );
  }
}

class MiniEntryCard extends StatelessWidget {
  const MiniEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? AppColors.accent;
    final tint = accent == null
        ? AppColors.accentTint
        : AppColors.tintFor(effectiveAccent);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: softCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconContainer(icon: icon, color: effectiveAccent, tint: tint),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: AppColors.activeInk,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MaterialCard extends StatelessWidget {
  const MaterialCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: TextStyle(color: AppColors.activeMuted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class TwoColumnActions extends StatelessWidget {
  const TwoColumnActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions,
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: softCardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.activeInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent),
        filled: true,
        fillColor: AppColors.activeSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.activeBorderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.activeBorderStrong),
        ),
      ),
    );
  }
}

class HorizontalChips extends StatelessWidget {
  const HorizontalChips({
    super.key,
    required this.labels,
    required this.selectedId,
    this.onSelected,
  });

  final List<ChipData> labels;
  final String selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            GestureDetector(
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(labels[i].id),
              child: AppChip(
                label: labels[i].label,
                selected: labels[i].id == selectedId,
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class ChipData {
  const ChipData({required this.id, required this.label});

  final String id;
  final String label;
}

class LabelBlock extends StatelessWidget {
  const LabelBlock({super.key, required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.activeBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(height: 1.5, color: AppColors.activeInk)),
        ],
      ),
    );
  }
}

class BulletLine extends StatelessWidget {
  const BulletLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 9),
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    );
  }
}

class StatusButton extends StatelessWidget {
  const StatusButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = enabled
        ? selected
              ? color
              : AppColors.activeMuted
        : AppColors.activeSubtle;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: softCardDecoration(),
          child: Row(
            children: [
              IconContainer(
                icon: icon,
                color: AppColors.accent,
                tint: AppColors.accentTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.activeInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.activeSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class IconContainer extends StatelessWidget {
  const IconContainer({
    super.key,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: softCardDecoration(),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.activeMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.activeMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.selectedColor,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.accent;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color : AppColors.activeSurfaceHigh,
        border: Border.all(
          color: selected ? color : AppColors.activeBorderStrong,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.activeInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) {
      return chip;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.activeInk,
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.titleWidget,
    this.titleLeading,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final Widget? titleWidget;
  final Widget? titleLeading;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? AppColors.activeBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child:
                          titleWidget ??
                          Row(
                            children: [
                              if (titleLeading != null) ...[
                                titleLeading!,
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.activeInk,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.activeBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.activeInk,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: const CircleBorder(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.activeInk,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

String statusLabel(SegmentStatus status) {
  switch (status) {
    case SegmentStatus.notStarted:
      return '未学';
    case SegmentStatus.learned:
      return '待复习';
    case SegmentStatus.mastered:
      return '已掌握';
    case SegmentStatus.weak:
      return '薄弱';
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

bool isLoginRequiredError(Object? error) {
  return error is StateError && error.message == '请先登录' ||
      '$error'.contains('请先登录');
}

Future<bool> openLoginPage(BuildContext context) async {
  final result = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const PhoneLoginPage()));
  return result == true;
}

Future<bool> ensureLoggedIn(BuildContext context) async {
  final user = await LocalSqliteStore.instance.currentUser();
  if (!context.mounted) {
    return false;
  }
  if (user != null) {
    return true;
  }
  return openLoginPage(context);
}

Color colorForKey(String key) {
  switch (key) {
    case 'red':
      return AppColors.red;
    case 'amber':
      return AppColors.amber;
    case 'blue':
      return AppColors.blue;
    case 'purple':
      return AppColors.purple;
    case 'green':
    default:
      return AppColors.green;
  }
}

Color tintForKey(String key) {
  if (AppColors.isDarkActive) {
    return AppColors.tintFor(colorForKey(key));
  }
  switch (key) {
    case 'red':
      return AppColors.redTint;
    case 'amber':
      return AppColors.amberTint;
    case 'blue':
      return AppColors.blueTint;
    case 'purple':
      return AppColors.purpleTint;
    case 'green':
    default:
      return AppColors.greenTint;
  }
}

BoxDecoration cardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.activeSurface,
    border: Border.all(color: AppColors.activeBorderStrong),
    borderRadius: BorderRadius.circular(radius),
  );
}

BoxDecoration softCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.activeSurface,
    border: Border.all(color: AppColors.activeBorderStrong),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: appSoftShadows(),
  );
}

List<BoxShadow> appSoftShadows({double opacity = 1}) {
  if (AppColors.isDarkActive) {
    return [
      BoxShadow(
        color: const Color(0x66000000).withValues(alpha: 0.26 * opacity),
        offset: const Offset(0, 12),
        blurRadius: 24,
      ),
    ];
  }
  return [
    BoxShadow(
      color: const Color(0xFF162235).withValues(alpha: 0.08 * opacity),
      offset: const Offset(0, 12),
      blurRadius: 26,
    ),
  ];
}

abstract final class AppColors {
  static const homeBackground = Color(0xFFFFFFFF);
  static const background = homeBackground;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFFBFCFE);
  static const ink = Color(0xFF17212B);
  static const subtle = Color(0xFF8B95A3);
  static const muted = Color(0xFF6D7887);
  static const border = Color(0xFFEAF0F6);
  static const borderStrong = Color(0xFFDDE6EF);
  static const green = Color(0xFF0B7A75);
  static const greenTint = Color(0xFFE6F4F2);
  static const blue = Color(0xFF2F5CDA);
  static const blueTint = Color(0xFFEAF0FF);
  static const cyan = Color(0xFF0087A3);
  static const indigo = Color(0xFF4058D8);
  static const amber = Color(0xFFB46A0B);
  static const amberTint = Color(0xFFFFF2D8);
  static const orange = Color(0xFFE16A1A);
  static const red = Color(0xFFB64A43);
  static const redTint = Color(0xFFFFECE9);
  static const purple = Color(0xFF6755C8);
  static const purpleTint = Color(0xFFF0EEFF);
  static const rose = Color(0xFFC94872);

  static const darkBackground = Color(0xFF0D141D);
  static const darkSurface = Color(0xFF16212C);
  static const darkSurfaceHigh = Color(0xFF1C2A36);
  static const darkInk = Color(0xFFEAF1F7);
  static const darkMuted = Color(0xFFA8B4C0);
  static const darkSubtle = Color(0xFF7F8D99);
  static const darkBorder = Color(0xFF23313E);
  static const darkBorderStrong = Color(0xFF304252);

  static bool get isDarkActive {
    switch (appSettingsController.settings.themeMode) {
      case 'dark':
        return true;
      case 'system':
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      case 'light':
      default:
        return false;
    }
  }

  static Color get activeBackground =>
      isDarkActive ? darkBackground : background;
  static Color get activeSurface => isDarkActive ? darkSurface : surface;
  static Color get activeSurfaceHigh =>
      isDarkActive ? darkSurfaceHigh : surfaceHigh;
  static Color get activeInk => isDarkActive ? darkInk : ink;
  static Color get activeMuted => isDarkActive ? darkMuted : muted;
  static Color get activeSubtle => isDarkActive ? darkSubtle : subtle;
  static Color get activeBorder => isDarkActive ? darkBorder : border;
  static Color get activeBorderStrong =>
      isDarkActive ? darkBorderStrong : borderStrong;
  static Color get accent => appSettingsController.seedColor;
  static Color tintFor(Color color) => isDarkActive
      ? color.withValues(alpha: 0.18)
      : Color.lerp(Colors.white, color, 0.13)!;
  static Color get accentTint => tintFor(accent);
}
