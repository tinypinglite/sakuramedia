---
outline: [2, 3]
---

# Media Storage Migration

When a local or NAS media library runs out of space, or you want to move already-imported content to a different kind of storage, you do not have to delete it and import it again. Media storage migration moves the selected media to a supported target media library in bulk while keeping the original media records.

In short: **what changes is where the media actually lives, not the media entry in SakuraMedia.**

So the media ID, movie association, playback progress, thumbnails, moments, clips and other existing associations all stay intact; after migration, lists, detail pages and the Activity Center still point at the same media.

## What is supported today

Migration capabilities are determined jointly by the providers of the source and target media libraries. The interface only lists target libraries that can complete a migration safely, and shows a hint when there is no available target.

The official implementation currently covers **local storage media library → 115 cloud drive media library** first:

- The target side only uses 115's instant upload and does not fall back to a normal upload; when 115 does not hit, that file is skipped and both the source file and the original media record stay unchanged.
- Before migrating, file size and SHA-1 are computed and verified; after 115 returns a target, the target's name, size, hash and directory visibility are confirmed once more.
- Only after the target is confirmed usable does the system switch the original media record to the target media library and clean up the corresponding file link in the local media library.

This is not a backup, sync or two-way mirror feature. Its goal is to complete a one-time "library switch" safely; other providers can join in the future once they implement the same migration capability.

## How to use it

1. First create and confirm that both the source and target media libraries work normally. To migrate from local to 115, you need SakuraMedia, Local Provider and 115 Provider versions that support migration.
2. Open media management and select the media to migrate **within the same source media library**.
3. Click "Migrate", choose one of the available target media libraries and submit.
4. Check progress and results in the Activity Center. The task reports separate counts for "Migrated", "Skipped", "Failed", "Source file unconfirmed" and "Not run"; click "View migration results" on the task card to see per-file outcomes and failure reasons.

Migration runs items serially. Items that succeeded keep their results; if a later item runs into a changed file, a busy library, a network error or a cleanup error, the task stops instead of risking the items that have not been processed yet.

## What is preserved

Migration does not create a new "target media" entry; it updates the storage ownership and storage reference of the original media. So the following stay associated:

- The movie or regular video association, media ID and saved metadata;
- playback progress, thumbnails, moments, clips and clip collections;
- movie-level subtitle records, plus data that depends on this media record such as image search and recommendations.

Embedded subtitles travel with the video bytes into the target; separately managed external subtitle records are not uploaded. Existing clip files are not moved by this migration either.

## Safety boundaries and caveats

- During migration, configuration, scanning and plugin management of the source and target media libraries are mutually exclusive with the migration; do not modify these two media libraries, upgrade providers or uninstall providers at the same time.
- The system only cleans up **that one source file link inside the media library**; it does not recursively delete directories, delete download client tasks or manage seeding relationships.
- If the media library file and the download directory are hard links, removing the media library link may not free disk space; if they are literally the same file path, the cleanup affects the download client. Confirm your directory and seeding strategy before migrating.
- When a task is interrupted or the source file cleanup result cannot be confirmed, the system does not retry automatically, migrate back or guess the file state. The Activity Center honestly marks it as "Source file unconfirmed", and you need to inspect and handle it yourself.
- A local video that is currently playing is not guaranteed to switch seamlessly; if you want to keep watching after migration, reopen that media.

::: tip
Start by migrating a few non-critical items to verify the storage provider, the 115 account and the directory configuration, then migrate the whole batch.
:::
