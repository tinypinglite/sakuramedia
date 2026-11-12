---
outline: [2, 3]
---

# Plugin Development

SakuraMedia plugins are Python packages running inside the backend process. This article covers the backend's current **Host API 18**; the host accepts only plugins declaring API **18**. A plugin's `manifest.json` and the `plugin_id` and `version` in the `register()` return value must match; for Host API declaration rules see [Version compatibility](#version-compatibility).

Plugins are not a frontend extension mechanism. You cannot currently register pages, UI components, HTTP routes, event hooks, or middleware, and you should not access the host database directly. Use only the public contracts listed here; binding to internal implementations such as `src.model` or `src.service` will break your plugin when the host is refactored.

## Choosing a plugin type

| Goal | Approach |
|---|---|
| Scheduled scraping, manual processing, subtitle or movie data processing | Register a background job |
| Periodically browse media library content, auto-import, or organize collections | Register a background job and call `context.imports`, `context.videos`, and `context.collections` |
| Detect missing movies, resolution, or file size in the media library and download automatically | Register a background job and call `context.media` and `context.downloads` |
| Provide movie metadata by number | Register the `catalog.metadata_source` extension point (requires Host API 18) |
| Provide a ranking source | Register the `discovery.ranking_source` extension point and register your own sync job |
| Integrate a new media storage or download platform | Register the `media.provider` extension point |

Most plugins only need background jobs. Use extension points only when the host needs to uniformly enumerate and orchestrate plugin capabilities.

## Minimal plugin

The plugin root directory name must equal `plugin_id` and contain `manifest.json` and `__init__.py`:

```text
example_plugin/
├── manifest.json
├── __init__.py
├── plugin.py
└── settings.py
```

`settings.py` is only needed when the manifest declares `settings_model`.

`manifest.json`:

```json
{
  "plugin_id": "example_plugin",
  "display_name": "示例插件",
  "display_name_i18n": {
    "zh-CN": "示例插件",
    "en": "Example plugin"
  },
  "description": "一句话说明插件用途，不超过 200 字。",
  "description_i18n": {
    "zh-CN": "一句话说明插件用途，不超过 200 字。",
    "en": "One sentence about what the plugin does, at most 200 characters."
  },
  "version": "1.0.0",
  "host_api_version": 18,
  "settings_model": "Settings",
  "requires_python": ">=3.10,<3.11",
  "dependencies": []
}
```

`plugin_id` may contain only lowercase letters, digits, and underscores, and must start with a letter. `settings_model` is optional; when declared, the host reads the Pydantic `BaseModel` of the same name from the plugin package root to generate the configuration schema and defaults and to validate configuration updates. `dependencies` is an optional PEP 508 dependency list; when declared, the host installs them synchronously before the full container starts. The manifest may also set `author`, `homepage`, and `release_api_url`, where `release_api_url` declares the Release API used for update checks; unknown fields are rejected.

`__init__.py` must expose at least `register`; if `settings_model` is declared, it must also expose the corresponding model from the package root:

```python
from .plugin import register
from .settings import Settings

__all__ = ["Settings", "register"]
```

Minimal `settings.py`:

```python
from pydantic import BaseModel


class Settings(BaseModel):
    enabled: bool = True
```

When you don't need structured settings, remove `settings_model` from the manifest and expose only `register`.

Below is a minimal scheduled-job plugin:

```python
from src.plugins import HOST_API_VERSION, PluginContext, PluginRegistration
from src.scheduler.contracts import JobDefinition


def run_example(reporter, params):
    reporter.emit(current=1, total=1, text="已完成")
    return {"processed": 1}


def register(context: PluginContext) -> PluginRegistration:
    return PluginRegistration(
        plugin_id="example_plugin",
        display_name="示例插件",
        version="1.0.0",
        host_api_version=HOST_API_VERSION,
        jobs=(
            JobDefinition(
                task_key="example_plugin_daily",
                log_name="example-plugin-daily",
                cli_name="example-plugin-daily",
                cli_help="运行示例任务",
                default_cron="0 3 * * *",
                handler=run_example,
            ),
        ),
    )
```

`task_key`, `log_name`, and `cli_name` must be unique across all built-in and plugin jobs. For a manual job that takes parameters, set `manual_only=True` and provide a Pydantic `params_schema`; job handlers always receive `(reporter, params)`.

## Registration and host capabilities

The host imports plugins and calls `register(context)` when the API and job services start. The registration phase should only build declarations and validate local configuration: don't access the network, validate cookies, create external directories, or start background threads.

`PluginContext` mainly provides the following stable capabilities:

- `settings`: read-only configuration from `plugins.settings.<plugin_id>`; when `settings_model` is declared, the host's plugin settings endpoint also provides the schema and defaults, and validates configuration saves against the model.
- `data_dir`: the plugin's private runtime data directory, preserved across reinstalls. Write runtime state here, not into the plugin code directory.
- `movies`: query movies and their associated actor and tag snapshots, paginate, and update protected fields.
- `actors`: read actor identity and profile snapshots, paginate, and update profile fields.
- `subscriptions`: read subscription state, subscribe or unsubscribe, and reset subscription search state.
- `notifications`: create, idempotently create, and resolve plugin notifications, and incrementally read host notifications in ascending notification ID order.
- `collections`: manage playlist, moment, and clip collections under the plugin's own keys.
- `subtitles`: list a movie's registered subtitles, and read raw bytes and SHA256.
- `media`: read media snapshots by movie or media library, and check whether media or playable media exists.
- `downloads`: list download targets, search candidates via the host's default routing or a specified `download_client_id`, and submit.
- `imports`: list media libraries, browse provider storage, start media library imports by provider reference, and query the results of your own jobs (Host API 9).
- `videos`: read regular video snapshots; for collection membership see `context.collections` (Host API 9).
- `import_movie_by_number(movie_number, *, force_subscribed=False)`: reuse a local movie, or import it through the enabled metadata plugin chain, returning a `MovieSnapshot`.
- `list_existing_movie_numbers()`: read the uppercase set of all movie numbers in the library.
- `import_subtitle(movie_number, content, filename, language=None)`: hand the subtitle to the host for validation, deduplication, storage, and registration.
- `sync_ranking_sources(progress_callback=None)`, `sync_ranking_board()`: sync the ranking sources declared by the current plugin.
- `get_task_logger(name)`: get a job logger.

Import movie, actor, query result, subscription, notification, collection, download, import acceptance, and subtitle types from `src.plugins.types`; import metadata source models from `src.plugins`. The public entry points are `src.plugins`, `src.plugins.types`, `src.scheduler.contracts`, and `src.plugins.provider_protocol` used by media providers.

### Plugin settings model

When `settings_model` is declared, the host's plugin settings endpoint returns the current `settings`, `schema`, and `defaults`. When saving configuration, the host validates against the model and writes back using model aliases; validation failures return field-level errors. When a configuration update requires restarting the API and job services, the endpoint returns `pending_restart`. When no model is declared, the old free-form JSON configuration behavior is kept.

## Movie and actor data

### Snapshots and pagination

`context.movies` provides `get(movie_id)`, `find_by_numbers(numbers)`, `list_page(after_id=0, limit=500)`, and `query(filters=None, after_id=0, limit=500)`; `context.actors` provides `get(actor_id)` and `list_page()` with the same parameters. `get()` returns `None` when not found; batch movie number queries deduplicate in input order and skip movies that don't exist. The page size limit is 1000; pass `next_cursor` as the next page's `after_id`, and stop when it is `None`.

Snapshots read fields through `values`, check ownership through `owners`, and use `revision` for concurrent update checks. Readable fields follow `MOVIE_SNAPSHOT_FIELDS` and `ACTOR_SNAPSHOT_FIELDS`:

- Movies newly expose readable `series_name` and `is_blacklisted`, and return associated snapshot tuples through `actors` and `tags`.
- Actor snapshots include `actor_id`, identity and subscription info, and profile data such as birthday, height, and measurements. `TagSnapshot` only contains `tag_id` and `name`.
- A movie's `revision` does not cover associated actors or tags; updating an actor must use that actor's own snapshot revision.

### Movie filter queries

`context.movies.query()` accepts `MovieQueryFilters` or a mapping with the same structure. Available filters include `search` (movie number or title), `actor_id`, `tag_ids`, `tag_match`, `year`, `subscribed`, `playable`, `status`, `collection_type`, `series_id`, `director_name`, `maker_name`, `number_source`, `heat_min`, `heat_max`, and `blacklisted`. `status` cannot be combined with `subscribed` or `playable`; results are stably sorted by the movie's internal id and use the `after_id` cursor.

```python
from src.plugins.types import MovieQueryFilters


page = context.movies.query(
    MovieQueryFilters(subscribed=True, playable=False),
    limit=100,
)
for movie in page.items:
    print(movie.values["movie_number"])
```

### Protected field updates

Both entry points use `patch(id, fields, expected_revision) -> bool` and only allow the following fields:

| Entry point | Writable fields | Value requirements |
|---|---|---|
| `context.movies.patch()` | `title`, `summary`, `maker_name`, `director_name` | strings; `None` is not accepted |
| `context.movies.patch()` | `is_collection`, `is_blacklisted` | booleans |
| `context.actors.patch()` | `birthday` | `datetime.date` or a `YYYY-MM-DD` string |
| `context.actors.patch()` | `height_cm`, `bust_cm`, `waist_cm`, `hips_cm` | integers from 1 to 2147483647 in centimeters; booleans are not accepted |
| `context.actors.patch()` | `cup`, `birthplace`, `blood_type` | non-empty text of 1–255 characters |

Actor profile fields can be passed `None` to clear them explicitly, but plugin ownership is retained. Actor names, aliases, avatars, and subscription state are not in the write whitelist.

When a field has not been taken over, there is no corresponding key in `owners`; after a plugin writes successfully, ownership becomes `plugin:<plugin_id>`, and manual edits become `host:manual`. Plugins may only write fields that are unclaimed or owned by themselves. If the record doesn't exist, the revision doesn't match, or any field ownership conflicts, `patch()` returns `False` with no changes at all; an illegal field or value raises `ValueError`. After receiving `False`, re-read and decide whether an update is still needed; don't blindly loop and retry.

```python
def mark_collection(context, movie_id: int) -> bool:
    movie = context.movies.get(movie_id)
    if movie is None:
        return False
    return context.movies.patch(
        movie.movie_id,
        {"is_collection": True},
        expected_revision=movie.revision,
    )


def update_actor_height(context, actor_id: int, height_cm: int) -> bool:
    actor = context.actors.get(actor_id)
    if actor is None:
        return False
    return context.actors.patch(
        actor.actor_id,
        {"height_cm": height_cm},
        expected_revision=actor.revision,
    )
```

`is_blacklisted=True` cannot be used on an already-subscribed movie, otherwise the entire patch returns `False`. `import_movie_by_number()` also doesn't overwrite fields of existing movies; to change them, read the snapshot separately and patch.

## Subscriptions, notifications, and collections

`context.subscriptions` provides `list()`, `count_by_status()`, `get(movie_id)`, `subscribe(movie_number)`, `unsubscribe(movie_number)`, and `reset_search(movie_ids=None)`. The subscription list is paginated by page number; `reset_search(None)` resets search state for all subscriptions, while passing a set of movie ids resets only those movies.

`context.notifications` provides `create()`, `create_once()`, and `resolve(dedupe_key)`. Idempotency keys automatically carry the current plugin namespace, so plugins don't overwrite each other; both the key in the creation result and `resolve()` use the plugin's own original key.

`list(after_id=0, limit=100)` returns `PluginNotification` snapshots in ascending notification ID order; it is read-only and does not change read state; `limit` is capped at 100. Push-style plugins should use the last successfully processed notification ID as the next `after_id` and keep progress in `data_dir`; the host does not track delivery state or retries.

`context.collections` provides `ensure_playlist()` / `set_playlist_movies()`, `ensure_moment()` / `set_moment_points()`, and `ensure_clip()` / `set_clip_clips()`. Collections are managed under the plugin's own `key`; setting members replaces all members of that collection, and you cannot modify keys owned by other plugins.

`ensure_video_collection(name, description=None)` gets or creates a video collection by name (Host API 9), used to add imported videos to a specified collection. A collection with the same name is reused as-is; the plugin does not overwrite the name and description set by the user; video collections have no plugin key, and `PluginCollection.key` is an empty string.

`add_video_items(collection, video_ids)` / `remove_video_items(collection, video_ids)` locate a video collection by id or name and add or remove members (Host API 9): adding is idempotent and returns 404 if any video doesn't exist; removing is idempotent, silently skips nonexistent video ids, and returns 404 if the collection doesn't exist.

## Subtitle reading and import

`context.subtitles.list(movie_id)` returns `tuple[SubtitleAsset, ...]`, each with `subtitle_id`, `file_name`, `format`, `size_bytes`, and `created_at`. It only lists registered subtitles that are still accessible, skips invalid files, and doesn't scan or clean directories.

`context.subtitles.read(movie_id, subtitle_id)` returns `SubtitleContent`: `content` is the raw `bytes`, and `sha256` is the fingerprint of the content read this time. The read limit is **10 MiB**; no host file path or writable handle is provided. Failures raise `SubtitleReadError` imported from `src.plugins.types`, distinguished by `code`:

| code | Meaning |
|---|---|
| `movie_not_found` | the movie doesn't exist (may be returned by both list and read) |
| `subtitle_not_found` | the subtitle doesn't exist or doesn't belong to that movie |
| `subtitle_path_invalid` | the subtitle path is invalid |
| `subtitle_unavailable` | the file doesn't exist or is inaccessible |
| `subtitle_too_large` | the subtitle exceeds the read limit |

Writes still use `context.import_subtitle()`, returning `SubtitleImportResult`. Check `status`, whose value is `imported`, `duplicate`, `movie_not_found`, or `invalid_format`; don't treat duplicates or invalid formats as successful new imports.

## Media queries and downloads

`context.media.list_for_movie(movie_id, library_id=None)` returns the media snapshots for that movie. Each item includes `media_id`, `movie_id`, `movie_number`, `library_id`, `library_name`, `provider_key`, `file_name`, `resolution`, `file_size_bytes`, `duration_seconds`, `valid`, and an optional `video_info`. It doesn't return a provider's `storage_ref`, real file paths, or writable handles.

`context.media.presence_for_movies(movie_ids, library_id=None)` returns each movie's `PluginMediaPresence` in a single batch query:

- `has_any`: any Media record exists, including invalid records with `valid=False`;
- `has_playable`: at least one media with `valid=True` exists;
- `items`: media snapshots in media import order.

Multi-library setups must pass the target `library_id`; omitting it means aggregating across all media libraries and cannot be used to decide whether a particular download target is missing a movie. Get the media library for a target download client via `context.downloads.get_target(download_client_id).library_id`.

Download targets can be routed automatically by the host or specified explicitly by the plugin. When `download_client_id` is not specified, the host chooses a target according to indexer–download client bindings and writes the resolved target into each candidate:

```python
candidates = context.downloads.search_candidates(
    movie_number="ABC-001",
    indexer_kind="pt",
)

candidate = choose_best(candidates)
result = context.downloads.submit(
    movie_number="ABC-001",
    candidate=candidate,
)
```

`context.downloads.list_targets()` reads the current download targets; the return value doesn't include credentials, and returns an empty tuple when there are no targets. With default routing, each indexer uses the first download client in its binding order; the order of the returned target list doesn't represent default priority. When `download_client_id` is passed explicitly, only indexers bound to that download client are searched. Candidates carry the `download_client_id`, `library_id`, `library_name`, and `provider_key` resolved by the host; plugins cannot redirect a candidate to another media library. If the target download client is deleted, unbound, or the media library provider changes, submission fails and does not automatically pick another target at submit time.

To submit the same movie to multiple media libraries, the plugin must search and submit separately for each target download client. The import after download still goes into the media library associated with that download client; you cannot combine one download provider and another storage provider in a normal plugin.

For batch backfill, it's recommended to read movie pages first, then call `presence_for_movies()`, and only search and submit for movies with `has_playable=False` in the target library. The facade currently only provides search and submit; it does not provide download job status, retries, deletion, or import control.

## Browsing media libraries and importing

`context.imports` (Host API 9) lets plugins browse media library provider storage and start imports just like manual imports in the frontend: file bytes always flow through the target media library's provider, and the plugin only handles opaque references.

- `list_libraries()`: returns all media libraries' `PluginLibrary` (`library_id`, `name`, `provider_key`), without provider configuration or credentials;
- `browse(library=..., parent_ref=None, cursor=None, limit=50)`: browse the target media library's provider storage, returning `PluginBrowsePage`; each `PluginBrowseEntry` includes the provider-private `source_ref`, `name`, `entry_type`, `size_bytes`, `modified_at`, and the host-determined `is_video` (`limit` capped at 200); ends when `next_cursor` is `None`;
- `enqueue(media_kind, library, source_ref, collection_id=None, source_disposition="keep")`: start an import by provider reference, returning `PluginImportBatch` (`task_run_id`, `task_key`, `state`);
- `get(task_run_id)`: read the status and result summary of an import job started by this plugin, returning `PluginImportStatus`; returns `None` if the job doesn't exist or doesn't belong to this plugin.

`library` accepts a media library id or name (names are unique). `source_ref` must come from a `browse()` entry and is interpreted by that media library's provider; plugins must not construct references themselves or use a reference with another media library. References with `entry_type="directory"` are expanded into their files by the provider during import.

```python
libraries = context.imports.list_libraries()
page = context.imports.browse(library="本地媒体库", limit=100)
collection = context.collections.ensure_video_collection("推特视频")

for entry in page.entries:
    if entry.entry_type != "file" or not entry.is_video:
        continue
    context.imports.enqueue(
        media_kind="video",
        library="本地媒体库",
        source_ref=entry.source_ref,
        collection_id=collection.collection_id,
    )
```

Import rules match manual imports in the frontend:

- `media_kind="video"`: create a regular video based on the file name, optionally adding it to `collection_id`;
- `media_kind="jav"`: parse the movie number from the file name, import it through the enabled metadata plugin chain, and subscribe automatically; a missing movie number, a file smaller than the minimum video size, or failed metadata retrieval is recorded as a failed item that can be handled manually in the Task Center; JAV does not support `collection_id`;
- `source_disposition="delete_after_commit"`: after a successful import, the provider deletes the source file; the default is `keep`;
- `source_disposition="in_place"`: neither copies nor moves the file; the media references the source file's current location. Only providers declaring this capability (bundle's `supports_in_place_import = True`) can use it; other providers return `422 in_place_import_unsupported`;
- only one import job is allowed per media library at a time; on conflict a `409 import_task_conflict` is raised, so wait for the current import to finish before retrying;
- with `keep` and `in_place`, the host deduplicates by the source identity provided by the provider; importing the same source again is skipped.

Browsing or import failures raise errors with `status_code` and `code` (for example library not found `404 media_library_not_found`, provider not installed `503 provider_not_installed`, authentication failure `401 provider_authentication_failed`). Import is an asynchronous job; after `enqueue()` returns, poll with `get(task_run_id)`: counts are zero during `pending` / `running`, and after completion it includes imported / skipped / failed counts, created video and movie ids, and `error_message`; the same job can also be viewed manually in the Task Center. Plugins can browse the provider list of all configured media libraries; this is the host's established trust model for trusted plugins in the repository.

## Regular videos (PornBox)

`context.videos` (Host API 9) provides read-only snapshots of regular video entries, for reconciliation, curation, and organization plugins:

- `get(video_id)`: read a single `PluginVideoSnapshot`; returns `None` if it doesn't exist;
- `list_page(after_id=0, limit=500)`: paginate through all videos by `VideoItem.id` cursor (`limit` capped at 1000), ending when `next_cursor` is `None`.

The snapshot includes `title`, `summary`, `release_date`, `media_count`, `has_playable`, `collection_ids`, and timestamps; `duration_seconds`, `file_size_bytes`, `resolution`, and `file_name` come from "the first valid media", and are `0`, `0`, `None`, `None` respectively when there is no valid media.

```python
# Add videos that have no collection yet and have playable media to the "待整理" collection.
collection = context.collections.ensure_video_collection("待整理")
page = context.videos.list_page(limit=200)
pending_ids = [
    item.video_id
    for item in page.items
    if item.has_playable and not item.collection_ids
]
if pending_ids:
    context.collections.add_video_items(collection.collection_id, pending_ids)
```

Plugins cannot rewrite a video's title, description, or cover, and there is no delete entry point; these operations happen only in the host UI.

## Movie metadata sources

### Registration and call order

Register the synchronous callback `fetch_movie(movie_number) -> PluginMovieMetadata | None` through `PluginExtension(key="catalog.metadata_source", data=PluginMetadataSource(...))`. `PluginMetadataSource`, `PluginMovieMetadata`, `PluginMetadataActor`, and `METADATA_SOURCE_EXTENSION_KEY` can all be imported from `src.plugins`.

Below is a loadable registration skeleton; a real plugin needs to replace the placeholder return of `fetch_movie()` with site queries, image downloads, and result construction, and declare the manifest's `host_api_version` as `18`:

```python
from src.plugins import (
    HOST_API_VERSION,
    METADATA_SOURCE_EXTENSION_KEY,
    PluginContext,
    PluginExtension,
    PluginMetadataSource,
    PluginMovieMetadata,
    PluginRegistration,
)


def register(context: PluginContext) -> PluginRegistration:
    def fetch_movie(movie_number: str) -> PluginMovieMetadata | None:
        # Query the site on each call; deliver metadata and images when found, return None when not.
        return None

    return PluginRegistration(
        plugin_id="example_plugin",
        display_name="示例插件",
        version="1.0.0",
        host_api_version=HOST_API_VERSION,
        extensions=(
            PluginExtension(
                key=METADATA_SOURCE_EXTENSION_KEY,
                data=PluginMetadataSource(fetch_movie=fetch_movie),
            ),
        ),
    )
```

The host calls enabled metadata sources in `plugins.enabled` order. When a plugin returns `None`, the next source is tried; exceptions or delivery validation failures are logged and the next source continues; the first valid result is used. If every source reports not found, the result is treated as not found; if sources failed and none succeeded, the source errors are returned.

The callback only delivers results; don't call `context.import_movie_by_number()` inside it, or you'll re-enter the same fallback chain.

For a complete implementation, see the [JavBus metadata plugin](https://github.com/tinypinglite/sakuramedia_javbus_metadata).

### Actor movie lists (optional)

A metadata plugin may also provide the optional `fetch_actor_movies` callback on `PluginMetadataSource` for subscribed-actor movie sync. `PluginActorMovieQuery`, `PluginActorMoviePage`, and `PluginActorRef` can all be imported from `src.plugins`:

```python
def fetch_actor_movies(
    query: PluginActorMovieQuery,
) -> PluginActorMoviePage | None:
    # Resolve the external actor by query.actor's name/aliases; return None when unknown.
    return PluginActorMoviePage(
        movie_numbers=["ABC-001", "ABC-002"],
        next_cursor=None,
    )
```

`PluginActorMovieQuery` contains the local `actor` identity, a `cursor`, and `mode` (`incremental` or `full`). When returning a page, `movie_numbers` contains the movie numbers on that page and `next_cursor` points to the next page; set it to `None` when there is no next page. The host calls every enabled metadata source that declares this capability, merges and deduplicates the numbers, then imports missing local movies through the metadata source order and links them to the actor.

The plugin owns the incremental range and any cached external actor IDs for `incremental` mode, and stores that state under `context.data_dir`. Do not return duplicate cursors; the host limits the number of pages fetched from one source.

### Results and image delivery

`PluginMovieMetadata` requires the following fields:

| Field | Requirement |
|---|---|
| `movie_number` | non-empty; after normalization must match the requested movie number |
| `title` | non-empty title |
| `release_date` | `datetime.date` or a strict `YYYY-MM-DD` string; timestamps or datetimes are not accepted |
| `duration_minutes` | positive integer; strings, floats, or booleans are not accepted |
| `cover_image_path` | local file path of the downloaded cover image; must not be a URL |

Optional fields are `summary`, `maker_name`, `director_name`, `series_name`, `actors`, `tags`, `plot_image_paths`, `source_url`, and `source_id`. Actors are expressed as `PluginMetadataActor(name=..., alias_names=[...])`; plot images are also delivered as local file paths. This contract does not accept fabricated source IDs, ratings, or external actor IDs.

Image delivery follows these rules:

1. During the callback, create a unique `context.data_dir / "metadata-tmp" / <request directory>` for each request and download the cover and plot images into that directory. Don't create directories during registration.
2. All images of the same result must belong to the same request directory; resolved paths must still be inside this plugin's `data/metadata-tmp/` and be actual, fully decodable image files.
3. Leave the files in place after returning; the host validates, copies, and ingests them. The host cleans up delivery files it has taken over after consumption; don't let a temporary directory context delete the images before the callback returns.
4. Plugins clean up files left behind by download failures, `None` returns, or failed path delivery validation. Don't use long-term cache files directly as delivery files, because the host may delete them.

The host stores source information and matches actors by local primary name or alias. If there is no match, it creates a local actor; when several records match at the same priority, the oldest record wins. Imported movies are ordinary local movies, and the host does not run an additional external backfill job. Metadata source delivery itself does not automatically claim field ownership.

Declare `test_movie_number` on `PluginRegistration` when the plugin exposes metadata, stats, or review capabilities. The plugin settings page uses it for a read-only capability test against the currently loaded configuration; the test does not import a movie, persist stats, or store reviews. If omitted, the host currently falls back to `SSIS-001` for compatibility.

## Ranking sources

Ranking plugins declare `PluginExtension(key="discovery.ranking_source", data=...)` in `extensions`. `PluginRankingSource` contains a globally unique `source_key` and one or more `PluginRankingBoard`; each board's `fetch_numbers(period)` returns a list of movie numbers, and the order is the ranking.

The plugin is responsible for accessing external sites and registering its own sync job; the host handles board storage, movie detail import, and the public API. See the [More Movie Rankings plugin](https://github.com/tinypinglite/sakuramedia_more_rank_movies).

## Media providers

A provider integrates a complete media storage boundary, not just a new download client. It is registered via `PluginExtension(key="media.provider", data=bundle)`; each `provider_key` is globally unique.

The bundle must declare:

- `provider_key`, `display_name`;
- `library_config_fields`: a tuple of `ConfigField`s; input types are only `text`, `secret`, and `path`;
- `playback_deliveries`: a non-empty tuple of distinct playback modes that must include `proxy` and may additionally support `redirect`; **the first item is the default mode**, e.g. `("redirect", "proxy")` defaults to redirect;
- `prepare_library()`: validate and normalize media library configuration;
- `build_storage()`: create a storage implementation for a media library;
- `downloads`: set to `None` when there is no download capability, or provide download components when there is.

The storage implementation must cover the following capabilities:

| Capability | Required methods |
|---|---|
| Browsing and import sources | `browse`, `scan_import_source`, `read_import_file`, `delete_import_file` |
| Import transactions | `stage_import_file`, `finalize_import`, `abort_import` |
| Media processing | `delete_media`, `compute_file_hash`, `handle_playback`, `generate_thumbnails`, `create_clip` |

`scan_import_source(source_ref=..., progress_callback=None)` may receive a JSON progress callback; only providers registered under Host API 7 receive this argument, and older providers are still called with the old signature without the callback. `generate_thumbnails(media=..., workspace=..., progress_callback=None)`'s progress callback is optional; the host is compatible with older implementations that don't yet declare it.

`source_ref`, `storage_ref`, import receipts, and `provider_config` are all opaque JSON: the host only stores and passes them back as-is, and the provider is responsible for interpreting them. `stage_import_file` must be idempotent by `operation_key`; `finalize_import` and `abort_import` must be safe to retry.

If you implement download components, you must also declare `config_fields`, implement configuration preparation and diagnostics (`prepare_client`, `test_client`, `build`), and remote job submission, listing, and deletion (`submit`, `list_tasks`, `delete_task`). Completed downloads can only be imported by the same provider.

Download components declare accepted source kinds through `supported_source_kinds`: `magnet`, `torrent`, `ed2k`, and `http`. When omitted, the host assumes `magnet`/`torrent`. `DownloadSubmission` carries `source_kind`, `resource_key`, and `source_size_bytes`; providers must treat `resource_key` as opaque and must not assume it is always a BTIH. HTTP direct links are passed to cloud download providers; the host does not fetch their content.

### Optional storage capabilities

The following capabilities are detected by method presence and are not required methods of the base storage implementation:

| Capability | Declaration or method | Convention |
|---|---|---|
| Merged playback | bundle's `merged_playback_format`, storage's `handle_merged_playback()` | format is `mp4` or `hls`; provide the merged stream in `medias` order |
| Merged playback preflight | `preflight_merged_playback(medias=...)` | validate before the host issues a merged playback URL; raise an operation error on failure |
| Skip unchanged import sources | `get_import_source_identity(source=...)` | return a string or `None`; the same identity must represent the same unchanged location, and renaming or moving must change the identity |
| Scan media references | `scan_media_refs(source_ref=...)` | enumerate provider-native references |
| Reconcile managed media | `scan_managed_media_ref_keys()`, `managed_media_ref_key(media_ref=...)` | return the key set of current media library files, and compute keys for registered media with the same rule |
| In-place import | bundle's `supports_in_place_import = True`; `stage_import_file(..., source_disposition="in_place")` | point the media directly at the import source without copying or moving files; `finalize_import`/`abort_import` must handle receipts for this disposition; `delete_media` and validity checks follow the provider's own reference rules |
| Regular video covers | `open_cover_source(media=...)` | provide the video source used for cover generation as a context manager |
| Supplement duration and resolution | `probe_duration_seconds(media=...)`, `probe_resolution(media=...)` | return integer seconds and a `"WxH"` string (or `None`) respectively; resolution may also be supplied via `StagedMedia.resolution` during import |
| Probe original video info | `probe_video_info(media=...)` | return a JSON object or `None`, used to supplement original file technical info |

### Media storage transfer

Transfer capabilities are implemented separately for the source and target sides:

- The source side's `open_transfer_source(media=...)` returns a `MediaTransferSource` context manager. The session provides `info` (file name and size), `open_reader()` (supports `read`/`seek`), and `assert_unchanged()`; it does not expose its own references or credentials to the target provider.
- The current migration flow also requires the source side to implement `cleanup_transfer_source(media=..., source=...)`, which only deletes the unchanged source file corresponding to the current session.
- The target side implements `stage_transfer(source=..., placement=..., operation_key=...)`, `finalize_transfer(receipt=...)`, and `abort_transfer(receipt=...)`. Staging is idempotent by operation key, and completion and rollback must be safe to retry.

When the target returns `StagedMediaTransfer(status="staged", ...)`, it must provide `storage_ref`, `receipt`, `file_name`, and `size_bytes`; the file name and size should match the source. When optimized transfer is unavailable, return `StagedMediaTransfer(status="not_available")` with all other fields set to `None`; the host skips that item and does not automatically fall back to a regular download plus upload.

After staging, the host checks that the source is unchanged, then switches the media storage record, completes target validation, and finally cleans up the source file. Providers should not delete the source file during `stage_transfer()`.

### Downloads and error handling

`RemoteDownloadTask.progress` is 0–1; when `state="completed"` it must carry a non-empty `completed_source_ref`, and other states must be `None`. State values are `queued`, `downloading`, `completed`, and `failed`.

Expected provider failures use `ProviderOperationError(provider_key, operation, code, safe_message, retryable)`. `code` supports `invalid_config`, `authentication_failed`, `source_not_found`, `task_not_managed`, `source_blacklisted`, `unsupported`, and `unavailable`. For example, use `task_not_managed` when refusing to delete a task not managed by this download client; `safe_message` is shown externally and should not contain cookies, passwords, or internal paths.

For complete type signatures, refer to the [backend provider protocol source](https://github.com/tinypinglite/sakuramediabe/blob/main/src/plugins/provider_protocol.py). See the [Local Storage & qBittorrent provider](https://github.com/tinypinglite/sakuramedia_local_provider) and the [115 provider](https://github.com/tinypinglite/sakuramedia_115_provider).

## Development, installation, and troubleshooting

Check a plugin directory from the root of the SakuraMediaBE repository:

```bash
uv run python -m src.start.commands plugins check /path/to/example_plugin
```

When publishing a zip, `manifest.json` and `__init__.py` must be at the zip root, without an extra directory level. After installation, plugins without dependencies only need the API and job services restarted; plugins that declare `dependencies` must restart the full container.

The runtime loader logs and isolates individual plugin load errors; however, dependency installation or pre-install validation before the container starts can still block startup, so check the container startup logs as well. Go to "System Settings → Plugins" or run `plugins list` to see `load_error`; common causes are the directory name not matching `plugin_id`, the plugin `version` in the manifest not matching `register()`, an incompatible Host API declaration, or conflicting job and extension point identifiers. `plugins check` only validates import, registration, and contracts; it does not mean network behavior, image delivery, or job execution have passed acceptance.

## Multilingual support (zh-CN / en)

Plugins can declare both Chinese and English copy, and the host renders it in the current language. A Chinese-only plugin still works, but user-visible copy should provide English as well.

### Catalogs

Catalogs live at the plugin package root:

```text
example_plugin/
├── manifest.json
├── __init__.py
└── i18n/
    ├── zh-CN.json
    └── en.json
```

- Both files must define exactly the same key set; keys are non-empty flat dotted strings (such as `jobs.sync.cli_help`), not nested objects.
- Values are strings; for plurals, write `{"one": ..., "other": ...}` and pass `count=` to `t()`.
- Placeholders use `{name}`, and both languages must use the same placeholders.
- A missing catalog or a missing key is legal: static fields fall back to the plugin's source text, and runtime text falls back to `default`. `plugins check` and pre-install validation strictly validate catalog structure (JSON, key form, value types), while runtime loading stays lenient, so a broken catalog does not block an enabled plugin.

Multilingual copy takes two paths: static copy is resolved by the host **at read time**, while runtime text is generated by the plugin **at write time**. Do not mix the two.

### Static copy: `*_i18n` dicts

These fields are a "source field plus optional `*_i18n` dict". The host resolves them in the current language at read time, falling back to `zh-CN` and then the plugin's source text:

| Location | Fields |
|---|---|
| `manifest.json`, `PluginRegistration` | `display_name_i18n` (either one is enough; when both are provided, `register()` wins); `manifest.json` may also declare `description` / `description_i18n`, which the plugin market uses for the plugin summary |
| `JobDefinition` | `cli_help_i18n` |
| Task parameter and settings JSON Schemas | `title_i18n` / `description_i18n` at any level, including `title_i18n` on combinator options such as `oneOf` |
| Provider `ConfigField` | `label_i18n`, `description_i18n`, `hint_i18n` |
| Media provider bundle | `display_name_i18n` |
| Ranking `PluginRankingSource`, `PluginRankingBoard` | `name_i18n` |

The `description` / `description_i18n` fields of `manifest.json` are used by the plugin market only: the market
index repository reads the manifest of each plugin's latest release every day and syncs the display name and
summary (including their translations) into `index.json`; the client resolves them as
"current language → `zh-CN` → source text". Both fields are optional — when a plugin does not declare them the
market keeps its own copy, so the English UI shows the source text. Declaring them requires a new plugin release
before the market index picks up the new copy.

Pydantic models carry the dicts through `json_schema_extra`, generated at import time by the plugin's own catalog reader:

```python
from pydantic import BaseModel, Field

from .translations import text_map


class Settings(BaseModel):
    username: str = Field(
        default="",
        json_schema_extra={"title_i18n": text_map("settings.username.title")},
    )
```

For how to read catalogs, follow the sample plugin `sakuramedia_more_rank_movies`'s `translations.py`: `text_map(key)` returns `{locale: text}`, and `text(key, locale, default)` returns the source text; when a file or key is missing they return an empty dict or a fallback value instead of failing at import time.

### Runtime text: `context.i18n.t()`

Progress, diagnostics, and error text are generated at write time, and the language depends on the request or job at that moment, so you must call `context.i18n.t()`:

```python
reporter.emit(
    current=done,
    total=total,
    text=context.i18n.t(
        "sync.progress",
        default="已同步 {done}/{total} 个榜单",
        done=done,
        total=total,
    ),
)
```

- `t(key, default=None, **params)` looks up the plugin catalog in the current language and falls back to `zh-CN`; **when the key is missing and no `default` is given, it returns the key itself**, so every call should provide a Chinese `default` fallback.
- Catalog files are cached by path, so calling inside loops is fine.
- Applies to job progress text, `ProviderDiagnosticCheck.message`, `ProviderOperationError.safe_message`, job failure reasons, notification bodies, and metadata errors.

### Declarations and language selection

New plugins should declare the manifest's `host_api_version` as `18`, and keep using the `HOST_API_VERSION` constant in `register()`; do not change the plugin's own `version` because of multilingual support.

On request paths, the host determines the current language from `Accept-Language`, then the user's `User.language` preference, and finally the default `zh-CN`; background jobs have no request context and read the single account's `User.language` when they run. Plugins do not need to parse request headers themselves.

Use `sakuramedia_more_rank_movies` as the sample: the manifest and `plugin.py` declare the display name, `boards.py` declares board names, `sync_jobs.py` declares task parameters and field titles, and the sync job uses `t()` to generate progress text.

## Version compatibility

The current host constants are `HOST_API_VERSION = 18` and `MIN_SUPPORTED_HOST_API_VERSION = 18`. Loading rules:

- The manifest's `host_api_version` must be **18**.
- `register()`'s `host_api_version` must also be **18**.
- `catalog.metadata_source`, `catalog.movie_reviews`, and `catalog.movie_stats` require Host API **18**.
- All older Host API plugins are incompatible and must be released again with API 18.

Before upgrading, verify the actual host version, public types, and capabilities you use, then run the plugin check. A plugin's own `version` and the Host API version are two different concepts; the plugin `version` in the manifest and `register()` must still match exactly.
