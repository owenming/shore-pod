#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import re
import uuid
from pathlib import Path


DEFAULT_CANDIDATES = Path("build/knowledge_segment_candidates_preview.json")
DEFAULT_SEED = Path("assets/data/shore_pod_seed.json")
NAMESPACE = uuid.UUID("6f0816a5-87a9-4e7f-a726-3a6cb73f768b")


def deterministic_uuid(kind, key):
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{key}"))


def load_json(path):
    return json.loads(path.read_text())


def flatten_candidates(path):
    data = load_json(path)
    rows = []
    for article in data["articles"]:
        rows.extend(article["candidates"])
    return rows


def explicit_consumed_ids(seed, candidates):
    candidate_ids = {row["id"] for row in candidates}
    segments = seed["tables"].get("basic_knowledge_segment", [])
    segment_ids = {row["id"] for row in segments}
    consumed = set()
    for row in segments:
        for candidate_id in row.get("source_candidate_ids", []):
            if candidate_id in candidate_ids:
                consumed.add(candidate_id)
    for candidate in candidates:
        if deterministic_uuid("segment", candidate["id"]) in segment_ids:
            consumed.add(candidate["id"])
    return consumed


def clean_text(text):
    text = str(text)
    text = re.sub(r"\r\n?", "\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    text = re.sub(r"^[（(]?\d+[）).、]\s*", "", text.strip())
    text = re.sub(r"\s+", " ", text)
    text = text.replace("  ", " ")
    return text.strip(" ：:;；")


def trim_to(text, max_len):
    text = clean_text(text)
    if len(text) <= max_len:
        return text
    cut = text[:max_len]
    for mark in ["。", "；", ";", "，", ","]:
        index = cut.rfind(mark)
        if index >= 70:
            return cut[: index + 1]
    return cut.rstrip() + "。"


def visible_topic(candidate):
    topic = clean_text(candidate.get("topic") or "")
    title = clean_text(candidate.get("knowledge_title") or "常识考点")
    if not topic or len(topic) > 28:
        raw = clean_text(candidate.get("raw_text") or "")
        topic = re.split(r"[：:。；;，,]", raw, maxsplit=1)[0]
    topic = re.sub(r"^[（(]?\d+[）).、]\s*", "", topic)
    topic = topic.strip(" ：:;；")
    if not topic:
        topic = title
    return trim_to(topic, 24)


def build_content(candidate):
    topic = visible_topic(candidate)
    title = clean_text(candidate.get("knowledge_title") or "")
    if title and title not in topic and len(topic) <= 18:
        content = f"{topic}的核心考点"
    else:
        content = topic
    return trim_to(content, 40)


def build_details(candidate, topic):
    raw = clean_text(candidate.get("raw_text") or "")
    title = clean_text(candidate.get("knowledge_title") or "")
    details = raw
    if details.startswith(topic):
        details = details
    elif topic and topic not in details[:40]:
        details = f"{topic}：{details}"
    details = trim_to(details, 300)
    if len(re.sub(r"\s+", "", details)) < 80:
        suffix = f"该知识点属于{title or '常识'}内容，复习时重点把握时间、人物、地点、制度、影响和容易混淆的对应关系。"
        details = trim_to(f"{details}。{suffix}", 300)
    return details


def sentence_for_answer(details, topic):
    parts = re.split(r"[。；;]", details)
    for part in parts:
        part = clean_text(part)
        if 12 <= len(part) <= 80 and topic[:4] in part:
            return part
    for part in parts:
        part = clean_text(part)
        if 12 <= len(part) <= 80:
            return part
    return trim_to(details, 70)


def first_year(text):
    match = re.search(r"(公元前\s*\d+\s*年|公元\s*\d+\s*年|\d{3,4}\s*年)", text)
    if not match:
        return None
    return re.sub(r"\s+", "", match.group(1))


def distractor_years(year):
    number = int(re.search(r"\d+", year).group(0))
    prefix = "公元前" if "前" in year else ("公元" if "公元" in year else "")
    values = [number + 1, max(1, number - 1), number + 10]
    return [f"{prefix}{value}年" if prefix else f"{value}年" for value in values]


def shuffle_question_options(question, seed):
    labels = ["A", "B", "C", "D"]
    options = [question[f"option_{label.lower()}"] for label in labels]
    correct = question["answer_key"].upper()
    order = list(range(4))
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    for index in range(3, 0, -1):
        swap_index = digest[3 - index] % (index + 1)
        order[index], order[swap_index] = order[swap_index], order[index]
    shuffled = [options[index] for index in order]
    correct_index = order.index(labels.index(correct))
    for label, value in zip(labels, shuffled):
        question[f"option_{label.lower()}"] = value
    question["answer_key"] = labels[correct_index]
    return question


def generic_distractors(content):
    return [
        f"{content}混淆了同专题相近知识点的对象或范围",
        f"{content}把材料中的时间、地点或条件对应错误",
        f"{content}误用相近概念的作用、结论或适用场景",
    ]


def build_questions(candidate, content, details):
    answer_sentence = sentence_for_answer(details, content)
    distractors = generic_distractors(content)
    questions = [
        {
            "question_text": f"下列关于“{content}”的说法，正确的是？",
            "option_a": trim_to(answer_sentence, 60),
            "option_b": trim_to(distractors[0], 60),
            "option_c": trim_to(distractors[1], 60),
            "option_d": trim_to(distractors[2], 60),
            "answer_key": "A",
            "explanation": trim_to(answer_sentence, 90),
        }
    ]
    year = first_year(answer_sentence)
    if year:
        b, c, d = distractor_years(year)
        questions.append(
            {
                "question_text": f"“{content}”相关材料中出现的关键时间是？",
                "option_a": year,
                "option_b": b,
                "option_c": c,
                "option_d": d,
                "answer_key": "A",
                "explanation": f"材料中与该考点直接相关的时间为{year}。",
            }
        )
    return [
        shuffle_question_options(question, f"{candidate['id']}:{index}")
        for index, question in enumerate(questions[:2])
    ]


def upsert(rows, key, row):
    for index, existing in enumerate(rows):
        if existing.get(key) == row.get(key):
            rows[index] = row
            return
    rows.append(row)


def main():
    parser = argparse.ArgumentParser(
        description="Auto-import remaining knowledge candidates as seed segments."
    )
    parser.add_argument("--candidates", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()

    candidates = flatten_candidates(args.candidates)
    seed = load_json(args.seed)
    tables = seed.setdefault("tables", {})
    segments = tables.setdefault("basic_knowledge_segment", [])
    questions = tables.setdefault("basic_knowledge_question", [])
    consumed = explicit_consumed_ids(seed, candidates)
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    imported_segments = 0
    imported_questions = 0

    for candidate in candidates:
        if candidate["id"] in consumed:
            continue
        if args.limit is not None and imported_segments >= args.limit:
            break

        content = build_content(candidate)
        details = build_details(candidate, content)
        source_key = candidate["id"]
        segment_id = deterministic_uuid("segment", source_key)
        segment_row = {
            "id": segment_id,
            "basic_knowledge_id": candidate["basic_knowledge_id"],
            "paragraph_index": candidate["paragraph_index"],
            "content": content,
            "created_time": now,
            "update_time": now,
            "deleted_time": None,
            "content_details": details,
            "source_candidate_ids": [candidate["id"]],
        }
        upsert(segments, "id", segment_row)
        imported_segments += 1

        for question_index, question in enumerate(
            build_questions(candidate, content, details)
        ):
            question_id = deterministic_uuid(
                "question", f"{source_key}:auto:{question_index}"
            )
            question_row = {
                "id": question_id,
                "basic_knowledge_id": candidate["basic_knowledge_id"],
                "knowledge_segment_id": segment_id,
                "question_type": "single_choice",
                "question_text": question["question_text"],
                "option_a": question["option_a"],
                "option_b": question["option_b"],
                "option_c": question["option_c"],
                "option_d": question["option_d"],
                "answer_key": question["answer_key"],
                "explanation": question["explanation"],
                "difficulty": 2,
                "question_status": 0,
                "created_time": now,
                "update_time": now,
            }
            upsert(questions, "id", question_row)
            imported_questions += 1

    seed["generated_at"] = now
    seed.setdefault("manual_batches", [])
    if "auto-remaining-rule-based" not in seed["manual_batches"]:
        seed["manual_batches"].append("auto-remaining-rule-based")
    args.seed.write_text(json.dumps(seed, ensure_ascii=False, indent=2) + "\n")
    print(f"auto segments imported: {imported_segments}")
    print(f"auto questions imported: {imported_questions}")
    print(f"seed segments total: {len(segments)}")
    print(f"seed questions total: {len(questions)}")


if __name__ == "__main__":
    main()
