# Deployment announcements

The backend polls `wiki/public/announcements.json` after it is deployed to
GitHub Pages. The published URL is:

`https://tinypinglite.github.io/sakuramedia/announcements.json`

## Feed shape

```json
{
  "schema_version": 1,
  "updated_at": "2026-11-12T00:00:00Z",
  "announcements": [
    {
      "id": "2026-11-12-backend-security",
      "level": "critical",
      "title_i18n": {
        "zh-CN": "请升级到 0.15.0",
        "en": "Upgrade to 0.15.0"
      },
      "body_i18n": {
        "zh-CN": "0.15.0 之前的后端版本存在已知安全问题。",
        "en": "Backend versions before 0.15.0 have a known security issue."
      },
      "published_at": "2026-11-12T08:00:00Z",
      "expires_at": null,
      "component": "backend",
      "affected_from_version": "0.10.0",
      "resolved_in_version": "0.15.0",
      "link": "https://github.com/tinypinglite/sakuramediabe/security/advisories"
    }
  ]
}
```

## Rules

- `id` must be stable and unique. It is the local acknowledgement key.
- `level` is `info`, `warning`, or `critical`.
- `title_i18n` and `body_i18n` must contain both `zh-CN` and `en`.
- `component` is `all`, `frontend`, or `backend`.
- Version bounds are optional for `frontend` / `backend`; `component: "all"`
  must not include version bounds.
- `affected_from_version` is inclusive; `resolved_in_version` is exclusive.
- `published_at` and `expires_at` are ISO 8601 timestamps and should include
  `Z` or an explicit offset. A naive timestamp is treated as UTC. A missing
  expiration keeps the announcement until it is removed from the feed.
- `link` is optional and must use HTTPS.
- Invalid entries are skipped by the backend. Keep the feed valid JSON.

## Publishing

1. Create or update the human-facing notice in GitHub Discussions
   (`Announcements`) and, for a security issue, publish a Security Advisory.
2. Add the matching entry to `wiki/public/announcements.json`.
3. Push the change. The existing GitHub Pages workflow deploys the feed.
4. Deployments receive it on their next poll; current cache lifetime is
   30 minutes.

Do not put executable commands in an announcement. The client renders the
title and body as plain text and only opens the HTTPS link in a browser.
