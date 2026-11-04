# Configuration Reference

The configuration file lives at `sakuramedia-data/config/config.toml`. Every path in the configuration refers to a path inside the container. `/data` holds backend runtime data.

## Configuration overview

- Root level: `enable_docs`
- `[database]`
- `[auth]`
- `[media]`
- `[metadata]`
- `[plugins]`
- `[scheduler]`
- `[downloads]`
- `[logging]`
- `[image_search]`
- `[qdrant]`

## `enable_docs`

```toml
enable_docs = false
```

Controls whether the Swagger / ReDoc documentation pages are enabled. Keep it `false` for normal use and switch it to `true` only when you need to read the API documentation.

## `[database]`

```toml
[database]
engine = "postgres"
url = "postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia"
```

| Field | Default | Purpose |
|---|---|---|
| `engine` | `postgres` | Database type. PostgreSQL is used at present. |
| `url` | `postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia` | PostgreSQL connection string. |

No changes are needed if you copy the compose file from Quick Start; with an external PostgreSQL, enter a reachable connection string and prepare the database before starting.

## `[auth]`

```toml
[auth]
username = "account"
password = "account"
secret_key = ""
algorithm = "HS256"
access_token_expire_minutes = 43200
refresh_token_expire_minutes = 10080
file_signature_secret = ""
```

| Field | Purpose |
|---|---|
| `username` / `password` | Credentials for the first login. They can be changed in System Settings after signing in. |
| `secret_key` | JWT signing key. When left empty, it is generated automatically on first start and written to the configuration. |
| `algorithm` | JWT signing algorithm, `HS256` by default. |
| `access_token_expire_minutes` | Access token lifetime (minutes). |
| `refresh_token_expire_minutes` | Refresh token lifetime (minutes). |
| `file_signature_secret` | Signing key for media, image and subtitle files. Generated automatically on first start when left empty. |

## `[media]`

```toml
[media]
allowed_min_video_file_size = 268435456
import_image_root_path = "/data/cache/assets"
media_clip_root_path = "/data/media-clips"
media_clip_max_duration_seconds = 900
media_clip_ffmpeg_timeout_seconds = 120
```

| Field | Purpose |
|---|---|
| `allowed_min_video_file_size` | Minimum video size for media import (bytes), 256 MB by default. |
| `import_image_root_path` | Directory where images are cached during import. |
| `media_clip_root_path` | Directory where clip files are stored. |
| `media_clip_max_duration_seconds` | Maximum allowed duration of a single clip, 900 seconds by default. |
| `media_clip_ffmpeg_timeout_seconds` | Timeout for one ffmpeg clip operation, 120 seconds by default. |

Collection detection for movies is handled by an installed plugin. Go to "System Settings → Plugins" to install, enable and configure the corresponding plugin.

## `[metadata]`

```toml
[metadata]
gfriends_filetree_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends/Filetree.json"
gfriends_cdn_base_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends"
gfriends_filetree_cache_path = "/data/cache/gfriends/gfriends-filetree.json"
gfriends_filetree_cache_ttl_hours = 168
import_metadata_max_workers = 3
```

| Field | Purpose |
|---|---|
| `gfriends_filetree_url` | URL of the GFriends file-tree index. |
| `gfriends_cdn_base_url` | Base URL of the GFriends CDN. |
| `gfriends_filetree_cache_path` | Local cache path for the file tree. |
| `gfriends_filetree_cache_ttl_hours` | File-tree cache lifetime (hours). |
| `import_metadata_max_workers` | Number of concurrent threads used to fetch metadata during movie import. |

Requests to external sites uniformly use the container environment variables `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY`. Connections to indexers, download providers and media providers are managed by each plugin's own configuration.

## `[plugins]`

```toml
[plugins]
root_dir = "/data/plugins"
enabled = []
job_crons = {}
settings = {}
```

| Field | Purpose |
|---|---|
| `root_dir` | Root directory where plugins are installed. |
| `enabled` | List of enabled plugin IDs. |
| `job_crons` | Cron overrides for plugin background tasks, grouped by plugin ID. |
| `settings` | Private plugin settings, grouped by plugin ID. |

The entry point for installing, enabling and configuring plugins is "System Settings → Plugins"; you can also use the `plugins` commands in [Common Commands](/guide/commands).

## `[scheduler]`

This group controls host scheduled tasks. Every value is a cron expression; the defaults are as follows:

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"
actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "* * * * *"
download_task_auto_import_cron = "* * * * *"
movie_heat_cron = "15 0 * * *"
movie_interaction_sync_cron = "0 5 * * *"
media_file_hash_backfill_cron = "0 3 * * *"
media_thumbnail_cron = "*/30 * * * *"
image_search_index_cron = "*/5 * * * *"
movie_similarity_recompute_cron = "30 3 * * *"
moment_recommendation_generate_cron = "0 4 * * *"
daily_recommendation_generate_cron = "0 5 * * *"
activity_cleanup_cron = "30 5 * * *"
gfriends_filetree_refresh_cron = "0 4 * * 1"
activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

| Field | Purpose |
|---|---|
| `enabled` | Whether background scheduled tasks are enabled. |
| `log_dir` | Log directory for background tasks. |
| `actor_subscription_sync_cron` | Sync of movies for subscribed actors. |
| `subscribed_movie_auto_download_cron` | Auto-download of missing subscribed movies. |
| `download_task_sync_cron` | Sync of provider download task status. |
| `download_task_auto_import_cron` | Hands completed provider tasks to the import flow. |
| `movie_heat_cron` | Movie heat recalculation. |
| `movie_interaction_sync_cron` | Sync of movie interaction counts. |
| `media_file_hash_backfill_cron` | Fills in hashes for media files that lack them. |
| `media_thumbnail_cron` | Media thumbnail generation. |
| `image_search_index_cron` | Vector indexing of media thumbnails and scene images. |
| `movie_similarity_recompute_cron` | Movie similarity recalculation. |
| `moment_recommendation_generate_cron` | Recommended moment generation. |
| `daily_recommendation_generate_cron` | Daily recommendation snapshot generation. |
| `activity_cleanup_cron` | Cleanup of Activity Center records. |
| `gfriends_filetree_refresh_cron` | Refresh of the GFriends file-tree cache. |
| `activity_task_run_retention_per_key` | Number of run records kept per task key. |
| `activity_notification_read_retention_days` | Days to keep read notifications. |

See [Background Tasks](/guide/tasks) for task details and how to trigger them manually.

## `[downloads]`

```toml
[downloads]
subscription_search_fresh_days = 90
subscription_search_stale_attempt_limit = 3
torznab_timeout_seconds = 60.0
```

| Field | Purpose |
|---|---|
| `subscription_search_fresh_days` | Number of days by which a movie counts as new based on its release date; when a search for a new movie finds no resources, it does not consume the stale attempt count. |
| `subscription_search_stale_attempt_limit` | Maximum number of rounds in which no usable resource is found for an older movie; once reached, it is marked as "given up" and the search must be reset manually. |
| `torznab_timeout_seconds` | Timeout for a single indexer search request (seconds), 60 by default. |

Which indexer and download client are used is decided by the indexer bindings; the provider's own connection parameters are entered in the media library or download client configuration.

## `[logging]`

```toml
[logging]
level = "INFO"
```

Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR` and `CRITICAL`. Use `INFO` normally and switch to `DEBUG` temporarily when troubleshooting.

## `[image_search]`

```toml
[image_search]
enabled = false
inference_base_url = "http://siglip2-embed:8080"
inference_timeout_seconds = 120.0
inference_connect_timeout_seconds = 3.0
inference_api_key = ""
inference_batch_size = 16
session_ttl_seconds = 600
default_page_size = 20
max_page_size = 100
search_scan_batch_size = 100
index_upsert_batch_size = 100
```

`enabled` controls image/text frame search, image vector indexing and visual recommendations, and it requires `[qdrant].enabled` to be on as well. On desktop you can edit both switches, the connection address and the API key in "System Settings → Advanced Settings → Image Search / Similarity"; restart the backend container (API and APS) after saving for the change to take effect.

Both switches are off by default on new deployments; when upgrading an older deployment, only missing switches are filled in as enabled, so values you have already saved are never overwritten. Mobile does not provide a settings form, but adjusts its entry points based on server capabilities.

These fields control the SigLIP2 embedding service connection, search sessions and Qdrant index batching. The default address matches the `siglip2-embed` service name in the [Quick start](/guide/quick-start#full-compose-example); you only need to change the connection fields when the embedding service runs on another host, uses a different service name, or has authentication enabled.

Text-to-frame search also requires the SigLIP2 container to load the text tower (loaded by default); if the container sets `TEXT_TOWER_ENABLED=false`, only image vectors are provided, text-to-frame search is unavailable, and image search is unaffected. See [Optional vector services and SigLIP2 hardware options](/guide/quick-start#optional-vector-services-and-siglip2-hardware-options) for details.

`index_upsert_batch_size` controls how many pending thumbnails and scene images the indexing task reads per round. The task keeps processing until both pending queues are empty; the parameter only limits the amount read per round and does not cap the total work of a single run.

## `[qdrant]`

```toml
[qdrant]
enabled = false
url = "http://qdrant:6333"
api_key = ""
```

`url` is the Qdrant HTTP API address; with the compose deployment, use the in-container service name `qdrant`. Fill in `api_key` when Qdrant authentication is enabled.

`enabled` controls similar movies and the vector service. When it is off, Qdrant is not contacted and recommendations skip the movie similarity signal; disabling image search does not affect similar movies, which depend on Qdrant alone. When disabling Qdrant you should disable image search as well; desktop prompts you and saves both together. The switch does not stop or remove Docker containers — to free resources, stop the containers on the deployment side.
