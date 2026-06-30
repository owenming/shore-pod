import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'agent_chinese_basic_seed.dart';
import 'agent_catalog.dart';

class LocalSqliteStore {
  LocalSqliteStore._();

  static final LocalSqliteStore instance = LocalSqliteStore._();
  static const _bundledSeedAsset = 'assets/data/shore_pod_seed.json';
  static const _localUserId = 'local';
  static const _currentUserSettingKey = 'current_user_id';

  Database? _database;
  Future<void>? _bootstrapFuture;
  String status = 'SQLite 尚未初始化';

  Future<void> bootstrap() async {
    if (_database != null) {
      return;
    }
    final runningBootstrap = _bootstrapFuture;
    if (runningBootstrap != null) {
      return runningBootstrap;
    }

    _bootstrapFuture = _open();
    return _bootstrapFuture;
  }

  Future<void> _open() async {
    try {
      final dbPath = path.join(await getDatabasesPath(), 'shore_pod.db');
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) => _ensureSchema(db),
        onOpen: (db) async {
          await _ensureSchema(db);
          await _removePrototypeSeeds(db);
          final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM content_items'),
          );
          status = 'SQLite 本地库已初始化：$count 条内容';
        },
      );
    } catch (error) {
      status = 'SQLite 初始化跳过：$error';
    } finally {
      _bootstrapFuture = null;
    }
  }

  Future<HomeDashboard> homeDashboard() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return HomeDashboard.empty(status);
    }

    final today = _dateKey(DateTime.now());
    final taskRows = await db.query(
      'daily_tasks',
      where: 'task_date = ?',
      whereArgs: [today],
      orderBy: 'sort_order ASC, id ASC',
    );
    final recommendationRows = await db.query(
      'home_recommendations',
      orderBy: 'sort_order ASC, id ASC',
      limit: 2,
    );
    final todayStudyRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(duration_minutes), 0) AS minutes
      FROM study_records
      WHERE created_at >= ? AND created_at < ?
      ''',
      [_startOfDay(DateTime.now()), _startOfNextDay(DateTime.now())],
    );
    final rankingRows = await db.query(
      'daily_rankings',
      where: 'rank_date = ?',
      whereArgs: [today],
      limit: 1,
    );
    final missionRow = taskRows.isEmpty ? null : taskRows.first;
    final missionTotal = _intValue(missionRow?['total_count'], fallback: 0);
    final missionCompleted = _intValue(
      missionRow?['completed_count'],
      fallback: 0,
    );
    final completedTasks = taskRows
        .where(
          (row) =>
              _intValue(row['total_count'], fallback: 0) > 0 &&
              _intValue(row['completed_count'], fallback: 0) >=
                  _intValue(row['total_count'], fallback: 0),
        )
        .length;

    return HomeDashboard(
      streakDays: await _streakDays(db, today),
      studiedMinutes: _intValue(todayStudyRows.first['minutes'], fallback: 0),
      completedTasks: completedTasks,
      totalTasks: taskRows.length,
      missionTitle: '今日主任务',
      missionSubtitle: _stringValue(missionRow?['title'], fallback: '暂无任务'),
      missionTarget: _stringValue(missionRow?['target'], fallback: ''),
      missionCompleted: missionCompleted,
      missionTotal: missionTotal,
      remainingMinutes: _intValue(
        missionRow?['estimated_minutes'],
        fallback: 0,
      ),
      beatPercent: rankingRows.isEmpty
          ? 0
          : _intValue(rankingRows.first['beat_percent'], fallback: 0),
      tasks: taskRows.map(HomeTask.fromRow).toList(growable: false),
      recommendations: recommendationRows
          .map(HomeRecommendation.fromRow)
          .toList(growable: false),
    );
  }

  Future<List<Map<String, Object?>>> latestContent({String? kind}) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const [];
    }

    return db.query(
      'content_items',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind],
      orderBy: 'created_at DESC',
      limit: 20,
    );
  }

  Future<Map<String, List<Map<String, Object?>>>>
  knowledgeCatalogTables() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const {};
    }

    return {
      'basic_knowledge_category': await db.query(
        'basic_knowledge_category',
        orderBy: 'created_time ASC, id ASC',
      ),
      'basic_knowledge_info': await db.query(
        'basic_knowledge_info',
        orderBy: 'created_time ASC, id ASC',
      ),
      'basic_knowledge_segment': await db.query(
        'basic_knowledge_segment',
        orderBy: 'basic_knowledge_id ASC, paragraph_index ASC, id ASC',
      ),
      'basic_knowledge_question': await db.query(
        'basic_knowledge_question',
        orderBy: 'basic_knowledge_id ASC, knowledge_segment_id ASC, id ASC',
      ),
    };
  }

  Future<Map<String, String>> cardNotesForTopic(String topicId) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const {};
    }
    final userId = await _requireCurrentUserId(db);

    final rows = await db.query(
      'user_basic_knowledge_info',
      columns: ['knowledge_segment_id', 'note'],
      where: 'user_id = ? AND basic_knowledge_id = ? AND note != ?',
      whereArgs: [userId, topicId, ''],
      orderBy: 'update_time DESC',
    );
    return {
      for (final row in rows)
        _stringValue(row['knowledge_segment_id'], fallback: ''): _stringValue(
          row['note'],
          fallback: '',
        ),
    }..remove('');
  }

  Future<void> saveCardNote({
    required String topicId,
    required String segmentId,
    required String note,
  }) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return;
    }
    final userId = await _requireCurrentUserId(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    final existingRows = await db.query(
      'user_basic_knowledge_info',
      columns: ['id'],
      where:
          'user_id = ? AND basic_knowledge_id = ? AND knowledge_segment_id = ?',
      whereArgs: [userId, topicId, segmentId],
      limit: 1,
    );

    if (existingRows.isEmpty) {
      if (note.isEmpty) {
        return;
      }
      await db.insert('user_basic_knowledge_info', {
        'id': _userKnowledgeInfoId(userId, topicId, segmentId),
        'user_id': userId,
        'basic_knowledge_id': topicId,
        'knowledge_segment_id': segmentId,
        'proficient_type': 1,
        'note': note,
        'wrong_count': 0,
        'review_count': 0,
        'last_review_time': null,
        'next_review_time': null,
        'created_time': now,
        'update_time': now,
      });
      return;
    }

    await db.update(
      'user_basic_knowledge_info',
      {'note': note, 'update_time': now},
      where: 'id = ?',
      whereArgs: [existingRows.first['id']],
    );
  }

  Future<List<Map<String, Object?>>> favoriteItemRows() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const [];
    }
    final userId = await _requireCurrentUserId(db);

    return db.query(
      'user_favorite_item',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'update_time DESC, created_time DESC',
    );
  }

  Future<void> saveFavoriteItem({
    required String favoriteType,
    required String targetId,
    String? targetSubId,
    required String title,
    required String summary,
  }) async {
    await bootstrap();
    final db = _database;
    if (db == null || targetId.isEmpty) {
      return;
    }
    final userId = await _requireCurrentUserId(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'favorite-$userId-$favoriteType-$targetId-${targetSubId ?? ''}';
    await db.insert('user_favorite_item', {
      'id': id,
      'user_id': userId,
      'favorite_type': favoriteType,
      'target_id': targetId,
      'target_sub_id': targetSubId,
      'title': title,
      'summary': summary,
      'created_time': now,
      'update_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavoriteItem(String id) async {
    await bootstrap();
    final db = _database;
    if (db == null || id.isEmpty) {
      return;
    }
    final userId = await _requireCurrentUserId(db);
    await db.delete(
      'user_favorite_item',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> saveUserNote({
    required String noteType,
    required String targetId,
    required String title,
    required String content,
  }) async {
    await bootstrap();
    final db = _database;
    if (db == null || targetId.isEmpty) {
      return;
    }
    final userId = await _requireCurrentUserId(db);

    final id = 'note-$userId-$noteType-$targetId';
    if (content.trim().isEmpty) {
      await db.delete(
        'user_note',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_note', {
      'id': id,
      'user_id': userId,
      'note_type': noteType,
      'target_id': targetId,
      'title': title,
      'content': content.trim(),
      'created_time': now,
      'update_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> userNoteRows() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const [];
    }
    final userId = await _requireCurrentUserId(db);

    final rows = <Map<String, Object?>>[];
    rows.addAll(
      await db.query(
        'user_note',
        columns: [
          'id',
          'note_type',
          'target_id',
          'title',
          'content',
          'created_time',
          'update_time',
        ],
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'update_time DESC, created_time DESC',
      ),
    );

    final cardRows = await db.query(
      'user_basic_knowledge_info',
      columns: [
        'id',
        'basic_knowledge_id',
        'knowledge_segment_id',
        'note',
        'created_time',
        'update_time',
      ],
      where: 'user_id = ? AND note != ?',
      whereArgs: [userId, ''],
      orderBy: 'update_time DESC, created_time DESC',
    );
    rows.addAll(
      cardRows.map(
        (row) => {
          'id': row['id'],
          'note_type': '卡片笔记',
          'target_id': row['basic_knowledge_id'],
          'target_sub_id': row['knowledge_segment_id'],
          'title': row['knowledge_segment_id'],
          'content': row['note'],
          'created_time': row['created_time'],
          'update_time': row['update_time'],
        },
      ),
    );

    rows.sort((a, b) {
      final left = _intValue(a['update_time'], fallback: 0);
      final right = _intValue(b['update_time'], fallback: 0);
      return right.compareTo(left);
    });
    return rows;
  }

  Future<void> recordStudy({
    required String contentId,
    required String action,
    int? score,
    int durationMinutes = 0,
  }) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return;
    }

    await db.insert('study_records', {
      'content_id': contentId,
      'action': action,
      'score': score,
      'duration_minutes': durationMinutes,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String?> latestKnowledgeCardTopicId() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return null;
    }

    final rows = await db.query(
      'study_records',
      columns: ['content_id'],
      where: 'action = ?',
      whereArgs: ['knowledge_card_view'],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final topicId = _stringValue(rows.first['content_id'], fallback: '');
    return topicId.isEmpty ? null : topicId;
  }

  Future<void> saveLatestKnowledgeCardTopic(String topicId) async {
    if (topicId.isEmpty) {
      return;
    }
    await recordStudy(contentId: topicId, action: 'knowledge_card_view');
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
    await bootstrap();
    final db = _database;
    if (db == null) {
      return;
    }
    final userId = await _requireCurrentUserId(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_practice_attempt', {
      'id': '$userId-$id',
      'user_id': userId,
      'title': title,
      'mode_type': modeType,
      'total_count': totalCount,
      'answered_count': answeredCount,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'duration_seconds': durationSeconds,
      'submitted': 1,
      'payload_json': payloadJson,
      'created_time': now,
      'update_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> practiceAttemptRecords() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const [];
    }
    final userId = await _requireCurrentUserId(db);

    return db.query(
      'user_practice_attempt',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_time DESC',
      limit: 50,
    );
  }

  Future<AppUser?> currentUser() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return null;
    }

    final userId = await _currentUserId(db);
    if (userId == null) {
      return null;
    }
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AppUser.fromRow(rows.first);
  }

  Future<AppUser> registerOrLoginWithPhoneCode({
    required String phone,
    required String code,
  }) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      throw StateError('SQLite 尚未初始化');
    }
    if (!isValidMainlandPhone(phone)) {
      throw ArgumentError('请输入正确的手机号');
    }
    if (code != '888888') {
      throw ArgumentError('验证码不正确');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final userId = _userIdForPhone(phone);
    final existingRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final nickname = existingRows.isEmpty
        ? _defaultCartoonNickname(phone)
        : _stringValue(existingRows.first['nickname'], fallback: '');
    final row = {
      'id': userId,
      'phone': phone,
      'nickname': nickname.isEmpty ? _defaultCartoonNickname(phone) : nickname,
      'created_time': existingRows.isEmpty
          ? now
          : _intValue(existingRows.first['created_time'], fallback: now),
      'update_time': now,
      'last_login_time': now,
    };
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_settings', {
      'setting_key': _currentUserSettingKey,
      'setting_value': userId,
      'update_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return AppUser.fromRow(row);
  }

  Future<AppUser> updateNickname(String nickname) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      throw StateError('SQLite 尚未初始化');
    }
    final trimmed = nickname.trim();
    if (trimmed.length < 2 || trimmed.length > 16) {
      throw ArgumentError('昵称需为 2-16 个字符');
    }

    final user = await currentUser();
    if (user == null) {
      throw StateError('请先登录');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'users',
      {'nickname': trimmed, 'update_time': now},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return user.copyWith(nickname: trimmed, updateTime: now);
  }

  Future<AppSettings> appSettings() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return AppSettings.defaults();
    }
    final rows = await db.query('app_settings');
    final values = {
      for (final row in rows)
        '${row['setting_key']}': '${row['setting_value']}',
    };
    return AppSettings.fromValues(values);
  }

  Future<AppSettings> saveAppSettings(AppSettings settings) async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return settings;
    }
    final batch = db.batch();
    for (final entry in settings.toValues().entries) {
      batch.insert('app_settings', {
        'setting_key': entry.key,
        'setting_value': entry.value,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return settings;
  }

  Future<DataUpdateResult> checkBundledDataUpdate() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return const DataUpdateResult(
        contentCount: 0,
        questionCount: 0,
        checkedAt: 0,
      );
    }
    await _seedAgentChineseCatalog(db);
    final checkedAt = DateTime.now().millisecondsSinceEpoch;
    await db.insert('app_settings', {
      'setting_key': 'last_data_check_time',
      'setting_value': '$checkedAt',
      'update_time': checkedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final contentCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM basic_knowledge_info'),
        ) ??
        0;
    final questionCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM basic_knowledge_question'),
        ) ??
        0;
    return DataUpdateResult(
      contentCount: contentCount,
      questionCount: questionCount,
      checkedAt: checkedAt,
    );
  }

  Future<void> resetLearningData() async {
    await bootstrap();
    final db = _database;
    if (db == null) {
      return;
    }
    await db.transaction((txn) async {
      await txn.delete('user_basic_knowledge_info');
      await txn.delete('user_wrong_question');
      await txn.delete('user_favorite_item');
      await txn.delete('user_note');
      await txn.delete('user_practice_attempt');
      await txn.delete('study_records');
      await txn.delete('daily_checkins');
      await txn.update('daily_tasks', {
        'completed_count': 0,
        'completed_at': null,
      });
    });
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        phone TEXT NOT NULL UNIQUE,
        nickname TEXT NOT NULL,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        last_login_time INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_id TEXT NOT NULL,
        action TEXT NOT NULL,
        score INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(content_id) REFERENCES content_items(id)
      )
    ''');
    await _ensureColumn(db, 'study_records', 'duration_minutes', 'INTEGER');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_checkins (
        checkin_date TEXT PRIMARY KEY,
        study_minutes INTEGER NOT NULL DEFAULT 0,
        completed_tasks INTEGER NOT NULL DEFAULT 0,
        total_tasks INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_tasks (
        id TEXT PRIMARY KEY,
        task_date TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL DEFAULT '',
        target TEXT NOT NULL,
        icon_key TEXT NOT NULL DEFAULT 'task',
        color_key TEXT NOT NULL DEFAULT 'green',
        completed_count INTEGER NOT NULL DEFAULT 0,
        total_count INTEGER NOT NULL DEFAULT 0,
        estimated_minutes INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_rankings (
        rank_date TEXT PRIMARY KEY,
        beat_percent INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_recommendations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        target TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await _ensureAgentChineseSchema(db);
    await _seedAgentChineseCatalog(db);
  }

  Future<void> _ensureAgentChineseSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS basic_knowledge_category (
        id TEXT PRIMARY KEY,
        category_title TEXT DEFAULT '30',
        category_status INTEGER NOT NULL DEFAULT 0,
        created_time TEXT DEFAULT CURRENT_TIMESTAMP,
        update_time TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS basic_knowledge_info (
        id TEXT PRIMARY KEY,
        knowledge_title TEXT DEFAULT '30',
        knowledge_category TEXT,
        knowledge_content TEXT,
        knowledge_status INTEGER NOT NULL DEFAULT 0,
        created_time TEXT DEFAULT CURRENT_TIMESTAMP,
        update_time TEXT DEFAULT CURRENT_TIMESTAMP,
        ai_slice_status INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS basic_knowledge_segment (
        id TEXT PRIMARY KEY,
        basic_knowledge_id TEXT NOT NULL,
        paragraph_index INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_time TEXT DEFAULT CURRENT_TIMESTAMP,
        update_time TEXT DEFAULT CURRENT_TIMESTAMP,
        deleted_time TEXT,
        content_details TEXT,
        FOREIGN KEY(basic_knowledge_id) REFERENCES basic_knowledge_info(id)
          ON DELETE CASCADE
      )
    ''');
    await _ensureColumn(db, 'basic_knowledge_segment', 'deleted_time', 'TEXT');
    await _ensureColumn(
      db,
      'basic_knowledge_segment',
      'content_details',
      'TEXT',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_basic_knowledge_info (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        basic_knowledge_id TEXT NOT NULL,
        knowledge_segment_id TEXT NOT NULL,
        proficient_type INTEGER NOT NULL DEFAULT 1,
        note TEXT NOT NULL DEFAULT '',
        wrong_count INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_review_time INTEGER,
        next_review_time INTEGER,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        FOREIGN KEY(basic_knowledge_id) REFERENCES basic_knowledge_info(id),
        FOREIGN KEY(knowledge_segment_id) REFERENCES basic_knowledge_segment(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS basic_knowledge_question (
        id TEXT PRIMARY KEY,
        basic_knowledge_id TEXT NOT NULL,
        knowledge_segment_id TEXT NOT NULL,
        question_type TEXT NOT NULL DEFAULT 'single_choice',
        question_text TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        answer_key TEXT NOT NULL,
        explanation TEXT NOT NULL DEFAULT '',
        difficulty INTEGER NOT NULL DEFAULT 2,
        question_status INTEGER NOT NULL DEFAULT 0,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        FOREIGN KEY(basic_knowledge_id) REFERENCES basic_knowledge_info(id),
        FOREIGN KEY(knowledge_segment_id) REFERENCES basic_knowledge_segment(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS basic_current_politics_info (
        id TEXT PRIMARY KEY,
        report_type TEXT NOT NULL,
        report_date TEXT NOT NULL,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        points TEXT NOT NULL,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_wrong_question (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        question_id TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        wrong_count INTEGER NOT NULL DEFAULT 1,
        note TEXT NOT NULL DEFAULT '',
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_favorite_item (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        favorite_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        target_sub_id TEXT,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_note (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        note_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_practice_attempt (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL,
        mode_type TEXT NOT NULL,
        total_count INTEGER NOT NULL,
        answered_count INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        submitted INTEGER NOT NULL DEFAULT 1,
        created_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )
    ''');
    await _ensureColumn(
      db,
      'user_wrong_question',
      'user_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'user_favorite_item',
      'user_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(db, 'user_note', 'user_id', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
      db,
      'user_practice_attempt',
      'user_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(db, 'user_practice_attempt', 'payload_json', 'TEXT');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_basic_knowledge_info_category ON basic_knowledge_info(knowledge_category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_basic_knowledge_segment_info ON basic_knowledge_segment(basic_knowledge_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_basic_knowledge_question_segment ON basic_knowledge_question(knowledge_segment_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_basic_knowledge_progress ON user_basic_knowledge_info(user_id, basic_knowledge_id, proficient_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_favorite_user ON user_favorite_item(user_id, update_time)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_note_user ON user_note(user_id, update_time)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_practice_attempt_user ON user_practice_attempt(user_id, created_time)',
    );
  }

  Future<void> _seedAgentChineseCatalog(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final seedTables = await _loadBundledSeedTables();
    final categoryRows = seedTables['basic_knowledge_category']!;
    final infoRows = seedTables['basic_knowledge_info']!;
    final segmentRows = seedTables['basic_knowledge_segment']!;
    final questionRows = seedTables['basic_knowledge_question']!;
    final currentPoliticsRows = seedTables['basic_current_politics_info']!;
    final batch = db.batch();

    for (final category in categoryRows) {
      batch.insert('basic_knowledge_category', {
        'id': category['id'],
        'category_title': category['category_title'],
        'category_status': category['category_status'] ?? 0,
        'created_time': category['created_time'],
        'update_time': category['update_time'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final info in infoRows) {
      batch.insert('basic_knowledge_info', {
        'id': info['id'],
        'knowledge_title': info['knowledge_title'],
        'knowledge_category': info['knowledge_category'],
        'knowledge_content': info['knowledge_content'],
        'knowledge_status': info['knowledge_status'] ?? 0,
        'created_time': info['created_time'],
        'update_time': info['update_time'],
        'ai_slice_status': info['ai_slice_status'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final segment in segmentRows) {
      batch.insert('basic_knowledge_segment', {
        'id': segment['id'],
        'basic_knowledge_id': segment['basic_knowledge_id'],
        'paragraph_index': segment['paragraph_index'],
        'content': segment['content'],
        'created_time': segment['created_time'],
        'update_time': segment['update_time'],
        'deleted_time': segment['deleted_time'],
        'content_details': segment['content_details'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final question in questionRows) {
      batch.insert('basic_knowledge_question', {
        'id': question['id'],
        'basic_knowledge_id': question['basic_knowledge_id'],
        'knowledge_segment_id': question['knowledge_segment_id'],
        'question_type': question['question_type'] ?? 'single_choice',
        'question_text': question['question_text'],
        'option_a': question['option_a'],
        'option_b': question['option_b'],
        'option_c': question['option_c'],
        'option_d': question['option_d'],
        'answer_key': question['answer_key'],
        'explanation': question['explanation'] ?? '',
        'difficulty': question['difficulty'] ?? 2,
        'question_status': question['question_status'] ?? 0,
        'created_time': question['created_time'] ?? now,
        'update_time': question['update_time'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final realInfoIdByTitle = <String, String>{
      for (final info in infoRows)
        if (info['knowledge_title'] != null && info['id'] != null)
          '${info['knowledge_title']}': '${info['id']}',
    };

    if (questionRows.isEmpty && segmentRows.isNotEmpty) {
      for (final question in practiceQuestions) {
        final topicTitle = knowledgeTopics
            .firstWhere(
              (topic) => topic.id == question.topicId,
              orElse: () => knowledgeTopics.first,
            )
            .title;
        batch.insert('basic_knowledge_question', {
          'id': question.id,
          'basic_knowledge_id':
              realInfoIdByTitle[topicTitle] ?? question.topicId,
          'knowledge_segment_id': question.segmentId,
          'question_type': 'single_choice',
          'question_text': question.question,
          'option_a': question.options[0],
          'option_b': question.options[1],
          'option_c': question.options[2],
          'option_d': question.options[3],
          'answer_key': question.answer,
          'explanation': question.explanation,
          'difficulty': question.difficulty,
          'question_status': 0,
          'created_time': now,
          'update_time': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    for (final row in currentPoliticsRows) {
      batch.insert('basic_current_politics_info', {
        'id': row['id'],
        'report_type': row['report_type'],
        'report_date': row['report_date'],
        'title': row['title'],
        'summary': row['summary'],
        'points': row['points'],
        'created_time': row['created_time'] ?? now,
        'update_time': row['update_time'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final favorite in favoriteSeeds) {
      batch.insert('user_favorite_item', {
        'id': 'favorite-${favorite.type}-${favorite.title}',
        'favorite_type': favorite.type,
        'target_id': favorite.title,
        'target_sub_id': null,
        'title': favorite.title,
        'summary': favorite.subtitle,
        'created_time': now,
        'update_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final note in noteSeeds) {
      batch.insert('user_note', {
        'id': 'note-${note.type}-${note.title}',
        'note_type': note.type,
        'target_id': note.title,
        'title': note.title,
        'content': note.content,
        'created_time': now,
        'update_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  Future<Map<String, List<Map<String, Object?>>>>
  _loadBundledSeedTables() async {
    try {
      final raw = await rootBundle.loadString(_bundledSeedAsset);
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final tables = decoded['tables'] as Map<String, Object?>;
      return {
        'basic_knowledge_category': _tableRows(
          tables['basic_knowledge_category'],
        ),
        'basic_knowledge_info': _tableRows(tables['basic_knowledge_info']),
        'basic_knowledge_segment': _tableRows(
          tables['basic_knowledge_segment'],
        ),
        'basic_knowledge_question': _tableRows(
          tables['basic_knowledge_question'],
        ),
        'basic_current_politics_info': _tableRows(
          tables['basic_current_politics_info'],
        ),
      };
    } catch (_) {
      return {
        'basic_knowledge_category': agentChineseBasicKnowledgeCategories,
        'basic_knowledge_info': agentChineseBasicKnowledgeInfos,
        'basic_knowledge_segment': const <Map<String, Object?>>[],
        'basic_knowledge_question': const <Map<String, Object?>>[],
        'basic_current_politics_info': const <Map<String, Object?>>[],
      };
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

  Future<void> _removePrototypeSeeds(Database db) async {
    if (await _tableExists(db, 'home_summary')) {
      await db.delete('home_summary');
    }
    if (await _tableExists(db, 'home_tasks')) {
      await db.delete(
        'home_tasks',
        where: 'id IN (?, ?)',
        whereArgs: ['recite_review', 'wrong_review'],
      );
    }
    await db.delete('home_recommendations', where: null);
    await db.delete('daily_tasks', where: null);
    await db.delete('daily_rankings', where: null);
    await db.delete('content_items', where: null);
    await db.delete(
      'user_favorite_item',
      where: 'id IN (?, ?, ?)',
      whereArgs: [
        'favorite-专题-中国古代史',
        'favorite-文章-宪法是国家的根本法',
        'favorite-时政-今日时政日报',
      ],
    );
    await db.delete(
      'user_note',
      where: 'id IN (?, ?)',
      whereArgs: ['note-卡片笔记-西周宗法制', 'note-错题笔记-扩张性财政政策'],
    );
    await db.delete(
      'user_practice_attempt',
      where: 'id = ?',
      whereArgs: ['attempt-today-brush'],
    );
    await db.delete(
      'basic_current_politics_info',
      where: 'id IN (?, ?, ?)',
      whereArgs: ['ca-daily-1', 'ca-monthly-1', 'ca-xiaohei-1'],
    );
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', table],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<int> _streakDays(Database db, String today) async {
    var streak = 0;
    var cursor = DateTime.parse(today);

    while (true) {
      final rows = await db.query(
        'daily_checkins',
        where: 'checkin_date = ? AND completed_at IS NOT NULL',
        whereArgs: [_dateKey(cursor)],
        limit: 1,
      );
      if (rows.isEmpty) {
        return streak;
      }
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  int _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  int _startOfNextDay(DateTime date) {
    return DateTime(date.year, date.month, date.day + 1).millisecondsSinceEpoch;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int _intValue(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value') ?? fallback;
  }

  String _stringValue(Object? value, {required String fallback}) {
    if (value == null) {
      return fallback;
    }
    final text = '$value';
    return text.isEmpty ? fallback : text;
  }

  Future<String?> _currentUserId(Database db) async {
    final settingRows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [_currentUserSettingKey],
      limit: 1,
    );
    if (settingRows.isNotEmpty) {
      final userId = _stringValue(
        settingRows.first['setting_value'],
        fallback: '',
      );
      if (userId.isNotEmpty) {
        return userId;
      }
    }
    final legacyRows = await db.query(
      'users',
      columns: ['id'],
      orderBy: 'last_login_time DESC, update_time DESC',
      limit: 1,
    );
    if (legacyRows.isEmpty) {
      return null;
    }
    final userId = _stringValue(legacyRows.first['id'], fallback: '');
    if (userId.isEmpty) {
      return null;
    }
    await db.insert('app_settings', {
      'setting_key': _currentUserSettingKey,
      'setting_value': userId,
      'update_time': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return userId;
  }

  Future<String> _requireCurrentUserId(Database db) async {
    final userId = await _currentUserId(db);
    if (userId == null || userId.isEmpty) {
      throw StateError('请先登录');
    }
    await _claimLegacyUserRows(db, userId);
    return userId;
  }

  Future<void> _claimLegacyUserRows(Database db, String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final table in [
      'user_favorite_item',
      'user_note',
      'user_practice_attempt',
      'user_wrong_question',
    ]) {
      await db.update(table, {
        'user_id': userId,
        'update_time': now,
      }, where: "user_id = ''");
    }
    await db.update(
      'user_basic_knowledge_info',
      {'user_id': userId, 'update_time': now},
      where: 'user_id = ?',
      whereArgs: [_localUserId],
    );
  }

  String _userKnowledgeInfoId(String userId, String topicId, String segmentId) {
    return 'user-basic-knowledge-$userId-$topicId-$segmentId';
  }

  String _userIdForPhone(String phone) {
    return 'user-$phone';
  }

  String _defaultCartoonNickname(String phone) {
    const names = [
      '星星勇士',
      '果冻队长',
      '闪电小侠',
      '云朵魔法师',
      '像素船长',
      '彩虹练习生',
      '月光冲刺员',
      '奶油探险家',
    ];
    final seed = phone.codeUnits.fold<int>(
      0,
      (previous, codeUnit) => previous + codeUnit,
    );
    return names[seed % names.length];
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

  factory AppUser.fromRow(Map<String, Object?> row) {
    return AppUser(
      id: '${row['id']}',
      phone: '${row['phone']}',
      nickname: '${row['nickname']}',
      createdTime: _rowIntValue(row['created_time']),
      updateTime: _rowIntValue(row['update_time']),
      lastLoginTime: row['last_login_time'] == null
          ? null
          : _rowIntValue(row['last_login_time']),
    );
  }

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
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: 'light',
      themeColor: 'indigo',
      soundEnabled: true,
      hapticEnabled: true,
      lastDataCheckTime: 0,
    );
  }

  factory AppSettings.fromValues(Map<String, String> values) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      themeMode: values['theme_mode'] ?? defaults.themeMode,
      themeColor: values['theme_color'] ?? defaults.themeColor,
      soundEnabled: (values['sound_enabled'] ?? '1') == '1',
      hapticEnabled: (values['haptic_enabled'] ?? '1') == '1',
      lastDataCheckTime:
          int.tryParse(values['last_data_check_time'] ?? '') ??
          defaults.lastDataCheckTime,
    );
  }

  final String themeMode;
  final String themeColor;
  final bool soundEnabled;
  final bool hapticEnabled;
  final int lastDataCheckTime;

  Map<String, String> toValues() {
    return {
      'theme_mode': themeMode,
      'theme_color': themeColor,
      'sound_enabled': soundEnabled ? '1' : '0',
      'haptic_enabled': hapticEnabled ? '1' : '0',
      'last_data_check_time': '$lastDataCheckTime',
    };
  }

  AppSettings copyWith({
    String? themeMode,
    String? themeColor,
    bool? soundEnabled,
    bool? hapticEnabled,
    int? lastDataCheckTime,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      lastDataCheckTime: lastDataCheckTime ?? this.lastDataCheckTime,
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

  factory HomeTask.fromRow(Map<String, Object?> row) {
    final estimatedMinutes = _rowIntValue(row['estimated_minutes']);
    final completedCount = _rowIntValue(row['completed_count']);
    final totalCount = _rowIntValue(row['total_count']);
    final fallbackMeta = totalCount == 0 ? '0' : '$completedCount/$totalCount';

    return HomeTask(
      id: '${row['id']}',
      title: '${row['title']}',
      subtitle: '${row['subtitle']}',
      meta: estimatedMinutes > 0 ? '$estimatedMinutes 分钟' : fallbackMeta,
      iconKey: '${row['icon_key']}',
      colorKey: '${row['color_key']}',
      target: '${row['target']}',
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final String iconKey;
  final String colorKey;
  final String target;
}

int _rowIntValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse('$value') ?? 0;
}

class HomeRecommendation {
  const HomeRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.target,
  });

  factory HomeRecommendation.fromRow(Map<String, Object?> row) {
    return HomeRecommendation(
      id: '${row['id']}',
      title: '${row['title']}',
      subtitle: '${row['subtitle']}',
      target: '${row['target']}',
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String target;
}
