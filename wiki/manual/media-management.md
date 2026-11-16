# Media library management

"Media management" brings files, duplicates, multiple versions and broken media together. Before cleaning up, decide whether you want to delete a particular file version, or to stop wanting the movie at all.

## How the operations differ

| Operation | Effect |
| --- | --- |
| Delete media | Deletes the selected media record and its storage file, along with that media's moments, playback progress and thumbnails; it does not cancel the movie subscription |
| Unsubscribe from movie | Removes the intent to have the movie; blocked by default when media exists |
| Delete media and force unsubscribe | Deletes the related media files and records first, then unsubscribes; a failure may leave part of the deletion done |
| Block movie | Adds the movie to the blocklist; a subscribed movie must be unsubscribed before it can be blocked |
| Delete download job | Handles the download job; whether the task and files on the download client are deleted too depends on the choice you make when confirming |

::: warning Cleaning up can trigger a new resource search
If you delete only the media and keep the movie subscribed, the movie can be downloaded again automatically once it has no other media, no download job blocking lookups, and still meets the lookup conditions. If you no longer want the movie, deal with the subscription as well.
:::

Download jobs and media library records are managed separately. Deleting a download job does not clean up imported records for you; if the download directory and the media library effectively share files, deleting files on the download client can still break playback, so verify the storage relationship when acting.

## Clean up duplicate files and multiple versions

1. Open the matching duplicate media or multiple-version view in media management.
2. Compare file names, sizes, media libraries and version information.
3. Select the items to delete, read the confirmation dialog and proceed.
4. Go back to the movie details and confirm the kept version still plays.

Duplicate media are grouped by file content fingerprint, while multiple versions are organized by movie. Two versions of the same movie do not necessarily have identical content. The dedicated grouping views require at least one item to be kept per group or per movie.

## Handle broken media

Broken media are records whose actual source was found unavailable during inspection. First check whether a cloud drive, mount or storage service is just temporarily offline, then judge whether the file is really gone.

Once you have confirmed the source is lost, you can delete the corresponding record. If the movie stays subscribed, whether it can be fetched again depends on resources, download jobs and lookup state; deleting does not guarantee an immediate re-download.

## Migrate media to other storage

Select media within the same source media library, click "Migrate", choose one of the target libraries offered in the interface and submit. Then check the result in the task center.

Migration reuses the original media record and keeps associations such as playback progress. The available targets depend on the capabilities of the source and target storage plugins; storage ownership is switched and source files are handled only after the target is verified.

See [Media storage migration](/guide/media-storage-transfer) for supported combinations and for handling of skips and interruptions.

## Before cleaning up collections

Moments currently depend on the media record, so deleting media also deletes those moments and their collection memberships. Standalone clips that were already generated are kept. Before cleaning up an original, verify that the clips you intend to keep can play, and back up the collection records and necessary files. To review organizing options, go back to [Collections and organizing](./collections).
