import 'package:flutter/material.dart';

import 'agent_chinese_basic_seed.dart';
import 'bundled_seed_loader.dart';

enum SegmentStatus { notStarted, learned, mastered, weak }

class KnowledgeCategory {
  const KnowledgeCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.colorKey,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String colorKey;
}

class KnowledgeTopic {
  const KnowledgeTopic({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.segments,
    this.article = '',
  });

  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final List<KnowledgeSegment> segments;
  final String article;
}

class KnowledgeSegment {
  const KnowledgeSegment({
    required this.id,
    required this.topicId,
    required this.index,
    required this.content,
    required this.details,
    this.status = SegmentStatus.notStarted,
    this.note = '',
  });

  final String id;
  final String topicId;
  final int index;
  final String content;
  final String details;
  final SegmentStatus status;
  final String note;
}

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.topicId,
    required this.segmentId,
    required this.module,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.difficulty = 2,
  });

  final String id;
  final String topicId;
  final String segmentId;
  final String module;
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final int difficulty;
}

class CurrentAffairsItem {
  const CurrentAffairsItem({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.summary,
    required this.points,
    required this.questions,
  });

  final String id;
  final String type;
  final String date;
  final String title;
  final String summary;
  final List<String> points;
  final List<PracticeQuestion> questions;
}

class FavoriteSeed {
  const FavoriteSeed({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final String type;
  final String title;
  final String subtitle;
}

class NoteSeed {
  const NoteSeed({
    required this.type,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String type;
  final String title;
  final String content;
  final String updatedAt;
}

const knowledgeCategories = [
  KnowledgeCategory(
    id: 'history',
    title: '历史篇',
    description: '中国史、世界史与重大制度演变',
    icon: Icons.account_balance_rounded,
    colorKey: 'green',
  ),
  KnowledgeCategory(
    id: 'humanities',
    title: '人文篇',
    description: '文学、文化、思想与艺术常识',
    icon: Icons.menu_book_rounded,
    colorKey: 'amber',
  ),
  KnowledgeCategory(
    id: 'science',
    title: '自然科技篇',
    description: '物理、化学、生物、地理与科技',
    icon: Icons.science_rounded,
    colorKey: 'blue',
  ),
  KnowledgeCategory(
    id: 'law',
    title: '法律篇',
    description: '宪法、行政法、民法与常见法条',
    icon: Icons.gavel_rounded,
    colorKey: 'purple',
  ),
  KnowledgeCategory(
    id: 'economy',
    title: '经济篇',
    description: '宏观经济、市场机制与财政金融',
    icon: Icons.trending_up_rounded,
    colorKey: 'red',
  ),
  KnowledgeCategory(
    id: 'official',
    title: '公文篇',
    description: '公文格式、行文规则与机关实务',
    icon: Icons.description_rounded,
    colorKey: 'green',
  ),
  KnowledgeCategory(
    id: 'management',
    title: '管理篇',
    description: '管理职能、公共管理与组织协调',
    icon: Icons.groups_rounded,
    colorKey: 'amber',
  ),
  KnowledgeCategory(
    id: 'mao',
    title: '毛泽东思想',
    description: '革命道路、统一战线与群众路线',
    icon: Icons.flag_rounded,
    colorKey: 'red',
  ),
  KnowledgeCategory(
    id: 'marxism',
    title: '马克思主义',
    description: '哲学、政治经济学与科学社会主义',
    icon: Icons.psychology_alt_rounded,
    colorKey: 'purple',
  ),
  KnowledgeCategory(
    id: 'honor',
    title: '荣誉成就',
    description: '重要人物、奖项、科技与国家成就',
    icon: Icons.workspace_premium_rounded,
    colorKey: 'amber',
  ),
  KnowledgeCategory(
    id: 'province',
    title: '国情省情',
    description: '国家概况、区域发展与省情考点',
    icon: Icons.map_rounded,
    colorKey: 'blue',
  ),
  KnowledgeCategory(
    id: 'defense',
    title: '国防与军队',
    description: '国防常识、军队建设与安全观',
    icon: Icons.security_rounded,
    colorKey: 'green',
  ),
];

const knowledgeTopics = [
  KnowledgeTopic(
    id: 'ancient-history',
    categoryId: 'history',
    title: '中国古代史',
    summary: '夏商周到明清的制度、文化与社会演变。',
    segments: [
      KnowledgeSegment(
        id: 'ancient-history-0',
        topicId: 'ancient-history',
        index: 0,
        content: '夏商周时期，中国早期国家形态逐渐形成，礼乐制度和宗法观念对后世产生了深远影响。',
        details: '常考点包括分封制、宗法制、礼乐制度、井田制，以及周代政治秩序对传统社会结构的影响。',
        status: SegmentStatus.mastered,
        note: '宗法制核心是血缘与等级秩序。',
      ),
      KnowledgeSegment(
        id: 'ancient-history-1',
        topicId: 'ancient-history',
        index: 1,
        content: '秦汉时期完成大一统格局，郡县制、中央集权和统一文字度量衡成为重要制度基础。',
        details: '秦统一后推行郡县制、统一文字、货币、度量衡。汉代在继承秦制基础上发展出察举制等治理机制。',
        status: SegmentStatus.learned,
      ),
      KnowledgeSegment(
        id: 'ancient-history-2',
        topicId: 'ancient-history',
        index: 2,
        content: '隋唐时期制度完备、经济繁荣、文化开放，是中国古代社会的重要高峰。',
        details: '三省六部制、科举制、大运河、开放的中外交流，是隋唐常识题的高频线索。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'modern-history',
    categoryId: 'history',
    title: '中国近现代史',
    summary: '民族独立、人民解放与现代国家建设。',
    segments: [
      KnowledgeSegment(
        id: 'modern-history-0',
        topicId: 'modern-history',
        index: 0,
        content: '中国近代史一般从鸦片战争开始，核心主题是民族独立、人民解放和国家富强。',
        details: '晚清以来，洋务运动、戊戌变法、辛亥革命等探索体现了传统社会向近现代社会的转型。',
        status: SegmentStatus.weak,
      ),
      KnowledgeSegment(
        id: 'modern-history-1',
        topicId: 'modern-history',
        index: 1,
        content: '新中国成立后，社会主义制度建立和改革开放共同构成现代中国发展的关键线索。',
        details: '现代史学习要把事件放到国家建设、制度发展和改革开放的历史脉络中理解。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'china-modern-history',
    categoryId: 'history',
    title: '中国现代史',
    summary: '新中国成立、社会主义建设和改革开放以来的发展历程。',
    segments: [
      KnowledgeSegment(
        id: 'china-modern-history-0',
        topicId: 'china-modern-history',
        index: 0,
        content: '中国现代史重点关注新中国成立、社会主义制度建立以及改革开放以来的发展历程。',
        details: '常考线索包括新民主主义革命胜利、社会主义制度建立、改革开放、现代化建设和国家治理能力提升。',
      ),
      KnowledgeSegment(
        id: 'china-modern-history-1',
        topicId: 'china-modern-history',
        index: 1,
        content: '现代中国在政治建设、经济发展、科技进步、文化教育和社会治理等方面持续推进。',
        details: '理解中国现代史，有助于把握当代中国道路的历史逻辑和现实基础。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'world-history',
    categoryId: 'history',
    title: '世界历史',
    summary: '古代文明、工业革命、战争与全球化进程。',
    segments: [
      KnowledgeSegment(
        id: 'world-history-0',
        topicId: 'world-history',
        index: 0,
        content: '世界历史涵盖古代文明的产生、中世纪社会结构、近代资本主义兴起和现代国际格局演变。',
        details: '古埃及、古巴比伦、古印度、古希腊罗马等文明各具特色，是常识题的基础材料。',
      ),
      KnowledgeSegment(
        id: 'world-history-1',
        topicId: 'world-history',
        index: 1,
        content: '工业革命、殖民扩张、两次世界大战和全球化进程，是理解现代世界的重要线索。',
        details: '这类题常考重大事件影响、国际组织、科技革命和世界格局变化。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'literature',
    categoryId: 'humanities',
    title: '古代文学',
    summary: '先秦散文、汉赋、唐诗、宋词、元曲与明清小说。',
    segments: [
      KnowledgeSegment(
        id: 'literature-0',
        topicId: 'literature',
        index: 0,
        content: '唐诗、宋词、元曲、明清小说共同构成中国古代文学的重要脉络。',
        details: '文学题常考代表人物、作品、体裁和时代风格，例如李杜诗歌、苏辛词风、四大名著等。',
        status: SegmentStatus.learned,
      ),
      KnowledgeSegment(
        id: 'literature-1',
        topicId: 'literature',
        index: 1,
        content: '先秦诸子散文兼具思想性与文学性，是理解中国传统思想的重要入口。',
        details: '儒、道、墨、法等学派的代表人物和核心主张，常与历史、政治常识交叉命题。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'modern-literature',
    categoryId: 'humanities',
    title: '现代文学',
    summary: '鲁迅、茅盾、巴金、老舍、曹禺等代表作家与现实主题。',
    segments: [
      KnowledgeSegment(
        id: 'modern-literature-0',
        topicId: 'modern-literature',
        index: 0,
        content: '现代文学是在社会转型和思想启蒙背景下形成的文学形态，强调人的觉醒、社会批判和语言革新。',
        details: '现代文学作品常与民族命运、社会现实和个体精神密切相关。',
        status: SegmentStatus.learned,
      ),
      KnowledgeSegment(
        id: 'modern-literature-1',
        topicId: 'modern-literature',
        index: 1,
        content: '鲁迅、郭沫若、茅盾、巴金、老舍、曹禺等作家具有重要地位。',
        details: '常考作家作品配对、文学流派、作品主题和时代背景。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'ancient-culture',
    categoryId: 'humanities',
    title: '古代文化',
    summary: '礼制、历法、教育、科举、宗法、节日和传统艺术。',
    segments: [
      KnowledgeSegment(
        id: 'ancient-culture-0',
        topicId: 'ancient-culture',
        index: 0,
        content: '古代文化涵盖礼制、历法、教育、科举、宗法、节日、艺术、科技等内容。',
        details: '儒家思想长期影响中国传统社会的伦理秩序和政治理念。',
      ),
      KnowledgeSegment(
        id: 'ancient-culture-1',
        topicId: 'ancient-culture',
        index: 1,
        content: '理解古代文化，需要关注制度、观念和日常生活之间的联系。',
        details: '常考内容包括传统节日、天干地支、科举制度、礼仪称谓和书画音乐常识。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'modern-culture',
    categoryId: 'humanities',
    title: '现代文化',
    summary: '文化自信、公共文化服务、文化产业和文明交流。',
    segments: [
      KnowledgeSegment(
        id: 'modern-culture-0',
        topicId: 'modern-culture',
        index: 0,
        content: '现代文化体现了传统文化与现代社会的融合发展，涉及教育、传媒、艺术、公共文化服务和文化产业等方面。',
        details: '文化自信、文化创新和文明交流是现代文化建设的重要主题。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'physics',
    categoryId: 'science',
    title: '物理知识',
    summary: '力学、热学、电磁学、光学和生活现象判断。',
    segments: [
      KnowledgeSegment(
        id: 'physics-0',
        topicId: 'physics',
        index: 0,
        content: '力是改变物体运动状态的重要原因，推、拉、摩擦都属于常见力的表现。',
        details: '常识题通常要求判断生活现象背后的力学原理，例如惯性、摩擦力、压强和浮力。',
      ),
      KnowledgeSegment(
        id: 'physics-1',
        topicId: 'physics',
        index: 1,
        content: '光的反射、折射和色散是光学常识中的高频考点。',
        details: '镜面成像、筷子在水中看似弯折、彩虹形成等，都可用基础光学原理解释。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'geography',
    categoryId: 'science',
    title: '地理知识',
    summary: '自然地理、人文地理、地图判读与区域发展。',
    segments: [
      KnowledgeSegment(
        id: 'geography-0',
        topicId: 'geography',
        index: 0,
        content: '地理知识包括自然地理和人文地理两大方面。',
        details: '自然地理关注地形、气候、水文、土壤和生态环境，人文地理关注人口、城市、产业和区域发展。',
      ),
      KnowledgeSegment(
        id: 'geography-1',
        topicId: 'geography',
        index: 1,
        content: '地图判读、区域特征和人与环境关系是常见考点。',
        details: '常见题型会结合经纬度、气候类型、地形区、产业布局和生态保护进行判断。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'chemistry',
    categoryId: 'science',
    title: '化学知识',
    summary: '元素、酸碱盐、氧化还原与生活化学。',
    segments: [
      KnowledgeSegment(
        id: 'chemistry-0',
        topicId: 'chemistry',
        index: 0,
        content: '化学知识研究物质的组成、结构、性质及其变化规律。',
        details: '常见内容包括元素周期律、酸碱盐、氧化还原反应和常见材料。',
      ),
      KnowledgeSegment(
        id: 'chemistry-1',
        topicId: 'chemistry',
        index: 1,
        content: '生活中的燃烧、腐蚀、清洁、食品安全等现象都与化学知识有关。',
        details: '公基常识题常把化学概念放进生活场景中考查。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'biology',
    categoryId: 'science',
    title: '生物知识',
    summary: '细胞、遗传、进化、生态系统和人体健康。',
    segments: [
      KnowledgeSegment(
        id: 'biology-0',
        topicId: 'biology',
        index: 0,
        content: '生物知识研究生命现象和生命活动规律。',
        details: '细胞、遗传、进化、生态系统、人体健康和生物技术是基础内容。',
      ),
      KnowledgeSegment(
        id: 'biology-1',
        topicId: 'biology',
        index: 1,
        content: '学习生物常识要关注生命结构、功能适应以及人与自然的关系。',
        details: '生态平衡、疾病预防、遗传变异和现代生物技术是常见题材。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'life-common-sense',
    categoryId: 'science',
    title: '生活常识',
    summary: '安全、健康、饮食、交通、应急和环保。',
    segments: [
      KnowledgeSegment(
        id: 'life-common-sense-0',
        topicId: 'life-common-sense',
        index: 0,
        content: '生活常识涉及安全、健康、饮食、交通、应急、环保等日常知识。',
        details: '常见考点包括急救处理、食品保存、用电安全、消防知识和自然灾害避险。',
      ),
      KnowledgeSegment(
        id: 'life-common-sense-1',
        topicId: 'life-common-sense',
        index: 1,
        content: '发生火灾时应优先保证人身安全，及时撤离并拨打报警电话，不要贪恋财物。',
        details: '应急题通常考查处置顺序和安全优先原则。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'technology',
    categoryId: 'science',
    title: '科技知识',
    summary: '人工智能、航天、新能源、新材料和信息通信。',
    segments: [
      KnowledgeSegment(
        id: 'technology-0',
        topicId: 'technology',
        index: 0,
        content: '科技知识关注现代科学技术的发展与应用。',
        details: '人工智能、航天技术、信息通信、新能源、新材料和生物技术是当前重要方向。',
      ),
      KnowledgeSegment(
        id: 'technology-1',
        topicId: 'technology',
        index: 1,
        content: '学习科技常识要把握基本原理、代表成果和社会影响。',
        details: '常考我国重大科技工程、科学家、技术应用和基础原理。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'law-basics',
    categoryId: 'law',
    title: '宪法基础',
    summary: '国家制度、公民基本权利与国家机构。',
    segments: [
      KnowledgeSegment(
        id: 'law-basics-0',
        topicId: 'law-basics',
        index: 0,
        content: '宪法是国家的根本法，具有最高法律效力。',
        details: '宪法规定国家根本制度、根本任务、公民基本权利义务和国家机构组织原则。',
      ),
      KnowledgeSegment(
        id: 'law-basics-1',
        topicId: 'law-basics',
        index: 1,
        content: '公民基本权利包括平等权、政治权利、人身自由、社会经济权利等。',
        details: '常见考法是区分不同权利类别，并判断国家机关行为是否符合宪法原则。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'macro-economy',
    categoryId: 'economy',
    title: '宏观经济常识',
    summary: '财政政策、货币政策、通胀就业与市场调节。',
    segments: [
      KnowledgeSegment(
        id: 'macro-economy-0',
        topicId: 'macro-economy',
        index: 0,
        content: '财政政策主要通过政府支出、税收和国债等手段影响经济运行。',
        details: '扩张性财政政策通常表现为增加支出、减少税收；紧缩性财政政策则相反。',
      ),
      KnowledgeSegment(
        id: 'macro-economy-1',
        topicId: 'macro-economy',
        index: 1,
        content: '货币政策通过利率、存款准备金率和公开市场操作影响货币供应量。',
        details: '中央银行是货币政策主要实施主体，常见目标包括稳定币值、促进就业和经济增长。',
      ),
    ],
  ),
  KnowledgeTopic(
    id: 'official-doc',
    categoryId: 'official',
    title: '公文写作基础',
    summary: '文种、格式、行文关系和机关表达。',
    segments: [
      KnowledgeSegment(
        id: 'official-doc-0',
        topicId: 'official-doc',
        index: 0,
        content: '公文具有法定作者、法定效力和规范体式。',
        details: '常见文种包括通知、通报、请示、报告、函、纪要等，行文方向和适用场景不同。',
      ),
      KnowledgeSegment(
        id: 'official-doc-1',
        topicId: 'official-doc',
        index: 1,
        content: '请示应当一文一事，通常需要上级机关批复。',
        details: '请示和报告经常混淆：请示用于请求指示批准，报告主要用于汇报工作、反映情况。',
      ),
    ],
  ),
];

final _fallbackPracticeQuestions = [
  PracticeQuestion(
    id: 'q-ancient-0',
    topicId: 'ancient-history',
    segmentId: 'ancient-history-0',
    module: '历史篇',
    question: '下列关于西周宗法制的说法，正确的是：',
    options: ['以军功爵位为核心', '以血缘关系维系统治秩序', '主要用于选拔官吏', '直接废除了分封制'],
    answer: 'B',
    explanation: '宗法制以血缘关系为纽带，配合分封制维护等级秩序。',
  ),
  PracticeQuestion(
    id: 'q-ancient-1',
    topicId: 'ancient-history',
    segmentId: 'ancient-history-1',
    module: '历史篇',
    question: '秦统一后在地方行政上主要推行：',
    options: ['分封制', '郡县制', '行省制', '三省六部制'],
    answer: 'B',
    explanation: '秦朝在全国推行郡县制，加强中央集权。',
  ),
  PracticeQuestion(
    id: 'q-literature-0',
    topicId: 'literature',
    segmentId: 'literature-0',
    module: '人文篇',
    question: '“唐诗、宋词、元曲”主要体现的是：',
    options: ['不同朝代的代表性文学体裁', '古代选官制度', '古代天文历法', '传统礼仪制度'],
    answer: 'A',
    explanation: '唐诗、宋词、元曲分别是相应时代最具代表性的文学形式之一。',
  ),
  PracticeQuestion(
    id: 'q-physics-0',
    topicId: 'physics',
    segmentId: 'physics-0',
    module: '自然科技篇',
    question: '公交车突然刹车时，人会向前倾，这主要体现了：',
    options: ['惯性', '浮力', '热胀冷缩', '光的折射'],
    answer: 'A',
    explanation: '人保持原有运动状态的趋势体现了惯性。',
  ),
  PracticeQuestion(
    id: 'q-law-0',
    topicId: 'law-basics',
    segmentId: 'law-basics-0',
    module: '法律篇',
    question: '在我国法律体系中，具有最高法律效力的是：',
    options: ['刑法', '民法典', '宪法', '行政法规'],
    answer: 'C',
    explanation: '宪法是国家根本法，具有最高法律效力。',
  ),
  PracticeQuestion(
    id: 'q-economy-0',
    topicId: 'macro-economy',
    segmentId: 'macro-economy-0',
    module: '经济篇',
    question: '下列属于扩张性财政政策的是：',
    options: ['提高税率', '减少政府投资', '增加公共支出', '提高存款准备金率'],
    answer: 'C',
    explanation: '增加公共支出通常属于扩张性财政政策。',
  ),
  PracticeQuestion(
    id: 'q-official-0',
    topicId: 'official-doc',
    segmentId: 'official-doc-1',
    module: '公文篇',
    question: '关于请示的说法，正确的是：',
    options: ['可以一文多事', '一般不需要上级答复', '适用于向上级请求指示批准', '只能平行机关之间使用'],
    answer: 'C',
    explanation: '请示用于向上级机关请求指示、批准，应当一文一事。',
  ),
];

List<PracticeQuestion> practiceQuestions = _fallbackPracticeQuestions;

const currentAffairsItems = <CurrentAffairsItem>[];

const favoriteSeeds = <FavoriteSeed>[];

const noteSeeds = <NoteSeed>[];

List<KnowledgeCategory> syncedKnowledgeCategories =
    _buildSyncedKnowledgeCategories();
List<KnowledgeTopic> syncedKnowledgeTopics = _buildSyncedKnowledgeTopics();

Future<void> loadBundledKnowledgeSeed() async {
  try {
    applyKnowledgeTables(
      await loadBundledSeedTables(
        tableNames: const [
          'basic_knowledge_category',
          'basic_knowledge_info',
          'basic_knowledge_segment',
          'basic_knowledge_question',
        ],
      ),
    );
  } catch (_) {
    resetKnowledgeToFallback();
  }
}

void applyKnowledgeTables(Map<String, List<Map<String, Object?>>> tables) {
  final categories = tables['basic_knowledge_category'] ?? const [];
  final infos = tables['basic_knowledge_info'] ?? const [];
  final segments = tables['basic_knowledge_segment'] ?? const [];
  final questions = tables['basic_knowledge_question'] ?? const [];
  if (categories.isEmpty || infos.isEmpty) {
    resetKnowledgeToFallback();
    return;
  }

  final categoryTitleById = <String, String>{
    for (final row in categories)
      _string(row['id']): _string(row['category_title'], fallback: '未命名分类'),
  };
  final segmentsByTopic = <String, List<KnowledgeSegment>>{};
  for (final row in segments) {
    final topicId = _string(row['basic_knowledge_id']);
    if (topicId.isEmpty) {
      continue;
    }
    segmentsByTopic
        .putIfAbsent(topicId, () => [])
        .add(
          KnowledgeSegment(
            id: _string(row['id']),
            topicId: topicId,
            index: _int(row['paragraph_index']),
            content: _string(row['content'], fallback: '未命名卡片'),
            details: _string(row['content_details'], fallback: '暂无详情'),
          ),
        );
  }
  for (final rows in segmentsByTopic.values) {
    rows.sort((a, b) => a.index.compareTo(b.index));
  }

  syncedKnowledgeCategories = categories
      .map((row) {
        final title = _string(row['category_title'], fallback: '未命名分类');
        final visual = _categoryVisual(title);
        return KnowledgeCategory(
          id: _string(row['id']),
          title: title,
          description: _categoryDescription(title),
          icon: visual.icon,
          colorKey: visual.colorKey,
        );
      })
      .where((category) => category.id.isNotEmpty)
      .toList(growable: false);

  syncedKnowledgeTopics = infos
      .map((row) {
        final id = _string(row['id']);
        final title = _string(row['knowledge_title'], fallback: '未命名专题');
        final content = _string(row['knowledge_content']).trim();
        final loadedSegments = segmentsByTopic[id];
        return KnowledgeTopic(
          id: id,
          categoryId: _string(row['knowledge_category']),
          title: title,
          summary: _summaryFromContent(content),
          article: content,
          segments: loadedSegments == null || loadedSegments.isEmpty
              ? [_buildKnowledgeArticle(id, title, content)]
              : loadedSegments,
        );
      })
      .where((topic) => topic.id.isNotEmpty)
      .toList(growable: false);

  practiceQuestions = questions
      .map((row) {
        final topicId = _string(row['basic_knowledge_id']);
        final categoryTitle = _moduleTitleForTopic(topicId, categoryTitleById);
        return PracticeQuestion(
          id: _string(row['id']),
          topicId: topicId,
          segmentId: _string(row['knowledge_segment_id']),
          module: categoryTitle,
          question: _string(row['question_text'], fallback: '未命名题目'),
          options: [
            _string(row['option_a']),
            _string(row['option_b']),
            _string(row['option_c']),
            _string(row['option_d']),
          ],
          answer: _string(row['answer_key'], fallback: 'A').toUpperCase(),
          explanation: _string(row['explanation'], fallback: '暂无解析'),
          difficulty: _int(row['difficulty'], fallback: 2),
        );
      })
      .where(
        (question) =>
            question.id.isNotEmpty &&
            question.topicId.isNotEmpty &&
            question.options.every((option) => option.isNotEmpty),
      )
      .toList(growable: false);
  if (practiceQuestions.isEmpty) {
    practiceQuestions = _fallbackPracticeQuestions;
  }
}

void resetKnowledgeToFallback() {
  syncedKnowledgeCategories = _buildSyncedKnowledgeCategories();
  syncedKnowledgeTopics = _buildSyncedKnowledgeTopics();
  practiceQuestions = _fallbackPracticeQuestions;
}

String _string(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

String _moduleTitleForTopic(
  String topicId,
  Map<String, String> categoryTitleById,
) {
  final topic = syncedKnowledgeTopics.where((topic) => topic.id == topicId);
  if (topic.isEmpty) {
    return '公基';
  }
  return categoryTitleById[topic.first.categoryId] ?? '公基';
}

List<KnowledgeCategory> _buildSyncedKnowledgeCategories() {
  return agentChineseBasicKnowledgeCategories
      .map((row) {
        final title = '${row['category_title'] ?? '未命名分类'}';
        final visual = _categoryVisual(title);
        return KnowledgeCategory(
          id: '${row['id']}',
          title: title,
          description: _categoryDescription(title),
          icon: visual.icon,
          colorKey: visual.colorKey,
        );
      })
      .toList(growable: false);
}

List<KnowledgeTopic> _buildSyncedKnowledgeTopics() {
  return agentChineseBasicKnowledgeInfos
      .map((row) {
        final id = '${row['id']}';
        final title = '${row['knowledge_title'] ?? '未命名专题'}';
        final content = '${row['knowledge_content'] ?? ''}'.trim();
        return KnowledgeTopic(
          id: id,
          categoryId: '${row['knowledge_category'] ?? ''}',
          title: title,
          summary: _summaryFromContent(content),
          segments: [_buildKnowledgeArticle(id, title, content)],
        );
      })
      .toList(growable: false);
}

KnowledgeSegment _buildKnowledgeArticle(
  String topicId,
  String title,
  String content,
) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  final body = normalized.isEmpty ? '暂无正文内容' : normalized;
  return KnowledgeSegment(
    id: '$topicId-article',
    topicId: topicId,
    index: 0,
    content: _compact(body == '暂无正文内容' ? title : body, maxLength: 96),
    details: body,
    status: SegmentStatus.learned,
  );
}

String _summaryFromContent(String content) {
  if (content.isEmpty) {
    return '暂无专题简介';
  }
  return _compact(
    content.replaceAll('\r\n', ' ').replaceAll('\n', ' '),
    maxLength: 44,
  );
}

String _compact(String text, {required int maxLength}) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }
  return '${compact.substring(0, maxLength)}...';
}

String _categoryDescription(String title) {
  if (title.contains('历史')) {
    return '中国史、世界史与制度演变';
  }
  if (title.contains('人文')) {
    return '文学、文化、思想与艺术常识';
  }
  if (title.contains('自然') || title.contains('科技')) {
    return '自然科学、生活常识与科技成果';
  }
  if (title.contains('法律')) {
    return '宪法、行政法、民法与常见法条';
  }
  if (title.contains('经济')) {
    return '宏观经济、市场机制与财政金融';
  }
  if (title.contains('管理')) {
    return '公共管理、组织协调与行政实务';
  }
  if (title.contains('公文')) {
    return '公文格式、行文规则与机关表达';
  }
  if (title.contains('国情') || title.contains('省情')) {
    return '国家概况、区域发展与地方常识';
  }
  return '公基高频专题与常识积累';
}

_CategoryVisual _categoryVisual(String title) {
  if (title.contains('历史')) {
    return const _CategoryVisual(Icons.account_balance_rounded, 'green');
  }
  if (title.contains('人文')) {
    return const _CategoryVisual(Icons.menu_book_rounded, 'amber');
  }
  if (title.contains('自然') || title.contains('科技')) {
    return const _CategoryVisual(Icons.science_rounded, 'blue');
  }
  if (title.contains('法律')) {
    return const _CategoryVisual(Icons.gavel_rounded, 'purple');
  }
  if (title.contains('经济')) {
    return const _CategoryVisual(Icons.trending_up_rounded, 'red');
  }
  if (title.contains('管理')) {
    return const _CategoryVisual(Icons.groups_rounded, 'amber');
  }
  if (title.contains('公文')) {
    return const _CategoryVisual(Icons.description_rounded, 'green');
  }
  if (title.contains('国情') || title.contains('省情')) {
    return const _CategoryVisual(Icons.map_rounded, 'blue');
  }
  if (title.contains('军')) {
    return const _CategoryVisual(Icons.security_rounded, 'green');
  }
  return const _CategoryVisual(Icons.school_rounded, 'purple');
}

class _CategoryVisual {
  const _CategoryVisual(this.icon, this.colorKey);

  final IconData icon;
  final String colorKey;
}

List<KnowledgeTopic> topicsForCategory(String categoryId) {
  return syncedKnowledgeTopics
      .where((topic) => topic.categoryId == categoryId)
      .toList(growable: false);
}

KnowledgeTopic topicById(String id) {
  return syncedKnowledgeTopics.firstWhere(
    (topic) => topic.id == id,
    orElse: () => syncedKnowledgeTopics.first,
  );
}

List<PracticeQuestion> questionsForTopic(String topicId) {
  return practiceQuestions
      .where((question) => question.topicId == topicId)
      .toList(growable: false);
}

List<PracticeQuestion> questionsForModule(String categoryId) {
  final topicIds = topicsForCategory(
    categoryId,
  ).map((topic) => topic.id).toSet();
  return practiceQuestions
      .where((question) => topicIds.contains(question.topicId))
      .toList(growable: false);
}

int learnedSegmentCount(KnowledgeTopic topic) {
  return topic.segments
      .where((segment) => segment.status != SegmentStatus.notStarted)
      .length;
}

int masteredSegmentCount() {
  return syncedKnowledgeTopics
      .expand((topic) => topic.segments)
      .where((segment) => segment.status == SegmentStatus.mastered)
      .length;
}

int weakSegmentCount() {
  return syncedKnowledgeTopics
      .expand((topic) => topic.segments)
      .where((segment) => segment.status == SegmentStatus.weak)
      .length;
}

int totalSegmentCount() {
  return syncedKnowledgeTopics.expand((topic) => topic.segments).length;
}

int learnedTotalCount() {
  return syncedKnowledgeTopics
      .expand((topic) => topic.segments)
      .where((segment) => segment.status != SegmentStatus.notStarted)
      .length;
}
