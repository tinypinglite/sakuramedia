<p align="center">
  <img src="./wiki/public/brand/sakuramedia-logo.png" alt="SakuraMedia logo" width="88" />
</p>
<h1 align="center">SakuraMedia</h1>

<p align="center">
  <strong>Turn the movies on your disks and cloud drives into a searchable, subscribable library you can pick up where you left off.</strong>
</p>
<p align="center">
  Built for people running their own media library: the backend can run on a NAS, mini PC, server, or VPS, and movies can live on local disks or in a 115 cloud drive.
</p>

> [!WARNING]
> **SakuraMedia is currently unavailable due to changes to the upstream JavDB API.**


> **由于上游 JavDB 接口发生变动，SakuraMedia 目前无法正常使用。**

<p align="center">
  <a href="https://github.com/tinypinglite/sakuramedia/releases/latest"><strong>Download the client</strong></a>
  ·
  <a href="https://tinypinglite.github.io/sakuramedia/guide/quick-start"><strong>Deploy the backend</strong></a>
  ·
  <a href="https://tinypinglite.github.io/sakuramedia/"><strong>Browse the Wiki</strong></a>
  ·
  <a href="https://tinypinglite.github.io/sakuramedia/videos/sakuramedia-demo-en.mp4"><strong>Watch the demo</strong></a>
</p>

<p align="center">
  <a href="https://github.com/tinypinglite/sakuramedia/releases/latest"><img src="https://img.shields.io/github/v/release/tinypinglite/sakuramedia?style=flat-square" alt="Latest release" /></a>
  <a href="https://github.com/tinypinglite/sakuramedia/stargazers"><img src="https://img.shields.io/github/stars/tinypinglite/sakuramedia?style=flat-square" alt="GitHub stars" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue?style=flat-square" alt="License" /></a>
</p>

<p align="center">
  <sub><strong>English</strong> · <a href="./README.zh-CN.md">简体中文</a></sub>
</p>

<p align="center">
  <sub>Needs an always-on host plus Docker; the client can't be used on its own.</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/home-hero.jpg" alt="SakuraMedia interface preview" width="1100" />
</p>

<p align="center">
  After collecting for years, I started asking myself: what do I actually want to keep from this movie?<br />
  <a href="https://tinypinglite.github.io/sakuramedia/guide/collection-strategy"><strong>Why I built SakuraMedia →</strong></a>
</p>

## Core features

From finding and downloading movies to watching and organizing them, the current release covers the following.

### Finding and acquiring

- 🔍 **Discovery and subscriptions**: Search by movie number or look up an actor by name; browse tags, rankings, and recommendations; subscribe to an actor to keep up with new releases (her whole catalog isn't downloaded automatically).
- 📥 **Automatic download and import**: Once a movie is subscribed, SakuraMedia keeps looking for sources and downloads it through qBittorrent or 115 offline download; finished downloads are imported into the media library automatically, and movies with no source stay on the subscription list.
- 📦 **Import and metadata**: Import from a local disk or select cloud drives; the movie number is detected and the title, cast, cover, and other metadata are scraped and filled in; if detection fails you can match manually.

### Watching and keeping

- 🎬 **Playback and moments**: The thumbnail timeline takes you straight to a frame; mark moments; cut a stretch of video into a standalone clip; variable speed, subtitles, resume, and external players.
- 🥽 **VR playback**: Play VR movies in an external player; multi-part sources can be merged into continuous playback; experimental support for using devices such as Pico in 2D.
- 🖼️ **Image search**: Use a thumbnail, a scene still, or a text description to find similar frames in other movies; results with a playable source jump straight to the matching timestamp (optional, needs a separately deployed embedding service; it only searches images already indexed in your media library).
- ❤️ **Favorites and organization**: Playlists, moment collections, and clip collections; use collections to group what you want to rewatch.

> Moments depend on the source media; clips are standalone video files.

### Regular videos (PornBox)

- 📼 **Importing regular videos**: In "Media import → Videos", choose a directory or video files from storage; they can join a collection right away during import. No movie number is needed, and none of the JAV subscription or download flow applies.
- 🗂️ **Collections**: See the members in a collection's detail view, reorder them by hand, add or remove members; "Play all" starts in the current order.
- 🔗 **Collection playback**: The thumbnail panel on the right stitches the keyframes of every entry into a single strip; scroll or click to jump to that movie and frame, and playback moves on to the next one automatically.
- 📌 **Marking moments during playback**: Right-click a thumbnail → "Add marker". Moments stay bound to a specific movie and media, so continuous playback never loses them. The same menu also saves to local storage, and once image search is enabled you can look for similar images there too.

> PornBox and JAV have separate movie number, subscription, and download flows; collections only organize regular movies that are already in your media library.

### Management and extensibility

- 🗂️ **Media library management**: Spot duplicate files, multiple versions, and dead media; fingerprint sampling reads only a few fragments to detect duplicates across libraries and storage. Migrate local movies to a cloud drive through 115 rapid upload while keeping media records and playback progress; files that don't match are skipped and the originals kept.
- 🔔 **Tasks and notifications**: The task center shows downloads, imports, and background jobs; notifications keep you posted, and notification channels are extensible.
- 🧩 **Plugin extensions**: Storage, download, rankings, subtitles, and actor metadata completion are all delivered through plugins.
- 💻 **Multiple clients**: Windows / macOS / Android / iOS. Desktop handles configuration and central management; mobile is for browsing and watching. The available entry points vary by platform.

## Screenshots

> Screenshots use demo data; covers and thumbnails are blurred. See the video below for the full demo.

<p align="center">
  <img src="./wiki/public/images/readme-en/carousel.gif" alt="Interface carousel" width="900" />
</p>
<p align="center">
  <sub>Overview / Discover / Details / Player / Clips / PornBox</sub>
</p>

<p align="center">
  <a href="https://tinypinglite.github.io/sakuramedia/videos/sakuramedia-demo-en.mp4"><strong>▶ Watch the full 45-second demo</strong></a>
</p>

<details>
<summary><strong>More screenshots</strong></summary>

<p align="center">
  <img src="./wiki/public/images/readme-en/desktop-overview.png" alt="Overview" width="1100" />
</p>
<p align="center">
  <sub>Overview: media assets, viewing trends, storage distribution</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/desktop-discover.png" alt="Discover page" width="49%" />
  <img src="./wiki/public/images/readme-en/desktop-detail.png" alt="Movie details" width="49%" />
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/desktop-player.png" alt="Player with thumbnail timeline" width="1100" />
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/thumbnail-menu.png" alt="Searching similar frames from a thumbnail" width="1100" />
</p>
<p align="center">
  <sub>Right-click a thumbnail → Similar images</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/thumbnail-timeline.gif" alt="Thumbnail timeline demo" width="400" />
  <img src="./wiki/public/images/readme-en/clip-selection.png" alt="Selecting a clip" width="400" />
</p>
<p align="center">
  <sub>Thumbnail timeline / Clip selection</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/clips-page.png" alt="Clips page" width="1100" />
</p>
<p align="center">
  <sub>Clips page: browse, play, add to collections</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/pornbox-collection.png" alt="PornBox collection details" width="1100" />
</p>
<p align="center">
  <sub>PornBox collections: members, manual order, play all</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/pornbox-timeline.png" alt="Collection playback thumbnails and adding a marker" width="420" />
</p>
<p align="center">
  <sub>Collection playback: the thumbnail panel is assembled per collection; right-click → Add marker</sub>
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/desktop-image-search.png" alt="Image search" width="1100" />
</p>

<p align="center">
  <img src="./wiki/public/images/readme-en/mobile-home.png" alt="Mobile" width="260" />
</p>

</details>

## How to store, how to download

A NAS is optional: the backend runs on any machine that can keep Docker running long term, and where movies live is decided by the storage plugin.

| Combination | Storage | Download | Best for |
| --- | --- | --- | --- |
| 💾 Local + qBittorrent (bundled in the backend image) | Local disk | qBittorrent | You have local space and want to keep movies in your own hands |
| ☁️ 115 cloud drive + offline download | 115 cloud drive | 115 offline download | You'd rather not use local space; good for a mini PC, server, or VPS |
| ☁️ Guangyapan cloud drive + cloud add | Guangyapan cloud drive | Guangyapan cloud add | You'd rather not use local space; good for a mini PC, server, or VPS |

> Storage and download both come in through plugins. The backend image ships with "Local Storage & qBittorrent"; the 115 and Guangyapan cloud drives are optional plugins you install yourself under "System settings → Plugins".

## Download and install

Get the client from [GitHub Releases](https://github.com/tinypinglite/sakuramedia/releases/latest). The Windows installer is currently unsigned; the macOS installer is signed with a fixed self-signed certificate and is not notarized by Apple, so the system may warn about an unidentified developer. Once you've confirmed where the download came from, follow the system prompt to allow it.

| Platform | Installer | Notes |
| --- | --- | --- |
| Windows | `sakuramedia-windows-*-setup-unsigned.exe` | Unsigned; when SmartScreen appears, choose "More info → Run anyway" |
| macOS | `sakuramedia-macos-<tag>.dmg` | Fixed self-signed certificate; not notarized. If macOS warns, allow it under "Privacy & Security" |
| Android | `sakuramedia-android-*-release-signed.apk` | Install directly; the system may warn about unknown sources |
| iOS | `sakuramedia-ios-*-sidestore-ready.ipa` | Requires iOS 15.0+ and installs through SideStore or a self-signing tool; if you haven't sideloaded before, start with the desktop client |

> If SakuraMedia has been useful to you, [a star](https://github.com/tinypinglite/sakuramedia/stargazers) helps more people find it.

## Who it's for

**A good fit**: you have a NAS, mini PC, server, or VPS that can run around the clock, and you want movie discovery, downloading, importing, and watching in one place.

**Not a good fit**: you have no always-on machine, you expect to install an app and start watching, or you don't want to configure a backend or any plugins. SakuraMedia doesn't provide movies and bundles no source sites.

## Community and support

- Found a bug or have a feature request: [open an issue](https://github.com/tinypinglite/sakuramedia/issues). Please include the client, backend, and plugin versions, the steps to reproduce, and the relevant logs; don't upload screenshots, covers, or personal information that shouldn't be public.
- Chat with other users or ask for help: [join Discussions](https://github.com/tinypinglite/sakuramedia/discussions).
- If you hit connection or import problems, check connectivity for your media library, indexer, JavDB, and the embedding service under "Overview → Component diagnostics" first.
- You can also hand the Markdown files in `wiki/` to an AI together with your problem and the steps you've already tried; that usually narrows things down faster.
- The project is evolving quickly; check the release notes before upgrading, and upgrade the client, backend, and plugins together whenever possible.

## Contributing

- [Star the project](https://github.com/tinypinglite/sakuramedia/stargazers) so more people find it.
- Help improve the [Wiki](https://tinypinglite.github.io/sakuramedia/) and the docs.
- Build plugins: see the [plugin development guide](https://tinypinglite.github.io/sakuramedia/guide/plugin-development); to list one in the plugin market, send a PR to [sakuramedia-plugin-market](https://github.com/tinypinglite/sakuramedia-plugin-market).
- Send PRs for bug fixes or new features. The client is built with Flutter, currently on 3.47.2; after `flutter pub get`, run the tests with `./scripts/test.sh -j 4`.

The project doesn't need donations; stars, docs, plugins, and PRs are all help.

## Risks and disclaimer

- This project is for technical exchange only and provides no movies or download links.
- Everything that results from using this tool is the user's own responsibility, not the author's.
- Please learn about and follow your local laws and regulations before use; if your use would break them, don't use it.
- Commercial use of this software is prohibited.
- If you don't agree with any of the above, don't use it.
- License: [PolyForm Noncommercial 1.0.0](./LICENSE)

<h2 align="center">Star History</h2>

<p align="center">
  <a href="https://github.com/tinypinglite/sakuramedia/stargazers">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://tinypinglite.github.io/sakuramedia/star-history-dark.svg" />
      <source media="(prefers-color-scheme: light)" srcset="https://tinypinglite.github.io/sakuramedia/star-history-light.svg" />
      <img alt="Star History Chart" src="https://tinypinglite.github.io/sakuramedia/star-history-light.svg" />
    </picture>
  </a>
</p>

