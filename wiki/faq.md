---
outline: [2, 3]
---

# FAQ

This page collects the explanations of behavior that come up most often in the current version. Background task frequency follows your own `config.toml`.

## Metadata plugin networking and proxy

The bundled metadata plugins access the following domains:

```text
adult.contents.fc2.com
storage*.contents.fc2.com
contents-thumbnail*.fc2.com
fc2cmadb.com
api.video.dmm.co.jp
video.dmm.co.jp
awsimgsrc.dmm.co.jp
pics.dmm.co.jp
www.javbus.com
```

The host being able to reach a site does not mean the container can reach it. Requests to external sites use the `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` environment variables of the `sakuramedia` container; setting a proxy only for the Docker daemon or the host does not pass it to the container.

Troubleshooting order:

1. Run "Overview → Component Diagnostics". It uses the test movie number to make a real request to every enabled metadata source inside the container. "No data" means the network works but the test movie number was not found; "Failed" means you should check the network or plugin settings next.
2. Check DNS and connectivity for the fixed domains from the deployment host. If the host has `curl`, run:

   ```bash
   for host in adult.contents.fc2.com fc2cmadb.com api.video.dmm.co.jp video.dmm.co.jp awsimgsrc.dmm.co.jp pics.dmm.co.jp www.javbus.com; do
     curl -sS -o /dev/null -w "$host %{http_code}\n" --max-time 10 "https://$host"
   done
   ```

   `storage*` and `contents-thumbnail*` are wildcard subdomains; verify them through the real requests made by Component Diagnostics.
3. Check whether a router or transparent proxy routes these domains to an unusable gateway.
4. If a proxy is required, configure it in `sakuramedia.environment` in the compose file:

   ```yaml
   HTTP_PROXY: "http://192.168.1.1:7890"
   HTTPS_PROXY: "http://192.168.1.1:7890"
   NO_PROXY: "localhost,127.0.0.1,postgres,qbittorrent"
   ```

   The proxy address must be reachable from the container; inside a container, `127.0.0.1` usually points to the container itself rather than the host. Keep LAN indexers, qBittorrent, PostgreSQL, and similar services in `NO_PROXY` so internal requests do not go through the proxy. Restart the `sakuramedia` container after changing these values.

Connection settings for indexers, download providers and media providers are still entered in their own configuration.

## Accounts and sign-in

### What if I forget my username or password?

Run `reset-account` in the backend container to rebuild the account with a new username and password:

```bash
docker exec -it --user app -w /app sakuramedia python -m src.start.commands reset-account
```

You can also pass `--username` and `--password` directly. The command clears refresh tokens, so clients that were signed in need to sign in again. See [Common commands](/guide/commands#reset-the-account).

## Search and data

### Search or import by movie number fails. What should I do?

This release uses only enabled metadata plugins, in the order configured under Settings → Metadata Sources. The official image bundles four metadata sources: DMM / FANZA, FC2, FC2CMADB, and JavBus. Run the "Capability test" for the relevant plugin on the Plugins page, then check each source's result under "Overview → Component Diagnostics". "No data" means the plugin is reachable but did not find the test movie number; "Failed" means you should check the plugin settings and network. Every plugin must declare Host API 18; older plugins that have not been released against 18 cannot load.

### Online search for movies or actors fails

First run "Component Diagnostics" on the "Overview" page to confirm the media library, metadata sources and indexers are reachable; each metadata source shows its own test result. Then check container networking, proxy rules and DNS. Plugin-specific errors appear in the manual-match source-error notice or backend logs.

Covers and stills are delivered by metadata plugins; avatars are downloaded by the backend from GFriends. If your router runs a transparent proxy, check whether the relevant domains are routed to an unusable gateway; when they cannot be reached, images will be missing. See [Metadata plugin networking and proxy](#metadata-plugin-networking-and-proxy) for the domains and container proxy settings.

### Why don't I see any movies or actors right after starting?

Local search only queries data that has already been imported. After a first deployment, turn on the "Online" switch on the search page and run an online search once; successful results are written to the local library.

### Why is "New from actors" empty?

That page shows recent local movies linked to actors you have subscribed to. The system syncs release data through metadata plugins that declare the actor movie list capability; the bundled JavBus plugin supports it. The background task is "Subscribed actor movie sync", which runs daily at 02:00 by default. The first run scans the full list, and later runs check incrementally.

Check in order: you have subscribed to actors, the sync task completed successfully, and the metadata plugin can reach the network. The list can also be empty when a subscription was just added and has not synced yet, or when there are no recent releases. Subscribing to an actor does not subscribe to her movies; once you see a movie you want, subscribe to that movie separately. See [Background Tasks](/guide/tasks#subscribed-actor-movie-sync) for details.

### Why can't I see interaction stats, heat, or reviews?

Movie interaction stats, heat, and reviews are all provided by plugins. The official image does not bundle such a plugin. When none is installed, or no stats/review source is bound under "Settings → Metadata Sources", the frontend hides the related sections. After installing a compatible plugin, select the source for each capability there.

### What does search by image require?

The image library comes from thumbnails generated for playable media, feature extraction is done by the SigLIP2 embedding service, and vectors are stored in Qdrant. Once all three are ready, background tasks generate and index images gradually.

If results are empty, check the embedding service on the "Overview" page first, then run "Media thumbnail generation", "Search-by-image thumbnail vector index" and "Search-by-image plot image vector index" in the task center.

## Media library and import

### How do I choose a source when importing ordinary videos?

Go to "Manage → Resource import", switch to "Videos", create a new import and choose the target media library, then use the source browser to pick files or directories. Before importing, decide whether to keep the source files.

Ordinary videos can go into video collections; after the import task finishes, adjust the member order on the collection page. See [PornBox and ordinary videos](/guide/videos) for details.

### What if the import says the file is too small?

Movie import uses `[media].allowed_min_video_file_size` to filter out videos that are too small; the default is 256 MB. To import smaller videos, lower that value in the system settings or in `config.toml`.

### Why doesn't a subscribed movie download automatically?

Automatic download requires all of the following at once: the movie has no playable media yet, the indexer returns candidates, the indexer is bound to a download client, and that download client's provider configuration is usable. Run component diagnostics first, then trigger "Auto download missing subscribed movies" manually in the task center.

### How does auto download choose candidates?

A candidate must have an available source, a size between `1 GiB` and `40 GiB`, and more than `0` seeders. The system sorts by size from largest to smallest and uses the indexer name and title for a stable order; when submitting, it uses the first download client in that indexer's binding order.

### How does a completed download reach the media library?

Once the download provider returns `completed` and `completed_source_ref`, a background task hands that source to the target media library provider for import. When checking, confirm in order: the download client's state has been synced, the task carries the completed source reference, the media library provider configuration is usable, and the "Auto import completed downloads" task has not failed.

### Media breaks after an in-place import

In-place media references the source file directly. If the source file is moved, renamed or its content changes, the media breaks; deleting the media record in SakuraMedia does not delete the source file. Keep the file location fixed, or switch to the "Keep source files" import mode.

## Playback and decoding

### Where does the play URL come from?

The backend generates a signed `play_url` for every media item, and clients play through that URL. Signed URLs expire, and clients fetch a new one when needed.

### Does playback need server-side transcoding?

Decoding happens on the client. Whether the player can use hardware decoding depends on the current device, the operating system and the media codec; the server is responsible for serving the media and the signed play URL.

### What should I check first when playback stutters?

First confirm the media library provider is reachable and the `play_url` opens in the client, then check the client device's decoding capability and network bandwidth. You can run component diagnostics on the "Overview" page.

## Task center

### What do the notification center and task center show?

The notification center shows reminders; the task center shows the status, progress, results and errors of background jobs. Download sync, automatic import, thumbnails, image indexing and plugin tasks are all viewed in the task center.

### Can download jobs be deleted?

Yes. When deleting from the download job list, choose whether the provider should also delete the remote task and files. Deletion only removes the selected task records; it does not delete movies already imported into a media library.

## Clips and video collections

### After deleting media, do moments remain?

The current version deletes the associated moments and their collection memberships together with the media. Moments cannot be reattached automatically once detached from media. Standalone clips that were already generated are kept; verify they can play before cleaning up. See [Media library management](/manual/media-management).

### Where are clips stored?

Clips are standalone mp4 files stored in `[media].media_clip_root_path` (default `/data/media-clips`). That directory needs to be persisted, and deleting the source movie does not delete clip files.

### Why is a clip too long or failing to generate?

A single clip's duration is limited by `media_clip_max_duration_seconds`, and ffmpeg execution time is limited by `media_clip_ffmpeg_timeout_seconds`. See [Configuration](/guide/config#media) for how to adjust them.

### Can a video collection play continuously?

Yes. A collection stores its video members and their order, and the client plays them in order; the same video can belong to several collections.

