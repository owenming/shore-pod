#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
import uuid
from pathlib import Path


DEFAULT_CANDIDATES = Path("build/knowledge_segment_candidates_preview.json")
DEFAULT_SEED = Path("assets/data/shore_pod_seed.json")
DEFAULT_BATCH_DIR = Path("build/manual_batches")
IMPORT_SCRIPT = Path("tool/import_manual_segment_batch_to_seed.py")
NAMESPACE = uuid.UUID("6f0816a5-87a9-4e7f-a726-3a6cb73f768b")


def load_json(path: Path):
    return json.loads(path.read_text())


def flatten_candidates(path: Path):
    data = load_json(path)
    rows = []
    for article in data["articles"]:
        rows.extend(article["candidates"])
    return rows


def seed_counts(seed_path: Path):
    seed = load_json(seed_path)
    tables = seed["tables"]
    return (
        len(tables.get("basic_knowledge_segment", [])),
        len(tables.get("basic_knowledge_question", [])),
    )


def deterministic_uuid(kind: str, key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{key}"))


def consumed_candidate_ids(seed_path: Path, candidates):
    seed = load_json(seed_path)
    segments = seed["tables"].get("basic_knowledge_segment", [])
    consumed = set()
    segment_ids = {row["id"] for row in segments}
    candidate_ids = {row["id"] for row in candidates}

    for row in segments:
        explicit_ids = row.get("source_candidate_ids")
        if explicit_ids:
            consumed.update(cid for cid in explicit_ids if cid in candidate_ids)

    for candidate in candidates:
        legacy_segment_id = deterministic_uuid("segment", candidate["id"])
        if legacy_segment_id in segment_ids:
            consumed.add(candidate["id"])

    return consumed


def next_unconsumed_index(seed_path: Path, candidates):
    consumed = consumed_candidate_ids(seed_path, candidates)
    for index, candidate in enumerate(candidates):
        if candidate["id"] not in consumed:
            return index, consumed
    return len(candidates), consumed


def command_status(args):
    candidates = flatten_candidates(args.candidates)
    segment_count, question_count = seed_counts(args.seed)
    next_start, consumed = next_unconsumed_index(args.seed, candidates)
    next_end = min(next_start + args.batch_size, len(candidates))
    print(f"候选块总数: {len(candidates)}")
    print(f"已覆盖候选块: {len(consumed)}")
    print(f"已入 seed 卡片: {segment_count}")
    print(f"已入 seed 题目: {question_count}")
    print(f"下一批范围: [{next_start}, {next_end})")
    if next_start < len(candidates):
        first = candidates[next_start]
        print(f"下一批首条: {first['knowledge_title']} / {first['topic']}")


def command_next(args):
    candidates = flatten_candidates(args.candidates)
    next_start, _ = next_unconsumed_index(args.seed, candidates)
    start = args.start if args.start is not None else next_start
    end = min(start + args.batch_size, len(candidates))
    batch = candidates[start:end]
    if not batch:
        print("没有新的候选块。")
        return

    args.output_dir.mkdir(parents=True, exist_ok=True)
    batch_index = start // args.batch_size
    range_label = f"{start:04d}_{end:04d}"
    json_path = args.output_dir / f"manual_batch_input_{range_label}.json"
    md_path = args.output_dir / f"manual_batch_input_{range_label}.md"
    payload = {
        "batch_index": batch_index,
        "start": start,
        "end": end,
        "batch_size": args.batch_size,
        "candidates": batch,
    }
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    md_path.write_text(build_markdown_template(batch_index, start, batch))
    print(f"下一批 JSON: {json_path}")
    print(f"下一批 Markdown: {md_path}")


def build_markdown_template(batch_index, start, batch):
    lines = [
        f"# 知识卡片整理批次 {batch_index:04d}",
        "",
        "请把下面候选块整理为正式 JSON：",
        "",
        "- content: 10-40 字",
        "- content_details: 80-300 字",
        "- questions: 每张卡片 1-3 道单选题",
        "- 保留 source_candidate_id / basic_knowledge_id / paragraph_index",
        "",
    ]
    for offset, item in enumerate(batch):
        lines.extend(
            [
                "---",
                f"global_index: {start + offset}",
                f"source_candidate_id: {item['id']}",
                f"basic_knowledge_id: {item['basic_knowledge_id']}",
                f"paragraph_index: {item['paragraph_index']}",
                f"knowledge_title: {item['knowledge_title']}",
                f"topic: {item['topic']}",
                "",
                item["raw_text"],
                "",
            ]
        )
    return "\n".join(lines)


def command_validate(args):
    data = load_json(args.batch)
    items = data["items"]
    errors = []
    for item_index, item in enumerate(items):
        source_candidate_ids = item.get("source_candidate_ids") or (
            [item["source_candidate_id"]] if item.get("source_candidate_id") else []
        )
        content = item.get("content", "")
        details = item.get("content_details", "")
        questions = item.get("questions", [])
        if not source_candidate_ids:
            errors.append(f"{item_index}: 缺少 source_candidate_id/source_candidate_ids")
        if not (6 <= visible_len(content) <= 40):
            errors.append(f"{item_index}: content 长度异常：{content}")
        if not (60 <= visible_len(details) <= 360):
            errors.append(
                f"{item_index}: content_details 长度异常：{content} ({visible_len(details)})"
            )
        if not (1 <= len(questions) <= 3):
            errors.append(f"{item_index}: questions 数量异常：{content}")
        for question_index, question in enumerate(questions):
            if question.get("answer_key") not in ["A", "B", "C", "D"]:
                errors.append(f"{item_index}.{question_index}: answer_key 异常")
            required = [
                "question_text",
                "option_a",
                "option_b",
                "option_c",
                "option_d",
                "explanation",
            ]
            for key in required:
                if not question.get(key):
                    errors.append(f"{item_index}.{question_index}: 缺少 {key}")
            option_values = [
                str(question.get("option_a", "")),
                str(question.get("option_b", "")),
                str(question.get("option_c", "")),
                str(question.get("option_d", "")),
            ]
            for option_index, option in enumerate(option_values):
                if is_lazy_option(option):
                    label = ["A", "B", "C", "D"][option_index]
                    errors.append(
                        f"{item_index}.{question_index}: 选项 {label} 像 AI 兜底废选项：{option}"
                    )
            if is_lazy_explanation(str(question.get("explanation", "")), option_values):
                errors.append(
                    f"{item_index}.{question_index}: explanation 过于机械，不能只复制选项"
                )
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(f"batch ok: {len(items)} 张卡片，{sum(len(i['questions']) for i in items)} 道题")


def command_import(args):
    command_validate(args)
    subprocess.run(
        [
            sys.executable,
            str(IMPORT_SCRIPT),
            "--batch",
            str(args.batch),
            "--seed",
            str(args.seed),
        ],
        check=True,
    )
    command_status(args)


def command_validate_seed(args):
    seed = load_json(args.seed)
    tables = seed["tables"]
    infos = {row["id"] for row in tables["basic_knowledge_info"]}
    segments = tables.get("basic_knowledge_segment", [])
    questions = tables.get("basic_knowledge_question", [])
    segment_ids = {row["id"] for row in segments}
    errors = []
    for row in segments:
        if row["basic_knowledge_id"] not in infos:
            errors.append(f"segment 外键异常: {row['id']}")
    for row in questions:
        if row["knowledge_segment_id"] not in segment_ids:
            errors.append(f"question 外键异常: {row['id']}")
        if row.get("answer_key") not in ["A", "B", "C", "D"]:
            errors.append(f"question 答案异常: {row['id']}")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(f"seed ok: {len(segments)} 张卡片，{len(questions)} 道题")


def visible_len(text):
    return len("".join(str(text).split()))


def is_lazy_option(text):
    lazy_patterns = [
        "原始资料",
        "与本题无关",
        "与材料无关",
        "与题干无关",
        "该考点主要属于",
        "不需要区分",
        "只需记住名称",
        "具体内容在考试中通常不作区分",
        "以上都不对",
        "以上都正确",
    ]
    return any(pattern in text for pattern in lazy_patterns)


def is_lazy_explanation(explanation, options):
    normalized = "".join(explanation.split())
    if not normalized:
        return True
    option_texts = {"".join(str(option).split()) for option in options}
    if normalized in option_texts:
        return True
    return visible_len(explanation) < 12


def add_common(parser):
    parser.add_argument("--candidates", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--batch-size", type=int, default=24)


def main():
    parser = argparse.ArgumentParser(description="Knowledge segment fixed pipeline.")
    sub = parser.add_subparsers(required=True)

    status = sub.add_parser("status", help="Show current progress.")
    add_common(status)
    status.set_defaults(func=command_status)

    next_parser = sub.add_parser("next", help="Export the next batch template.")
    add_common(next_parser)
    next_parser.add_argument("--start", type=int)
    next_parser.add_argument("--output-dir", type=Path, default=DEFAULT_BATCH_DIR)
    next_parser.set_defaults(func=command_next)

    validate = sub.add_parser("validate", help="Validate a completed manual batch.")
    add_common(validate)
    validate.add_argument("--batch", type=Path, required=True)
    validate.set_defaults(func=command_validate)

    import_parser = sub.add_parser("import", help="Validate and import a batch.")
    add_common(import_parser)
    import_parser.add_argument("--batch", type=Path, required=True)
    import_parser.set_defaults(func=command_import)

    seed_parser = sub.add_parser("validate-seed", help="Validate bundled seed links.")
    add_common(seed_parser)
    seed_parser.set_defaults(func=command_validate_seed)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
