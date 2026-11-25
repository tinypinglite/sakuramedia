#!/usr/bin/env python3
"""SakuraMedia movie acquisition workflow over the backend HTTP API.

The tool is read-only unless the user passes --confirm to a write command.
It keeps the current plan on disk so a chat agent can split discovery,
confirmation, submission, import and verification across several turns.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error, parse, request

DEFAULT_LANGUAGE = "zh-CN"
DEFAULT_TIMEOUT_SECONDS = 30.0
DEFAULT_PLAN_LIMIT = 10
MAX_PAGE_SIZE = 100
BASE_URL_ENV = "SAKURAMEDIA_BASE_URL"
API_KEY_ENV = "SAKURAMEDIA_API_KEY"
DEFAULT_CACHE_DIR = Path(
    os.environ.get("SAKURAMEDIA_ACQUIRE_CACHE", "~/.cache/sakuramedia-acquire")
)


class AcquireError(RuntimeError):
    """A user-facing acquisition failure."""


class ApiRequestError(AcquireError):
    def __init__(
        self,
        *,
        path: str,
        status_code: int | None,
        code: str | None,
        message: str,
        details: Any = None,
    ) -> None:
        super().__init__(message)
        self.path = path
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details

    def as_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"path": self.path, "message": self.message}
        if self.status_code is not None:
            payload["status_code"] = self.status_code
        if self.code is not None:
            payload["code"] = self.code
        if self.details is not None:
            payload["details"] = self.details
        return payload


@dataclass(frozen=True)
class Connection:
    base_url: str
    api_key: str


class ApiClient:
    def __init__(self, connection: Connection, timeout: float) -> None:
        self.connection = connection
        self.timeout = timeout

    def get_json(self, path: str, params: dict[str, Any] | None = None) -> Any:
        return self._request_json("GET", path, params=params)

    def post_json(
        self,
        path: str,
        data: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> Any:
        return self._request_json("POST", path, params=params, data=data)

    def _request_json(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        data: dict[str, Any] | None = None,
    ) -> Any:
        url = self._url(path, params)
        headers = {
            "Accept": "application/json",
            "Accept-Language": DEFAULT_LANGUAGE,
            "Authorization": f"Bearer {self.connection.api_key}",
            "User-Agent": "sakuramedia-acquire/0.1",
        }
        body = None
        if data is not None:
            body = json.dumps(data, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request_obj = request.Request(
            url,
            data=body,
            headers=headers,
            method=method,
        )
        try:
            with request.urlopen(request_obj, timeout=self.timeout) as response:
                payload = response.read()
        except error.HTTPError as exc:
            raise self._http_error(path, exc) from exc
        except error.URLError as exc:
            raise AcquireError(f"无法连接 SakuraMedia 后端: {exc.reason}") from exc
        except TimeoutError as exc:
            raise AcquireError(f"请求超时: {path}") from exc
        try:
            return json.loads(payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ApiRequestError(
                path=path,
                status_code=None,
                code="invalid_json_response",
                message="后端返回的不是有效 JSON",
                details=str(exc),
            ) from exc

    def _url(self, path: str, params: dict[str, Any] | None) -> str:
        base_url = self.connection.base_url.rstrip("/")
        url = f"{base_url}/{path.lstrip('/')}"
        if params:
            url = f"{url}?{parse.urlencode(params, doseq=True)}"
        return url

    @staticmethod
    def _http_error(path: str, exc: error.HTTPError) -> ApiRequestError:
        body = exc.read()
        code: str | None = None
        message = f"HTTP {exc.code}"
        details: Any = None
        try:
            payload = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            payload = None
        if isinstance(payload, dict):
            error_payload = payload.get("error")
            if isinstance(error_payload, dict):
                code = error_payload.get("code")
                message = error_payload.get("message") or message
                details = error_payload.get("details")
        return ApiRequestError(
            path=path,
            status_code=exc.code,
            code=code,
            message=message,
            details=details,
        )


def _read_connection() -> Connection:
    base_url = os.environ.get(BASE_URL_ENV, "").strip()
    api_key = os.environ.get(API_KEY_ENV, "").strip()

    if not base_url or not api_key:
        raise AcquireError(
            f"缺少连接信息。宿主 Agent 需要为本次进程设置 {BASE_URL_ENV} "
            f"和 {API_KEY_ENV}。"
        )
    parsed = parse.urlsplit(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise AcquireError("base_url 必须是完整的 http/https URL")
    return Connection(
        base_url=base_url.rstrip("/"),
        api_key=api_key,
    )


def _build_client(args: argparse.Namespace) -> ApiClient:
    return ApiClient(
        _read_connection(),
        timeout=float(getattr(args, "timeout", DEFAULT_TIMEOUT_SECONDS)),
    )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _plan_dir() -> Path:
    path = DEFAULT_CACHE_DIR.expanduser() / "plans"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _plan_path(plan_id: str) -> Path:
    if not re.fullmatch(r"[0-9a-f]{12}", plan_id):
        raise AcquireError("plan_id 无效")
    return _plan_dir() / f"{plan_id}.json"


def _write_plan(plan: dict[str, Any]) -> str:
    plan_id = uuid.uuid4().hex[:12]
    plan["plan_id"] = plan_id
    plan["created_at"] = _now()
    path = _plan_path(plan_id)
    path.write_text(
        json.dumps(plan, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    try:
        path.chmod(0o600)
    except OSError:
        pass
    return plan_id


def _read_plan(plan_id: str) -> dict[str, Any]:
    path = _plan_path(plan_id)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AcquireError(f"找不到 plan: {plan_id}") from exc
    except json.JSONDecodeError as exc:
        raise AcquireError(f"plan 文件损坏: {plan_id}") from exc
    if not isinstance(payload, dict):
        raise AcquireError("plan 文件格式无效")
    return payload


def _movie_summary(movie: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(movie, dict):
        return None
    return {
        "movie_number": movie.get("movie_number"),
        "title": movie.get("title"),
        "release_date": movie.get("release_date"),
        "duration_minutes": movie.get("duration_minutes"),
        "can_play": movie.get("can_play"),
        "media_count": movie.get("media_count"),
        "is_collection": movie.get("is_collection"),
        "is_subscribed": movie.get("is_subscribed"),
    }


def _task_summary(task: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": task.get("id"),
        "movie_number": task.get("movie_number"),
        "name": task.get("name"),
        "display_name": task.get("display_name"),
        "state": task.get("state"),
        "progress": task.get("progress"),
        "import_status": task.get("import_status"),
        "import_status_label": task.get("import_status_label"),
        "client_id": task.get("client_id"),
        "created_at": task.get("created_at"),
        "updated_at": task.get("updated_at"),
    }


def _candidate_summary(
    candidate: dict[str, Any],
    index: int,
) -> dict[str, Any]:
    evaluation = candidate.get("selection_evaluation")
    return {
        "candidate_index": index,
        "source_uri": candidate.get("source_uri"),
        "indexer_name": candidate.get("indexer_name"),
        "indexer_kind": candidate.get("indexer_kind"),
        "resolved_client_id": candidate.get("resolved_client_id"),
        "resolved_client_name": candidate.get("resolved_client_name"),
        "download_clients": candidate.get("download_clients") or [],
        "movie_number": candidate.get("movie_number"),
        "title": candidate.get("title"),
        "release_title": candidate.get("release_title") or "",
        "description": candidate.get("description") or "",
        "size_bytes": candidate.get("size_bytes"),
        "seeders": candidate.get("seeders"),
        "published_at": candidate.get("published_at"),
        "selection_evaluation": evaluation,
    }


def _search_movies(client: ApiClient, query: str) -> list[dict[str, Any]]:
    data = client.get_json(
        "/movies",
        {"query": query, "page_size": 10},
    )
    items = data.get("items") if isinstance(data, dict) else None
    return [item for item in items or [] if isinstance(item, dict)]


def _resolve_movie_number(
    query: str,
    movies: list[dict[str, Any]],
) -> str | None:
    normalized_query = query.strip().casefold()
    for movie in movies:
        number = str(movie.get("movie_number") or "")
        if number.casefold() == normalized_query:
            return number
    if len(movies) == 1:
        number = str(movies[0].get("movie_number") or "")
        if number:
            return number
    if not movies:
        return query.strip().upper()
    return None


def _get_movie_or_none(
    client: ApiClient,
    movie_number: str,
) -> dict[str, Any] | None:
    try:
        return client.get_json(f"/movies/{parse.quote(movie_number, safe='')}")
    except ApiRequestError as exc:
        if exc.status_code == 404:
            return None
        raise


def cmd_plan(args: argparse.Namespace) -> int:
    client = _build_client(args)
    query = args.query.strip()
    if not query:
        raise AcquireError("query 不能为空")
    movies = _search_movies(client, query)
    movie_number = _resolve_movie_number(query, movies)
    if movie_number is None:
        _emit(
            {
                "ok": True,
                "status": "ambiguous",
                "query": query,
                "movies": [_movie_summary(item) for item in movies],
                "message": "搜索到多部影片，请让用户选择精确番号后再生成计划。",
            }
        )
        return 0

    movie = _get_movie_or_none(client, movie_number)
    task_page = client.get_json(
        "/download-tasks",
        {"movie_number": movie_number, "page_size": MAX_PAGE_SIZE},
    )
    tasks = [
        _task_summary(item)
        for item in (task_page.get("items") or [])
        if isinstance(item, dict)
    ]
    already_available = bool(isinstance(movie, dict) and movie.get("can_play"))

    candidate_error = None
    candidates: list[dict[str, Any]] = []
    if not already_available:
        params: dict[str, Any] = {"movie_number": movie_number}
        if args.indexer_kind:
            params["indexer_kind"] = args.indexer_kind
        try:
            candidate_data = client.get_json("/download-candidates", params)
        except ApiRequestError as exc:
            candidate_error = exc.as_dict()
            candidate_data = []
        if isinstance(candidate_data, list):
            candidates = [
                _candidate_summary(item, index)
                for index, item in enumerate(candidate_data[:DEFAULT_PLAN_LIMIT])
                if isinstance(item, dict)
            ]

    recommended_index: int | None = None
    for candidate in candidates:
        evaluation = candidate.get("selection_evaluation")
        if isinstance(evaluation, dict) and evaluation.get("eligible"):
            recommended_index = candidate["candidate_index"]
            break
    if recommended_index is None and candidates:
        recommended_index = candidates[0]["candidate_index"]

    plan: dict[str, Any] = {
        "ok": True,
        "status": "ready",
        "movie_number": movie_number,
        "movie": _movie_summary(movie),
        "already_available": already_available,
        "download_tasks": tasks,
        "candidates": candidates,
        "recommended_candidate_index": recommended_index,
        "candidate_error": candidate_error,
    }
    plan_id = _write_plan(plan)
    plan["plan_id"] = plan_id
    _emit(plan)
    return 0


def _require_confirm(args: argparse.Namespace, operation: str) -> None:
    if not getattr(args, "confirm", False):
        raise AcquireError(f"{operation} 是写操作，必须显式传入 --confirm")


def cmd_submit(args: argparse.Namespace) -> int:
    _require_confirm(args, "提交下载")
    plan = _read_plan(args.plan_id)
    candidates = plan.get("candidates") or []
    if not 0 <= args.candidate_index < len(candidates):
        raise AcquireError("candidate_index 超出计划范围")
    candidate = candidates[args.candidate_index]
    client_id = args.client_id or candidate.get("resolved_client_id")
    if not client_id:
        raise AcquireError("候选没有可用下载器，请先配置下载器")
    payload = {
        "client_id": client_id,
        "movie_number": plan["movie_number"],
        "candidate": {
            "source_uri": candidate["source_uri"],
            "indexer_name": candidate["indexer_name"],
            "title": candidate["title"],
            "size_bytes": candidate["size_bytes"],
            "seeders": candidate["seeders"],
            "release_title": candidate.get("release_title") or "",
            "description": candidate.get("description") or "",
        },
    }
    result = _build_client(args).post_json("/download-requests", payload)
    _emit(
        {
            "ok": True,
            "plan_id": args.plan_id,
            "candidate_index": args.candidate_index,
            "created": result.get("created"),
            "download_task": _task_summary(result.get("task") or {}),
        }
    )
    return 0


def _list_tasks(client: ApiClient, *, movie_number: str) -> list[dict[str, Any]]:
    page = client.get_json(
        "/download-tasks",
        {"movie_number": movie_number, "page_size": MAX_PAGE_SIZE},
    )
    return [
        _task_summary(item)
        for item in (page.get("items") or [])
        if isinstance(item, dict)
    ]


def cmd_status(args: argparse.Namespace) -> int:
    client = _build_client(args)
    _emit(
        {
            "ok": True,
            "movie_number": args.movie_number,
            "download_tasks": _list_tasks(
                client,
                movie_number=args.movie_number,
            ),
        }
    )
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    _require_confirm(args, "触发导入")
    result = _build_client(args).post_json(f"/download-tasks/{args.task_id}/import")
    _emit({"ok": True, **result})
    return 0


def cmd_task_run(args: argparse.Namespace) -> int:
    result = _build_client(args).get_json(f"/system/task-runs/{args.task_run_id}")
    _emit({"ok": True, "task_run": result})
    return 0


def cmd_failures(args: argparse.Namespace) -> int:
    result = _build_client(args).get_json(f"/imports/{args.task_run_id}/failed-items")
    _emit({"ok": True, "failed_items": result})
    return 0


def cmd_metadata_candidates(args: argparse.Namespace) -> int:
    result = _build_client(args).get_json(
        f"/imports/{args.task_run_id}/failed-items/"
        f"{parse.quote(args.item_id, safe='')}/metadata-candidates",
        {"movie_number": args.movie_number},
    )
    _emit({"ok": True, **result})
    return 0


def cmd_retry(args: argparse.Namespace) -> int:
    _require_confirm(args, "重试导入")
    result = _build_client(args).post_json(
        f"/imports/{args.task_run_id}/failed-items/"
        f"{parse.quote(args.item_id, safe='')}/retry",
        {"candidate_id": args.candidate_id},
    )
    _emit({"ok": True, **result})
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    client = _build_client(args)
    movie = _get_movie_or_none(client, args.movie_number)
    subtitles = (
        client.get_json(f"/movies/{parse.quote(args.movie_number, safe='')}/subtitles")
        if movie is not None
        else {"items": []}
    )
    _emit(
        {
            "ok": True,
            "movie_number": args.movie_number,
            "playable": bool(isinstance(movie, dict) and movie.get("can_play")),
            "movie": _movie_summary(movie),
            "media_items": (
                [
                    {
                        "id": item.get("id"),
                        "resolution": item.get("resolution"),
                        "file_size_bytes": item.get("file_size_bytes"),
                        "valid": item.get("valid"),
                    }
                    for item in (movie.get("media_items") or [])
                    if isinstance(item, dict)
                ]
                if isinstance(movie, dict)
                else []
            ),
            "subtitles": subtitles.get("items") if isinstance(subtitles, dict) else [],
        }
    )
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    client = _build_client(args)
    health = client.get_json("/healthz")
    status = client.get_json("/status")
    _emit(
        {
            "ok": True,
            "health": health,
            "backend_version": status.get("backend_version"),
            "movies": status.get("movies"),
            "media_files": status.get("media_files"),
        }
    )
    return 0


def _emit(payload: Any) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False))


def _add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="HTTP timeout seconds",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="SakuraMedia movie acquisition workflow",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser(
        "plan",
        help="Resolve a movie and build a download plan",
    )
    _add_common_arguments(plan)
    plan.add_argument("--query", required=True)
    plan.add_argument("--indexer-kind", default=None)

    submit = subparsers.add_parser(
        "submit",
        help="Submit a candidate from a saved plan",
    )
    _add_common_arguments(submit)
    submit.add_argument("--plan-id", required=True)
    submit.add_argument("--candidate-index", type=int, required=True)
    submit.add_argument("--client-id", type=int, default=None)
    submit.add_argument("--confirm", action="store_true")

    status = subparsers.add_parser("status", help="Show download status")
    _add_common_arguments(status)
    status.add_argument("--movie-number", required=True)

    import_task = subparsers.add_parser("import", help="Trigger import")
    _add_common_arguments(import_task)
    import_task.add_argument("--task-id", type=int, required=True)
    import_task.add_argument("--confirm", action="store_true")

    task_run = subparsers.add_parser("task-run", help="Show an import task run")
    _add_common_arguments(task_run)
    task_run.add_argument("--task-run-id", type=int, required=True)

    failures = subparsers.add_parser(
        "failures",
        help="List failed import items",
    )
    _add_common_arguments(failures)
    failures.add_argument("--task-run-id", type=int, required=True)

    metadata = subparsers.add_parser(
        "metadata-candidates",
        help="Search metadata candidates for a failed import item",
    )
    _add_common_arguments(metadata)
    metadata.add_argument("--task-run-id", type=int, required=True)
    metadata.add_argument("--item-id", required=True)
    metadata.add_argument("--movie-number", required=True)

    retry = subparsers.add_parser(
        "retry",
        help="Retry a failed import item with a metadata candidate",
    )
    _add_common_arguments(retry)
    retry.add_argument("--task-run-id", type=int, required=True)
    retry.add_argument("--item-id", required=True)
    retry.add_argument("--candidate-id", required=True)
    retry.add_argument("--confirm", action="store_true")

    verify = subparsers.add_parser(
        "verify",
        help="Verify that a movie is playable",
    )
    _add_common_arguments(verify)
    verify.add_argument("--movie-number", required=True)

    check = subparsers.add_parser("check", help="Validate connection")
    _add_common_arguments(check)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            return cmd_plan(args)
        if args.command == "submit":
            return cmd_submit(args)
        if args.command == "status":
            return cmd_status(args)
        if args.command == "import":
            return cmd_import(args)
        if args.command == "task-run":
            return cmd_task_run(args)
        if args.command == "failures":
            return cmd_failures(args)
        if args.command == "metadata-candidates":
            return cmd_metadata_candidates(args)
        if args.command == "retry":
            return cmd_retry(args)
        if args.command == "verify":
            return cmd_verify(args)
        if args.command == "check":
            return cmd_check(args)
        parser.error("Unsupported command")
        return 2
    except ApiRequestError as exc:
        _emit({"ok": False, "error": exc.as_dict()})
        return 3
    except AcquireError as exc:
        _emit({"ok": False, "error": {"message": str(exc)}})
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
