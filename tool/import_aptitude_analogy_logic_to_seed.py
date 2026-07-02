#!/usr/bin/env python3
import json
import re
from dataclasses import dataclass
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from split_seed_io import load_seed, save_seed

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "assets/data/shore_pod_seed.json"
CREATED_TIME = "2026-07-01T00:00:00.000000+08:00"

JUDGMENT_CATEGORY_ID = "7e2546db-57f4-5c94-9493-bedbc79bb12e"
ANALOGY_SUBCATEGORY_ID = "b1b28140-d060-50d1-b5e8-42643a144d27"
LOGIC_SUBCATEGORY_ID = "fdc2536c-ed7a-5626-904b-cee9f29f8b9f"

ANALOGY_QUESTION_PDF = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目/判断/类比推理PDF107页.pdf"
)
ANALOGY_ANSWER_DIR = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案/判断/类比推理"
)
LOGIC_QUESTION_PDF = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目/判断/逻辑判断PDF421页.pdf"
)
LOGIC_ANSWER_DIR = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案/判断/逻辑判断"
)

ANALOGY_SOURCE_NAME = "粉笔行测两万五-类比推理"
LOGIC_SOURCE_NAME = "粉笔行测两万五-逻辑判断"

TEXT_FALLBACK_IMAGE_PREFIX = "assets/images/aptitude/text_fallback"
QUESTION_FIXES = {
    (ANALOGY_SOURCE_NAME, 653): {
        "question_image": f"{TEXT_FALLBACK_IMAGE_PREFIX}/analogy_q0653.png",
        "option_a": "x>1：x²>1",
        "option_b": "100℃：沸腾",
        "option_c": "O₃：臭氧",
        "option_d": "π：圆面积",
    },
    (LOGIC_SOURCE_NAME, 623): {
        "question_image": f"{TEXT_FALLBACK_IMAGE_PREFIX}/logic_q0623.png",
        "option_a": "60%的调查者表示，不愿意因数据被动分享而降低个人能源使用比例",
        "option_b": "60%的调查者认为，数据的被动分享大大增加个人隐私被侵犯的风险",
        "option_c": "60%的调查者表示，那些关心气候变化的人更可能接受数据被动分享",
        "option_d": "60%的调查者认为，数据不可能不被分享，否则智能技术不可能应用",
    },
    (LOGIC_SOURCE_NAME, 1109): {
        "question_image": f"{TEXT_FALLBACK_IMAGE_PREFIX}/logic_q1109.png",
        "option_a": "20mm/s，75次/分",
        "option_b": "20mm/s，60次/分",
        "option_c": "25mm/s，75次/分",
        "option_d": "25mm/s，60次/分",
    },
    (LOGIC_SOURCE_NAME, 1681): {
        "question_image": f"{TEXT_FALLBACK_IMAGE_PREFIX}/logic_q1681.png",
        "option_d": "14%正说明培养大学生对传统文化的学习大有潜力可挖",
    },
}


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
    value = re.sub(r"(?m)^\s*vx:bishengkejian\s*$", "", value)
    value = re.sub(r"(?m)^\s*免费\s*$", "", value)
    value = re.sub(r"[ \t]{2,}", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    value = value.replace("（ ", "（").replace(" ）", "）")
    return value.strip()


def clean_option(value: str) -> str:
    value = clean_text(value)
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
        if stripped in {"vx:bishengkejian", "免费", "成生047338901友粉户用笔粉由卷试本 ·"}:
            continue
        if re.fullmatch(r"页\s*\d+\s*共，页\s*\d+\s*第", stripped):
            continue
        lines.append(line)
    return "\n".join(lines)


def section_key_from_title(title: str, fallback_index: int) -> str:
    return f"{fallback_index:03d}"


def split_question_pdf_into_sections(pdf_path: Path) -> list[tuple[str, str, int, str]]:
    sections: list[tuple[str, str, int, str]] = []
    current_title: str | None = None
    current_key: str | None = None
    current_start = 1
    current_parts: list[str] = []
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
                sections.append(
                    (current_key, current_title, current_start, "\n".join(current_parts))
                )
            fallback_index += 1
            current_title = title
            current_key = section_key_from_title(title or "", fallback_index)
            current_start = page_number
            current_parts = []
        elif title and current_title is None:
            fallback_index += 1
            current_title = title
            current_key = section_key_from_title(title, fallback_index)
            current_start = page_number

        body = normalized_page_body(text)
        if body:
            current_parts.append(body)

    if current_title is not None and current_key is not None:
        sections.append((current_key, current_title, current_start, "\n".join(current_parts)))
    return sections


QUESTION_MARKER_RE = re.compile(r"(?<![A-D]\s)(\d{1,3})[.．]")
OPTION_MARKER_RE = re.compile(r"([A-D])\s*[.．]")


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
    return options, max(marker.end() for marker in markers) if text.find("\n", markers[-1].end()) == -1 else text.find("\n", markers[-1].end()) + 1


def parse_section_questions(
    *,
    section_key: str,
    section_title: str,
    section_text: str,
    source_page: int,
) -> list[ParsedQuestion]:
    text = clean_text(section_text)
    questions: list[ParsedQuestion] = []
    cursor = 0
    expected = 1
    while True:
        marker = find_expected_marker(text, expected, cursor)
        if marker is None:
            break
        question_text = clean_text(text[cursor : marker.start()])
        try:
            options, option_end = parse_options_after_marker(text, marker.end())
        except ValueError:
            # A small number of pages contain unusual spacing. Move forward so the
            # issue is reported through the final count mismatch instead of looping.
            cursor = marker.end()
            expected += 1
            continue
        if question_text:
            questions.append(
                ParsedQuestion(
                    section_key=section_key,
                    section_title=section_title,
                    local_number=expected,
                    question_text=question_text,
                    options=options,
                    source_page=source_page,
                )
            )
        cursor = option_end
        expected += 1
    return questions


def parse_question_pdf(pdf_path: Path) -> list[ParsedQuestion]:
    parsed: list[ParsedQuestion] = []
    for section_key, title, source_page, text in split_question_pdf_into_sections(pdf_path):
        parsed.extend(
            parse_section_questions(
                section_key=section_key,
                section_title=title,
                section_text=text,
                source_page=source_page,
            )
        )
    for index, question in enumerate(parsed, start=1):
        question.global_number = index
    return parsed


ANSWER_START_RE = re.compile(
    r"(?m)^\s*(?:\uf0b7|)?\s*(\d{1,3})[.．]?\s*(?:\n\s*)?(?:正确答案(?:是|为)?\s*[:：]?\s*)?([A-D])?",
)
ANSWER_KEY_RE = re.compile(r"正确答案(?:是|为)?\s*[:：]?\s*([A-D])")
ANSWER_KEY_FALLBACK_RE = re.compile(r"故正确(?:答案|选项)(?:是|为)\s*([A-D])")
ANSWER_OPTION_CORRECT_RE = re.compile(r"([A-D])\s*项[^。]*(?:正确|当选)")
ANSWER_OPTION_TARGET_RE = re.compile(r"对应\s*([A-D])\s*项")


def parse_answer_pdf(pdf_path: Path, expected_count: int) -> list[ParsedAnswer]:
    text = "\n".join(page_texts(pdf_path))
    text = clean_text(text)
    starts: list[re.Match[str]] = []
    expected = 1
    position = 0
    while expected <= expected_count:
        pattern = re.compile(
            rf"(?m)^\s*(?:\uf0b7|)?\s*{expected}\s*(?:[.．]|(?=\n\s*正确答案))\s*(?:\n\s*)?(?:正确答案(?:是|为)?\s*[:：]?\s*)?([A-D])?"
        )
        match = pattern.search(text, position)
        if match is None:
            break
        starts.append(match)
        position = match.end()
        expected += 1

    if len(starts) != expected_count:
        # Some answer files do not expose a clean leading number for every item,
        # but all of them keep the "故正确答案为 X" conclusion in order.
        keys = ANSWER_KEY_FALLBACK_RE.findall(text)
        if len(keys) < expected_count:
            keys = ANSWER_KEY_RE.findall(text)
        if len(keys) >= expected_count:
            chunks = re.split(r"(?=故正确答案(?:是|为)\s*[A-D])", text)
            explanations: list[str] = []
            for index in range(expected_count):
                explanations.append(clean_text(chunks[index + 1] if index + 1 < len(chunks) else ""))
            return [
                ParsedAnswer(answer_key=keys[index], explanation=explanations[index] or "")
                for index in range(expected_count)
            ]
        raise ValueError(
            f"{pdf_path} expected {expected_count} answers, got starts={len(starts)} keys={len(keys)}"
        )

    answers: list[ParsedAnswer] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        segment = clean_text(text[match.start() : end])
        key = match.group(1) if match.lastindex and match.group(1) else ""
        key_match = (
            ANSWER_KEY_RE.search(segment)
            or ANSWER_KEY_FALLBACK_RE.search(segment)
            or ANSWER_OPTION_CORRECT_RE.search(segment)
            or ANSWER_OPTION_TARGET_RE.search(segment)
        )
        if key_match:
            key = key_match.group(1)
        if not key:
            raise ValueError(f"missing answer key in {pdf_path} item {index + 1}")
        answers.append(ParsedAnswer(answer_key=key, explanation=segment))
    return answers


def analogy_answer_files() -> list[Path]:
    return sorted(ANALOGY_ANSWER_DIR.glob("类比*.pdf"), key=natural_key)


LOGIC_TITLE_TO_FILE_PREFIX = {
    "常规翻译": "常规翻译",
    "翻译推理-其他": "翻译推理-其他",
    "推理形式": "推理形式",
    "集合推理": "集合推理",
    "真假推理": "真假",
    "日常结论": "日常结论",
    "必要条件": "加强",
    "加强题型": "加强",
    "补充论据": "加强",
    "搭桥": "加强",
    "加强-其他": "加强",
    "加强选非题": "加强",
    "削弱题型": "削弱",
    "原因解释": "原因",
    "论证结构": "论结",
    "论证缺陷": "论缺",
    "组合排列-单题": "排列组合",
}


def logic_answer_file_map() -> dict[str, Path]:
    files = sorted(LOGIC_ANSWER_DIR.rglob("*.pdf"), key=natural_key)
    by_stem = {path.stem: path for path in files}
    mapped: dict[str, Path] = {}
    counters: dict[str, int] = {}
    for section_key, title, _, _ in split_question_pdf_into_sections(LOGIC_QUESTION_PDF):
        base = re.sub(r"\d+$", "", title)
        number_match = re.search(r"(\d+)$", title)
        number = number_match.group(1) if number_match else ""
        prefix = LOGIC_TITLE_TO_FILE_PREFIX.get(base, base)
        if number:
            stem = f"{prefix}{number}"
        else:
            counters[prefix] = counters.get(prefix, 0) + 1
            stem = prefix if prefix in by_stem else f"{prefix}{counters[prefix]}"
        if stem not in by_stem:
            raise ValueError(f"no answer file for logic section {title} -> {stem}")
        mapped[section_key] = by_stem[stem]
    return mapped


def attach_answers_by_section(
    questions: list[ParsedQuestion],
    answer_files: dict[str, Path] | list[Path],
) -> dict[tuple[str, int], ParsedAnswer]:
    grouped: dict[str, list[ParsedQuestion]] = {}
    for question in questions:
        grouped.setdefault(question.section_key, []).append(question)

    result: dict[tuple[str, int], ParsedAnswer] = {}
    if isinstance(answer_files, list):
        ordered_sections = sorted(grouped.keys(), key=lambda item: int(item))
        if len(ordered_sections) != len(answer_files):
            raise ValueError(
                f"answer file count mismatch: sections={len(ordered_sections)} files={len(answer_files)}"
            )
        section_to_file = dict(zip(ordered_sections, answer_files, strict=True))
    else:
        section_to_file = answer_files

    for section_key, section_questions in grouped.items():
        answers = parse_answer_pdf(section_to_file[section_key], len(section_questions))
        for question, answer in zip(section_questions, answers, strict=True):
            result[(section_key, question.local_number)] = answer
    return result


def build_rows(
    *,
    questions: list[ParsedQuestion],
    answers: dict[tuple[str, int], ParsedAnswer],
    source_name: str,
    subcategory_id: str,
    id_prefix: str,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for question in questions:
        answer = answers[(question.section_key, question.local_number)]
        section_label = question.section_title
        row = {
            "id": stable_id(f"{id_prefix}/{question.section_key}/{question.local_number}"),
            "category_id": JUDGMENT_CATEGORY_ID,
            "subcategory_id": subcategory_id,
            "question_number": question.global_number,
            "question_type": "single_choice",
            "question_text": f"【{section_label}】{question.question_text}",
            "question_image": "",
            "option_a": question.options["A"],
            "option_b": question.options["B"],
            "option_c": question.options["C"],
            "option_d": question.options["D"],
            "option_a_image": "",
            "option_b_image": "",
            "option_c_image": "",
            "option_d_image": "",
            "answer_key": answer.answer_key,
            "explanation": answer.explanation,
            "difficulty": 2,
            "question_status": 0,
            "source_name": source_name,
            "source_page": question.source_page,
            "created_time": CREATED_TIME,
            "update_time": CREATED_TIME,
        }
        row.update(QUESTION_FIXES.get((source_name, question.global_number), {}))
        rows.append(row)
    return rows


def main() -> None:
    analogy_questions = parse_question_pdf(ANALOGY_QUESTION_PDF)
    logic_questions = parse_question_pdf(LOGIC_QUESTION_PDF)

    analogy_answers = attach_answers_by_section(analogy_questions, analogy_answer_files())
    logic_answers = attach_answers_by_section(logic_questions, logic_answer_file_map())

    analogy_rows = build_rows(
        questions=analogy_questions,
        answers=analogy_answers,
        source_name=ANALOGY_SOURCE_NAME,
        subcategory_id=ANALOGY_SUBCATEGORY_ID,
        id_prefix="analogy",
    )
    logic_rows = build_rows(
        questions=logic_questions,
        answers=logic_answers,
        source_name=LOGIC_SOURCE_NAME,
        subcategory_id=LOGIC_SUBCATEGORY_ID,
        id_prefix="logic",
    )

    data = load_seed(SEED_PATH)
    tables = data["tables"]
    existing = [
        row
        for row in tables.get("aptitude_question", [])
        if row.get("source_name") not in {ANALOGY_SOURCE_NAME, LOGIC_SOURCE_NAME}
    ]
    tables["aptitude_question"] = existing + analogy_rows + logic_rows
    save_seed(data, SEED_PATH)

    print(f"Imported analogy questions: {len(analogy_rows)}")
    print(f"Imported logic questions: {len(logic_rows)}")
    print(f"Total aptitude questions: {len(tables['aptitude_question'])}")


if __name__ == "__main__":
    main()
