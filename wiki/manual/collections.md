# Collections and organizing: playlists, moments and clips

After watching a movie, choose how to organize it depending on what you want to keep.

| What you want to keep | What to use | How to come back to it |
| --- | --- | --- |
| A group of movies | Playlist | Open movies from the list |
| A particular frame and position | Moment, moment collection | Jump back into the movie at that position when a usable source exists |
| An actual stretch of video | Clip, clip collection | Play the generated standalone file |

Each of these ways of organizing serves a different purpose than subscriptions. Subscriptions express the intent to obtain and keep movies, while playlists are for sorting; adding a movie to a playlist should not be treated as a substitute for subscribing.

## Organize movies with playlists

1. Create a playlist on the "Playlists" page and give it a name.
2. From a movie's playlist action, choose which lists to add it to.
3. Go back to the playlist details to confirm the members and keep browsing.

Name lists by genre, actor or your own viewing plan. Adding to a list organizes the relationship between movies; it does not copy the video for each list.

## Mark moments

In a movie's thumbnails or frame preview, choose "Add marker" to save a position you are interested in. View saved frames under "Moments" in the sidebar; once a moment is selected, you can group it with "Add to collection".

<Screenshot src="/images/readme-en/thumbnail-menu.png" alt="Thumbnail action menu" caption="Thumbnail action menu: similar images, save locally, add marker, play." />

To revisit, open a moment using an available source media. A moment records a frame and a position; it does not extract a standalone video. When the source is unavailable, a visible preview image does not mean the original still plays.

::: warning Moments depend on the source media
In the current version, deleting media also deletes that media's moments and their collection memberships; moments are not automatically reattached after the media is deleted. To keep these moments, keep the source media; when you need to keep a video separately, generate and verify a clip first.
:::

## Create clips

1. Open a movie media's thumbnail panel and click "Select clip range".
2. Choose the start and end points and check the range and duration in the selection bar.
3. Click create, optionally fill in a clip title and confirm.
4. Wait for generation to succeed, then view and play it on the "Clips" page.

<Screenshot variant="narrow" src="/images/readme-en/clip-selection.png" alt="Selecting a clip range" caption="Choose the start and end points, confirm the range and duration, then create the clip." />

Clip generation takes time and is limited by server settings such as the maximum duration. If it fails, read the message first and, if needed, shorten the range and check the service configuration; see [Clips FAQ](/faq#clips-and-video-collections).

A successfully generated clip is a standalone video file that you can add to a clip collection and revisit from it. Before cleaning up the original, confirm the clip has been generated and can play.

<Screenshot src="/images/readme-en/clips-page.png" alt="SakuraMedia Clips page" caption="The Clips page brings clip collections and all clips together." />

## Organizing and backup

Playlists, moment collections and clip collections organize different kinds of content, so name them however you like — there is no need to turn every moment into a clip.

To keep standalone clips, you must back up the clip files; to keep collections and preview frames, you also need the corresponding database and image files. Copying only the original movie directory does not preserve all of your organizing.

Next: [Media library management](./media-management).
