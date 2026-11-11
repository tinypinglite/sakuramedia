# Import existing files

When movies already live on your NAS or cloud drive, you can import them directly instead of waiting for a download. This page covers JAV movies; for content without a movie number, use [Ordinary video import](/guide/videos).

## Before you start

Create the target media library under "System settings → Media library" and confirm the matching storage plugin is enabled. The browsable sources come from that media library's storage configuration, such as the manual import root directory of local storage.

**Start with a small directory to verify the flow**. JAV import needs to detect the movie number and scrape metadata and covers (it does not rely on local NFO files; all metadata and covers come from built-in data sources), so a clear movie number helps detection; network or metadata source failures can also affect the import.

## Submit an import

1. Go to "Manage → Resource import" and choose "JAV movies".
2. Click "New import" and select the target media library.
3. Find the file or directory to import in the source browser. To pick the directory you are currently browsing, click "Select current directory".
4. Check "Import mode"; for a first run, keep the default "Keep source files".
5. Click "Start import". Once the task-submitted notice appears, check progress in the "Task center", or click "View import task" on the import page.

Three import modes:

| Mode | What actually happens | Source file |
|---|---|---|
| Keep source files | Hard link first; copy when hard linking is not possible | Kept |
| Delete source files after a successful import | Copy to the media library, then delete the source file on success (effectively a move) | Deleted |
| In-place import | Neither copy nor hard link; the media references the source file directly | Untouched |

On the same mount point, "Keep source files" can use hard links; across mount points or file systems it copies instead. In-place media depends on the source file's location and becomes invalid if the file is moved, renamed or changed.

::: warning Handling of source files
Choosing "Delete source files after a successful import" deletes the source files once the media is imported successfully. This cannot be undone; use it only when you are sure you do not need the source files.
:::

## Judge whether it worked

After the task finishes, check the succeeded, skipped and failed counts, then open the movie details to confirm the media appeared. A directory can partly succeed and partly fail; a finished task does not mean every file was imported.

JAV file imports add the linked movies to your subscriptions, so they show up under Subscriptions afterwards. There is no need to create downloads again for files that are already imported.

## Deal with failed or skipped files

| Result or cause | Where to look |
| --- | --- |
| Movie number not detected | Check the file name against the movie number; choose the correct movie in the failed entry that offers "Manual match" |
| Scrape failed (metadata fetch, cover download) | Check enabled [metadata plugins](/guide/config#metadata), network and proxy, then handle the failed entry |
| File import failed | Read the specific error and check source reachability and the media library configuration |
| Skipped because the file is too small | Confirm whether it is a sample; adjust the minimum video size setting if you need to keep it |

The current task details and the failed-entry entry points in media management show the reason; when "Manual match" appears, search for and verify the correct movie record before confirming. Do not match a file to an unrelated movie just to make the task pass.
