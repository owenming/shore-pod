import 'dart:convert';

import 'package:flutter/services.dart';

class LocalSqliteStore {
  LocalSqliteStore._();

  static final LocalSqliteStore instance = LocalSqliteStore._();
  AppUser? _currentUser;
  String? _latestKnowledgeCardTopicId;
  AppSettings _settings = AppSettings.defaults();
  final List<Map<String, Object?>> _favoriteRows = [];
  final List<Map<String, Object?>> _noteRows = [];

  String status = 'Web 预览使用空数据层；移动端启动时使用 SQLite 本地库';

  Future<void> bootstrap() async {}

  Future<Map<String, List<Map<String, Object?>>>>
  knowledgeCatalogTables() async {
    return const {};
  }

  Future<Map<String, List<Map<String, Object?>>>>
  aptitudeCatalogTables() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/shore_pod_seed.json',
      );
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final tables = decoded['tables'] as Map<String, Object?>;
      return {
        'aptitude_category': _tableRows(tables['aptitude_category']),
        'aptitude_subcategory': _tableRows(tables['aptitude_subcategory']),
        'aptitude_question': _tableRows(tables['aptitude_question']),
      };
    } catch (_) {
      return const {};
    }
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

  Future<Map<String, String>> cardNotesForTopic(String topicId) async {
    final userId = _requireCurrentUserId();
    return {
      for (final row in _noteRows.where(
        (row) =>
            row['user_id'] == userId &&
            row['note_type'] == '卡片笔记' &&
            row['target_id'] == topicId,
      ))
        '${row['target_sub_id']}': '${row['content']}',
    };
  }

  Future<void> saveCardNote({
    required String topicId,
    required String segmentId,
    required String note,
  }) async {
    final userId = _requireCurrentUserId();
    _noteRows.removeWhere(
      (row) =>
          row['user_id'] == userId &&
          row['note_type'] == '卡片笔记' &&
          row['target_id'] == topicId &&
          row['target_sub_id'] == segmentId,
    );
    if (note.trim().isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _noteRows.add({
      'id': 'note-$userId-$topicId-$segmentId',
      'user_id': userId,
      'note_type': '卡片笔记',
      'target_id': topicId,
      'target_sub_id': segmentId,
      'title': segmentId,
      'content': note.trim(),
      'created_time': now,
      'update_time': now,
    });
  }

  Future<List<Map<String, Object?>>> favoriteItemRows() async {
    final userId = _requireCurrentUserId();
    return List.unmodifiable(
      _favoriteRows.where((row) => row['user_id'] == userId),
    );
  }

  Future<void> saveFavoriteItem({
    required String favoriteType,
    required String targetId,
    String? targetSubId,
    required String title,
    required String summary,
  }) async {
    final userId = _requireCurrentUserId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'favorite-$userId-$favoriteType-$targetId-${targetSubId ?? ''}';
    _favoriteRows.removeWhere((row) => row['id'] == id);
    _favoriteRows.insert(0, {
      'id': id,
      'user_id': userId,
      'favorite_type': favoriteType,
      'target_id': targetId,
      'target_sub_id': targetSubId,
      'title': title,
      'summary': summary,
      'created_time': now,
      'update_time': now,
    });
  }

  Future<void> removeFavoriteItem(String id) async {
    final userId = _requireCurrentUserId();
    _favoriteRows.removeWhere(
      (row) => row['id'] == id && row['user_id'] == userId,
    );
  }

  Future<void> saveUserNote({
    required String noteType,
    required String targetId,
    required String title,
    required String content,
  }) async {
    final userId = _requireCurrentUserId();
    final id = 'note-$userId-$noteType-$targetId';
    _noteRows.removeWhere((row) => row['id'] == id);
    if (content.trim().isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _noteRows.add({
      'id': id,
      'user_id': userId,
      'note_type': noteType,
      'target_id': targetId,
      'title': title,
      'content': content.trim(),
      'created_time': now,
      'update_time': now,
    });
  }

  Future<List<Map<String, Object?>>> userNoteRows() async {
    final userId = _requireCurrentUserId();
    return List.unmodifiable(
      _noteRows.where((row) => row['user_id'] == userId),
    );
  }

  Future<void> savePracticeAttemptRecord({
    required String id,
    required String title,
    required String modeType,
    required int totalCount,
    required int answeredCount,
    required int correctCount,
    required int wrongCount,
    required int durationSeconds,
    required String payloadJson,
  }) async {
    _requireCurrentUserId();
  }

  Future<List<Map<String, Object?>>> practiceAttemptRecords() async {
    _requireCurrentUserId();
    return const [];
  }

  Future<HomeDashboard> homeDashboard() async {
    return HomeDashboard.empty(status);
  }

  Future<List<Map<String, Object?>>> latestContent({String? kind}) async {
    return const [];
  }

  Future<AppUser?> currentUser() async {
    return _currentUser;
  }

  Future<AppUser> registerOrLoginWithPhoneCode({
    required String phone,
    required String code,
  }) async {
    if (!isValidMainlandPhone(phone)) {
      throw ArgumentError('请输入正确的手机号');
    }
    if (code != '888888') {
      throw ArgumentError('验证码不正确');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _currentUser = AppUser(
      id: 'user-$phone',
      phone: phone,
      nickname: _currentUser?.nickname ?? '星星勇士',
      createdTime: _currentUser?.createdTime ?? now,
      updateTime: now,
      lastLoginTime: now,
    );
    return _currentUser!;
  }

  Future<AppUser> updateNickname(String nickname) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('请先登录');
    }
    final trimmed = nickname.trim();
    if (trimmed.length < 2 || trimmed.length > 16) {
      throw ArgumentError('昵称需为 2-16 个字符');
    }
    _currentUser = user.copyWith(
      nickname: trimmed,
      updateTime: DateTime.now().millisecondsSinceEpoch,
    );
    return _currentUser!;
  }

  Future<AppSettings> appSettings() async {
    return _settings;
  }

  Future<AppSettings> saveAppSettings(AppSettings settings) async {
    _settings = settings;
    return _settings;
  }

  Future<DataUpdateResult> checkBundledDataUpdate() async {
    final checkedAt = DateTime.now().millisecondsSinceEpoch;
    _settings = _settings.copyWith(lastDataCheckTime: checkedAt);
    return DataUpdateResult(
      contentCount: 0,
      questionCount: 0,
      checkedAt: checkedAt,
    );
  }

  Future<void> resetLearningData() async {}

  Future<void> recordStudy({
    required String contentId,
    required String action,
    int? score,
    int durationMinutes = 0,
  }) async {}

  Future<String?> latestKnowledgeCardTopicId() async {
    return _latestKnowledgeCardTopicId;
  }

  Future<void> saveLatestKnowledgeCardTopic(String topicId) async {
    _latestKnowledgeCardTopicId = topicId.isEmpty ? null : topicId;
  }

  String _requireCurrentUserId() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('请先登录');
    }
    return user.id;
  }
}

bool isValidMainlandPhone(String phone) {
  return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.nickname,
    required this.createdTime,
    required this.updateTime,
    this.lastLoginTime,
  });

  final String id;
  final String phone;
  final String nickname;
  final int createdTime;
  final int updateTime;
  final int? lastLoginTime;

  AppUser copyWith({String? nickname, int? updateTime, int? lastLoginTime}) {
    return AppUser(
      id: id,
      phone: phone,
      nickname: nickname ?? this.nickname,
      createdTime: createdTime,
      updateTime: updateTime ?? this.updateTime,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.themeColor,
    required this.soundEnabled,
    required this.hapticEnabled,
    required this.lastDataCheckTime,
    required this.latestAptitudeCategoryId,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: 'light',
      themeColor: 'indigo',
      soundEnabled: true,
      hapticEnabled: true,
      lastDataCheckTime: 0,
      latestAptitudeCategoryId: '',
    );
  }

  final String themeMode;
  final String themeColor;
  final bool soundEnabled;
  final bool hapticEnabled;
  final int lastDataCheckTime;
  final String latestAptitudeCategoryId;

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    bool? soundEnabled,
    bool? hapticEnabled,
    int? lastDataCheckTime,
    String? latestAptitudeCategoryId,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      lastDataCheckTime: lastDataCheckTime ?? this.lastDataCheckTime,
      latestAptitudeCategoryId:
          latestAptitudeCategoryId ?? this.latestAptitudeCategoryId,
    );
  }
}

class DataUpdateResult {
  const DataUpdateResult({
    required this.contentCount,
    required this.questionCount,
    required this.checkedAt,
  });

  final int contentCount;
  final int questionCount;
  final int checkedAt;
}

class HomeDashboard {
  const HomeDashboard({
    required this.streakDays,
    required this.studiedMinutes,
    required this.completedTasks,
    required this.totalTasks,
    required this.missionTitle,
    required this.missionSubtitle,
    required this.missionTarget,
    required this.missionCompleted,
    required this.missionTotal,
    required this.remainingMinutes,
    required this.beatPercent,
    required this.tasks,
    required this.recommendations,
  });

  factory HomeDashboard.empty(String message) {
    return HomeDashboard(
      streakDays: 0,
      studiedMinutes: 0,
      completedTasks: 0,
      totalTasks: 0,
      missionTitle: '今日主任务',
      missionSubtitle: message,
      missionTarget: '',
      missionCompleted: 0,
      missionTotal: 0,
      remainingMinutes: 0,
      beatPercent: 0,
      tasks: const [],
      recommendations: const [],
    );
  }

  final int streakDays;
  final int studiedMinutes;
  final int completedTasks;
  final int totalTasks;
  final String missionTitle;
  final String missionSubtitle;
  final String missionTarget;
  final int missionCompleted;
  final int missionTotal;
  final int remainingMinutes;
  final int beatPercent;
  final List<HomeTask> tasks;
  final List<HomeRecommendation> recommendations;
}

class HomeTask {
  const HomeTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.iconKey,
    required this.colorKey,
    required this.target,
  });

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final String iconKey;
  final String colorKey;
  final String target;
}

class HomeRecommendation {
  const HomeRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.target,
  });

  final String id;
  final String title;
  final String subtitle;
  final String target;
}
