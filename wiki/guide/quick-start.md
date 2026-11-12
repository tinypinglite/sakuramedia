---
outline: [2, 3]
---

# Quick Start

This guide deploys the SakuraMedia backend from scratch and imports movies that already exist on the host into the media library. After completing the basic flow, you can continue to configure automatic downloading and vector services as needed.

If you only want to get import and playback working first, completing stages 1 and 2 is enough. Automatic downloading, image search, the 115 cloud drive and other features are optional extensions; see the two sections below and [Recommended Plugins](/guide/plugins).

## Before you begin

- A host or NAS that runs continuously, with Docker and Docker Compose installed.
- An SSD directory for backend runtime data (database, configuration, logs, plugins).
- The client, downloaded from [GitHub Releases](https://github.com/tinypinglite/sakuramedia/releases/latest).

## Stage 1: Deploy the backend

### 1. Prepare the directories

#### 1.1 Prepare the runtime data directory

First create an empty directory on an SSD (recommended) and create a `sakuramedia-data` directory inside it. This directory holds the files `sakuramedia` needs at runtime; it does not contain media files.

#### 1.2 Prepare the media file directory

This guide assumes you already have some movies, stored under `/mnt/av`. Create a `media` directory in the parent directory of `av`; that is the directory you will use when adding the media library later, and every movie that is downloaded automatically or imported afterwards will be stored there. **Do not manually add files to this directory or modify the files inside it.**

#### 1.3 Prepare the qBittorrent download directory

So that imports can hard link files correctly, set the qBittorrent download directory as a sibling of the `media` directory — that is, of the media library root. For example `/mnt/downloads`.

Final directory layout example:

```text
/mnt
├── av/          # Existing movies (example name; replace with your actual directory)
├── media/       # For the SakuraMedia media library you will create later
└── downloads/   # The download directory of the qBittorrent container
```

With this layout, the mount in the next step only needs to mount `/mnt`, which brings the existing movies directory, the media library directory and the qBittorrent download directory in at the same time.

### 2. Write `compose.yaml`

Create `compose.yaml` as a sibling of the `sakuramedia-data` directory and fill in the following content. The `volumes` of the `sakuramedia` container must be adjusted to your actual setup.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: sakuramedia-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: sakuramedia
      POSTGRES_USER: sakuramedia
      POSTGRES_PASSWORD: sakuramedia
    volumes:
      - ./sakuramedia-data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sakuramedia -d sakuramedia"]
      interval: 10s
      timeout: 5s
      retries: 10

  sakuramedia:
    image: tinyping/sakuramediabe:latest
    container_name: sakuramedia
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      # Change the 38000 on the left if you need a different host port.
      - "38000:8000"
    environment:
      # If you know what PUID/PGID mean, set them to match the host user.
      PUID: 0
      PGID: 0
      # Change this to the host time zone if you are not on China time.
      TZ: "Asia/Shanghai"
      # If the host cannot reach GFriends or the metadata sites directly, uncomment the next three lines and fill in your proxy address.
      # HTTP_PROXY: "http://192.168.1.1:7890"
      # HTTPS_PROXY: "http://192.168.1.1:7890"
      # NO_PROXY: "localhost,127.0.0.1,postgres,qbittorrent"
      MALLOC_TRIM_THRESHOLD_: "131072"
    volumes:
      - ./sakuramedia-data:/data # This line usually does not need to change.
      # Host parent directory that holds the existing movies and the media library; change it to your own path. This example follows the assumptions above.
      - /mnt:/mnt
```

::: danger Must be changed before saving
- Change `/mnt` to the host parent directory that contains both the "existing movies directory" and the "media library directory". It must be an absolute path.
- Change `TZ` if you are not in the China time zone.
- If SakuraMedia runs as a non-root user, make sure PUID/PGID have read and write access to your mounted media directory (in the example, `/mnt`).
:::

SakuraMedia's `/data` holds backend runtime data, while media data lives under `/mnt`; an HDD is recommended.

::: tip Database
By default the backend connects to the built-in PostgreSQL through the service name `postgres`, so the example works as-is. To use an external PostgreSQL, change `[database].url` as described in the [Configuration Reference](/guide/config#database).
:::

### 3. Start

```bash
# Go to the directory containing compose.yaml
cd /path/to/compose-directory
docker compose up -d
docker compose ps
```

The first start creates the tables. Once `postgres` shows `healthy` and `sakuramedia` shows `running` in `docker compose ps`, open the client and enter the backend address on first login:

```text
http://your-ip:38000
```

The default username and password are `account` and `account`. Change the password right after logging in.

::: tip Metadata plugins
This release requires every plugin to declare Host API 18. The official image already bundles and enables four metadata plugins: DMM / FANZA, FC2, FC2CMADB, and JavBus, so no installation is needed on a first deployment. You can adjust their order under Settings → Metadata Sources; restart the backend after saving. JavBus also supports syncing subscribed-actor movie lists. Actor search uses the backend's bundled GFriends index.
:::

::: warning Metadata plugin networking
These plugins need the container to resolve and reach the following domains when querying metadata and downloading covers:

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

After startup, run "Overview → Component Diagnostics"; it uses the test movie number to make a real request to every enabled metadata source. If it fails, check the host network and DNS first. If the container still cannot connect, configure `HTTP_PROXY` / `HTTPS_PROXY` for the `sakuramedia` service (the compose example has commented lines ready) and restart the container before testing again. See the [FAQ](/faq#metadata-plugin-networking-and-proxy) for transparent-proxy routing and `NO_PROXY` guidance.
:::

## Stage 2: Create a media library and import your existing movies

The official image already has "Local Storage & qBittorrent" installed and enabled, along with common metadata, ranking, collection detection, and subtitle plugins, so there is no need to upload a plugin.

### 1. Create a media library

Go to "System Settings → Media Library → Add", choose "Local Storage & qBittorrent" and fill in:

| Field | Value | Host directory |
|---|---|---|
| Media library path | `/mnt/media` | `/mnt/media` |
| Manual import root (the directory where your existing movies are stored) | `/mnt/av` | `/mnt/av` |

The media library path is the final destination for imported movies; the manual import root is the root directory browsed when importing resources in the app.

### 2. Import your existing movies

"Manage → Media Import" → "JAV Movies" → "New Import" → select the media library you just created → select movie files or directories in the source browser → choose an import mode → start the import.

The three import modes:

| Mode | What actually happens | Source file | Best for |
|---|---|---|---|
| Keep source file | Prefers a hard link; falls back to copying when a hard link is not possible | Kept | Same mount point, saving space and keeping the torrent seeding |
| Delete source file after import | Copies into the media library and deletes the source file on success (effectively a move) | Deleted | You do not want to keep the original |
| Import in place | No copy and no hard link; the media references the source file directly | Untouched | Files are already organized and you do not want to touch them |

- **Keep source file**: on the same mount point with a filesystem that supports hard links, the import finishes almost instantly and uses no extra space; when a hard link is not possible it copies instead, which is slower and uses twice the space.
- **Delete source file after import**: the file is copied into the media library first and the source is deleted after a successful import; during the import it temporarily uses twice the space, but it also works across filesystems. Before choosing it, make sure the file is not seeding or in use by another program.
- **Import in place**: only supported from a manual import directory; if the source file is later moved, renamed or modified, the media becomes broken; deleting the media record in SakuraMedia does not delete the source file.

For a first import, pick a small directory and verify the flow with "Keep source file".

After submitting, watch the progress in the "Task Center". Once the import succeeds, open the movie detail page to confirm the media appears and plays.

Import tasks are one-off tasks; if the source directory changes later, for example when new movies are added, they will not be imported automatically.

## Optional: auto download and indexers

After completing the deployment and media library creation above, SakuraMedia needs a configured download client and indexer before it can automatically find sources for subscribed movies, submit downloads, and import them into the media library. This section uses local storage and qBittorrent as an example.

### What you need

- A reachable qBittorrent on the same machine as SakuraMedia (Docker on the same host or a NAS package).
- A Jackett or Prowlarr indexer.
- If you want to use hard links, the download directory and the media library must be on the same mount point.

### 1. Make qBittorrent and SakuraMedia see the same download directory

The basic deployment above sets the media library directory to `/mnt/media` and mounts its parent directory `/mnt` into the `sakuramedia` container. The qBittorrent container's download directory must also live at `/mnt/downloads` under that same mount point; this assumes your qBittorrent is deployed with Docker as well and its download directory setting is `/downloads`, so make sure **the download directory inside qBittorrent maps to `/mnt/downloads` on the host**.

### 2. Add a download client

Go to "System Settings → Download Clients → Add" and select the target media library:

| Field | Value |
|---|---|
| qBittorrent address | qB on the host: `http://<host-ip>:8080` (use your qB WebUI port); qB and SakuraMedia in the same compose: `http://qbittorrent:8080` |
| Username / password | The qBittorrent WebUI credentials |
| qBittorrent save root | `/downloads` — adjust this to your actual setup |
| Backend download root | `/mnt/downloads` — the same download directory as seen by `sakuramedia`; it must be the same directory on the host |

Click "Test Configuration" before saving to confirm that the directory mapping and hard links pass. A directory mapping failure usually means the two root directories do not point at the same physical directory.

<Screenshot src="/images/guide-en/download-client-form.png" alt="Add download client form" caption="Interface illustration: when adding a download client, select the target media library and fill in the configuration fields provided by the plugin." />

### 3. Configure an indexer and bind a download client

Go to "System Settings → Indexers → Add". The "Feed URL" must be the full Torznab URL, not the home page of a site or aggregator:

| Source | Feed URL | API Key |
|---|---|---|
| Jackett | The site's "Copy Torznab Feed" link | Copy it from the top-right corner of the dashboard |
| Prowlarr | The RSS icon URL in the indexer list, shaped like `http://<host>:9696/<indexer-ID>/api?apikey=...` | The URL already contains `apikey`, so you can leave this empty |

After saving, bind one or more download clients (the first one becomes the default download target), then click "Test Torznab Connectivity".

### 4. Verify

1. On the "Overview" page, run "Component Diagnostics" to confirm connectivity to the media library, metadata sources, and indexers. Each metadata source shows "Passed / No data / Failed"; check the download client separately with "Test Configuration" on the download clients page.
2. Subscribe to a movie and wait for the background task to look for resources.
3. To actively verify the automatic flow, manually trigger "Auto-download missing subscribed movies" in the Task Center and check the run result. When no suitable resource exists, a completed run does not mean a successful download.

See [Get your first movie](/manual/first-movie) for the full flow. Importing existing movies does not need this step; see [Import existing assets](/manual/import).

## Optional: vector services and SigLIP2 hardware options

Image search and similar movies rely on Qdrant and the SigLIP2 embedding service. The CPU image in the examples on this page works on AMD, Intel and ARM64 hosts. The SigLIP2 image already bundles the model and runtime — you do **not** need to download models, mount a model directory, or pre-scale images. On startup the service automatically picks an inference backend based on the runtimes installed in the image; no configuration is required.

When the backend and the embedding service are in the same Compose project, no port mapping is needed; the backend reaches the service at `http://siglip2-embed:8080` by default.

### Enabling on demand

A basic deployment does not need either service. If you only want similar movies, start Qdrant and turn on "Similar Movies & Vector Service" in desktop advanced settings; if you want image search, deploy SigLIP2 as well and turn on "Image & Text Search". See the [Full Compose example](#full-compose-example) below. Restart the backend container after saving.

Thumbnails and moment favorites are kept independently. Daily recommendations and moment recommendations still use other candidate signals after vector capabilities are turned off. Re-enabling keeps the existing index; if deletions or updates happened while it was off, rebuild the image search index in "System Settings → System Maintenance" and run "Movie Similarity Recalculation" in the Task Center.

### Full Compose example

Append these two services to the basic compose file above. A basic deployment does not need them; they are only required when you enable similar movies or image search. Enabling image search on ARM platforms is not recommended.

```yaml
  qdrant:
    image: qdrant/qdrant:v1.12.4
    container_name: qdrant
    restart: unless-stopped
    environment:
      QDRANT__SERVICE__HTTP_PORT: "6333"
      QDRANT__LOG_LEVEL: "INFO"
    volumes:
      - ./sakuramedia-data/image-search-index:/qdrant/storage
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  siglip2-embed:
    image: tinyping/siglip2-embed-service:cpu
    container_name: siglip2-embed
    restart: unless-stopped
    environment:
      CPU_CONCURRENCY: "1"
      MALLOC_TRIM_THRESHOLD_: "131072"
      # If memory is tight, try setting this to false to lower the memory used by text search.
      TEXT_TOWER_ENABLED: "true"
```

### Intel integrated graphics

For Linux amd64 hosts with Intel integrated graphics. Replace the `siglip2-embed` service above with:

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:intel
    container_name: siglip2-embed
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri
    group_add:
      # Replace with the actual GID of the host's render group (getent group render)
      - "0"
    environment:
      CPU_CONCURRENCY: "1"
```

Run `getent group render` on the host to look up the GID of the `render` group, then replace the number in `group_add` above with that GID (for example `- "105"`). Confirm that `/dev/dri` exists before starting the container.

### NVIDIA CUDA

The host needs the NVIDIA driver and `nvidia-container-toolkit` installed, and `nvidia-smi` must display the GPU correctly. Replace the service above with:

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:cuda
    container_name: siglip2-embed
    restart: unless-stopped
    gpus: all
    environment:
      CPU_CONCURRENCY: "1"
```

If the container does not use the GPU after starting, first check whether `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi` succeeds, then check the NVIDIA Container Toolkit configuration.

### Image search only: disable the text tower

By default SigLIP2 loads both the image tower and the text tower. If you only search for similar images and do not need text-to-frame search, add this to the `environment` of `siglip2-embed`:

```yaml
      TEXT_TOWER_ENABLED: "false"
```

On startup the service skips the text encoder and tokenizer and keeps only the image tower, which lowers memory usage. Text-to-frame search then fails (the text endpoint returns 503), while image search, similar images and image indexing are unaffected. Set it back to `"true"` or delete the line and restart the container to restore it.

### Deploying the embedding service on another host

Port mapping is only needed when the backend and SigLIP2 are not on the same Compose network, for example by adding:

```yaml
    ports:
      - "8080:8080"
```

Then, in desktop advanced settings, change the SigLIP2 address to a reachable HTTP address for that service, fill in the API key if needed, and restart the backend after saving. Qdrant likewise supports a remote address; when you use a remote service, you do not need to start the corresponding local container.

## Next steps

- Import more movies: [Import existing assets](/manual/import)
- Full subscription flow after automatic download: [Get your first movie](/manual/first-movie)
- Image search usage: [Discover more from a single frame](/manual/image-search)
- The 115 cloud drive and other plugins: [Recommended Plugins](/guide/plugins)
- Fields and task schedules: [Configuration Reference](/guide/config), [Background Tasks](/guide/tasks)
