# Wedding Gallery Backend

## Ruby Setup

This repo is configured for RVM with:

- [`.ruby-version`](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/.ruby-version): `ruby-3.3.11`
- [`.ruby-gemset`](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/.ruby-gemset): `wedding-gallery-backend`

If your shell has RVM loaded, entering this directory should automatically switch to:

```sh
ruby-3.3.11@wedding-gallery-backend
```

## API Docs

A Swagger/OpenAPI spec for the currently available endpoints lives at
[docs/openapi.yaml](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/docs/openapi.yaml).

You can view it in either of these ways:

1. Open https://editor.swagger.io/ and paste the contents of `docs/openapi.yaml`.
2. Import `docs/openapi.yaml` into any Swagger UI or OpenAPI-compatible tool.

## Deployment

This repo now includes a Render blueprint at [render.yaml](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/render.yaml) with:

- a `web` service for the Rails API
- a `worker` service for `solid_queue`
- a managed Postgres database

Two small startup wrappers are included for container platforms:

- [bin/render-start-web](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/bin/render-start-web)
- [bin/render-start-worker](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/bin/render-start-worker)

Production expects these environment variables at minimum:

```sh
RAILS_MASTER_KEY=...
JWT_SECRET=...
DATABASE_URL=...
SENTRY_DSN=...
STORAGE_PROVIDER=cloudflare_r2
STORAGE_BUCKET=...
STORAGE_REGION=auto
STORAGE_ENDPOINT=...
STORAGE_PUBLIC_URL=...
STORAGE_ACCESS_KEY=...
STORAGE_SECRET_KEY=...
STORAGE_FORCE_PATH_STYLE=false
STORAGE_PRESIGN_EXPIRY=3600
FORCE_SSL=true
ASSUME_SSL=true
```

The GitHub Actions workflow in [ci.yml](/Users/umeshpalav/Desktop/Projects/wedding-gallery-backend/.github/workflows/ci.yml) now runs the full RSpec suite, RuboCop, Brakeman, and Bundler Audit.
