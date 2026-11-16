# Get your first movie

This time, pick just one movie and go all the way from search and subscription to playback. Confirm the whole flow works before adding subscriptions gradually.

## 1. Confirm the configuration downloads need

Sign in to the desktop client, open "System settings" and check:

| Configuration | Purpose | Relationship to confirm |
| --- | --- | --- |
| Storage plugin and media library | Store and play the imported file | The plugin the media library uses is enabled and the storage is reachable |
| Download client | Receives download jobs | The correct target media library is selected |
| Indexer | Searches for movie resources | A usable download client is bound |

If nothing is configured yet, follow [Auto download and indexers](/guide/quick-start#optional-auto-download-and-indexers). If configuration exists, run "Component diagnostics" on the "Overview" page and fix connection problems for the affected components first.

Resource lookup, download status sync and importing are handled by different background tasks. A deployed server needs the scheduler started; see [Background tasks](/guide/tasks) for the individual tasks.

## 2. Search for a movie

Open the search entry point, type a movie number or keyword, and the search runs against the local library by default. On first use the local library may be empty, so click "Fetch from external source" in the results area, or turn on "Online search" in the search box.

<Screenshot src="/images/guide-en/online-search-network-toggle.png" alt="The online search switch to the right of the search box" caption="The online switch to the right of the search box; external sources are queried only when it is on." />

Once you get results, open the details and check the movie number, cover and cast to confirm this is the movie you want. Online search fetches records; the video file still has to be downloaded or imported.

<Screenshot src="/images/readme-en/desktop-detail.png" alt="SakuraMedia movie details page" caption="Check the movie number, cover and cast in the details; the media list is further down the page." />

If there are no results, check the keywords you entered and the online switch first, then check connectivity to the metadata source on the "Overview" page.

## 3. Subscribe to the movie

Choose "Subscribe to movie" in the action menu of the movie card or the details page. After subscribing, look it up under "Subscriptions".

A new subscription usually starts in "Pending lookup". Subscriptions may open with a status filter applied; when you cannot find the movie you just subscribed to, switch to "All" or "Pending lookup" and search by movie number.

A subscription does not guarantee an immediate download job. The system waits for the relevant tasks to run and for a resource that meets the conditions.

## 4. Follow up on download and import

Check "Subscriptions" first, then go to the "Task center" as needed:

- **Pending lookup, missing resource**: no usable download has been submitted yet. Wait for the next lookup, or check [Subscriptions and download progress](./subscriptions).
- **Downloading**: look at the corresponding download record to confirm progress. A completed download that is waiting to be imported may still show this status.
- **Import failed**: check the import result in the task center and deal with storage or file detection problems.
- **Imported**: open the movie details and check the media list.

To actively verify the automated flow, trigger "Auto download missing subscribed movies" manually in the task center and check the run result. When no suitable resource exists, the task can finish without a successful download.

## 5. Open a media item and play

Go to the movie details and pick a version from the media list to play. When there are several files, pay attention to the file name, size and media library.

<Screenshot src="/images/readme-en/desktop-player.png" alt="SakuraMedia player with the thumbnail panel" caption="Once playable media exists, choose a version to enter the player; thumbnails on the right help you locate scenes." />

Once playback works, this flow is complete. The subscription stays; from here you can subscribe to more movies or [follow actors you like](./discover).

If you already have this movie's file, there is no need to wait for a download — go straight to [Import existing files](./import).
