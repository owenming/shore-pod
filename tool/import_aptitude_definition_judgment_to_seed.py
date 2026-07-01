#!/usr/bin/env python3
import json
import re
import subprocess
import tempfile
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

import pdfplumber
from pypdf import PdfReader
from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "assets/data/shore_pod_seed.json"
QUESTION_PDF = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/题目/行测题目/判断/定义判断PDF298页.pdf"
)
ANSWER_DIR = Path(
    "/Users/ming/公基资料/【粉笔行测两万五】/答案/行测答案/判断/定义判断"
)
SOURCE_NAME = "粉笔行测两万五-定义判断"
CREATED_TIME = "2026-07-01T00:00:00.000000+08:00"
IMAGE_ASSET_DIR = ROOT / "assets/images/aptitude/definition_judgment"
IMAGE_ASSET_PREFIX = "assets/images/aptitude/definition_judgment"
PDFTOPPM = (
    ROOT
    / "../.."
    / ".cache/codex-runtimes/codex-primary-runtime/dependencies/bin/pdftoppm"
).resolve()


def stable_id(value: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"shore-pod/aptitude-question/{value}"))


def clean_text(value: str) -> str:
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    value = value.replace("（ ", "（").replace(" ）", "）")
    return value.strip()


def strip_option_label(value: str) -> str:
    return clean_text(re.sub(r"^[A-D][.．]\s*", "", value.strip()))


def trim_whitespace(image: Image.Image, padding: int = 8) -> Image.Image:
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


def render_page(page_number: int, output_dir: Path, dpi: int = 180) -> Path:
    prefix = output_dir / f"definition_judgment_page_{page_number:03d}"
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


def crop_option_image(
    *,
    question_number: int,
    option_label: str,
    label_word: dict,
    next_boundary: dict | None,
    page_width: float,
    page_height: float,
    render_dir: Path,
) -> str:
    page_number = int(label_word["page_number"])
    rendered_path = render_page(page_number, render_dir)
    with Image.open(rendered_path) as page_image:
        scale_x = page_image.width / page_width
        scale_y = page_image.height / page_height
        top = max(float(label_word["top"]) - 4, 0)
        if next_boundary is not None and next_boundary["page_number"] == page_number:
            bottom = max(float(next_boundary["top"]) - 5, top + 20)
        else:
            bottom = page_height - 48
        crop_box = (
            int(55 * scale_x),
            int(top * scale_y),
            int(550 * scale_x),
            int(bottom * scale_y),
        )
        cropped = page_image.crop(crop_box)
        cropped = trim_whitespace(cropped)
        output_name = f"definition_judgment_q{question_number:04d}_{option_label.lower()}.png"
        output_path = IMAGE_ASSET_DIR / output_name
        output_path.parent.mkdir(parents=True, exist_ok=True)
        cropped.save(output_path)
        return f"{IMAGE_ASSET_PREFIX}/{output_name}"


def words_to_text(words: list[dict]) -> str:
    if not words:
        return ""
    lines: list[list[dict]] = []
    for word in sorted(words, key=lambda item: (item["doctop"], item["x0"])):
        if not lines or abs(lines[-1][0]["doctop"] - word["doctop"]) > 3:
            lines.append([word])
        else:
            lines[-1].append(word)
    rendered = []
    for line in lines:
        pieces = [item["text"] for item in sorted(line, key=lambda item: item["x0"])]
        rendered.append("".join(pieces))
    return clean_text("\n".join(rendered))


def extract_question_rows(
    category_id: str,
    subcategory_id: str,
    answers: dict[int, dict[str, str]],
) -> list[dict]:
    all_words: list[dict] = []
    markers: list[dict] = []
    current_set_number = 1
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
                title_match = re.search(r"专项智能练习（定义判断(\d+)）", word["text"])
                if title_match:
                    current_set_number = int(title_match.group(1))
            for word in words:
                text = word["text"].strip()
                if not text:
                    continue
                if "专项智能练习" in text or word["top"] > 790:
                    continue
                item = dict(word)
                item["page_number"] = page_index
                all_words.append(item)
                if word["x0"] < 42 and re.fullmatch(r"\d+[.．]", text):
                    local_number = int(text[:-1])
                    markers.append(
                        {
                            "number": (current_set_number - 1) * 40
                            + local_number,
                            "local_number": local_number,
                            "set_number": current_set_number,
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
    for old_image in IMAGE_ASSET_DIR.glob("definition_judgment_q*.png"):
        old_image.unlink()

    with tempfile.TemporaryDirectory(prefix="shore_pod_aptitude_pages_") as tmp:
        render_dir = Path(tmp)
        for index, marker in enumerate(markers):
            next_marker = markers[index + 1] if index + 1 < len(markers) else None
            next_doctop = next_marker["doctop"] if next_marker else float("inf")
            number = marker["number"]
            chunk = [
                word
                for word in all_words
                if marker["doctop"] - 0.2 <= word["doctop"] < next_doctop - 0.2
                and not (
                    word["x0"] < 42
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
                    f"question {number}: expected A-D markers, got {labels[:8]}"
                )
                continue
            option_indexes = option_indexes[:4]
            question_text = words_to_text(chunk[: option_indexes[0]])
            option_images = {"A": "", "B": "", "C": "", "D": ""}
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
            for option_position, option_label in enumerate(["A", "B", "C", "D"]):
                if options[option_label]:
                    continue
                label_word = chunk[option_indexes[option_position]]
                if option_position < 3:
                    next_boundary = chunk[option_indexes[option_position + 1]]
                else:
                    next_boundary = next_marker
                option_images[option_label] = crop_option_image(
                    question_number=number,
                    option_label=option_label,
                    label_word=label_word,
                    next_boundary=next_boundary,
                    page_width=page_width,
                    page_height=page_height,
                    render_dir=render_dir,
                )
                options[option_label] = f"图片选项{option_label}"
            answer = answers.get(number)
            if answer is None:
                parse_errors.append(f"question {number}: missing answer")
                continue
            if not question_text or any(not value for value in options.values()):
                parse_errors.append(f"question {number}: empty question or option")
                continue
            rows.append(
                {
                    "id": stable_id(f"definition-judgment/{number}"),
                    "category_id": category_id,
                    "subcategory_id": subcategory_id,
                    "question_number": number,
                    "question_type": "single_choice",
                    "question_text": question_text,
                    "option_a": options["A"],
                    "option_b": options["B"],
                    "option_c": options["C"],
                    "option_d": options["D"],
                    "option_a_image": option_images["A"],
                    "option_b_image": option_images["B"],
                    "option_c_image": option_images["C"],
                    "option_d_image": option_images["D"],
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
        preview = "\n".join(parse_errors[:20])
        raise RuntimeError(f"question parse failed:\n{preview}")
    return rows


def extract_answers() -> dict[int, dict[str, str]]:
    answer_files = sorted(
        ANSWER_DIR.glob("定义判断*.pdf"),
        key=lambda item: int(re.search(r"\d+", item.stem).group(0)),
    )
    answers: dict[int, dict[str, str]] = {}
    for answer_file in answer_files:
        file_number = int(re.search(r"\d+", answer_file.stem).group(0))
        base_number = (file_number - 1) * 40
        reader = PdfReader(str(answer_file))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        text = re.sub(r"(?im)^\s*vx:bishengkejian\s*$", "", text)
        raw_matches = list(re.finditer(r"(?m)^\s*(\d+)[.．]\s*", text))
        matches = []
        expected_number = 1
        for match in raw_matches:
            if int(match.group(1)) == expected_number:
                matches.append(match)
                expected_number += 1
        for index, match in enumerate(matches):
            local_number = int(match.group(1))
            start = match.end()
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            segment = clean_text(text[start:end])
            answer_match = re.search(r"(?:故正确答案为|故本题答案为|本题答案为)\s*([A-D])", segment)
            if not answer_match:
                answer_match = re.search(r"([A-D])\s*项[:：][\s\S]{0,260}?当选", segment)
            if not answer_match:
                raise RuntimeError(f"missing answer key in {answer_file.name} #{local_number}")
            global_number = base_number + local_number
            answers[global_number] = {
                "answer_key": answer_match.group(1),
                "explanation": segment,
            }
    return answers


def main() -> None:
    seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
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
        and row.get("subcategory_title") == "定义判断"
    )

    answers = extract_answers()
    rows = extract_question_rows(category["id"], subcategory["id"], answers)
    missing_answers = sorted(set(answers) - {row["question_number"] for row in rows})
    if missing_answers:
        raise RuntimeError(f"answers without questions: {missing_answers[:20]}")

    rows.sort(key=lambda row: row["question_number"])
    tables["aptitude_question"] = rows
    SEED_PATH.write_text(
        json.dumps(seed, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"imported {len(rows)} questions into {SEED_PATH}")
    print("first:", rows[0]["question_text"][:80], rows[0]["answer_key"])
    print("last:", rows[-1]["question_number"], rows[-1]["answer_key"])


if __name__ == "__main__":
    main()
