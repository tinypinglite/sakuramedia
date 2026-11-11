---
outline: [2, 3]
---

# Recommended Plugins

SakuraMedia's media storage, download and some automation capabilities are provided by plugins. You can browse, install and update plugins directly in "System Settings → Plugins → Plugin Market" (on mobile, enter from the bottom of the "Plugins" page), or upload a zip package manually. See the [plugin development guide](/guide/plugin-development#version-compatibility) for the compatibility rules between plugins and the host.

::: info About plugin sources
This release requires every plugin to declare Host API 18; older plugins cannot load. The bundled plugin list is empty for now, so a first deployment must install compatible plugins.

Only plugins whose source repository is public and that provide a Release package are listed here. Licensing terms follow each repository's own statement.
:::

## Installing from the plugin market

1. Open "System Settings → Plugins" and switch to the "Plugin Market" tab.
2. Find the plugin you need and click "Install"; when an installed plugin has a newer version, the button changes to "Update".
3. After installing, restart the SakuraMedia container so that the API and APS reload the plugins and their dependencies.

The market index comes from the officially maintained [sakuramedia-plugin-market](https://github.com/tinypinglite/sakuramedia-plugin-market) repository, which lists both official and community plugins. Community plugins carry a "Community" badge; make sure the source is trustworthy before installing.

## Installing a zip manually

If you do not use the plugin market, you can also download the package manually:

1. Download the zip package from the plugin's "Download latest" page.
2. Go to "System Settings → Plugins", click "Install Plugin" on the "Installed" tab, upload the zip and confirm that the plugin is enabled.
3. After installing all the plugins you need, restart the SakuraMedia container so that the API and APS reload the plugins and their dependencies.
4. After installing a provider plugin, first create a media library in "System Settings → Media Library"; when you need downloads, create a download client bound to that media library.
5. Background tasks from ranking, collection detection, subtitle and actor metadata plugins can be viewed or triggered manually in the Task Center.

::: warning Security notice
Plugins run inside the SakuraMedia backend process. Only install plugins from trustworthy sources; community plugins are not audited officially, so read their source before installing.
:::

Plugins listed on this page take effect only after the container is restarted once installed or updated; the plugins preinstalled in the official image are already enabled on first start. See the [Configuration Reference](/guide/config#plugins) for plugin directories and settings, and [Common Commands](/guide/commands#plugin-management) for command-line management.

## Plugin directory

| Plugin | Plugin ID | Purpose | Links |
|---|---|---|---|
| 115 Cloud Drive Provider | `sakuramedia_115_provider` | Connects to the 115 cloud drive and provides directory browsing, movie import, 115 offline downloads, 302/backend-proxied playback, thumbnails and clips. | [Source](https://github.com/tinypinglite/sakuramedia_115_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_115_provider/releases/latest) |
| Guangyapan Cloud Drive Provider | `sakuramedia_guangyapan_provider` | Connects to the Guangyapan cloud drive and provides directory browsing, movie import, 302 direct-link or backend-proxied playback, thumbnails, clips, and adding magnet/torrent downloads to the cloud. | [Source](https://github.com/tinypinglite/sakuramedia_guangyapan_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_guangyapan_provider/releases/latest) |
| Local Storage & qBittorrent | `sakuramedia_local_provider` | Connects to local media directories and provides manual import, qBittorrent downloads, backend-proxied playback, thumbnails and clips. | [Source](https://github.com/tinypinglite/sakuramedia_local_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_local_provider/releases/latest) |
| Actor Metadata Completion | `sakuramedia_actor_metadata` | Completes local actor profiles from JavDB and MinnanoAV, including birthday, height, measurements, cup size, birthplace, blood type and gender. | [Source](https://github.com/tinypinglite/sakuramedia-actor-metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia-actor-metadata/releases/latest) |
| JavBus Metadata | `sakuramedia_javbus_metadata` | Fills in title, release date, runtime, label, cast, tags, cover, stills and other metadata from JavBus by movie number. | [Source](https://github.com/tinypinglite/sakuramedia_javbus_metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia_javbus_metadata/releases/latest) |
| Movie Text Scraping & Translation | `sakuramedia_movie_scrape_translate` | Scrapes the Japanese title and synopsis of a movie from DMM, and can optionally translate them into Chinese and write them back to the movie title and synopsis. | [Source](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate) · [Download latest](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate/releases/latest) |
| JavDB Rankings | `sakuramedia_javdb_ranking` | Provides the JavDB trending, top-rated, censored, uncensored, FC2 and TOP250 boards, and registers scheduled sync tasks. | [Source](https://github.com/tinypinglite/sakuramedia_javdb_ranking) · [Download latest](https://github.com/tinypinglite/sakuramedia_javdb_ranking/releases/latest) |
| More Movie Rankings | `sakuramedia_more_rank_movies` | Connects to Minnano AV and JavLibrary, providing the Minnano AV daily/weekly/monthly boards and the JavLibrary top-rated and most-wanted boards (last month/all time), and registers scheduled sync tasks. | [Source](https://github.com/tinypinglite/sakuramedia_more_rank_movies) · [Download latest](https://github.com/tinypinglite/sakuramedia_more_rank_movies/releases/latest) |
| Detect collection movies by duration, number pattern or tag | `sakuramedia_judge_collecttion_movie` | Automatically flags collection movies based on movie runtime and movie number prefix, without overriding manual flags made in the app. | [Source](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie) · [Download latest](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie/releases/latest) |
| SubtitleCat Chinese Subtitles | `sakuramedia_subtitlecat` | Fetches `zh-CN` subtitles for existing movies, supporting manual fetching for a single movie and scheduled processing of subscribed movies. | [Source](https://github.com/tinypinglite/sakuramedia_subtitlecat) · [Download latest](https://github.com/tinypinglite/sakuramedia_subtitlecat/releases/latest) |

## How to choose

- This release no longer bundles plugins. Install a local storage provider that declares Host API 18 before creating a media library. Configure qBittorrent for automatic downloads, and install "115 Cloud Drive Provider" for 115 offline downloads.
- Ranking, collection detection, subtitle, actor metadata, JavBus metadata and movie text scraping & translation plugins can be installed independently as needed; they do not determine how media is stored.
- Movie text scraping & translation requires the container to reach DMM (usually a Japanese IP or a proxy is needed); when translation is enabled, you also need an LLM API compatible with `chat_completions`.
- For lookups by movie number, the host calls enabled metadata plugins in the order configured under Settings → Metadata Sources and uses the first valid result.
- SubtitleCat currently only fetches Chinese subtitles, and the movie must already exist in SakuraMedia.

## Companion services are not plugins

The SigLIP2 embedding service and the SakuraMedia Torznab Server are companion services deployed separately. They cannot be installed from "System Settings → Plugins", so they are not listed on this page.
