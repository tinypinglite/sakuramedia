---
outline: [2, 3]
---

# Recommended Plugins

SakuraMedia's media storage, download and some automation capabilities are provided by plugins. You can browse, install and update plugins directly in "System Settings → Plugins → Plugin Market" (on mobile, enter from the bottom of the "Plugins" page), or upload a zip package manually. See the [plugin development guide](/guide/plugin-development#version-compatibility) for the compatibility rules between plugins and the host.

::: info About plugin sources
This release requires every plugin to declare Host API 18; older plugins cannot load. The official image bundles 11 official plugins that are installed and enabled on first start. Upgrading the image also upgrades bundled plugins while preserving their settings, `data/`, and enabled state.

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

Plugins listed on this page take effect only after the container is restarted once installed or updated; plugins bundled in the official image are installed and enabled automatically on first start. See the [Configuration Reference](/guide/config#plugins) for plugin directories and settings, and [Common Commands](/guide/commands#plugin-management) for command-line management.

## Plugin directory

| Plugin | Plugin ID | Bundled | Purpose | Links |
|---|---|---|---|---|
| Local Storage & qBittorrent | `sakuramedia_local_provider` | Yes | Connects to local media directories and provides manual import, qBittorrent downloads, backend-proxied playback, thumbnails and clips. | [Source](https://github.com/tinypinglite/sakuramedia_local_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_local_provider/releases/latest) |
| 115 Cloud Drive Provider | `sakuramedia_115_provider` | Yes | Connects to the 115 cloud drive and provides directory browsing, movie import, 115 offline downloads, 302/backend-proxied playback, thumbnails and clips. | [Source](https://github.com/tinypinglite/sakuramedia_115_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_115_provider/releases/latest) |
| Guangyapan Cloud Drive Provider | `sakuramedia_guangyapan_provider` | Yes | Connects to the Guangyapan cloud drive and provides directory browsing, movie import, 302 direct-link or backend-proxied playback, thumbnails, clips, and adding magnet/torrent downloads to the cloud. | [Source](https://github.com/tinypinglite/sakuramedia_guangyapan_provider) · [Download latest](https://github.com/tinypinglite/sakuramedia_guangyapan_provider/releases/latest) |
| DMM / FANZA Metadata | `sakuramedia_dmm_metadata` | Yes | Provides Japanese titles, synopses, release dates, runtimes, labels, series, cast, directors, tags, covers, and sample images from DMM / FANZA by movie number. | [Source](https://github.com/tinypinglite/sakuramedia_dmm_metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia_dmm_metadata/releases/latest) |
| FC2 Metadata | `sakuramedia_fc2_metadata` | Yes | Provides titles, synopses, tags, covers, and sample images from FC2 official product pages by product number; the official pages have no cast field. | [Source](https://github.com/tinypinglite/sakuramedia_fc2_metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia_fc2_metadata/releases/latest) |
| FC2CMADB Metadata | `sakuramedia_fc2cmadb_metadata` | Yes | Provides titles, tags, and covers from the FC2CMADB mirror by product number; it has no synopsis or plot images, and actor data is best-effort. | [Source](https://github.com/tinypinglite/sakuramedia_fc2cmadb_metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia_fc2cmadb_metadata/releases/latest) |
| JavBus Metadata | `sakuramedia_javbus_metadata` | Yes | Provides titles, release dates, runtimes, labels, directors, series, cast, tags, covers, and stills from JavBus by movie number; it has no synopsis. It also supports syncing subscribed-actor movie lists. | [Source](https://github.com/tinypinglite/sakuramedia_javbus_metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia_javbus_metadata/releases/latest) |
| Actor Metadata Completion | `sakuramedia_actor_metadata` | No | Completes local actor birthday, height, measurements, cup size, and birthplace from JavBus. It does not fill blood type or gender, only writes empty fields, and never overwrites manually maintained values. Install it from the plugin market when needed. | [Source](https://github.com/tinypinglite/sakuramedia-actor-metadata) · [Download latest](https://github.com/tinypinglite/sakuramedia-actor-metadata/releases/latest) |
| JavDB Rankings | `sakuramedia_javdb_ranking` | Yes | Provides JavDB trending, top-rated, censored, uncensored and FC2 charts plus bundled TOP250 lists, and registers scheduled sync tasks. | [Source](https://github.com/tinypinglite/sakuramedia_javdb_ranking) · [Download latest](https://github.com/tinypinglite/sakuramedia_javdb_ranking/releases/latest) |
| More Movie Rankings | `sakuramedia_more_rank_movies` | Yes | Connects to Minnano AV and JavLibrary, providing the Minnano AV daily/weekly/monthly boards and the JavLibrary top-rated and most-wanted boards (last month/all time), and registers scheduled sync tasks. | [Source](https://github.com/tinypinglite/sakuramedia_more_rank_movies) · [Download latest](https://github.com/tinypinglite/sakuramedia_more_rank_movies/releases/latest) |
| JavDB Reviews | `sakuramedia_javdb_comment` | No | Provides JavDB movie reviews by movie number with pagination and latest/hottest sorting; requires a JavDB account. Install it from the plugin market when needed. | [Source](https://github.com/tinypinglite/sakuramedia_javdb_comment) · [Download latest](https://github.com/tinypinglite/sakuramedia_javdb_comment/releases/latest) |
| Detect collection movies by duration, number pattern or tag | `sakuramedia_judge_collecttion_movie` | Yes | Automatically flags collection movies based on movie runtime, movie number patterns, and tags, without overriding manual flags made in the app. | [Source](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie) · [Download latest](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie/releases/latest) |
| SubtitleCat Chinese Subtitles | `sakuramedia_subtitlecat` | Yes | Fetches `zh-CN` subtitles for existing movies, supporting manual fetching for a single movie and scheduled processing of subscribed movies. | [Source](https://github.com/tinypinglite/sakuramedia_subtitlecat) · [Download latest](https://github.com/tinypinglite/sakuramedia_subtitlecat/releases/latest) |
| Movie Text Scraping & Translation | `sakuramedia_movie_scrape_translate` | No | Scrapes the Japanese title and synopsis of a movie from DMM, and can optionally translate them into Chinese and write them back to the movie title and synopsis. Install it from the plugin market when needed. | [Source](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate) · [Download latest](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate/releases/latest) |

## Testing plugins

- In "System Settings → Plugins", click the test-tube icon in the plugin row on desktop, or choose "Capability test" from the plugin action menu on mobile.
- The capability test uses the test movie number declared by the plugin and only reads the currently loaded configuration; it does not import movies, write stats, or store reviews.
- After changing plugin settings, save and restart the backend before testing; otherwise the test still uses the previous configuration.
- "Overview → Component Diagnostics" runs the same test for every enabled metadata source and shows the title, actor count, tag count and image count. "No data" means the plugin responded but did not find the test movie number.

## How to choose

- The official image already bundles local storage with qBittorrent, 115, Guangyapan, four metadata sources, JavDB rankings, more movie rankings, collection detection, and subtitles. No manual upload is needed on a first deployment. Create a media library to import files, and configure qBittorrent for automatic downloads.
- The four bundled metadata sources are enabled by default. Adjust their order under "Settings → Metadata Sources"; restart the backend after saving. Different sources cover different movie numbers, and the order only affects which source wins when several match.
- JavDB Rankings is bundled and JavDB Reviews is not; both require container access to JavDB, and reviews also require a JavDB account. After installing the review plugin, restart and bind the review source as instructed. Using a third-party plugin to access JavDB carries a risk of account restriction or ban; a dedicated secondary account is recommended.
- Movie text scraping & translation is not bundled; install it from the plugin market when needed. DMM metadata already provides Japanese titles and synopses, so install this plugin only when you need Chinese translations written back to the movie.
- Actor metadata completion is not bundled; install it from the plugin market when needed.
- Movie text scraping & translation requires the container to reach DMM; configure a container proxy if your current network cannot reach it. When translation is enabled, you also need an LLM API compatible with `chat_completions`.
- See the [FAQ](/faq#metadata-plugin-networking-and-proxy) for the external domains metadata plugins use and how to configure a container proxy.
- SubtitleCat currently only fetches Chinese subtitles, and the movie must already exist in SakuraMedia.

## Companion services are not plugins

The SigLIP2 embedding service and the SakuraMedia Torznab Server are companion services deployed separately. They cannot be installed from "System Settings → Plugins", so they are not listed on this page.
