#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from split_seed_io import load_seed, save_seed

from PIL import Image, ImageChops
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "assets/data/shore_pod_seed.json"
QUESTION_ROOT = Path("/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目")
ANSWER_ROOT = Path("/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案")
CREATED_TIME = "2026-07-01T00:00:00.000000+08:00"
PDFTOPPM = (
    ROOT / "../.." / ".cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdftoppm"
).resolve()
RENDER_DPI = 120


@dataclass
class ImportConfig:
    slug: str
    category_title: str
    subcategory_title: str
    question_pdf: Path
    answer_dir: Path
    source_name: str
    image_prefix: str = ""
    answer_slice_start: int | None = None
    answer_slice_end: int | None = None


@dataclass
class Section:
    section_key: str
    title: str
    start_page: int
    pages: list[tuple[int, str]]


@dataclass
class ParsedQuestion:
    section_key: str
    section_title: str
    local_number: int
    question_text: str
    options: dict[str, str]
    source_page: int
    global_number: int = 0


@dataclass
class ParsedAnswer:
    answer_key: str
    explanation: str


CONFIGS = [
    ImportConfig(
        slug="math_operations",
        category_title="数量关系",
        subcategory_title="数学运算",
        question_pdf=QUESTION_ROOT / "数量/数学运算PDF326页.pdf",
        answer_dir=ANSWER_ROOT / "数量/数学运算",
        source_name="粉笔行测两万五-数学运算",
        image_prefix="assets/images/aptitude/quantitative_reasoning/math_operations",
    ),
    ImportConfig(
        slug="number_reasoning",
        category_title="数量关系",
        subcategory_title="数字推理",
        question_pdf=QUESTION_ROOT / "数量/数推PDF70页.pdf",
        answer_dir=ANSWER_ROOT / "数量/数字推理",
        source_name="粉笔行测两万五-数字推理",
        image_prefix="assets/images/aptitude/quantitative_reasoning/number_reasoning",
    ),
    ImportConfig(
        slug="logical_fill",
        category_title="言语理解与表达",
        subcategory_title="逻辑填空",
        question_pdf=QUESTION_ROOT / "言语/逻辑填空PDF315页.pdf",
        answer_dir=ANSWER_ROOT / "言语/逻辑填空",
        source_name="粉笔行测两万五-逻辑填空",
    ),
    ImportConfig(
        slug="passage_reading",
        category_title="言语理解与表达",
        subcategory_title="篇章阅读",
        question_pdf=QUESTION_ROOT / "言语/篇章阅读PDF144页.pdf",
        answer_dir=ANSWER_ROOT / "言语/篇章阅读",
        source_name="粉笔行测两万五-篇章阅读",
    ),
    ImportConfig(
        slug="sentence_expression",
        category_title="言语理解与表达",
        subcategory_title="语句表达",
        question_pdf=QUESTION_ROOT / "言语/语句表达PDF113页.pdf",
        answer_dir=ANSWER_ROOT / "言语/语句表达",
        source_name="粉笔行测两万五-语句表达",
    ),
    ImportConfig(
        slug="reading_comprehension",
        category_title="言语理解与表达",
        subcategory_title="阅读理解",
        question_pdf=QUESTION_ROOT / "言语/阅读理解PDF443页.pdf",
        answer_dir=ANSWER_ROOT / "言语/阅读理解",
        source_name="粉笔行测两万五-阅读理解",
    ),
    ImportConfig(
        slug="data_analysis_part_1",
        category_title="资料分析",
        subcategory_title="资料分析",
        question_pdf=QUESTION_ROOT / "资料/资料题目合并PDF_1-372.pdf",
        answer_dir=ANSWER_ROOT / "资料",
        source_name="粉笔行测两万五-资料分析",
        image_prefix="assets/images/aptitude/data_analysis/part_1",
        answer_slice_start=0,
        answer_slice_end=40,
    ),
    ImportConfig(
        slug="data_analysis_part_2",
        category_title="资料分析",
        subcategory_title="资料分析",
        question_pdf=QUESTION_ROOT / "资料/资料题目合并PDF_373-785.pdf",
        answer_dir=ANSWER_ROOT / "资料",
        source_name="粉笔行测两万五-资料分析",
        image_prefix="assets/images/aptitude/data_analysis/part_2",
        answer_slice_start=40,
        answer_slice_end=None,
    ),
]


def stable_id(value: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"shore-pod/aptitude-question/{value}"))


def natural_key(path: Path) -> list[object]:
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", str(path))]


def clean_text(value: str) -> str:
    value = value.replace("\x00", "")
    value = value.replace("\uf0b7", "")
    value = value.translate(str.maketrans("ＡＢＣＤ", "ABCD"))
    value = re.sub(r"(?m)^\s*成生047338901友粉户用笔粉由卷试本\s*·?\s*$", "", value)
    value = re.sub(r"(?m)^\s*页\s*\d+\s*共，页\s*\d+\s*第\s*$", "", value)
    value = re.sub(r"(?m)^\s*专项智能练习（[^）]+）\s*$", "", value)
    value = re.sub(r"(?m)^\s*更多其他考试资料.*$", "", value)
    value = re.sub(r"(?m)^\s*更多资料添加.*$", "", value)
    value = re.sub(r"(?m)^\s*vx\s*:\s*bishengkejian\s*$", "", value)
    value = re.sub(r"(?m)^\s*免费\s*$", "", value)
    value = re.sub(r"[ \t]{2,}", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def clean_question_text(value: str) -> str:
    value = re.sub(r"(?m)^<<<PAGE:\d+>>>$", "", value)
    return clean_text(value)


def clean_option(value: str) -> str:
    value = clean_question_text(value)
    value = re.sub(r"^[A-D]\s*[.．]\s*", "", value)
    return value.strip()


def page_texts(pdf_path: Path) -> list[str]:
    reader = PdfReader(str(pdf_path))
    return [page.extract_text() or "" for page in reader.pages]


def page_title(text: str) -> str | None:
    match = re.search(r"专项智能练习（([^\n）]+)）", text)
    return re.sub(r"\s+", "", match.group(1)) if match else None


def normalized_page_body(text: str) -> str:
    lines: list[str] = []
    for line in text.replace("\r", "\n").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if "专项智能练习" in stripped:
            continue
        if "更多其他考试资料" in stripped or "更多资料添加" in stripped:
            continue
        if stripped in {"vx:bishengkejian", "vx: bishengkejian", "免费", "成生047338901友粉户用笔粉由卷试本 ·"}:
            continue
        if re.fullmatch(r"页\s*\d+\s*共，页\s*\d+\s*第", stripped):
            continue
        lines.append(line)
    return "\n".join(lines)


def split_sections(pdf_path: Path) -> list[Section]:
    sections: list[Section] = []
    current_title: str | None = None
    current_key: str | None = None
    current_start = 1
    current_pages: list[tuple[int, str]] = []
    fallback_index = 0

    for page_number, text in enumerate(page_texts(pdf_path), start=1):
        title = page_title(text)
        starts_section = False
        if title:
            has_number = bool(re.search(r"\d+$", title))
            current_base = re.sub(r"\d+$", "", current_title or "")
            title_base = re.sub(r"\d+$", "", title)
            starts_section = current_title is None or (
                title != current_title and (has_number or title_base != current_base)
            )
        if starts_section:
            if current_title is not None and current_key is not None:
                sections.append(Section(current_key, current_title, current_start, current_pages))
            fallback_index += 1
            current_title = title
            current_key = f"{fallback_index:03d}"
            current_start = page_number
            current_pages = []
        elif title and current_title is None:
            fallback_index += 1
            current_title = title
            current_key = f"{fallback_index:03d}"
            current_start = page_number

        body = normalized_page_body(text)
        if body:
            current_pages.append((page_number, body))

    if current_title is not None and current_key is not None:
        sections.append(Section(current_key, current_title, current_start, current_pages))
    return sections


OPTION_MARKER_RE = re.compile(r"([A-D])\s*[.．]")
PAGE_MARKER_RE = re.compile(r"<<<PAGE:(\d+)>>>")


def find_expected_marker(text: str, expected: int, start: int) -> re.Match[str] | None:
    pattern = re.compile(rf"(?<![A-D]\s){expected}[.．]")
    for match in pattern.finditer(text, start):
        before = text[max(0, match.start() - 8) : match.start()]
        after = text[match.end() : match.end() + 16]
        if re.search(r"[A-D]\s*$", before):
            continue
        if not after.startswith("\n") and not re.match(r"\s", after):
            continue
        return match
    return None


def source_page_before(text: str, position: int, fallback: int) -> int:
    result = fallback
    for match in PAGE_MARKER_RE.finditer(text, 0, position):
        result = int(match.group(1))
    return result


def parse_options_after_marker(text: str, start: int) -> tuple[dict[str, str], int]:
    markers = []
    search_start = start
    for expected in "ABCD":
        found = None
        for match in OPTION_MARKER_RE.finditer(text, search_start):
            if match.group(1) == expected:
                found = match
                break
        if found is None:
            raise ValueError(f"missing option {expected} near {text[start:start+160]!r}")
        markers.append(found)
        search_start = found.end()

    options: dict[str, str] = {}
    for index, label in enumerate("ABCD"):
        begin = markers[index].end()
        if label != "D":
            end = markers[index + 1].start()
        else:
            newline = text.find("\n", begin)
            end = newline if newline != -1 else len(text)
        options[label] = clean_option(text[begin:end])
    d_newline = text.find("\n", markers[-1].end())
    return options, d_newline + 1 if d_newline != -1 else markers[-1].end()


def parse_section_questions(section: Section) -> list[ParsedQuestion]:
    parts: list[str] = []
    for page_number, body in section.pages:
        parts.append(f"<<<PAGE:{page_number}>>>")
        parts.append(body)
    text = clean_text("\n".join(parts))

    questions: list[ParsedQuestion] = []
    cursor = 0
    expected = 1
    while True:
        marker = find_expected_marker(text, expected, cursor)
        if marker is None:
            break
        question_text = clean_question_text(text[cursor : marker.start()])
        try:
            options, option_end = parse_options_after_marker(text, marker.end())
        except ValueError:
            cursor = marker.end()
            expected += 1
            continue
        if question_text:
            questions.append(
                ParsedQuestion(
                    section_key=section.section_key,
                    section_title=section.title,
                    local_number=expected,
                    question_text=question_text,
                    options=options,
                    source_page=source_page_before(text, marker.start(), section.start_page),
                )
            )
        cursor = option_end
        expected += 1
    return questions


def parse_question_pdf(pdf_path: Path) -> list[ParsedQuestion]:
    parsed: list[ParsedQuestion] = []
    for section in split_sections(pdf_path):
        parsed.extend(parse_section_questions(section))
    for index, question in enumerate(parsed, start=1):
        question.global_number = index
    return parsed


ANSWER_START_TEMPLATE = (
    r"(?m)^\s*(?:\uf0b7|)?\s*{number}\s*(?:[.．]|(?=\n)|(?=\s*正确答案))"
)
KEY_PATTERNS = [
    re.compile(r"正确答案(?:是|为)?\s*[:：]?\s*([A-H])"),
    re.compile(r"故(?:本题)?正确答案(?:是|为)\s*([A-H])"),
    re.compile(r"故(?:本题)?答案(?:是|为)\s*([A-H])"),
    re.compile(r"故选\s*([A-H])"),
    re.compile(r"锁定\s*([A-H])\s*项"),
    re.compile(r"只有\s*([A-H])\s*项"),
    re.compile(r"与\s*([A-H])\s*项(?:符合|最接近)"),
    re.compile(r"对应\s*([A-H])\s*项"),
    re.compile(r"([A-H])\s*项[^。；;]*(?:正确|当选|符合)"),
]
KEY_SEQUENCE_RE = re.compile(
    r"(?:正确答案(?:是|为)?\s*[:：]?|故(?:本题)?正确答案(?:是|为)|故(?:本题)?答案(?:是|为))\s*([A-H])"
)
EXCLUDED_RE = re.compile(r"(?:排除|不选|错误)[^。；;\n]*?([A-D])\s*项")
ANSWER_KEY_OVERRIDES = {
    ("工程4.pdf", 23): "D",
}


def answer_key_from_segment(segment: str) -> str:
    for pattern in KEY_PATTERNS:
        match = pattern.search(segment)
        if match:
            return match.group(1)
    excluded = set(EXCLUDED_RE.findall(segment))
    if len(excluded) == 3:
        return next(label for label in "ABCD" if label not in excluded)
    raise ValueError("missing answer key")


def parse_answer_pdf(pdf_path: Path, expected_count: int) -> list[ParsedAnswer]:
    text = clean_text("\n".join(page_texts(pdf_path)))
    starts: list[re.Match[str]] = []
    position = 0
    for expected in range(1, expected_count + 1):
        match = re.compile(ANSWER_START_TEMPLATE.format(number=expected)).search(text, position)
        if match is None:
            break
        starts.append(match)
        position = match.end()

    if len(starts) != expected_count:
        keys = KEY_SEQUENCE_RE.findall(text)
        if len(keys) >= expected_count:
            return [
                ParsedAnswer(answer_key=keys[index], explanation="")
                for index in range(expected_count)
            ]
        return [
            ParsedAnswer(answer_key="", explanation="")
            for _ in range(expected_count)
        ]

    answers: list[ParsedAnswer] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        segment = clean_text(text[match.start() : end])
        key = ANSWER_KEY_OVERRIDES.get((pdf_path.name, index + 1), "")
        if not key:
            try:
                key = answer_key_from_segment(segment)
            except ValueError:
                key = ""
        answers.append(ParsedAnswer(answer_key=key, explanation=segment))
    return answers


def answer_files(config: ImportConfig) -> list[Path]:
    files = sorted(config.answer_dir.rglob("*.pdf"), key=natural_key)
    if config.answer_slice_start is not None or config.answer_slice_end is not None:
        return files[config.answer_slice_start : config.answer_slice_end]
    return files


def compact_title(value: str) -> str:
    return re.sub(r"[\s_\-.。．]+", "", value)


def answer_file_map(config: ImportConfig, questions: list[ParsedQuestion]) -> dict[str, Path]:
    grouped_titles = {
        question.section_key: question.section_title
        for question in questions
    }
    files = answer_files(config)
    by_stem = {compact_title(path.stem): path for path in files}
    mapped: dict[str, Path] = {}
    aliases = {
        "工程问题": "工程",
        "和差倍比问题": "和差倍比",
        "溶液问题": "溶液",
        "计数模型问题": "计数",
        "行程问题": "行程",
        "余数和同余问题": "余数同余问题",
        "平均数问题": "平均数问题",
        "牛吃草问题": "牛吃草",
        "资料分析": "资料",
    }
    for section_key, title in grouped_titles.items():
        candidates = [title]
        for source, target in aliases.items():
            if title.startswith(source):
                candidates.append(title.replace(source, target, 1))
        matched = None
        for candidate in candidates:
            matched = by_stem.get(compact_title(candidate))
            if matched is not None:
                break
        if matched is None:
            raise ValueError(f"no answer file for {config.source_name} section {title}")
        mapped[section_key] = matched
    return mapped


def attach_answers(questions: list[ParsedQuestion], config: ImportConfig) -> dict[tuple[str, int], ParsedAnswer]:
    grouped: dict[str, list[ParsedQuestion]] = {}
    for question in questions:
        grouped.setdefault(question.section_key, []).append(question)
    file_map = answer_file_map(config, questions)
    answers: dict[tuple[str, int], ParsedAnswer] = {}
    for section_key, section_questions in grouped.items():
        parsed_answers = parse_answer_pdf(file_map[section_key], len(section_questions))
        for question, answer in zip(section_questions, parsed_answers, strict=True):
            answers[(section_key, question.local_number)] = answer
    return answers


def near_white_trim(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    white = Image.new("RGB", rgb.size, (235, 235, 235))
    diff = ImageChops.difference(rgb, white)
    bbox = diff.point(lambda value: 0 if value < 22 else 255).getbbox()
    if bbox is None:
        return rgb
    left, upper, right, lower = bbox
    pad = 8
    return rgb.crop(
        (
            max(0, left - pad),
            max(0, upper - pad),
            min(rgb.width, right + pad),
            min(rgb.height, lower + pad),
        )
    )


def render_page_images(config: ImportConfig) -> dict[int, str]:
    if not config.image_prefix:
        return {}
    output_dir = ROOT / config.image_prefix
    output_dir.mkdir(parents=True, exist_ok=True)
    for old in output_dir.glob("*.png"):
        old.unlink()
    with tempfile.TemporaryDirectory() as temp:
        prefix = Path(temp) / config.slug
        subprocess.run(
            [str(PDFTOPPM), "-r", str(RENDER_DPI), "-png", str(config.question_pdf), str(prefix)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        page_map: dict[int, str] = {}
        for source in sorted(Path(temp).glob(f"{config.slug}-*.png"), key=natural_key):
            match = re.search(r"-(\d+)\.png$", source.name)
            if not match:
                continue
            page_number = int(match.group(1))
            target = output_dir / f"page_{page_number:04d}.png"
            near_white_trim(Image.open(source)).save(target)
            page_map[page_number] = f"{config.image_prefix}/{target.name}"
        return page_map


def load_seed_tables() -> tuple[dict, dict[str, str], dict[tuple[str, str], str]]:
    data = load_seed(SEED_PATH)
    tables = data["tables"]
    category_ids = {row["category_title"]: row["id"] for row in tables["aptitude_category"]}
    subcategory_ids = {
        (category["category_title"], subcategory["subcategory_title"]): subcategory["id"]
        for category in tables["aptitude_category"]
        for subcategory in tables["aptitude_subcategory"]
        if subcategory["category_id"] == category["id"]
    }
    return data, category_ids, subcategory_ids


def build_rows(
    config: ImportConfig,
    questions: list[ParsedQuestion],
    answers: dict[tuple[str, int], ParsedAnswer],
    category_id: str,
    subcategory_id: str,
    page_images: dict[int, str],
    number_offset: int = 0,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for question in questions:
        answer = answers[(question.section_key, question.local_number)]
        if answer.answer_key not in {"A", "B", "C", "D"}:
            continue
        global_number = number_offset + question.global_number
        has_page_image = question.source_page in page_images
        options = {
            label: question.options[label] if question.options[label] else (label if has_page_image else "")
            for label in "ABCD"
        }
        rows.append(
            {
                "id": stable_id(f"{config.slug}/{question.section_key}/{question.local_number}"),
                "category_id": category_id,
                "subcategory_id": subcategory_id,
                "question_number": global_number,
                "question_type": "single_choice",
                "question_text": f"【{question.section_title}】{question.question_text}",
                "question_image": page_images.get(question.source_page, ""),
                "option_a": options["A"],
                "option_b": options["B"],
                "option_c": options["C"],
                "option_d": options["D"],
                "option_a_image": "",
                "option_b_image": "",
                "option_c_image": "",
                "option_d_image": "",
                "answer_key": answer.answer_key,
                "explanation": answer.explanation,
                "difficulty": 2,
                "question_status": 0,
                "source_name": config.source_name,
                "source_page": question.source_page,
                "created_time": CREATED_TIME,
                "update_time": CREATED_TIME,
            }
        )
    return rows


def main() -> None:
    data, category_ids, subcategory_ids = load_seed_tables()
    imported_rows: list[dict[str, object]] = []
    source_names = {config.source_name for config in CONFIGS}
    offsets: dict[str, int] = {}

    for config in CONFIGS:
        questions = parse_question_pdf(config.question_pdf)
        offset = offsets.get(config.source_name, 0)
        answers = attach_answers(questions, config)
        page_images = render_page_images(config)
        rows = build_rows(
            config=config,
            questions=questions,
            answers=answers,
            category_id=category_ids[config.category_title],
            subcategory_id=subcategory_ids[(config.category_title, config.subcategory_title)],
            page_images=page_images,
            number_offset=offset,
        )
        offsets[config.source_name] = offset + len(questions)
        imported_rows.extend(rows)
        print(f"{config.subcategory_title}: {len(rows)}")

    tables = data["tables"]
    existing = [
        row
        for row in tables.get("aptitude_question", [])
        if row.get("source_name") not in source_names
    ]
    tables["aptitude_question"] = existing + imported_rows
    save_seed(data, SEED_PATH)
    print(f"Imported quantity/verbal/data questions: {len(imported_rows)}")
    print(f"Total aptitude questions: {len(tables['aptitude_question'])}")


if __name__ == "__main__":
    main()
