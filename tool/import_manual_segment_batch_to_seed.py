#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import uuid
from pathlib import Path


NAMESPACE = uuid.UUID("6f0816a5-87a9-4e7f-a726-3a6cb73f768b")


def deterministic_uuid(kind: str, key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{key}"))


def upsert(rows, key, row):
    for index, existing in enumerate(rows):
        if existing.get(key) == row.get(key):
            rows[index] = row
            return
    rows.append(row)


def main():
    parser = argparse.ArgumentParser(
        description="Import manually curated knowledge segment batches into the bundled seed JSON."
    )
    parser.add_argument(
        "--batch",
        default="build/basic_knowledge_segment_manual_batch_0000.json",
        help="Manual batch JSON path.",
    )
    parser.add_argument(
        "--seed",
        default="assets/data/shore_pod_seed.json",
        help="Bundled seed JSON path.",
    )
    args = parser.parse_args()

    batch_path = Path(args.batch)
    seed_path = Path(args.seed)
    batch = json.loads(batch_path.read_text())
    seed = json.loads(seed_path.read_text())
    tables = seed.setdefault("tables", {})
    segments = tables.setdefault("basic_knowledge_segment", [])
    questions = tables.setdefault("basic_knowledge_question", [])
    now = dt.datetime.now(dt.timezone.utc).isoformat()

    imported_segments = 0
    imported_questions = 0

    for item in batch["items"]:
        source_candidate_ids = item.get("source_candidate_ids") or [
            item["source_candidate_id"]
        ]
        source_key = item.get("segment_key") or "|".join(source_candidate_ids)
        segment_id = deterministic_uuid("segment", source_key)
        segment_row = {
            "id": segment_id,
            "basic_knowledge_id": item["basic_knowledge_id"],
            "paragraph_index": item["paragraph_index"],
            "content": item["content"],
            "created_time": now,
            "update_time": now,
            "deleted_time": None,
            "content_details": item["content_details"],
            "source_candidate_ids": source_candidate_ids,
        }
        upsert(segments, "id", segment_row)
        imported_segments += 1

        for question_index, question in enumerate(item["questions"]):
            question_id = deterministic_uuid(
                "question", f"{source_key}:{question_index}"
            )
            question_row = {
                "id": question_id,
                "basic_knowledge_id": item["basic_knowledge_id"],
                "knowledge_segment_id": segment_id,
                "question_type": "single_choice",
                "question_text": question["question_text"],
                "option_a": question["option_a"],
                "option_b": question["option_b"],
                "option_c": question["option_c"],
                "option_d": question["option_d"],
                "answer_key": question["answer_key"].upper(),
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
    if batch.get("batch_id") not in seed["manual_batches"]:
        seed["manual_batches"].append(batch.get("batch_id"))

    seed_path.write_text(json.dumps(seed, ensure_ascii=False, indent=2) + "\n")
    print(f"segments imported: {imported_segments}")
    print(f"questions imported: {imported_questions}")
    print(f"seed segments total: {len(segments)}")
    print(f"seed questions total: {len(questions)}")


if __name__ == "__main__":
    main()
