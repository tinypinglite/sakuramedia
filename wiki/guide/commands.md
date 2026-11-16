---
outline: [2, 4]
---

# Common Commands

Run all of the following commands inside the backend container. The container name in the examples is `sakuramedia`; replace it if your deployment differs.

## Account

### Reset the account

```bash
docker exec -it --user app -w /app sakuramedia python -m src.start.commands reset-account
```

You can also pass the new credentials directly:

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands reset-account --username admin --password 'your-new-password'
```

The command overwrites the account in the database and clears refresh tokens, so signed-in clients have to log in again.

## Database and services

### Initialize the database

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands initdb
```

### Apply the database schema

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate
```

### Wait for the database to be ready

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands wait-db --timeout 60 --interval 2
```

## Triggering background tasks manually

The `aps` subcommand puts tasks into the Task Center, where you can check progress and results:

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-subscribed-actor-movies
docker exec --user app -w /app sakuramedia python -m src.start.commands aps auto-download-subscribed-movies
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-download-tasks
docker exec --user app -w /app sakuramedia python -m src.start.commands aps auto-import-download-tasks
docker exec --user app -w /app sakuramedia python -m src.start.commands aps generate-media-thumbnails
```

See [Background Tasks](/guide/tasks) for the full list of task names and default schedules. Tasks registered by plugins also appear automatically in the `aps` command group.

## Plugin management

```bash
# List plugins
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins list

# Install from a directory or a zip package
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins install /path/to/plugin.zip

# Enable or disable
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins enable plugin_id
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins disable plugin_id

# Remove
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins remove plugin_id

# Validate a plugin directory
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins check /path/to/plugin
```

After changing plugins, restart the `api` and `aps` services as instructed by the command output.

## Other maintenance commands

Generate covers for movies that lack a thin cover image:

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands backfill-movie-thin-cover-images
```

Imports of regular movies and videos are started from "Manage → Media Import" in the client. Source browsing is provided by the media library provider, and the submitted data contains a `source_ref` that the provider understands.
