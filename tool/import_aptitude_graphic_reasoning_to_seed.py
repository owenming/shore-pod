#!/usr/bin/env python3
import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from split_seed_io import load_seed, save_seed

import pdfplumber
from PIL import Image, ImageChops
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "assets/data/shore_pod_seed.json"
QUESTION_ROOT = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目/判断/图形推理"
)
ANSWER_ROOT = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案/判断/图形推理"
)
IMAGE_ASSET_DIR = ROOT / "assets/images/aptitude/graphic_reasoning"
IMAGE_ASSET_PREFIX = "assets/images/aptitude/graphic_reasoning"
PDFTOPPM = (
    ROOT
    / "../.."
    / ".cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdftoppm"
).resolve()

SOURCE_NAME = "粉笔行测两万五-图形推理"
CREATED_TIME = "2026-07-01T00:00:00.000000+08:00"
JUDGMENT_CATEGORY_ID = "7e2546db-57f4-5c94-9493-bedbc79bb12e"
GRAPHIC_SUBCATEGORY_ID = "0dfea451-b390-52e6-a85b-ccd26d296e0a"

PAGE_TOP = 72.0
PAGE_BOTTOM = 790.0
PAGE_LEFT = 32.0
PAGE_RIGHT = 562.0
RENDER_DPI = 120


@dataclass
class BatchConfig:
    slug: str
    label: str
    question_pdf: Path
    answer_dir: Path
    answer_pattern: str


@dataclass
class QuestionStart:
    section_key: str
    section_title: str
    local_number: int
    page_number: int
    top: float
    prompt: str


@dataclass
class ParsedAnswer:
    answer_key: str
    explanation: str


BATCHES = [
    BatchConfig(
        slug="position_style_attribute_quantity",
        label="位置+样式+属性+数量",
        question_pdf=QUESTION_ROOT / "位置+样式+属性+数量PDF.pdf",
        answer_dir=ANSWER_ROOT / "位置+样式+属性+数量",
        answer_pattern="位置+样式+属性+数量*.pdf",
    ),
    BatchConfig(
        slug="graphic_other",
        label="图形推理-其他",
        question_pdf=QUESTION_ROOT / "图形推理-其他.pdf",
        answer_dir=ANSWER_ROOT / "图形推理-其他",
        answer_pattern="图形推理-其他.pdf",
    ),
    BatchConfig(
        slug="text_letter_number",
        label="文字、字母、数字类",
        question_pdf=QUESTION_ROOT / "文字、字母、数字类PDF.pdf",
        answer_dir=ANSWER_ROOT / "文字、字母、数字类",
        answer_pattern="文字、字母、数字类*.pdf",
    ),
    BatchConfig(
        slug="special_pattern",
        label="特殊规律",
        question_pdf=QUESTION_ROOT / "特殊规律PDF.pdf",
        answer_dir=ANSWER_ROOT / "特殊规律",
        answer_pattern="特殊规律*.pdf",
    ),
    BatchConfig(
        slug="spatial",
        label="空间类",
        question_pdf=QUESTION_ROOT / "空间类PDF.pdf",
        answer_dir=ANSWER_ROOT / "空间类",
        answer_pattern="空间类*.pdf",
    ),
    BatchConfig(
        slug="black_white_block",
        label="黑白块类",
        question_pdf=QUESTION_ROOT / "黑白块类PDF.pdf",
        answer_dir=ANSWER_ROOT / "黑白块类",
        answer_pattern="黑白块类*.pdf",
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
    value = re.sub(r"(?m)^\s*更多其他考试资料.*$", "", value)
    value = re.sub(r"(?m)^\s*更多资料添加.*$", "", value)
    value = re.sub(r"(?m)^\s*vx:bishengkejian\s*$", "", value)
    value = re.sub(r"[ \t]{2,}", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def page_texts(pdf_path: Path) -> list[str]:
    reader = PdfReader(str(pdf_path))
    return [page.extract_text() or "" for page in reader.pages]


def page_lines(page) -> list[tuple[str, float, float, float]]:
    words = page.extract_words(x_tolerance=1, y_tolerance=3) or []
    lines: list[list[dict]] = []
    for word in sorted(words, key=lambda item: (item["top"], item["x0"])):
        if not lines or abs(float(lines[-1][0]["top"]) - float(word["top"])) > 4:
            lines.append([word])
        else:
            lines[-1].append(word)
    rendered: list[tuple[str, float, float, float]] = []
    for line in lines:
        sorted_line = sorted(line, key=lambda item: item["x0"])
        text = "".join(item["text"] for item in sorted_line)
        rendered.append(
            (
                text,
                min(float(item["x0"]) for item in sorted_line),
                min(float(item["top"]) for item in sorted_line),
                max(float(item["bottom"]) for item in sorted_line),
            )
        )
    return rendered


def normalize_title(title: str) -> str:
    return re.sub(r"\s+", "", title).replace("_", "、")


def parse_question_starts(config: BatchConfig) -> list[QuestionStart]:
    starts: list[QuestionStart] = []
    current_section_key = ""
    current_section_title = ""
    section_index = 0
    with pdfplumber.open(config.question_pdf) as pdf:
        for page_number, page in enumerate(pdf.pages, start=1):
            for text, x0, top, _ in page_lines(page):
                title_match = re.search(r"专项智能练习（([^\n）]+)）", text)
                if title_match:
                    title = normalize_title(title_match.group(1))
                    has_number = bool(re.search(r"\d+$", title))
                    title_base = re.sub(r"\d+$", "", title)
                    current_base = re.sub(r"\d+$", "", current_section_title)
                    if (
                        not current_section_key
                        or has_number
                        or (title != current_section_title and title_base != current_base)
                    ):
                        section_index += 1
                        current_section_key = f"{section_index:03d}"
                        current_section_title = title

                question_match = re.match(r"^\s*(\d{1,3})[.．]\s*(.*)", text)
                if question_match and x0 < 92:
                    if not current_section_key:
                        section_index += 1
                        current_section_key = f"{section_index:03d}"
                        current_section_title = config.label
                    starts.append(
                        QuestionStart(
                            section_key=current_section_key,
                            section_title=current_section_title,
                            local_number=int(question_match.group(1)),
                            page_number=page_number,
                            top=top,
                            prompt=clean_text(question_match.group(2)),
                        )
                    )
    return starts


def render_page(pdf_path: Path, page_number: int, output_dir: Path) -> Path:
    prefix = output_dir / f"{pdf_path.stem}_page_{page_number:04d}"
    output = prefix.with_suffix(".png")
    if output.exists():
        return output
    subprocess.run(
        [
            str(PDFTOPPM),
            "-png",
            "-r",
            str(RENDER_DPI),
            "-f",
            str(page_number),
            "-l",
            str(page_number),
            "-singlefile",
            str(pdf_path),
            str(prefix),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return output


def render_pdf_pages(pdf_path: Path, output_dir: Path) -> dict[int, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = output_dir / re.sub(r"[^A-Za-z0-9_]+", "_", pdf_path.stem)
    if not prefix.with_name(f"{prefix.name}-1.png").exists():
        subprocess.run(
            [
                str(PDFTOPPM),
                "-png",
                "-r",
                str(RENDER_DPI),
                str(pdf_path),
                str(prefix),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    rendered: dict[int, Path] = {}
    for path in output_dir.glob(f"{prefix.name}-*.png"):
        match = re.search(r"-(\d+)\.png$", path.name)
        if match:
            rendered[int(match.group(1))] = path
    if not rendered:
        raise RuntimeError(f"failed to render {pdf_path}")
    return rendered


def near_white_trim(image: Image.Image, padding: int = 10) -> Image.Image:
    rgb = image.convert("RGB")
    mask = rgb.convert("L").point(lambda value: 255 if value < 225 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return rgb
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(rgb.width, bbox[2] + padding)
    bottom = min(rgb.height, bbox[3] + padding)
    return rgb.crop((left, top, right, bottom))


def vertical_join(images: list[Image.Image]) -> Image.Image:
    if len(images) == 1:
        return images[0]
    width = max(image.width for image in images)
    height = sum(image.height for image in images) + (len(images) - 1) * 12
    joined = Image.new("RGB", (width, height), "white")
    y = 0
    for image in images:
        joined.paste(image, (0, y))
        y += image.height + 12
    return joined


def crop_question_image(
    *,
    config: BatchConfig,
    question: QuestionStart,
    next_question: QuestionStart | None,
    rendered_pages: dict[int, Path],
    page_count: int,
    page_width: float,
    page_height: float,
    output_name: str,
) -> str:
    start_page = question.page_number
    end_page = next_question.page_number if next_question else page_count
    crops: list[Image.Image] = []
    for page_number in range(start_page, end_page + 1):
        if page_number == start_page:
            top = max(PAGE_TOP, question.top - 8)
        else:
            top = PAGE_TOP
        if next_question and page_number == next_question.page_number:
            bottom = max(top + 12, next_question.top - 8)
        else:
            bottom = min(PAGE_BOTTOM, page_height - 42)
        if bottom <= top + 12:
            continue

        rendered_path = rendered_pages[page_number]
        with Image.open(rendered_path) as page_image:
            scale_x = page_image.width / page_width
            scale_y = page_image.height / page_height
            box = (
                int(PAGE_LEFT * scale_x),
                int(top * scale_y),
                int(PAGE_RIGHT * scale_x),
                int(bottom * scale_y),
            )
            crops.append(near_white_trim(page_image.crop(box).convert("RGB")))
    if not crops:
        raise RuntimeError(f"empty crop for {config.label} {question.local_number}")
    image = near_white_trim(vertical_join(crops))
    if image.width > 980:
        new_height = max(1, int(image.height * 980 / image.width))
        image = image.resize((980, new_height), Image.Resampling.LANCZOS)
    output_path = IMAGE_ASSET_DIR / output_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, optimize=True, compress_level=9)
    return f"{IMAGE_ASSET_PREFIX}/{output_name}"


ANSWER_START_TEMPLATE = (
    r"(?m)^\s*(?:\uf0b7|)?\s*{number}\s*"
    r"(?:[.．]|(?=\n\s*正确答案){bare_gap})\s*"
    r"(?:\n\s*)?(?:正确答案(?:是|为)?\s*[:：]?\s*)?([A-D])?"
)
ANSWER_KEY_RE = re.compile(r"正确答案(?:是|为)?\s*[:：]?\s*([A-D])")
ANSWER_KEY_FALLBACK_RE = re.compile(r"故正确(?:答案|选项)(?:是|为|选)\s*([A-D])")
ANSWER_KEY_THIS_RE = re.compile(r"(?:故)?本题答案(?:是|为)\s*([A-D])")
ANSWER_OPTION_CORRECT_RE = re.compile(r"([A-D])\s*项[^。]*(?:正确|当选|符合)")
ANSWER_OPTION_TARGET_RE = re.compile(r"对应\s*([A-D])\s*选?项")
ANSWER_OPTION_RESULT_RE = re.compile(r"将\s*([A-D])\s*项[^。]*(?:得到|符合)")
ANSWER_OVERRIDES = {
    ("特殊规律2.pdf", 36): "B",
    ("空间类8.pdf", 28): "A",
}


def parse_answer_pdf(pdf_path: Path, expected_count: int) -> list[ParsedAnswer]:
    text = clean_text("\n".join(page_texts(pdf_path)))
    starts: list[re.Match[str]] = []
    position = 0
    for expected in range(1, expected_count + 1):
        bare_gap = r"|(?=\s+[^\s、，,：:])" if expected >= 10 else ""
        pattern = re.compile(
            ANSWER_START_TEMPLATE.format(number=expected, bare_gap=bare_gap)
        )
        match = pattern.search(text, position)
        if match is None:
            break
        starts.append(match)
        position = match.end()

    if len(starts) != expected_count:
        keys = ANSWER_KEY_FALLBACK_RE.findall(text)
        if len(keys) < expected_count:
            keys = ANSWER_KEY_RE.findall(text)
        if len(keys) >= expected_count:
            return [
                ParsedAnswer(answer_key=keys[index], explanation="")
                for index in range(expected_count)
            ]
        raise RuntimeError(
            f"{pdf_path} expected {expected_count} answers, got starts={len(starts)} keys={len(keys)}"
        )

    answers: list[ParsedAnswer] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        segment = clean_text(text[match.start() : end])
        key = match.group(1) or ""
        key_match = (
            ANSWER_KEY_RE.search(segment)
            or ANSWER_KEY_FALLBACK_RE.search(segment)
            or ANSWER_KEY_THIS_RE.search(segment)
            or ANSWER_OPTION_CORRECT_RE.search(segment)
            or ANSWER_OPTION_TARGET_RE.search(segment)
            or ANSWER_OPTION_RESULT_RE.search(segment)
        )
        if key_match:
            key = key_match.group(1)
        if not key:
            key = ANSWER_OVERRIDES.get((pdf_path.name, index + 1), "")
        if not key:
            raise RuntimeError(f"missing answer key in {pdf_path} item {index + 1}")
        answers.append(ParsedAnswer(answer_key=key, explanation=segment))
    return answers


def grouped_questions(starts: list[QuestionStart]) -> dict[str, list[QuestionStart]]:
    grouped: dict[str, list[QuestionStart]] = {}
    for start in starts:
        grouped.setdefault(start.section_key, []).append(start)
    return grouped


def answer_files(config: BatchConfig) -> list[Path]:
    return sorted(config.answer_dir.glob(config.answer_pattern), key=natural_key)


def rows_for_batch(
    config: BatchConfig,
    *,
    global_start: int,
    render_dir: Path,
) -> list[dict[str, object]]:
    starts = parse_question_starts(config)
    with pdfplumber.open(config.question_pdf) as pdf:
        page_count = len(pdf.pages)
        page_width = float(pdf.pages[0].width)
        page_height = float(pdf.pages[0].height)
    rendered_pages = render_pdf_pages(config.question_pdf, render_dir / config.slug)
    sections = grouped_questions(starts)
    files = answer_files(config)
    ordered_section_keys = sorted(sections.keys(), key=lambda value: int(value))
    if len(ordered_section_keys) != len(files):
        raise RuntimeError(
            f"{config.label}: sections={len(ordered_section_keys)} answer_files={len(files)}"
        )

    answers_by_question: dict[tuple[str, int], ParsedAnswer] = {}
    for section_key, answer_file in zip(ordered_section_keys, files, strict=True):
        section_questions = sections[section_key]
        answers = parse_answer_pdf(answer_file, len(section_questions))
        for question, answer in zip(section_questions, answers, strict=True):
            answers_by_question[(section_key, question.local_number)] = answer

    rows: list[dict[str, object]] = []
    for index, question in enumerate(starts):
        next_question = starts[index + 1] if index + 1 < len(starts) else None
        global_number = global_start + len(rows)
        image_name = f"{config.slug}_q{global_number:04d}.png"
        question_image = crop_question_image(
            config=config,
            question=question,
            next_question=next_question,
            rendered_pages=rendered_pages,
            page_count=page_count,
            page_width=page_width,
            page_height=page_height,
            output_name=image_name,
        )
        answer = answers_by_question[(question.section_key, question.local_number)]
        rows.append(
            {
                "id": stable_id(f"graphic/{config.slug}/{question.section_key}/{question.local_number}"),
                "category_id": JUDGMENT_CATEGORY_ID,
                "subcategory_id": GRAPHIC_SUBCATEGORY_ID,
                "question_number": global_number,
                "question_type": "single_choice",
                "question_text": f"【图形推理-{config.label}】请根据题图选择答案。",
                "question_image": question_image,
                "option_a": "A",
                "option_b": "B",
                "option_c": "C",
                "option_d": "D",
                "option_a_image": "",
                "option_b_image": "",
                "option_c_image": "",
                "option_d_image": "",
                "answer_key": answer.answer_key,
                "explanation": answer.explanation,
                "difficulty": 2,
                "question_status": 0,
                "source_name": SOURCE_NAME,
                "source_page": question.page_number,
                "created_time": CREATED_TIME,
                "update_time": CREATED_TIME,
            }
        )
    return rows


def main() -> None:
    if IMAGE_ASSET_DIR.exists():
        shutil.rmtree(IMAGE_ASSET_DIR)
    IMAGE_ASSET_DIR.mkdir(parents=True, exist_ok=True)

    all_rows: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory() as tmp:
        render_dir = Path(tmp)
        for config in BATCHES:
            rows = rows_for_batch(
                config,
                global_start=len(all_rows) + 1,
                render_dir=render_dir,
            )
            all_rows.extend(rows)
            print(f"{config.label}: {len(rows)}")

    data = load_seed(SEED_PATH)
    tables = data["tables"]
    existing = [
        row
        for row in tables.get("aptitude_question", [])
        if row.get("source_name") != SOURCE_NAME
    ]
    tables["aptitude_question"] = existing + all_rows
    save_seed(data, SEED_PATH)

    print(f"Imported graphic reasoning questions: {len(all_rows)}")
    print(f"Total aptitude questions: {len(tables['aptitude_question'])}")


if __name__ == "__main__":
    main()
