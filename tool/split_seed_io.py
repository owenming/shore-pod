import json
from pathlib import Path
from typing import Any


def load_seed(seed_path: Path) -> dict[str, Any]:
    seed = json.loads(seed_path.read_text(encoding="utf-8"))
    tables = seed.get("tables", {})
    if not isinstance(tables, dict):
        seed["tables"] = {}
        return seed

    root = seed_path.parents[2]
    loaded_tables: dict[str, Any] = {}
    for name, value in tables.items():
        if isinstance(value, str):
            loaded_tables[name] = json.loads(
                (root / value).read_text(encoding="utf-8")
            )
        else:
            loaded_tables[name] = value
    seed["tables"] = loaded_tables
    return seed


def save_seed(seed: dict[str, Any], seed_path: Path) -> None:
    current = json.loads(seed_path.read_text(encoding="utf-8"))
    current_tables = current.get("tables", {})
    tables = seed.get("tables", {})
    if not isinstance(current_tables, dict) or not isinstance(tables, dict):
        seed_path.write_text(
            json.dumps(seed, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return

    root = seed_path.parents[2]
    manifest = dict(seed)
    manifest_tables: dict[str, Any] = {}
    for name, rows in tables.items():
        current_value = current_tables.get(name)
        if isinstance(current_value, str):
            table_path = root / current_value
            table_path.parent.mkdir(parents=True, exist_ok=True)
            table_path.write_text(
                json.dumps(rows, ensure_ascii=False, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            manifest_tables[name] = current_value
        else:
            manifest_tables[name] = rows
    manifest["tables"] = manifest_tables
    seed_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
