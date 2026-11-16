# Subscriptions and download progress

"Subscriptions" answers one question in one place: how far along is the movie I want right now? It is the management entry point on the desktop client.

## Read subscription status

Open "Subscriptions" and use the status filter at the top to locate the problem; to find a particular movie, switch to "All" and search by movie number or title.

| <span style="white-space: nowrap">Subscription status</span> | What it means | What to do next |
| --- | --- | --- |
| Pending lookup | No resource lookup has run since subscribing | Wait for the next automatic lookup, or trigger one manually in the task center |
| Missing resource | A lookup ran but found no usable resource | Wait for later lookups, or check resources manually |
| Lookup error | The lookup hit an error | Read the error and check settings such as the indexer; the next round retries |
| Abandoned | This round of lookups for an older movie has run out of attempts | If you still want it, reset the lookup to start a new round |
| Downloading | There is an active related download, or the download finished and import is still pending or running | Check the download record and import progress |
| Import failed | There is a download job, but this import run produced no media | Check the task details; the import may have errored, or every file may have been skipped |
| Imported | A linked media record exists | Choose a media item in the movie details to play; if the actual file is broken, handle it in media management instead |

"Abandoned" describes this round of resource lookups; the movie stays subscribed. "Lookup error" and "Import failed" happen at different stages, and are handled in different places.

## How the system finds resources automatically

Automated tasks pick subscribed movies that have no media and no active related download jobs, and check whether the lookup state still allows another attempt.

Current automatic candidates need an available source, a size between 1 GiB and 40 GiB, and more than 0 seeders. Eligible candidates are tried from largest to smallest and submitted to the download client bound to the indexer. A resource appearing in search results does not mean it meets the automatic selection conditions.

The default rules described by the current interface are: new movies released within 90 days are looked up continuously; older movies accumulate at most 3 lookups that find no usable resource, then are marked "Abandoned". Lookup errors do not consume that count. The actual boundaries and limits follow the server [configuration](/guide/config#downloads).

After resetting a lookup in Subscriptions, the movie is queued again; resetting does not clear torrent records already judged as failed, and does not guarantee an immediate download.

## When you want to pick resources yourself

Open "Torrent search" in the movie details, review the candidates' names, sizes, sources and download clients, then choose which resource to submit. Manual picking suits cases where you already know which version you want.

After submitting, still follow the download and import in the task center. Do not submit the same resource over and over just because media has not appeared yet.

## Why a finished download still cannot play

The system first has to sync the download client's state, then hand the completed file to the media library for import. These are two different steps.

Check in order:

1. Whether the download job is finished and its latest state has been synced.
2. Whether the automatic import has started.
3. Whether the import result is succeeded, skipped or failed.
4. Whether the movie details now show media.

When "Import failed" appears, resetting the resource lookup usually does not help. Read the import error first; all files being skipped for reasons such as size can also cause a finished download with no media.

## When you no longer want the movie

A movie without media can be unsubscribed. When media exists, the system blocks ordinary cancellation and may offer a flow that deletes the media and then force-unsubscribes. Read [Media library management](./media-management) before acting, so that cancelling a subscription is not used as a way to merely hide an entry.

The task center is for specific progress and errors; notifications are for reminders. You do not need to search every page at once — use the status above to find the current stage first.
