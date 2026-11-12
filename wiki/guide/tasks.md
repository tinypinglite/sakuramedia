---
outline: [2, 3]
---

# Background Tasks

The SakuraMedia host includes built-in scheduled tasks, and plugins can register their own. The Task Center shows run status, progress, results and error messages.

## Built-in task overview

| Task | Purpose | Default schedule |
|---|---|---|
| Subscribed actor movie sync | Syncs movie lists for subscribed actors and imports missing movie records | Daily at 02:00 |
| Auto-download missing subscribed movies | Searches for and submits matching resources | Daily at 02:30 |
| Movie stats and heat sync | Refreshes interaction stats and heat through the bound plugin | Daily at 05:00 |
| Download task status sync | Syncs task status from each provider's download client | Every minute |
| Auto-import completed downloads | Hands completed tasks to the import flow using `completed_source_ref` | Every minute |
| Media file hash backfill | Computes hashes for media files that lack them | Daily at 03:00 |
| Media thumbnail generation | Generates thumbnails for playable media | Every 30 minutes |
| Image search indexing | Generates vectors for media thumbnails and scene images | Every 5 minutes |
| Movie similarity recalculation | Computes similar movie results | Daily at 03:30 |
| Recommended moment generation | Generates candidate recommended moments | Daily at 04:00 |
| Daily recommendation generation | Generates daily recommendation snapshots | Daily at 05:00 |
| GFriends avatar cache refresh | Refreshes the GFriends file-tree cache | Mondays at 04:00 |
| Activity record cleanup | Cleans up task run records and read notifications | Daily at 05:30 |

Tasks registered by plugins appear in the same Task Center and use the plugin's own settings and cron.

When "Image & Text Search" is off, the image search indexing task is not scheduled; when "Similar Movies & Vector Service" is off, similarity recalculation and the index build at startup do not run. The Task Center shows them as "Not enabled" and they cannot be run manually; related tasks already queued before the restart are skipped. Thumbnail generation and recommendation tasks remain, and recommendations skip the disabled signal.

## Subscription sync tasks

### Subscribed actor movie sync

The system walks through subscribed actors, calls every enabled metadata plugin that declares the actor movie list capability, merges and deduplicates movie numbers, imports missing movies into the local library, and links them to the actor. The first sync scans the full list, and later runs check incrementally; the task is skipped when no capable plugin is enabled. The bundled JavBus plugin supports this capability.

Subscribing to an actor only syncs release data. It does not subscribe to her movies or download them automatically.

## Download pipeline tasks

### Auto-download missing subscribed movies

The system queries indexers for movies that are subscribed but do not have playable media yet. Candidates are selected by the backend's filtering rules and then handed to the first download client bound to that indexer; the download client is provided by a provider, and its exact capabilities are decided by the plugin.

### Download task status sync

Status is synced through the task interface of the download client provider. Task records keep the state the host needs and the source reference returned by the provider.

### Auto-import completed downloads

Once a download client returns `completed` with a `completed_source_ref`, the task enters the import queue. The import request passes `source_ref` unchanged to the provider of the target media library, which scans the source and writes it into the media library.

## Media and discovery tasks

- **Media thumbnail generation**: prepares the thumbnails needed for moment previews and image search on playable media.
- **Media file hash backfill**: computes hashes for media files that lack them.
- **Image search indexing**: hands pending media thumbnails and scene images to the SigLIP2 embedding service, then writes them into Qdrant.
- **Movie similarity recalculation**: computes the similar movies shown on detail pages offline.
- **Recommended moment generation / daily recommendation generation**: prepares data for the discover and recommendation pages.
- **Movie stats and heat sync**: refreshes `interaction_stats` and the plugin-computed `heat` for movies. It does nothing when no stats plugin is bound; existing values remain available.
- **GFriends avatar cache refresh**: downloads the file-tree index and writes it to the local cache.

## Default cron configuration

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"

actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "* * * * *"
download_task_auto_import_cron = "* * * * *"
movie_stats_sync_cron = "0 5 * * *"
media_file_hash_backfill_cron = "0 3 * * *"
media_thumbnail_cron = "*/30 * * * *"
image_search_index_cron = "*/5 * * * *"
movie_similarity_recompute_cron = "30 3 * * *"
moment_recommendation_generate_cron = "0 4 * * *"
daily_recommendation_generate_cron = "0 5 * * *"
gfriends_filetree_refresh_cron = "0 4 * * 1"
activity_cleanup_cron = "30 5 * * *"

activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

## Task execution rules

- Tasks triggered by `aps <job>` or from the Task Center appear in the Task Center.
- Manual and scheduled runs of the same task are mutually exclusive; a running task is not queued again.
- A service restart reclaims the state of interrupted tasks.
- Download tasks can be deleted from the download task center; when deleting, you can let the provider delete the remote task and its files as well, depending on what the provider supports.
- Deleting a task record only affects the local list; it is not a substitute for storage management in the media library or the provider.

See the [Configuration Reference](/guide/config#scheduler) for task cron expressions and retention periods; plugin tasks follow the plugin settings.
