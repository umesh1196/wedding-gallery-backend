# Rails Backend API — Linear Task Board

*Rails 8 API-only · JWT Auth · PostgreSQL · Cloudflare R2 · Solid Queue*

---

## Epic 1: Project Setup & Infrastructure

### SETUP-1: Initialize Rails 8 API-only application
**Priority:** Urgent | **Estimate:** 1 point

```bash
rails new wedding_gallery_api --api --database=postgresql -T
```

- [ ] Create Rails 8 app with `--api` flag and PostgreSQL
- [ ] Remove unused middleware (cookies, sessions — pure API)
- [ ] Add `.ruby-version` file
- [ ] Set up `Dockerfile` and `docker-compose.yml` (Postgres + Rails)
- [ ] Configure `database.yml` for dev / test / production
- [ ] Add `rack-cors` gem, configure CORS for frontend origin
- [ ] Set up `.env` with `dotenv-rails` for local secrets
- [ ] Verify `rails db:create` and `rails s` work cleanly
- [ ] Push to GitHub with proper `.gitignore`

**Acceptance:** App boots, connects to Postgres, responds to `GET /health` with `{ status: "ok" }`.

---

### SETUP-2: Configure core gems and tooling
**Priority:** Urgent | **Estimate:** 1 point

Add to Gemfile and configure:

- [ ] `rack-cors` — CORS policy
- [ ] `jwt` — token encoding/decoding
- [ ] `bcrypt` — password hashing (already default)
- [ ] `jbuilder` or `blueprinter` — JSON serialization (recommend `blueprinter` for cleaner API responses)
- [ ] `pagy` — pagination
- [ ] `dotenv-rails` — env vars
- [ ] `aws-sdk-s3` — S3-compatible API (works with R2, B2, S3, MinIO)
- [ ] `marcel` — MIME type detection for uploads
- [ ] `image_processing` + `ruby-vips` — thumbnail/preview generation
- [ ] `solid_queue` — background jobs (Rails 8 built-in)
- [ ] `rubocop-rails` — linting
- [ ] `rspec-rails` + `factory_bot_rails` — testing

**Acceptance:** `bundle install` succeeds, RSpec runs with 0 examples.

---

### SETUP-3: Build provider-agnostic storage abstraction layer
**Priority:** High | **Estimate:** 3 points

We do NOT use Active Storage. Instead, we build a thin `Storage::Service` abstraction over the S3 API that works with any S3-compatible provider (Cloudflare R2, Backblaze B2, AWS S3, MinIO).

**ENV-based provider config:**
```bash
STORAGE_PROVIDER=r2              # r2 | b2 | s3 | minio
STORAGE_ACCESS_KEY=your_key
STORAGE_SECRET_KEY=your_secret
STORAGE_BUCKET=wedding-gallery-uploads
STORAGE_REGION=auto
STORAGE_ENDPOINT=https://xxxx.r2.cloudflarestorage.com
STORAGE_PUBLIC_URL=https://cdn.yourdomain.com
STORAGE_FORCE_PATH_STYLE=true
STORAGE_PRESIGN_EXPIRY=3600
```

- [ ] Create `Storage::Client` — builds `Aws::S3::Client` from ENV vars, handles endpoint/region/path-style per provider
- [ ] Create `Storage::Service` with methods:
  - `upload(key:, body:, content_type:)`
  - `upload_file(key:, file_path:, content_type:)` with auto multipart for files > 5MB
  - `download(key:)` — returns body
  - `download_to_tempfile(key:)` — streams to tempfile, returns tempfile
  - `presigned_upload_url(key:, content_type:, expires_in:)`
  - `presigned_download_url(key:, expires_in:, filename:)`
  - `public_url(key:)` — constructs CDN/public URL for Imgproxy
  - `exists?(key:)`
  - `delete(key:)`
  - `delete_batch(keys:)` — batch delete up to 1000 per call
  - `list(prefix:, max_keys:)`
  - `copy(source_key:, destination_key:)` — for future migrations
- [ ] Create `Storage::KeyBuilder` — centralizes all path conventions:
  - `original(studio_id:, wedding_id:, photo_id:, ext:)`
  - `thumbnail(studio_id:, wedding_id:, photo_id:)`
  - `hero(studio_id:, wedding_id:)`
  - `ceremony_cover(studio_id:, wedding_id:, ceremony_id:)`
  - `studio_logo(studio_id:)`
  - `wedding_prefix(studio_id:, wedding_id:)` — for bulk listing/cleanup
- [ ] Set up MinIO in `docker-compose.yml` for local development
- [ ] Use MinIO as test backend in RSpec (`STORAGE_PROVIDER=minio`)
- [ ] Verify presigned upload + download works via Rails console
- [ ] Verify batch delete works
- [ ] Document all ENV vars in README with example configs for R2, B2, S3, MinIO

**Acceptance:** Can upload a file, retrieve it, generate presigned URLs, and delete — all via `Storage::Service`. Swapping provider requires only ENV changes, zero code changes.

---

### SETUP-3b: Verify multi-provider compatibility
**Priority:** Medium | **Estimate:** 1 point

- [ ] Test with Cloudflare R2 (staging env)
- [ ] Test with Backblaze B2 (staging env)
- [ ] Test presigned upload URLs work from frontend for each provider
- [ ] Test presigned download URLs render in browser for each provider
- [ ] Test multipart upload for large files (> 5MB originals)
- [ ] Test `list` + `delete_batch` works per provider
- [ ] Document any provider-specific quirks in README

**Acceptance:** Full upload → process → serve → delete cycle works on at least 2 providers.

---

### SETUP-4: Set up Solid Queue for background jobs
**Priority:** High | **Estimate:** 1 point

- [ ] Run `bin/rails solid_queue:install`
- [ ] Configure `config/queue.yml` with queues: `default`, `images`, `downloads`
- [ ] Set `config.active_job.queue_adapter = :solid_queue`
- [ ] Create a test job, verify it executes
- [ ] Configure `images` queue with concurrency limit (2-3 workers — image processing is CPU-heavy)

**Acceptance:** A test background job enqueues and executes successfully.

---

### SETUP-5: Set up base API response structure
**Priority:** High | **Estimate:** 1 point

- [ ] Create `ApplicationController` with:
  - Standard JSON error responses (`render_error(message, status)`)
  - Standard success responses (`render_success(data, status)`)
  - Exception handling (`rescue_from ActiveRecord::RecordNotFound`, `RecordInvalid`, etc.)
- [ ] Create `Api::V1::BaseController` (API versioning from day 1)
- [ ] Set up consistent response envelope:

```json
{
  "success": true,
  "data": { ... },
  "meta": { "page": 1, "total": 100 }
}
```

```json
{
  "success": false,
  "error": { "code": "not_found", "message": "Gallery not found" }
}
```

- [ ] Add request logging middleware (request ID, duration)

**Acceptance:** All API responses follow consistent envelope format. Errors return proper status codes + JSON body.

---

## Epic 2: Authentication (JWT)

### AUTH-1: Create Studio (photographer) model and migration
**Priority:** Urgent | **Estimate:** 1 point

```ruby
# studios table
create_table :studios, id: :uuid do |t|
  t.string :email, null: false, index: { unique: true }
  t.string :password_digest, null: false
  t.string :studio_name, null: false
  t.string :slug, null: false, index: { unique: true }
  t.string :phone
  t.string :plan, default: "free"
  t.datetime :plan_expires_at
  t.timestamps
end
```

- [ ] Generate migration with UUID primary key
- [ ] Add `has_secure_password` to model
- [ ] Add validations: email uniqueness, email format, studio_name presence
- [ ] Add slug auto-generation from studio_name (with uniqueness)
- [ ] Add `before_validation` callback to generate slug via `parameterize`

**Acceptance:** `Studio.create(email:, password:, studio_name:)` works. Slug auto-generates. Duplicate emails rejected.

---

### AUTH-2: Build JWT encode/decode service
**Priority:** Urgent | **Estimate:** 1 point

- [ ] Create `JwtService` in `app/services/jwt_service.rb`

```ruby
class JwtService
  SECRET = ENV.fetch("JWT_SECRET")

  def self.encode(payload, exp: 7.days.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
```

- [ ] Token payload: `{ studio_id:, exp: }`
- [ ] Set JWT_SECRET in `.env`
- [ ] Write RSpec tests for encode, decode, expired token, invalid token

**Acceptance:** Tokens encode/decode correctly. Expired tokens return nil.

---

### AUTH-3: Build signup endpoint
**Priority:** Urgent | **Estimate:** 1 point

`POST /api/v1/auth/signup`

```json
// Request
{ "email": "priya@studio.com", "password": "securepass", "studio_name": "Priya Photography" }

// Response 201
{ "success": true, "data": { "token": "eyJ...", "studio": { "id": "uuid", "email": "...", "studio_name": "...", "slug": "priya-photography" } } }
```

- [ ] Create `Api::V1::AuthController#signup`
- [ ] Validate input, create studio, return JWT
- [ ] Handle duplicate email with 422 error
- [ ] Handle validation errors with field-level messages

**Acceptance:** Signup creates studio, returns JWT. Duplicate email returns 422.

---

### AUTH-4: Build login endpoint
**Priority:** Urgent | **Estimate:** 1 point

`POST /api/v1/auth/login`

```json
// Request
{ "email": "priya@studio.com", "password": "securepass" }

// Response 200
{ "success": true, "data": { "token": "eyJ...", "studio": { ... } } }
```

- [ ] Create `Api::V1::AuthController#login`
- [ ] Find studio by email, authenticate with `authenticate` method
- [ ] Return 401 for invalid credentials
- [ ] Return JWT + studio data on success

**Acceptance:** Valid creds return token. Invalid creds return 401.

---

### AUTH-5: Build authentication middleware
**Priority:** Urgent | **Estimate:** 1 point

- [ ] Add `authenticate_studio!` method to `Api::V1::BaseController`
- [ ] Extract token from `Authorization: Bearer <token>` header
- [ ] Decode JWT, find studio, set `current_studio`
- [ ] Return 401 with message if token missing/invalid/expired
- [ ] Add `current_studio` helper method
- [ ] Apply `before_action :authenticate_studio!` as default in base controller

**Acceptance:** Protected routes reject requests without valid JWT. `current_studio` available in all controllers.

---

### AUTH-6: Build get current studio endpoint
**Priority:** Medium | **Estimate:** 0.5 points

`GET /api/v1/auth/me`

- [ ] Return current studio profile from JWT
- [ ] Include plan info, branding config, stats (wedding count)

**Acceptance:** Returns current studio's profile. 401 if not authenticated.

---

## Epic 3: Studio Branding

### BRAND-1: Add branding fields to studios table
**Priority:** High | **Estimate:** 1 point

```ruby
add_column :studios, :logo_url, :string
add_column :studios, :color_primary, :string, default: "#1a1a1a"
add_column :studios, :color_accent, :string, default: "#c9a96e"
add_column :studios, :font_heading, :string, default: "Playfair Display"
add_column :studios, :font_body, :string, default: "Inter"
add_column :studios, :watermark_url, :string
add_column :studios, :watermark_opacity, :decimal, default: 0.3
```

- [ ] Create migration
- [ ] Add validations (color format, opacity range 0-1, font whitelist)
- [ ] Update studio serializer/blueprint to include branding fields

**Acceptance:** Studio branding fields save and return correctly in API responses.

---

### BRAND-2: Build studio profile update endpoint
**Priority:** High | **Estimate:** 1 point

`PATCH /api/v1/studio`

- [ ] Update studio_name, slug, phone, branding fields
- [ ] Slug change must validate uniqueness
- [ ] Return updated studio

**Acceptance:** All studio fields update correctly. Slug conflicts return 422.

---

### BRAND-3: Build studio logo upload endpoint
**Priority:** High | **Estimate:** 2 points

`POST /api/v1/studio/logo`

- [ ] Accept logo image upload (multipart form data)
- [ ] Validate file type (png, jpg, svg) and size (< 2MB)
- [ ] Process: resize to max 400px width, optimize with ruby-vips
- [ ] Upload via `Storage::Service.upload` with key from `Storage::KeyBuilder.studio_logo`
- [ ] Store the object key in `studios.logo_key` (NOT full URL)
- [ ] Return signed URL via `Storage::Service.presigned_download_url`
- [ ] Same pattern for `POST /api/v1/studio/watermark`

**Acceptance:** Logo uploads, processes, stores in configured provider, returns accessible signed URL.

---

## Epic 4: Wedding Project CRUD

### WEDDING-1: Create weddings table and model
**Priority:** Urgent | **Estimate:** 1 point

```ruby
create_table :weddings, id: :uuid do |t|
  t.references :studio, type: :uuid, foreign_key: true, null: false
  t.string :couple_name, null: false
  t.date :wedding_date
  t.string :slug, null: false
  t.string :hero_image_url
  t.string :password_hash, null: false
  t.boolean :is_active, default: true
  t.datetime :expires_at, null: false
  t.string :allow_download, default: "shortlist"  # none | shortlist | all
  t.boolean :allow_comments, default: true
  t.integer :total_photos, default: 0
  t.integer :total_videos, default: 0
  t.jsonb :metadata, default: {}
  t.timestamps
end

add_index :weddings, [:studio_id, :slug], unique: true
```

- [ ] Generate migration with UUID
- [ ] Model: `belongs_to :studio`, `has_many :ceremonies`
- [ ] Auto-generate slug from couple_name
- [ ] Validate: couple_name, slug uniqueness scoped to studio, password presence
- [ ] Use `bcrypt` to hash gallery password (separate from studio password)
- [ ] Add `expired?` method: `expires_at < Time.current || !is_active`
- [ ] Add counter cache or method for total_photos

**Acceptance:** Wedding creates with hashed password. Slug auto-generates. Scoped uniqueness works.

---

### WEDDING-2: Build wedding CRUD endpoints
**Priority:** Urgent | **Estimate:** 2 points

All scoped to `current_studio`:

**`POST /api/v1/weddings`**
```json
{
  "couple_name": "Priya & Arjun",
  "wedding_date": "2026-02-15",
  "password": "priya2026",
  "expires_at": "2026-03-17",
  "allow_download": "shortlist"
}
```

**`GET /api/v1/weddings`**
- List all weddings for current studio
- Include ceremony count, photo count, active/expired status
- Paginated with `pagy`

**`GET /api/v1/weddings/:slug`**
- Full wedding detail with ceremonies

**`PATCH /api/v1/weddings/:slug`**
- Update couple_name, date, password, expiry, permissions, metadata

**`DELETE /api/v1/weddings/:slug`**
- Soft delete (set `is_active: false`) or hard delete with confirmation param

- [ ] Create `Api::V1::WeddingsController`
- [ ] Scope all queries to `current_studio.weddings`
- [ ] Use slug as the URL param (not UUID)
- [ ] Create `WeddingBlueprint` serializer

**Acceptance:** Full CRUD works. Weddings scoped to authenticated studio. Slugs used in URLs.

---

### WEDDING-3: Build hero image upload for wedding
**Priority:** High | **Estimate:** 1 point

`POST /api/v1/weddings/:slug/hero`

- [ ] Accept image upload
- [ ] Process: generate full-res (2400px) + blur placeholder with ruby-vips
- [ ] Upload via `Storage::Service.upload` with key from `Storage::KeyBuilder.hero`
- [ ] Store object key in `weddings.hero_image_key` (NOT full URL)
- [ ] Return signed URL + blur data URI

**Acceptance:** Hero image uploads, processes, stores in configured provider, returns full + blur URLs.

---

## Epic 5: Ceremonies

### CEREMONY-1: Create ceremonies table and model
**Priority:** Urgent | **Estimate:** 1 point

```ruby
create_table :ceremonies, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.string :name, null: false
  t.string :slug, null: false
  t.string :cover_image_url
  t.string :description
  t.integer :sort_order, null: false, default: 0
  t.integer :photo_count, default: 0
  t.integer :video_count, default: 0
  t.timestamps
end

add_index :ceremonies, [:wedding_id, :slug], unique: true
add_index :ceremonies, [:wedding_id, :sort_order]
```

- [ ] Model: `belongs_to :wedding`, `has_many :photos`
- [ ] Auto-generate slug from name
- [ ] Validate uniqueness of slug scoped to wedding
- [ ] Default ceremony templates (engagement, haldi, mehendi, wedding, reception, family)

**Acceptance:** Ceremonies create with proper ordering. Slug unique within wedding.

---

### CEREMONY-2: Build ceremony CRUD endpoints
**Priority:** Urgent | **Estimate:** 2 points

**`POST /api/v1/weddings/:wedding_slug/ceremonies`**
```json
{ "name": "Haldi Ceremony", "description": "The turmeric ceremony", "sort_order": 2 }
```

**`GET /api/v1/weddings/:wedding_slug/ceremonies`**
- Ordered by `sort_order`
- Include photo_count, cover_image_url

**`PATCH /api/v1/weddings/:wedding_slug/ceremonies/:slug`**
- Update name, description, sort_order

**`DELETE /api/v1/weddings/:wedding_slug/ceremonies/:slug`**
- Cascade delete photos (with R2 cleanup job)

**`PATCH /api/v1/weddings/:wedding_slug/ceremonies/reorder`**
```json
{ "order": ["ceremony-uuid-1", "ceremony-uuid-3", "ceremony-uuid-2"] }
```

- [ ] Create `Api::V1::CeremoniesController`
- [ ] Nested under wedding: `current_studio.weddings.find_by!(slug:).ceremonies`
- [ ] Bulk reorder endpoint
- [ ] Cover image upload endpoint

**Acceptance:** CRUD works. Reorder works. Photos cascade on delete.

---

### CEREMONY-3: Build ceremony template seeding
**Priority:** Medium | **Estimate:** 0.5 points

`POST /api/v1/weddings/:wedding_slug/ceremonies/seed`

```json
{ "template": "indian_wedding" }
```

Templates:
- `indian_wedding`: Engagement, Haldi, Mehendi, Sangeet, Wedding Ceremony, Reception, Candid Moments, Family Portraits
- `minimal`: Ceremony, Reception, Portraits

- [ ] Create predefined ceremony sets
- [ ] Seed ceremonies with default sort_order
- [ ] Skip if ceremonies already exist (or option to replace)

**Acceptance:** Template seeds correct ceremonies with proper ordering.

---

## Epic 6: Photo Import, Upload & Processing

### Epic Goal
Photographers should be able to get large wedding photo sets into the platform without manual one-by-one uploads.

This epic must support **both** ingestion paths:
- direct browser upload to gallery-managed storage via presigned URLs
- direct import from existing photographer cloud storage such as **Backblaze B2** or **Cloudflare R2**

The system should treat both paths the same after ingestion:
- create `Photo` records
- copy or place originals into gallery-managed storage
- process thumbnails + blur placeholders
- expose stable photo URLs for studio and gallery APIs

Recommended product stance:
- **Primary real-world workflow:** import from photographer storage
- **Fallback workflow:** direct upload via presigned URLs
- **Serving layer:** gallery-managed storage, not third-party source URLs
- **Connection model:** studio-specific saved storage connections, with optional env-based global fallback for local development/admin use
- **Original format policy:** preserve the original file bytes and extension in gallery-managed storage; generate derivative formats separately

---

### PHOTO-1: Create photos table and model
**Priority:** Urgent | **Estimate:** 1 point

```ruby
create_table :photos, id: :uuid do |t|
  t.references :ceremony, type: :uuid, foreign_key: true, null: false
  t.references :wedding, type: :uuid, foreign_key: true, null: false

  # Storage keys in gallery-managed storage
  t.string :original_key, null: false
  t.string :thumbnail_key

  # Original source metadata
  t.string :source_provider, null: false, default: "gallery_storage"  # gallery_storage | backblaze_b2 | cloudflare_r2 | imported
  t.string :source_bucket
  t.string :source_key
  t.string :source_etag

  # Small inline placeholder
  t.text :blur_data_uri

  # Image dimensions
  t.integer :width, null: false, default: 0
  t.integer :height, null: false, default: 0

  # File metadata
  t.bigint :file_size_bytes, null: false, default: 0
  t.string :mime_type, null: false, default: "image/jpeg"
  t.string :original_filename
  t.string :file_extension, null: false, default: "jpg"

  # EXIF metadata
  t.jsonb :exif_data, default: {}

  # Ordering & display
  t.integer :sort_order, null: false, default: 0
  t.boolean :is_cover, default: false

  # Ingestion state: how the original lands in gallery-managed storage
  t.string :ingestion_status, null: false, default: "pending_import" # pending_import | queued | uploading | copied | failed
  t.string :ingestion_error
  t.datetime :ingested_at

  # Processing state: how derivatives/metadata are generated after ingestion
  t.string :processing_status, null: false, default: "pending"       # pending | processing | ready | failed
  t.string :processing_error
  t.datetime :processed_at

  t.timestamps
end

execute <<-SQL
  ALTER TABLE photos ADD COLUMN aspect_ratio DECIMAL(5,3)
    GENERATED ALWAYS AS (
      CASE WHEN height > 0 THEN ROUND(width::decimal / height::decimal, 3) ELSE 0 END
    ) STORED;
SQL
```

- [ ] Store gallery-serving object keys, not full URLs
- [ ] Preserve source metadata for audit/debug/reimport
- [ ] `blur_data_uri` stored inline in Postgres
- [ ] `aspect_ratio` generated column for frontend layout
- [ ] Preserve original file format and extension in storage
- [ ] Split state into two independent tracks:
  - ingestion: `pending_import` → `queued` → `uploading`/`copied` or `failed`
  - processing: `pending` → `processing` → `ready` or `failed`

```ruby
add_index :photos, [:ceremony_id, :sort_order], where: "processing_status = 'ready'"
add_index :photos, [:wedding_id, :created_at], where: "processing_status = 'ready'"
add_index :photos, [:ingestion_status, :created_at], where: "ingestion_status IN ('pending_import', 'queued', 'uploading')"
add_index :photos, [:processing_status, :created_at], where: "processing_status IN ('pending', 'processing')"
add_index :photos, :ceremony_id, where: "is_cover = true"
add_index :photos, [:ceremony_id, :source_provider, :source_bucket, :source_key, :source_etag], unique: true, where: "source_key IS NOT NULL", name: "idx_photos_unique_import_source"
```

- [ ] Model: `belongs_to :ceremony`, `belongs_to :wedding`
- [ ] Denormalized `wedding_id` for fast queries
- [ ] Validations for mime type, source provider, ingestion status, processing status
- [ ] Duplicate protection for repeated imports from the same source object + etag

**Acceptance:** Photo records support both imported and directly uploaded assets, preserve original file type, track ingestion/processing independently, and reject duplicate imports safely.

---

### PHOTO-2: Build source connection abstraction
**Priority:** Urgent | **Estimate:** 2 points

Create a provider-agnostic source adapter layer for:
- Backblaze B2
- Cloudflare R2

Connection model:
- Each studio owns one or more saved storage connections
- Import requests should use a `connection_id` or the studio's default connection
- Global env credentials may exist only as a development/admin fallback, not the primary production model

Add a table for saved studio-owned connections:

```ruby
create_table :studio_storage_connections, id: :uuid do |t|
  t.references :studio, type: :uuid, foreign_key: true, null: false
  t.string :label, null: false
  t.string :provider, null: false                    # backblaze_b2 | cloudflare_r2
  t.string :account_id
  t.string :bucket, null: false
  t.string :region
  t.string :endpoint
  t.string :access_key_ciphertext, null: false
  t.string :secret_key_ciphertext, null: false
  t.string :base_prefix
  t.boolean :is_default, default: false, null: false
  t.boolean :active, default: true, null: false
  t.timestamps
end

add_index :studio_storage_connections, [:studio_id, :is_default], where: "is_default = true", unique: true, name: "idx_studio_storage_connections_one_default"
```

Example:
```ruby
module PhotoSources
  class Base
    def list(prefix:); end
    def head(key:); end
    def presigned_download_url(key:, expires_in: 3600); end
    def stream_to_tempfile(key:); end
  end
end
```

- [ ] Add `StudioStorageConnection` model with encrypted credentials
- [ ] Use Rails encrypted attributes or equivalent application-level encryption
- [ ] Scope all connections to a studio
- [ ] Support multiple connections per studio with one default
- [ ] Add env-based global fallback for development/admin workflows only
- [ ] Support credential rotation without losing import history
- [ ] Support source bucket + optional prefix per studio or wedding
- [ ] Normalize provider responses into one interface
- [ ] Support listing objects by prefix/folder
- [ ] Support metadata lookup: size, content type, etag, last modified
- [ ] Add connection test/health check action before import is allowed

**Acceptance:** The app can talk to either B2 or R2 through one internal interface using studio-owned saved connections.

---

### PHOTO-3: Build cloud import discovery endpoint
**Priority:** Urgent | **Estimate:** 2 points

`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/import/discover`

```json
{
  "connection_id": "uuid",
  "prefix": "2026/aditi-karan/mehendi/"
}
```

Response:
```json
{
  "data": {
    "connection_id": "uuid",
    "provider": "cloudflare_r2",
    "bucket": "photographer-archive",
    "prefix": "2026/aditi-karan/mehendi/",
    "files": [
      {
        "source_key": "2026/aditi-karan/mehendi/DSC_0012.jpg",
        "filename": "DSC_0012.jpg",
        "content_type": "image/jpeg",
        "byte_size": 4500000,
        "etag": "abc123"
      }
    ]
  }
}
```

- [ ] Resolve connection from `connection_id` or studio default connection
- [ ] Ensure the connection belongs to the authenticated studio
- [ ] Validate provider is one of `backblaze_b2`, `cloudflare_r2`
- [ ] List candidate image files from the connected bucket/prefix
- [ ] Filter to supported file types: jpg, jpeg, png, webp, heic
- [ ] Return metadata only; no DB writes yet
- [ ] Cap discovery result size per request or paginate it
- [ ] Return cursor/continuation token if provider listing is paginated
- [ ] Support prefix normalization using connection `base_prefix`

**Acceptance:** Photographer can select one of their saved storage connections and preview importable files from a folder/prefix.

---

### PHOTO-4: Build cloud import creation endpoint
**Priority:** Urgent | **Estimate:** 2 points

`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/import`

```json
{
  "connection_id": "uuid",
  "files": [
    {
      "source_key": "weddings/priya/haldi/DSC_0012.jpg",
      "filename": "DSC_0012.jpg",
      "content_type": "image/jpeg",
      "byte_size": 4500000,
      "etag": "abc123"
    }
  ]
}
```

- [ ] Create `Photo` records in `pending_import`
- [ ] Resolve source config from studio-owned connection
- [ ] Revalidate every selected source object server-side with `head` before record creation
- [ ] Store canonical source metadata from provider, not from client-submitted payload
- [ ] Store `source_provider`, `source_bucket`, `source_key`, `source_etag`
- [ ] Allocate final gallery-managed `original_key` up front using the true file extension
- [ ] Create an `upload_batch`/`import_batch` record for progress tracking
- [ ] Enqueue `PhotoImportJob` per file
- [ ] Make request idempotent using unique source identity
- [ ] Return skipped duplicates separately from newly queued files

**Acceptance:** Import request creates photo records and background jobs using the studio's saved storage connection without requiring manual uploads.

---

### PHOTO-5: Build presigned direct-upload endpoint
**Priority:** High | **Estimate:** 2 points

Keep direct upload as a supported fallback for cases where:
- files are not already in B2/R2
- photographer uploads from laptop/browser
- quick ad hoc additions are needed

`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/presign`

- [ ] Use `Storage::KeyBuilder.original(...)`
- [ ] Use `Storage::Service.presigned_upload_url(...)`
- [ ] Create `Photo` records with `ingestion_status: "uploading"` and `processing_status: "pending"`
- [ ] Validate up to 50 files per request
- [ ] Validate type and size (< 30MB per file)
- [ ] Set `source_provider = "gallery_storage"`
- [ ] Preserve original extension in `original_key`

**Acceptance:** Frontend can still upload directly to gallery storage when needed.

---

### PHOTO-6: Build upload confirmation and retry endpoints
**Priority:** Urgent | **Estimate:** 1 point

Primary confirmation path:

`POST /api/v1/photos/:id/confirm`
- used after direct browser upload

Retry/admin paths:

`POST /api/v1/photos/:id/retry_import`
- re-enqueue import if ingestion failed

`POST /api/v1/photos/:id/retry_processing`
- re-enqueue processing if derivatives failed

- [ ] Verify object exists in gallery-managed storage
- [ ] Mark ingestion as completed (`copied`/`ingested_at`) when confirmed
- [ ] Transition processing to `pending` or `processing`
- [ ] Enqueue `PhotoProcessingJob`
- [ ] Return photo record
- [ ] Make confirmation idempotent
- [ ] Retry endpoints should be safe and state-aware

**Acceptance:** Direct uploads can be confirmed once, and failed imports/processing can be retried explicitly without introducing ambiguous state.

---

### PHOTO-7: Build PhotoImportJob
**Priority:** Urgent | **Estimate:** 3 points

This job copies a source object from B2/R2 into gallery-managed storage.

```ruby
class PhotoImportJob < ApplicationJob
  queue_as :imports

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.update!(ingestion_status: "uploading", ingestion_error: nil)

    source = PhotoSources.build(photo.source_provider, bucket: photo.source_bucket)
    if source.supports_server_side_copy_to_gallery_storage?
      source.copy_to_gallery_storage(photo.source_key, destination_key: photo.original_key)
    else
      tempfile = source.stream_to_tempfile(photo.source_key)
      Storage::Service.new.upload_file(
        key: photo.original_key,
        file_path: tempfile.path,
        content_type: photo.mime_type
      )
    end

    photo.update!(
      ingestion_status: "copied",
      ingested_at: Time.current,
      processing_status: "pending",
      ingestion_error: nil
    )
    PhotoProcessingJob.perform_later(photo.id)
  rescue => e
    photo&.update!(ingestion_status: "failed", ingestion_error: e.message)
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
```

- [ ] Stream from source provider to tempfile
- [ ] Prefer provider-side copy when source/destination compatibility allows it
- [ ] Upload into gallery-managed storage
- [ ] Avoid keeping external source URLs as the long-term serving path
- [ ] Handle retries safely
- [ ] Preserve original filename, size, and content type

**Acceptance:** Imported photos move from B2/R2 into gallery-managed storage automatically.

---

### PHOTO-8: Build PhotoProcessingJob (thumbnail + blur only)
**Priority:** Urgent | **Estimate:** 3 points

Simplified pipeline:
- original stored in gallery-managed storage
- thumbnail generated and stored
- blur placeholder stored inline in DB
- preview/full generated later via Imgproxy

- [ ] Download original via `Storage::Service.download_to_tempfile`
- [ ] Generate thumbnail (300px wide, WebP, quality 60)
- [ ] Generate blur placeholder (20px wide, base64)
- [ ] Upload thumbnail via `Storage::Service.upload`
- [ ] Extract EXIF data
- [ ] Extract width/height for aspect ratio
- [ ] Update processing state to `processing` then `ready`
- [ ] Increment ceremony and wedding counters
- [ ] Set `processing_status = failed` with error on processing failure

**Acceptance:** Imported or directly uploaded photo becomes fully usable after processing.

---

### PHOTO-9: Set up Imgproxy for on-demand image resizing
**Priority:** High | **Estimate:** 2 points

- [ ] Deploy Imgproxy
- [ ] Configure it against `STORAGE_PUBLIC_URL`
- [ ] Add signed URL support
- [ ] Support AVIF, WebP, JPEG
- [ ] Put CDN in front for caching
- [ ] Verify it works for originals stored in gallery-managed storage

**Acceptance:** Preview/full variants are generated on demand without storing many redundant versions.

---

### PHOTO-10: Build PhotoUrlBuilder service
**Priority:** High | **Estimate:** 1 point

- [ ] Return:
  - blur
  - thumbnail
  - preview
  - full
  - avif_preview
  - avif_full
  - download
- [ ] Use gallery-managed storage keys as the source of truth
- [ ] Never expose raw B2/R2 source keys to gallery clients

**Acceptance:** Any ready photo can produce the full display/download URL set.

---

### PHOTO-11: Build studio photo listing endpoint
**Priority:** Urgent | **Estimate:** 1 point

`GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos`

- [ ] Cursor-based pagination using `sort_order`
- [ ] Default to `processing_status = 'ready'`
- [ ] Add optional studio filters for `failed`, `processing`, and `ingestion_status`
- [ ] Use `PhotoUrlBuilder`
- [ ] Include width, height, aspect ratio, sort order, cover status
- [ ] Include ingestion/processing status for studio dashboard views
- [ ] Do not include gallery-session fields yet

**Acceptance:** Photographer can browse ready photos and also inspect items that are still processing or failed.

---

### PHOTO-12: Build photo management endpoints
**Priority:** High | **Estimate:** 1 point

**`DELETE /api/v1/photos/:id`**
- delete record + enqueue cleanup

**`PATCH /api/v1/photos/:id`**
- update metadata like `sort_order`

**`PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/reorder`**
- bulk reorder

**`POST /api/v1/photos/:id/set_cover`**
- enforce one cover per ceremony

- [ ] On delete, collect gallery storage keys only
- [ ] Reorder accepts array of photo UUIDs
- [ ] Cover photo is unique per ceremony

**Acceptance:** Photographer can curate imported photos just like directly uploaded ones.

---

### PHOTO-13: Build storage cleanup job
**Priority:** Medium | **Estimate:** 1 point

`StorageCleanupJob`

- [ ] Accept keys from gallery-managed storage
- [ ] Use `Storage::Service.delete_batch(keys:)`
- [ ] Handle missing keys gracefully
- [ ] Log deletions for audit
- [ ] Never delete from external source buckets unless explicitly requested by product rules

**Acceptance:** Deleting a photo cleans up gallery-managed storage safely.

---

### PHOTO-14: Build import/upload batch tracking
**Priority:** Medium | **Estimate:** 1 point

```ruby
create_table :upload_batches, id: :uuid do |t|
  t.references :ceremony, type: :uuid, foreign_key: true, null: false
  t.references :studio, type: :uuid, foreign_key: true, null: false
  t.string :source_type, null: false, default: "import"   # import | direct_upload
  t.integer :total_files, null: false, default: 0
  t.integer :completed_files, null: false, default: 0
  t.integer :failed_files, null: false, default: 0
  t.string :status, null: false, default: "in_progress"
  t.timestamps
end
```

- [ ] Track both cloud imports and direct uploads
- [ ] Update counters as photos finish or fail
- [ ] Mark batch as `completed` or `partial`
- [ ] Photographer dashboard can show import progress
- [ ] Track skipped duplicates separately
- [ ] Track both ingestion failures and processing failures

**Acceptance:** Large imports from B2/R2 are trackable and support real upload progress UX.

---

### Notes on Product Direction
- Importing from photographer storage is the main workflow.
- Direct browser upload stays supported, but it is not the only ingestion path.
- We should serve client galleries from gallery-managed storage, not directly from photographer buckets.
- This keeps access control, thumbnails, expiry, downloads, and future migration under our control.
- Source credentials should be owned per studio through saved connections.
- Global env credentials should be used only for local development, initial bootstrap, or admin-only operational tools.
- Import requests must trust provider-side metadata, not raw client-submitted metadata.
- Retries should be explicit (`retry_import`, `retry_processing`) rather than overloading confirmation semantics.
- Duplicate imports should be prevented by canonical source identity, not by filename alone.

---

## Epic 7: Gallery Public Access (Client-Facing)

### GALLERY-1: Create gallery_sessions table
**Priority:** Urgent | **Estimate:** 1 point

```ruby
create_table :gallery_sessions, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.string :session_token_digest, null: false, index: { unique: true }
  t.string :visitor_name
  t.string :role, default: "guest"  # couple | family | guest
  t.string :last_ip
  t.string :last_user_agent
  t.datetime :last_active_at, default: -> { "now()" }, null: false
  t.datetime :revoked_at
  t.timestamps
end
```

- [ ] Token generated via `SecureRandom.urlsafe_base64(32)`
- [ ] Store only a SHA256 digest of the session token in DB
- [ ] Session expires after 24 hours of inactivity
- [ ] Support explicit invalidation via `revoked_at`
- [ ] Touch `last_active_at` on each authenticated gallery API call
- [ ] Optionally record `last_ip` and `last_user_agent` for audit/debugging

**Acceptance:** Sessions create, expire, and revoke correctly without storing raw bearer tokens in plaintext.

---

### GALLERY-2: Build gallery password verification endpoint
**Priority:** Urgent | **Estimate:** 1 point

`POST /api/v1/g/:studio_slug/:wedding_slug/verify`

```json
// Request
{ "password": "priya2026" }

// Response 200
{
  "success": true,
  "data": {
    "session_token": "random-secure-token",
    "gallery": {
      "couple_name": "Priya & Arjun",
      "wedding_date": "2026-02-15",
      "hero_image_url": "signed-url",
      "branding": { "logo_url": "...", "color_primary": "#1a1a1a", ... },
      "allow_download": "shortlist",
      "allow_comments": true
    }
  }
}
```

- [ ] Find wedding by studio_slug + wedding_slug combo
- [ ] Check `is_active` and `expires_at` — return 410 (Gone) if expired
- [ ] Verify password against `password_hash`
- [ ] Create `gallery_sessions` record and return raw session token once
- [ ] Include lightweight gallery bootstrap data only:
  - couple name
  - wedding date
  - hero image URL
  - branding
  - allow_download
  - allow_comments
- [ ] Do not preload ceremony lists, photo counts, likes, shortlist state, or comments here
- [ ] Add rate limiting/backoff to reduce brute-force attempts per IP and per wedding

**Acceptance:** Correct password returns a session token plus minimal gallery shell. Wrong password returns 401. Expired gallery returns 410. Repeated bad attempts are throttled.

---

### GALLERY-3: Build gallery authentication middleware
**Priority:** Urgent | **Estimate:** 1 point

Separate from studio JWT auth — this is for gallery visitors.

- [ ] Create `authenticate_gallery_session!` method
- [ ] Extract token from `X-Gallery-Token` header
- [ ] Digest incoming token before lookup
- [ ] Find session, check not expired, not revoked, and wedding still active
- [ ] Set `current_session` and `current_wedding`
- [ ] Touch `last_active_at`
- [ ] Ensure URL `studio_slug` and `wedding_slug` match the session's wedding on every request
- [ ] Return 401 if invalid, 410 if gallery expired

**Acceptance:** Gallery endpoints reject invalid, revoked, cross-gallery, or expired sessions. `current_wedding` is always bound to the authenticated gallery session.

---

### GALLERY-4: Build public gallery bootstrap endpoint
**Priority:** Urgent | **Estimate:** 0.5 points

`GET /api/v1/g/:studio_slug/:wedding_slug`

Header: `X-Gallery-Token: <session_token>`

- [ ] Return lightweight gallery metadata for already-authenticated sessions
- [ ] Include:
  - couple name
  - wedding date
  - hero image URL
  - branding
  - allow_download
  - allow_comments
- [ ] Keep this endpoint read-only and fast
- [ ] Do not include ceremony list or photo interaction state here

**Acceptance:** Frontend can refresh its gallery shell without re-running password verification.

---

### GALLERY-5: Build public ceremony listing endpoint
**Priority:** Urgent | **Estimate:** 0.5 points

`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies`

Header: `X-Gallery-Token: <session_token>`

- [ ] Return ceremonies ordered by `sort_order`
- [ ] Include cover image signed URLs, photo counts
- [ ] No authentication required beyond gallery session

**Acceptance:** Returns ceremony list for authenticated gallery session.

---

### GALLERY-6: Build public photo browsing endpoint
**Priority:** Urgent | **Estimate:** 1 point

`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos`

- [ ] Paginated (cursor-based for infinite scroll — use `(sort_order, id)` as a stable cursor)
- [ ] Return thumbnail + preview signed URLs + blur hash + dimensions
- [ ] Only `ready` processing status
- [ ] Do not include like, shortlist, or comment fields yet

```json
{
  "data": [
    {
      "id": "uuid",
      "thumbnail_url": "signed...",
      "preview_url": "signed...",
      "blur_hash": "base64...",
      "width": 4000,
      "height": 2667
    }
  ],
  "meta": { "next_cursor": "abc123", "has_more": true }
}
```

- [ ] Cursor-based pagination (not offset — better for infinite scroll)
- [ ] Cursor must remain stable if photographer reorders photos while guests are browsing
- [ ] Signed URLs should use short expiry windows
- [ ] Note product decision: already-issued signed URLs may remain valid briefly after gallery expiry until their TTL runs out

**Acceptance:** Infinite-scroll ready endpoint with signed URLs and display metadata only.

---

### Notes on Scope for Epic 7
- Epic 7 is intentionally read-only for public gallery access.
- Likes, shortlist state, and comment counts begin in later epics and should not block public browsing.
- `is_liked` and `is_shortlisted` are added in Epic 8.
- `comment_count` is added in Epic 10.
- `verify` creates the session and returns a minimal gallery shell.
- Ceremony listing and photo browsing stay as separate endpoints so auth remains lightweight.
- Session authentication must bind the token to the same wedding in the URL, not just any active wedding.
- Public password verification must be rate-limited from day one.

---

## Epic 8: Likes & Shortlisting

### LIKE-1: Create likes table and endpoints
**Priority:** High | **Estimate:** 1 point

```ruby
create_table :likes, id: :uuid do |t|
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.references :gallery_session, type: :uuid, foreign_key: true, null: false
  t.timestamps
end
add_index :likes, [:photo_id, :gallery_session_id], unique: true
```

**`POST /api/v1/g/.../photos/:photo_id/like`** — ensure liked
**`DELETE /api/v1/g/.../photos/:photo_id/like`** — ensure unliked

- [ ] `POST` must be idempotent: repeated requests keep the photo liked
- [ ] `DELETE` must be idempotent: repeated requests keep the photo unliked
- [ ] Validate that the liked photo belongs to `current_wedding`
- [ ] Extend Epic 7 public photo browsing response with `is_liked`

**Acceptance:** Like/unlike works predictably with retries. Duplicate likes prevented. Public photo response can reflect liked state.

---

### LIKE-2: Build liked photos listing endpoint
**Priority:** High | **Estimate:** 1 point

**`GET /api/v1/g/.../likes`** — list liked photos for current session

- [ ] Paginated response
- [ ] Return the same display fields as Epic 7 public photo browsing
- [ ] Scope strictly to `current_gallery_session`

**Acceptance:** Visitor can retrieve the set of photos they liked during the current gallery session.

---

### SHORT-1: Create shortlists table with one default shortlist per session
**Priority:** High | **Estimate:** 1 point

```ruby
create_table :shortlists, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.references :gallery_session, type: :uuid, foreign_key: true, null: false
  t.string :name, default: "My Shortlist"
  t.timestamps
end
add_index :shortlists, [:wedding_id, :gallery_session_id], unique: true

create_table :shortlist_photos, id: :uuid do |t|
  t.references :shortlist, type: :uuid, foreign_key: true, null: false
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.integer :sort_order, default: 0
  t.string :note
  t.timestamps
end
add_index :shortlist_photos, [:shortlist_id, :photo_id], unique: true
```

- [ ] Exactly one shortlist per `gallery_session` per `wedding`
- [ ] No shortlist sharing in Epic 8
- [ ] Validate that shortlisted photos belong to the same wedding as the shortlist
- [ ] Decide and document product behavior:
  shortlist state is session-local unless we later introduce visitor identity persistence

**Acceptance:** Each visitor session gets a single default shortlist for the current wedding.

---

### SHORT-2: Build shortlist item endpoints
**Priority:** High | **Estimate:** 2 points

**`POST /api/v1/g/.../shortlist/photos`** — add photo(s) to shortlist
```json
{ "photo_ids": ["uuid-1", "uuid-2"] }
```

- [ ] Auto-create shortlist on first add (lazy creation)
- [ ] Multi-add accepts an array of `photo_ids`
- [ ] Ignore or report duplicates predictably
- [ ] Extend Epic 7 public photo browsing response with `is_shortlisted`

**`DELETE /api/v1/g/.../shortlist/photos/:photo_id`** — remove from shortlist
- [ ] Idempotent remove

**`GET /api/v1/g/.../shortlist`** — view current shortlist
- [ ] Paginated response
- [ ] Return shortlist photos in `sort_order`

**`PATCH /api/v1/g/.../shortlist/reorder`** — reorder shortlist photos
- [ ] Accept ordered photo UUID array
- [ ] Reordering must only affect the current session shortlist

**Acceptance:** Visitor can add, remove, list, and reorder shortlist photos within one default shortlist.

---

### SHORT-3: Build photographer shortlist views
**Priority:** High | **Estimate:** 1 point

`GET /api/v1/weddings/:wedding_slug/shortlists`

- [ ] Paginated shortlist summary list
- [ ] Include visitor name, photo count, created date

`GET /api/v1/weddings/:wedding_slug/shortlists/:id`
- [ ] Detail view with shortlisted photos + notes
- [ ] Scope to the current studio's wedding only

**Acceptance:** Photographer can browse shortlist summaries and open a specific shortlist in detail.

---

### Notes on Scope for Epic 8
- Epic 8 is about selection state and photographer visibility, not public sharing.
- `is_liked` and `is_shortlisted` are added onto Epic 7 public photo responses here.
- Likes and shortlists are scoped to the current `gallery_session` unless later product work introduces persistent visitor identity.
- Shareable shortlist links are deferred to Epic 12.

---

## Epic 9: Downloads

### DL-1: Build single photo download endpoint
**Priority:** High | **Estimate:** 1 point

`GET /api/v1/g/.../photos/:id/download`

- [ ] Check wedding `allow_download` permission
- [ ] Centralize permission checks in a shared download policy/service
- [ ] Always download the gallery-managed original JPEG asset, never a preview/thumbnail variant
- [ ] Generate signed URL via `Storage::Service.presigned_download_url` with `filename:` param
- [ ] Return signed URL in JSON response (frontend can redirect)
- [ ] Include URL expiry metadata for client UX
- [ ] Log download event or record audit metadata for future reporting

**Acceptance:** Downloads respect permission settings. Provider-agnostic signed URL generated from the gallery original JPEG. Single-download endpoint stays synchronous and lightweight.

---

### DL-2: Build bulk download (ZIP) job
**Priority:** High | **Estimate:** 3 points

`POST /api/v1/g/.../downloads`

```json
{ "type": "ceremony", "ceremony_id": "uuid" }
// or
{ "type": "shortlist", "shortlist_id": "uuid" }
// or
{ "type": "full_gallery" }
```

- [ ] Create `downloads` table to track request status
- [ ] Store scope (`ceremony`, `shortlist`, `full_gallery`) and request owner (`gallery_session`)
- [ ] Enqueue `ZipGenerationJob`
- [ ] Create a shared scope resolver/service used by both single and bulk downloads
- [ ] Job: download original JPEGs via `Storage::Service.download_to_tempfile` → create ZIP in tmp → upload ZIP via `Storage::Service.upload_file` → generate signed URL
- [ ] Status polling endpoint: `GET /api/v1/g/.../downloads/:id`
- [ ] ZIP expires after 24 hours (cleanup job deletes from storage)
- [ ] Limit: check download permission per wedding settings
- [ ] Use a dedicated downloads queue
- [ ] Reject or fail cleanly if archive exceeds first-pass size limit; multi-ZIP chunking can follow later

**Acceptance:** Request ZIP → job processes → poll status → download via provider-agnostic signed URL.

**Scope Notes**
- Single photo download and bulk archive download must share the same permission policy.
- Guest downloads should always return the gallery-managed original JPEG, not preview or thumbnail derivatives.
- First pass should support ceremony, shortlist, and full-gallery scopes without introducing multi-part ZIP orchestration.
- Multi-ZIP chunking is deferred until real archive sizes justify it.

---

## Epic 10: Comments

### COMMENT-1: Create comments table and endpoints
**Priority:** Medium | **Estimate:** 1 point

```ruby
create_table :comments, id: :uuid do |t|
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.references :gallery_session, type: :uuid, foreign_key: true, null: false
  t.string :visitor_name_snapshot
  t.text :body, null: false
  t.timestamps
end

add_column :photos, :comments_count, :integer, default: 0, null: false
```

**`POST /api/v1/g/.../photos/:photo_id/comments`**
**`GET /api/v1/g/.../photos/:photo_id/comments`**
**`DELETE /api/v1/g/.../comments/:id`** (own comments only)

- [ ] Check `allow_comments` on wedding
- [ ] Limit comment length (500 chars)
- [ ] Strip blank/whitespace-only comments
- [ ] Snapshot visitor name into the comment record for stable display/reporting
- [ ] Add basic per-session or per-IP comment rate limiting to reduce spam
- [ ] Return newest-first ordering for photo comments
- [ ] Add pagination for photo comments and photographer review
- [ ] Extend gallery photo responses with `comment_count`
- [ ] Photographer view: `GET /api/v1/weddings/:slug/comments` (all comments across wedding, paginated)
- [ ] Include enough studio-side context in photographer view:
  - comment id
  - visitor name
  - body
  - photo id
  - ceremony slug/name
  - created_at
- [ ] Keep public gallery comment CRUD separate from studio-side review controller/actions

**Acceptance:** Comments create/list/delete. Respect permission and anti-spam rules. Public responses expose stable visitor name and photo-level comment counts. Photographer can review wedding comments with pagination and ceremony/photo context.

**Scope Notes**
- First pass supports only top-level comments on photos; threaded replies are out of scope.
- First pass can hard-delete user-owned comments rather than soft-delete/moderate.
- Comment permissions must still respect gallery session scope and wedding `allow_comments`.

---

## Epic 11: Gallery Expiry & Housekeeping

### EXPIRY-1: Build gallery expiry cron job
**Priority:** High | **Estimate:** 1 point

`GalleryExpiryJob` — runs daily via Solid Queue recurring schedule.

- [ ] Find weddings where `expires_at < Time.current AND is_active = true`
- [ ] Mark wedding as expired by deactivating public access
- [ ] Invalidate all gallery sessions in bulk
- [ ] Make the job idempotent so reruns are safe
- [ ] Keep this job focused on access expiry only, not storage deletion
- [ ] Send notification to photographer (optional, Phase 2)

**Acceptance:** Expired galleries deactivate automatically. Sessions are invalidated. Re-running the job does not change already-expired weddings.

---

### EXPIRY-2: Build storage cleanup cron job
**Priority:** Medium | **Estimate:** 1 point

`WeddingArchiveCleanupJob` — runs weekly.

- [ ] Find weddings where `is_active = false AND expires_at < 30.days.ago`
- [ ] Use `Storage::Service.list(prefix:)` with `Storage::KeyBuilder.wedding_prefix` to find all objects
- [ ] Use `Storage::Service.delete_batch(keys:)` to bulk delete — provider-agnostic
- [ ] Delete all photo/ceremony records (cascade)
- [ ] Mark wedding as archived (or set `archived_at`) so reruns skip it
- [ ] Keep the existing `StorageCleanupJob` as the low-level utility for deleting explicit key lists; do not overload it with recurring wedding archival behavior
- [ ] Make archive cleanup idempotent and safe to retry if storage deletion partially fails
- [ ] Log storage reclaimed

**Acceptance:** Old expired galleries are cleaned from any configured storage provider automatically. Already-archived weddings are skipped on reruns.

**Scope Notes**
- Expiry and archival are separate lifecycle steps:
  - expiry removes access
  - archival removes old data later
- Prefer an explicit archived marker (`archived_at` or status) over inferring everything from `is_active`
- First pass does not need outbound notifications or storage usage billing math

---

## Epic 12: Family Share Links

### SHARE-1: Create share_links table and endpoints
**Priority:** Medium | **Estimate:** 2 points

```ruby
create_table :share_links, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.references :created_by, type: :uuid, foreign_key: { to_table: :gallery_sessions }
  t.string :token_digest, null: false
  t.string :permissions, default: "view"  # view | view_like | view_download
  t.string :label  # "For Mom & Dad"
  t.datetime :expires_at
  t.datetime :revoked_at
  t.timestamps
end

add_index :share_links, :token_digest, unique: true
```

**`POST /api/v1/g/.../share`**
```json
{ "label": "For Mom & Dad", "permissions": "view_like" }
```

**`GET /api/v1/g/shared/:token`** — public, no password needed
- Returns gallery data (same as GALLERY-1 response)
- Creates restricted gallery session with limited permissions

- [ ] Store only token digests, never raw share tokens
- [ ] Shared links bypass password but respect permission level
- [ ] Redeeming a share link must create a restricted gallery session
- [ ] Restricted sessions must carry share-link permissions explicitly
- [ ] Like/download endpoints must honor both:
  - wedding-level settings
  - share-link permission level
- [ ] Shared link can be scoped to specific ceremonies later; defer in first pass
- [ ] Expiry defaults to wedding expiry
- [ ] Support revocation via `revoked_at`

**Acceptance:** Family member opens shared link → sees gallery (no password) → restricted session is created → permissions are enforced consistently across later endpoints.

**Scope Notes**
- First pass is whole-gallery only; ceremony-scoped share links are deferred.
- `view_like` allows likes/shortlists/comments only if the wedding itself allows them.
- `view_download` still must respect wedding `allow_download`; it does not bypass wedding policy.
- Share-link sessions should be auditable and revocable just like password-created sessions.

---

## Epic 13: Albums & Private Sharing

### ALBUM-1: Create albums table and model
**Priority:** Medium | **Estimate:** 2 points

Albums are curated photo collections within a ceremony. There are two album types:
- `studio_curated` — official albums created by the studio
- `user_created` — personal albums created by a gallery user/session

Albums are distinct from shortlists and distinct from full-gallery share links.

```ruby
create_table :albums, id: :uuid do |t|
  t.references :ceremony, type: :uuid, foreign_key: true, null: false
  t.references :created_by_studio, type: :uuid, foreign_key: { to_table: :studios }
  t.references :created_by_gallery_session, type: :uuid, foreign_key: { to_table: :gallery_sessions }
  t.string :album_type, null: false  # studio_curated | user_created
  t.string :name, null: false
  t.string :slug, null: false
  t.text :description
  t.references :cover_photo, type: :uuid, foreign_key: { to_table: :photos }
  t.string :visibility, default: "private", null: false  # private | shared
  t.timestamps
end

add_index :albums, [:ceremony_id, :slug], unique: true
```

- [ ] Add `Album` model with slug generation scoped to ceremony
- [ ] Require exactly one creator path:
  - studio albums use `created_by_studio_id`
  - user albums use `created_by_gallery_session_id`
- [ ] Keep albums independent from visitor shortlists
- [ ] Validate cover photo belongs to the same ceremony
- [ ] Validate `album_type` matches the creator type

**Acceptance:** Both studio-curated albums and user-created albums can exist under a ceremony with clear ownership rules.

---

### ALBUM-2: Create album_photos join table
**Priority:** Medium | **Estimate:** 1 point

```ruby
create_table :album_photos, id: :uuid do |t|
  t.references :album, type: :uuid, foreign_key: true, null: false
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.integer :sort_order, default: 0, null: false
  t.timestamps
end

add_index :album_photos, [:album_id, :photo_id], unique: true
add_index :album_photos, [:album_id, :sort_order]
```

- [ ] Add `AlbumPhoto` model
- [ ] Validate photo belongs to album ceremony
- [ ] Support stable manual ordering
- [ ] Prevent duplicate photo membership per album

**Acceptance:** Both studio-curated and user-created albums can contain ordered photos from exactly one ceremony.

---

### ALBUM-3: Build studio-curated album management APIs
**Priority:** High | **Estimate:** 2 points

**`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums`**
```json
{
  "album": {
    "name": "Bride's Family Favorites",
    "description": "Curated photos for close family",
    "album_type": "studio_curated"
  }
}
```

**`GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums`**
**`GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**
**`PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**
**`DELETE /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**

- [ ] Add album CRUD for authenticated studios
- [ ] Restrict this route family to `studio_curated` albums
- [ ] Return cover photo and photo counts
- [ ] Keep album routes nested under ceremony
- [ ] Soft-delete is optional; hard delete is acceptable in first pass

**Acceptance:** Studios can create, edit, list, and delete official curated albums for a ceremony.

---

### ALBUM-4: Build user-created album APIs
**Priority:** High | **Estimate:** 2 points

**`POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums`**
```json
{
  "album": {
    "name": "Our Family Picks",
    "description": "Photos we want to share",
    "album_type": "user_created"
  }
}
```

**`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums`**
**`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**
**`PATCH /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**
**`DELETE /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug`**

- [ ] Require active gallery session auth
- [ ] Only expose `user_created` albums owned by the current gallery session
- [ ] Keep user albums private by default
- [ ] Ensure session can only create albums inside the current ceremony

**Acceptance:** A gallery user can create and manage their own ceremony-scoped album without seeing other users’ private albums.

---

### ALBUM-5: Build album photo curation APIs
**Priority:** High | **Estimate:** 2 points

**Studio**
- `POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos`
- `DELETE /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos/:photo_id`
- `PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/reorder`
- `POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/cover`

**Gallery user**
- `POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos`
- `DELETE /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos/:photo_id`
- `PATCH /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/reorder`
- `POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/cover`

- [ ] Add/remove photos from album
- [ ] Reorder album photos
- [ ] Set album cover from one of the album photos
- [ ] Validate all curated photos belong to the same ceremony
- [ ] Enforce ownership:
  - studio can manage `studio_curated`
  - album owner session can manage `user_created`

**Acceptance:** Album contents and order can be curated without affecting the main ceremony/gallery ordering, with ownership enforced correctly.

---

### ALBUM-6: Create album_share_links table and endpoints
**Priority:** High | **Estimate:** 2 points

Album sharing is separate from whole-gallery sharing. Shared album access should only reveal album photos.

```ruby
create_table :album_share_links, id: :uuid do |t|
  t.references :album, type: :uuid, foreign_key: true, null: false
  t.references :created_by_studio, type: :uuid, foreign_key: { to_table: :studios }
  t.references :created_by_gallery_session, type: :uuid, foreign_key: { to_table: :gallery_sessions }
  t.string :token_digest, null: false
  t.string :permissions, default: "view", null: false  # view | view_like | view_download
  t.string :label
  t.datetime :expires_at
  t.timestamps
end

add_index :album_share_links, :token_digest, unique: true
```

**Studio-created album share link**
`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/share_links`

**User-created album share link**
`POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/share_links`

```json
{
  "label": "For Mom & Dad",
  "permissions": "view_download"
}
```

**`GET /api/v1/g/albums/shared/:token`**

- [ ] Store token digests, not raw tokens
- [ ] Create album-scoped viewer session on access
- [ ] Enforce permissions independently from whole-gallery links
- [ ] Default expiry to wedding expiry unless overridden
- [ ] Ensure share-link creator matches album owner type
- [ ] Do not expose photos outside the album

**Acceptance:** A studio can create a private album link that opens only that album for the recipient.

---

### ALBUM-7: Build public album viewing endpoints
**Priority:** High | **Estimate:** 2 points

**`GET /api/v1/g/albums/:token`**
**`GET /api/v1/g/albums/:token/photos`**

- [ ] Return album shell and paginated album photos
- [ ] Scope all access to the album only
- [ ] Reuse gallery photo presenters where possible
- [ ] Ensure likes/downloads respect both wedding settings and album-link permissions

**Acceptance:** Recipient opens an album link and can browse only the curated album photos with the granted permissions.

---

### Notes on Scope for Epic 13
- Albums are a content model; share links are an access model.
- Do not overload shortlist tables to act as albums.
- Whole-gallery share links remain Epic 12; album sharing is narrower and must stay album-scoped.
- Albums belong to a ceremony, not directly to a wedding.
- There are two supported album types: `studio_curated` and `user_created`.
- `studio_curated` albums are official and managed by studio auth.
- `user_created` albums are private by default and managed only by the creating gallery session.
- First pass should use private link-based access, not recipient email/phone invite workflows.
- Recipient-specific invite lists or OTP verification can be a later enhancement if needed.

---

## Epic 14: Deployment & DevOps

### DEPLOY-1: Set up production deployment
**Priority:** High | **Estimate:** 2 points

- [ ] Set up Railway / Render for Rails app
- [ ] Configure production Postgres (Railway managed or Neon)
- [ ] Set storage environment variables (`STORAGE_PROVIDER`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`, `STORAGE_BUCKET`, `STORAGE_ENDPOINT`, `STORAGE_PUBLIC_URL`, etc.)
- [ ] Set auth environment variables (`JWT_SECRET`)
- [ ] Set Imgproxy environment variables (`IMGPROXY_URL`, `IMGPROXY_KEY`, `IMGPROXY_SALT`)
- [ ] Configure Solid Queue worker process
- [ ] Set up production R2 bucket (separate from dev)
- [ ] Configure CORS for production frontend domain
- [ ] Set up health check endpoint
- [ ] SSL + custom domain for API

**Acceptance:** `api.yourdomain.com/health` returns 200 in production.

---

### DEPLOY-2: Set up CI/CD
**Priority:** Medium | **Estimate:** 1 point

- [ ] GitHub Actions workflow: run RSpec on push
- [ ] Auto-deploy to Railway/Render on merge to `main`
- [ ] Run `db:migrate` on deploy
- [ ] Rubocop lint check in CI

**Acceptance:** Push to main → tests run → auto-deploy.

---

### DEPLOY-3: Set up monitoring and error tracking
**Priority:** Medium | **Estimate:** 1 point

- [ ] Add Sentry for error tracking
- [ ] Add basic request logging (request ID, duration, status)
- [ ] Add background job monitoring (Solid Queue dashboard or Mission Control)
- [ ] Set up uptime monitoring (free tier: UptimeRobot or similar)

**Acceptance:** Errors captured in Sentry. Job failures visible.

---

## Summary: Sprint Plan

| Sprint | Epics | Duration |
|--------|-------|----------|
| **Sprint 1** | Epic 1 (Setup) + Epic 2 (Auth) | Week 1 |
| **Sprint 2** | Epic 3 (Branding) + Epic 4 (Weddings) | Week 2 |
| **Sprint 3** | Epic 5 (Ceremonies) + Epic 6 (Photos 1-4) | Week 3 |
| **Sprint 4** | Epic 6 (Photos 5-7) + Epic 7 (Gallery Public) | Week 4 |
| **Sprint 5** | Epic 8 (Likes + Shortlists) | Week 5 |
| **Sprint 6** | Epic 9 (Downloads) + Epic 10 (Comments) | Week 6 |
| **Sprint 7** | Epic 11 (Expiry) + Epic 12 (Share Links) | Week 7 |
| **Sprint 8** | Epic 13 (Albums) + Epic 14 (Deploy) | Week 8 |
| **Sprint 9** | Polish + Bug Fixes | Week 9 |

**Total: ~51 tasks · ~59 story points · 9 weeks**

---

*Each task is independently shippable. Work top-to-bottom within each epic. Don't skip ahead to later epics before the current one is solid.*
