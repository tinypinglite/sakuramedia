#!/usr/bin/env python3
"""Build versioned skill archives and the catalog consumed by the app."""

from __future__ import annotations

import argparse
import json
import shutil
import zipfile
from pathlib import Path
from typing import Any

DEFAULT_PUBLIC_BASE_URL = "https://tinypinglite.github.io/sakuramedia/downloads/skills"
SKIP_NAMES = {".DS_Store", "__pycache__", ".pytest_cache", "data"}


class PackageError(RuntimeError):
    pass


def _load_manifest(skill_dir: Path) -> dict[str, Any]:
    manifest_path = skill_dir / "skill.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PackageError(f"{skill_dir.name}: missing skill.json") from exc
    except json.JSONDecodeError as exc:
        raise PackageError(f"{skill_dir.name}: invalid skill.json") from exc
    if not isinstance(manifest, dict):
        raise PackageError(f"{skill_dir.name}: skill.json must be an object")
    name = str(manifest.get("name") or "").strip()
    version = str(manifest.get("version") or "").strip()
    if not name or name != skill_dir.name:
        raise PackageError(f"{skill_dir.name}: manifest name must match folder")
    if not version:
        raise PackageError(f"{skill_dir.name}: missing version")
    if not (skill_dir / "SKILL.md").is_file():
        raise PackageError(f"{skill_dir.name}: missing SKILL.md")
    entrypoint = manifest.get("entrypoint")
    if entrypoint and not (skill_dir / str(entrypoint)).is_file():
        raise PackageError(f"{skill_dir.name}: missing entrypoint {entrypoint}")
    return manifest


def _iter_skill_files(skill_dir: Path):
    for path in sorted(skill_dir.rglob("*")):
        if path.is_dir():
            continue
        if any(part in SKIP_NAMES for part in path.parts):
            continue
        if path.name.endswith((".pyc", ".pyo")):
            continue
        yield path


def _build_zip(skill_dir: Path, output_dir: Path, version: str) -> Path:
    archive_path = output_dir / f"{skill_dir.name}-{version}.zip"
    with zipfile.ZipFile(
        archive_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
    ) as archive:
        for path in _iter_skill_files(skill_dir):
            archive.write(path, f"{skill_dir.name}/{path.relative_to(skill_dir)}")
    return archive_path


def build_skills(
    *,
    skills_dir: Path,
    output_dir: Path,
    public_base_url: str,
) -> dict[str, Any]:
    if not skills_dir.is_dir():
        raise PackageError(f"skills directory not found: {skills_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)
    skills: list[dict[str, Any]] = []
    for skill_dir in sorted(skills_dir.iterdir()):
        if not skill_dir.is_dir() or skill_dir.name.startswith("_"):
            continue
        if not (skill_dir / "skill.json").is_file():
            continue
        manifest = _load_manifest(skill_dir)
        version = str(manifest["version"])
        archive_path = _build_zip(skill_dir, output_dir, version)
        skills.append(
            {
                "name": manifest["name"],
                "display_name": manifest.get("display_name") or manifest["name"],
                "display_name_en": manifest.get("display_name_en")
                or manifest.get("display_name")
                or manifest["name"],
                "description": manifest.get("description") or "",
                "description_en": manifest.get("description_en") or "",
                "version": version,
                "download_url": (f"{public_base_url.rstrip('/')}/{archive_path.name}"),
                "risk": manifest.get("risk") or "read",
            }
        )
    if not skills:
        raise PackageError("no skills found")
    catalog = {"skills": skills}
    (output_dir / "index.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return catalog


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skills-dir", default="skills")
    parser.add_argument(
        "--output",
        default="wiki/.vitepress/dist/downloads/skills",
    )
    parser.add_argument(
        "--public-base-url",
        default=DEFAULT_PUBLIC_BASE_URL,
    )
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    output_dir = Path(args.output)
    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)
    try:
        catalog = build_skills(
            skills_dir=Path(args.skills_dir),
            output_dir=output_dir,
            public_base_url=args.public_base_url,
        )
    except PackageError as exc:
        print(f"error: {exc}")
        return 1
    print(json.dumps(catalog, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
