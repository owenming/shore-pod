#!/usr/bin/env python3
import json
import re
import subprocess
import tempfile
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from split_seed_io import load_seed, save_seed

import pdfplumber
from PIL import Image, ImageChops, ImageDraw
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "assets/data/shore_pod_seed.json"
QUESTION_PDF = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目/判断/科学推理PDF80页.pdf"
)
ANSWER_DIR = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案/判断/科学推理"
)
SOURCE_NAME = "粉笔行测两万五-科学推理"
CREATED_TIME = "2026-07-01T00:00:00.000000+08:00"
IMAGE_ASSET_DIR = ROOT / "assets/images/aptitude/science_reasoning"
IMAGE_ASSET_PREFIX = "assets/images/aptitude/science_reasoning"
PDFTOPPM = (
    ROOT
    / "../.."
    / ".cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdftoppm"
).resolve()

SECTION_LABELS = {
    "physics1": "物理1",
    "physics2": "物理2",
    "physics3": "物理3",
    "physics4": "物理4",
    "physics5": "物理5",
    "physics6": "物理6",
    "chemistry": "化学",
    "biology": "生物",
    "geography": "地理",
}
SECTION_ORDER = {
    "physics1": 0,
    "physics2": 40,
    "physics3": 80,
    "physics4": 120,
    "physics5": 160,
    "physics6": 200,
    "chemistry": 220,
    "biology": 257,
    "geography": 280,
}


def stable_id(value: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"shore-pod/aptitude-question/{value}"))


def clean_text(value: str) -> str:
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    value = re.sub(r"(?m)^\s*(?:vx:bishengkejian|高分课程)\s*$", "", value)
    value = re.sub(r"(?m)^\s*更多其他考试资料.*$", "", value)
    value = value.replace("（ ", "（").replace(" ）", "）")
    return value.strip()


def strip_option_label(value: str) -> str:
    return clean_text(re.sub(r"^[A-D][.．]\s*", "", value.strip()))


def section_from_title(text: str, current: str | None) -> str | None:
    if text.startswith("物理"):
        match = re.search(r"物理(\d+)", text)
        return f"physics{match.group(1)}" if match else current
    if text == "化学":
        return "chemistry"
    if text == "生物":
        return "biology"
    if text == "地理":
        return "geography"
    return current


def answer_file_section(path: Path) -> str:
    name = path.name
    if match := re.search(r"物理(\d+)", name):
        return f"physics{match.group(1)}"
    if "化学" in name:
        return "chemistry"
    if "生物" in name:
        return "biology"
    if "地理" in name:
        return "geography"
    raise RuntimeError(f"unknown answer section: {path}")


def trim_whitespace(image: Image.Image, padding: int = 10) -> Image.Image:
    rgb = image.convert("RGB")
    background = Image.new("RGB", rgb.size, "white")
    diff = ImageChops.difference(rgb, background)
    bbox = diff.getbbox()
    if bbox is None:
        return rgb
    left = max(bbox[0] - padding, 0)
    top = max(bbox[1] - padding, 0)
    right = min(bbox[2] + padding, rgb.width)
    bottom = min(bbox[3] + padding, rgb.height)
    return rgb.crop((left, top, right, bottom))


def content_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    rgb = image.convert("RGB")
    background = Image.new("RGB", rgb.size, "white")
    diff = ImageChops.difference(rgb, background)
    return diff.getbbox()


def render_page(page_number: int, output_dir: Path, dpi: int = 120) -> Path:
    prefix = output_dir / f"science_reasoning_page_{page_number:03d}"
    output = prefix.with_suffix(".png")
    if output.exists():
        return output
    subprocess.run(
        [
            str(PDFTOPPM),
            "-png",
            "-r",
            str(dpi),
            "-f",
            str(page_number),
            "-l",
            str(page_number),
            "-singlefile",
            str(QUESTION_PDF),
            str(prefix),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return output


def main_text_bottom(words: list[dict], page_number: int, option_top: float) -> float:
    lines: list[list[dict]] = []
    for word in sorted(
        [item for item in words if int(item["page_number"]) == page_number],
        key=lambda item: (item["top"], item["x0"]),
    ):
        if float(word["top"]) >= option_top:
            continue
        if not lines or abs(float(lines[-1][0]["top"]) - float(word["top"])) > 4:
            lines.append([word])
        else:
            lines[-1].append(word)
    candidates: list[float] = []
    for line in lines:
        text = "".join(item["text"] for item in sorted(line, key=lambda item: item["x0"]))
        width = max(float(item["x1"]) for item in line) - min(
            float(item["x0"]) for item in line
        )
        compact = re.sub(r"\s+", "", text)
        if (
            len(compact) >= 8
            or width >= 180
            or compact.endswith(("的是：", "的是:", "的是。", "的是"))
        ):
            candidates.append(max(float(item["bottom"]) for item in line))
    if candidates:
        return max(candidates)
    if lines:
        return max(float(item["bottom"]) for line in lines for item in line)
    return option_top


def crop_question_image(
    *,
    section: str,
    local_number: int,
    question_words: list[dict],
    option_a_word: dict,
    page_width: float,
    render_dir: Path,
) -> str:
    if not question_words:
        return ""
    page_number = int(option_a_word["page_number"])
    same_page_question_words = [
        word for word in question_words if int(word["page_number"]) == page_number
    ]
    if same_page_question_words:
        main_bottom = main_text_bottom(
            question_words, page_number, float(option_a_word["top"])
        )
        top = main_bottom + 4
    else:
        main_bottom = 0.0
        top = 96
    bottom = float(option_a_word["top"]) - 5
    if bottom - top < 24:
        return ""

    rendered_path = render_page(page_number, render_dir)
    with Image.open(rendered_path) as page_image:
        scale_x = page_image.width / page_width
        scale_y = page_image.height / float(option_a_word["page_height"])
        crop_box = (
            int(34 * scale_x),
            int(top * scale_y),
            int(560 * scale_x),
            int(bottom * scale_y),
        )
        combined = page_image.crop(crop_box).convert("RGB")
    draw = ImageDraw.Draw(combined)
    if same_page_question_words:
        for word in same_page_question_words:
            if abs(float(word["bottom"]) - main_bottom) > 4:
                continue
            left = int(float(word["x0"]) * scale_x) - crop_box[0] - 3
            top_px = int((float(word["top"]) - 2) * scale_y) - crop_box[1]
            right = int(float(word["x1"]) * scale_x) - crop_box[0] + 3
            bottom_px = int((float(word["bottom"]) + 8) * scale_y) - crop_box[1]
            draw.rectangle((left, top_px, right, bottom_px), fill="white")
    bbox = content_bbox(combined)
    if bbox is None:
        return ""
    if bbox[2] - bbox[0] < 24 or bbox[3] - bbox[1] < 24:
        return ""
    combined = trim_whitespace(combined)
    output_name = f"science_reasoning_{section}_q{local_number:04d}.png"
    output_path = IMAGE_ASSET_DIR / output_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    combined.save(output_path, optimize=True, compress_level=9)
    return f"{IMAGE_ASSET_PREFIX}/{output_name}"


def words_to_text(words: list[dict]) -> str:
    if not words:
        return ""
    lines: list[list[dict]] = []
    for word in sorted(words, key=lambda item: (item["doctop"], item["x0"])):
        text = word["text"].strip()
        if not text:
            continue
        if "专项智能练习" in text or "更多其他考试资料" in text:
            continue
        if text in {"vx:bishengkejian", "高分课程"}:
            continue
        if not lines or abs(lines[-1][0]["doctop"] - word["doctop"]) > 3:
            lines.append([word])
        else:
            lines[-1].append(word)
    rendered = []
    for line in lines:
        pieces = [item["text"] for item in sorted(line, key=lambda item: item["x0"])]
        rendered.append("".join(pieces))
    return clean_text("\n".join(rendered))


def extract_answers() -> dict[tuple[str, int], dict[str, str]]:
    answer_files = sorted(ANSWER_DIR.glob("**/*.pdf"))
    answers: dict[tuple[str, int], dict[str, str]] = {}
    for answer_file in answer_files:
        section = answer_file_section(answer_file)
        reader = PdfReader(str(answer_file))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        text = clean_text(text)
        matches = list(
            re.finditer(
                r"(?m)^\s*(?:[•]\s*)?(\d+)\s*[.．]?\s*正确答案是[:：]\s*([A-D])",
                text,
            )
        )
        for index, match in enumerate(matches):
            local_number = int(match.group(1))
            start = match.start()
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            segment = clean_text(text[start:end])
            answers[(section, local_number)] = {
                "answer_key": match.group(2),
                "explanation": segment,
            }
    return answers


def extract_question_rows(
    category_id: str,
    subcategory_id: str,
    answers: dict[tuple[str, int], dict[str, str]],
) -> list[dict]:
    all_words: list[dict] = []
    markers: list[dict] = []
    current_section: str | None = None
    page_width = 0.0
    page_height = 0.0
    with pdfplumber.open(QUESTION_PDF) as pdf:
        for page_index, page in enumerate(pdf.pages, start=1):
            page_width = float(page.width)
            page_height = float(page.height)
            words = page.extract_words(
                x_tolerance=2,
                y_tolerance=3,
                keep_blank_chars=False,
                use_text_flow=True,
            )
            for word in words:
                if title_match := re.search(
                    r"专项智能练习（科学推理-([^）]+)）", word["text"]
                ):
                    current_section = section_from_title(
                        title_match.group(1), current_section
                    )
            for word in words:
                text = word["text"].strip()
                if not text:
                    continue
                if word["top"] < 68 or word["top"] > 795:
                    continue
                item = dict(word)
                item["page_number"] = page_index
                item["page_height"] = page_height
                item["section"] = current_section
                all_words.append(item)
                if (
                    current_section is not None
                    and word["x0"] < 45
                    and re.fullmatch(r"\d+[.．]", text)
                ):
                    local_number = int(text[:-1])
                    markers.append(
                        {
                            "section": current_section,
                            "local_number": local_number,
                            "number": SECTION_ORDER[current_section] + local_number,
                            "top": word["top"],
                            "doctop": word["doctop"],
                            "x0": word["x0"],
                            "page_number": page_index,
                            "text": text,
                        }
                    )

    all_words.sort(key=lambda item: (item["doctop"], item["x0"]))
    markers.sort(key=lambda item: (item["doctop"], item["x0"]))
    rows: list[dict] = []
    parse_errors: list[str] = []
    IMAGE_ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for old_image in IMAGE_ASSET_DIR.glob("science_reasoning_*.png"):
        old_image.unlink()

    with tempfile.TemporaryDirectory(prefix="shore_pod_science_pages_") as tmp:
        render_dir = Path(tmp)
        for index, marker in enumerate(markers):
            next_marker = markers[index + 1] if index + 1 < len(markers) else None
            next_doctop = next_marker["doctop"] if next_marker else float("inf")
            section = marker["section"]
            local_number = marker["local_number"]
            chunk = [
                word
                for word in all_words
                if marker["doctop"] - 0.2 <= word["doctop"] < next_doctop - 0.2
                and not (
                    word["x0"] < 45
                    and word["doctop"] == marker["doctop"]
                    and word["text"].strip() == marker["text"]
                )
            ]
            option_indexes = [
                i
                for i, word in enumerate(chunk)
                if re.match(r"^[A-D][.．]", word["text"].strip())
            ]
            labels = [chunk[i]["text"].strip()[0] for i in option_indexes]
            if labels[:4] != ["A", "B", "C", "D"]:
                parse_errors.append(
                    f"{section} #{local_number}: expected A-D markers, got {labels[:8]}"
                )
                continue
            option_indexes = option_indexes[:4]
            options = {
                "A": strip_option_label(
                    words_to_text(chunk[option_indexes[0] : option_indexes[1]])
                ),
                "B": strip_option_label(
                    words_to_text(chunk[option_indexes[1] : option_indexes[2]])
                ),
                "C": strip_option_label(
                    words_to_text(chunk[option_indexes[2] : option_indexes[3]])
                ),
                "D": strip_option_label(words_to_text(chunk[option_indexes[3] :])),
            }
            for option_label in ["A", "B", "C", "D"]:
                if not options[option_label]:
                    options[option_label] = f"图片选项{option_label}"
            question_text = words_to_text(chunk[: option_indexes[0]])
            answer = answers.get((section, local_number))
            if answer is None:
                parse_errors.append(f"{section} #{local_number}: missing answer")
                continue
            if not question_text:
                parse_errors.append(f"{section} #{local_number}: empty question or option")
                continue
            question_image = crop_question_image(
                section=section,
                local_number=local_number,
                question_words=chunk[: option_indexes[0]],
                option_a_word=chunk[option_indexes[0]],
                page_width=page_width,
                render_dir=render_dir,
            )
            rows.append(
                {
                    "id": stable_id(f"science-reasoning/{section}/{local_number}"),
                    "category_id": category_id,
                    "subcategory_id": subcategory_id,
                    "question_number": marker["number"],
                    "question_type": "single_choice",
                    "question_text": f"【科学推理-{SECTION_LABELS[section]}】{question_text}",
                    "question_image": question_image,
                    "option_a": options["A"],
                    "option_b": options["B"],
                    "option_c": options["C"],
                    "option_d": options["D"],
                    "option_a_image": "",
                    "option_b_image": "",
                    "option_c_image": "",
                    "option_d_image": "",
                    "answer_key": answer["answer_key"],
                    "explanation": answer["explanation"],
                    "difficulty": 2,
                    "question_status": 0,
                    "source_name": SOURCE_NAME,
                    "source_page": marker["page_number"],
                    "created_time": CREATED_TIME,
                    "update_time": CREATED_TIME,
                }
            )

    if parse_errors:
        preview = "\n".join(parse_errors[:30])
        raise RuntimeError(f"science question parse failed:\n{preview}")
    return rows


def main() -> None:
    seed = load_seed(SEED_PATH)
    tables = seed.setdefault("tables", {})
    categories = tables.get("aptitude_category", [])
    subcategories = tables.get("aptitude_subcategory", [])
    category = next(
        row for row in categories if row.get("category_title") == "判断推理"
    )
    subcategory = next(
        row
        for row in subcategories
        if row.get("category_id") == category["id"]
        and row.get("subcategory_title") == "科学推理"
    )

    answers = extract_answers()
    rows = extract_question_rows(category["id"], subcategory["id"], answers)
    question_keys = {
        (row["id"], row["source_name"], row["question_number"]) for row in rows
    }
    if len(question_keys) != len(rows):
        raise RuntimeError("duplicate science question rows")

    expected_count = 288
    if len(rows) != expected_count:
        raise RuntimeError(f"expected {expected_count} rows, got {len(rows)}")

    existing = tables.get("aptitude_question", [])
    existing = [
        row
        for row in existing
        if row.get("source_name") != SOURCE_NAME
        and not str(row.get("id", "")).startswith(
            stable_id("science-reasoning/")[:8]
        )
    ]
    rows.sort(key=lambda row: row["question_number"])
    tables["aptitude_question"] = existing + rows
    save_seed(seed, SEED_PATH)
    print(f"imported {len(rows)} science reasoning questions into {SEED_PATH}")
    print("first:", rows[0]["question_text"][:80], rows[0]["answer_key"])
    print("last:", rows[-1]["question_number"], rows[-1]["answer_key"])


if __name__ == "__main__":
    main()
