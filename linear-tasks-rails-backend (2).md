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

## Epic 6: Photo Upload & Processing

### PHOTO-1: Create photos table and model
**Priority:** Urgent | **Estimate:** 1 point

```ruby
create_table :photos, id: :uuid do |t|
  t.references :ceremony, type: :uuid, foreign_key: true, null: false
  t.references :wedding, type: :uuid, foreign_key: true, null: false  # denormalized

  # Storage keys (provider-agnostic, NOT full URLs)
  t.string :original_key, null: false        # studios/{sid}/weddings/{wid}/originals/{pid}.jpg
  t.string :thumbnail_key                    # studios/{sid}/weddings/{wid}/thumbnails/{pid}.webp

  # Blur placeholder (tiny ~200 bytes, stored inline in DB — NOT in storage)
  t.text :blur_data_uri                      # "data:image/webp;base64,UklGR..."

  # Image dimensions (extracted from original on upload)
  t.integer :width, null: false, default: 0
  t.integer :height, null: false, default: 0
  # aspect_ratio as generated column: width::decimal / height::decimal

  # File metadata
  t.bigint :file_size_bytes, null: false, default: 0
  t.string :mime_type, null: false, default: 'image/jpeg'
  t.string :original_filename

  # EXIF (camera info, date taken, GPS)
  t.jsonb :exif_data, default: {}

  # Ordering & display
  t.integer :sort_order, null: false, default: 0
  t.boolean :is_cover, default: false

  # Processing state: uploading → processing → ready → failed
  t.string :status, null: false, default: 'uploading'
  t.string :status_error

  t.timestamps
end

# Add generated column for aspect_ratio
execute <<-SQL
  ALTER TABLE photos ADD COLUMN aspect_ratio DECIMAL(5,3)
    GENERATED ALWAYS AS (
      CASE WHEN height > 0 THEN ROUND(width::decimal / height::decimal, 3) ELSE 0 END
    ) STORED;
SQL
```

- [ ] Store provider-agnostic R2/B2/S3 object keys (NOT full URLs)
- [ ] `blur_data_uri` stored inline in Postgres (~200 bytes per photo, eliminates HTTP request)
- [ ] `aspect_ratio` as generated column — frontend needs this for masonry grid before images load
- [ ] `status` state machine: `uploading → processing → ready` (or `→ failed`)
- [ ] Only 2 stored variants: original + thumbnail (preview/full via Imgproxy on demand)

```ruby
# Indexes
add_index :photos, [:ceremony_id, :sort_order], where: "status = 'ready'"
add_index :photos, [:wedding_id, :created_at], where: "status = 'ready'"
add_index :photos, [:status, :created_at], where: "status IN ('uploading', 'processing')"
add_index :photos, :ceremony_id, where: "is_cover = true"
```

- [ ] Model: `belongs_to :ceremony`, `belongs_to :wedding`
- [ ] Denormalized `wedding_id` for fast full-wedding queries
- [ ] Validations: status inclusion, mime_type format

**Acceptance:** Photo records create with proper references. Aspect ratio auto-calculates. Partial indexes work.

---

### PHOTO-2: Build presigned URL generation for direct upload
**Priority:** Urgent | **Estimate:** 2 points

`POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/presign`

```json
// Request
{
  "files": [
    { "filename": "DSC_0012.jpg", "content_type": "image/jpeg", "byte_size": 4500000 },
    { "filename": "DSC_0013.jpg", "content_type": "image/jpeg", "byte_size": 3800000 }
  ]
}

// Response
{
  "data": [
    {
      "photo_id": "uuid-1",
      "presigned_url": "https://provider-url...",
      "object_key": "studios/abc/weddings/def/originals/uuid-1.jpg",
      "headers": { "Content-Type": "image/jpeg" }
    }
  ]
}
```

- [ ] Use `Storage::KeyBuilder.original(...)` to generate provider-agnostic keys
- [ ] Use `Storage::Service.presigned_upload_url(...)` — works with any S3-compatible provider
- [ ] Create `Photo` record with `status: "uploading"`
- [ ] Validate file types (jpg, jpeg, png, webp, heic)
- [ ] Validate file size (< 30MB per file)
- [ ] Batch: accept up to 50 files per request
- [ ] Return presigned URLs + photo IDs so frontend can upload directly to storage

**Acceptance:** Frontend can use presigned URLs to PUT files directly to whichever provider is configured. Photo records created in uploading state.

---

### PHOTO-3: Build upload confirmation endpoint
**Priority:** Urgent | **Estimate:** 1 point

`POST /api/v1/photos/:id/confirm`

After frontend uploads to storage using presigned URL, it calls this to trigger processing.

- [ ] Use `Storage::Service.exists?(key:)` to verify the object exists in storage
- [ ] Update `status` to `"processing"`
- [ ] Enqueue `PhotoProcessingJob`
- [ ] Return photo record

**Acceptance:** Confirm triggers background processing. Invalid confirmations rejected.

---

### PHOTO-4: Build PhotoProcessingJob (thumbnail + blur only)
**Priority:** Urgent | **Estimate:** 3 points

Simplified pipeline — only generates thumbnail and blur placeholder. Preview/full handled by Imgproxy on demand.

```ruby
class PhotoProcessingJob < ApplicationJob
  queue_as :images
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.update!(status: "processing")

    # Download from whichever provider is configured
    tempfile = Storage::Service.download_to_tempfile(key: photo.original_key)

    # Process with ruby-vips
    image = Vips::Image.new_from_file(tempfile.path)

    # Generate thumbnail (300px wide, WebP, quality 60)
    thumb = image.thumbnail_image(300)
    thumb_buf = thumb.webpsave_buffer(Q: 60)

    # Generate blur placeholder (20px wide, base64 — stored in DB)
    blur = image.thumbnail_image(20)
    blur_buf = blur.webpsave_buffer(Q: 30)
    blur_data_uri = "data:image/webp;base64,#{Base64.strict_encode64(blur_buf)}"

    # Upload thumbnail via Storage::Service
    thumb_key = Storage::KeyBuilder.thumbnail(
      studio_id: photo.wedding.studio_id,
      wedding_id: photo.wedding_id,
      photo_id: photo.id
    )
    Storage::Service.upload(key: thumb_key, body: thumb_buf, content_type: "image/webp")

    # Extract EXIF metadata
    exif = extract_exif(tempfile.path)

    # Update photo record
    photo.update!(
      thumbnail_key: thumb_key,
      blur_data_uri: blur_data_uri,
      width: image.width,
      height: image.height,
      file_size_bytes: File.size(tempfile.path),
      exif_data: exif,
      status: "ready"
    )

    # Update counters
    Ceremony.increment_counter(:photo_count, photo.ceremony_id)
    Wedding.increment_counter(:total_photos, photo.wedding_id)

  rescue => e
    photo&.update!(status: "failed", status_error: e.message)
    raise  # re-raise for retry
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
```

- [ ] Download original via `Storage::Service.download_to_tempfile` (provider-agnostic)
- [ ] Generate thumbnail (300px wide, WebP, quality 60) — ~15KB each
- [ ] Generate blur placeholder (20px wide, base64) — ~200 bytes, stored in DB
- [ ] Upload thumbnail via `Storage::Service.upload` (provider-agnostic)
- [ ] Extract EXIF data (camera, lens, date, GPS)
- [ ] Extract width/height for aspect_ratio
- [ ] Update photo record: `thumbnail_key`, `blur_data_uri`, dimensions, status → `"ready"`
- [ ] Increment ceremony `photo_count` and wedding `total_photos`
- [ ] Handle failures: set status → `"failed"` with error message, retry up to 3 times
- [ ] Clean up tempfiles in `ensure` block

**Processing time per photo: ~1-2 seconds** (only thumbnail + blur, not 9 variants).
**For 3,000 photos with 3 workers: ~17 minutes.**

**Acceptance:** Upload an image → job processes → thumbnail + blur stored → photo record fully populated with status "ready".

---

### PHOTO-5: Set up Imgproxy for on-demand image resizing
**Priority:** High | **Estimate:** 2 points

Imgproxy generates preview (1200px) and full (2400px) variants on demand from the original. CDN caches the result.

- [ ] Deploy Imgproxy on Railway ($5/mo Docker container)
- [ ] Configure Imgproxy to fetch from `STORAGE_PUBLIC_URL` (works with any provider)
- [ ] Set `IMGPROXY_KEY` and `IMGPROXY_SALT` for signed URLs (prevent tampering)
- [ ] Configure AVIF + WebP + JPEG format support
- [ ] Put Cloudflare CDN in front for caching (30-day cache TTL)
- [ ] Create `ImgproxyService` in Rails:

```ruby
class ImgproxyService
  PRESETS = {
    preview:      { width: 1200, quality: 75, format: "webp" },
    full:         { width: 2400, quality: 85, format: "webp" },
    avif_preview: { width: 1200, quality: 60, format: "avif" },
    avif_full:    { width: 2400, quality: 70, format: "avif" },
  }.freeze

  def self.url_for(source_url, width:, quality:, format:)
    path = "/rs:fit:#{width}/q:#{quality}/#{encode(source_url)}.#{format}"
    signature = sign(path)
    "#{ENV['IMGPROXY_URL']}/#{signature}#{path}"
  end
end
```

- [ ] Verify first request generates image, second request serves from CDN cache
- [ ] Test with originals stored on R2, B2, and MinIO — Imgproxy fetches via `STORAGE_PUBLIC_URL`

**Acceptance:** Imgproxy resizes originals on demand. Changing storage provider only requires updating `STORAGE_PUBLIC_URL`.

---

### PHOTO-6: Build PhotoUrlBuilder service
**Priority:** High | **Estimate:** 1 point

Centralizes URL generation for all photo variants. Used by gallery API endpoints.

```ruby
class PhotoUrlBuilder
  def initialize(photo)
    @photo = photo
  end

  def urls
    {
      blur: @photo.blur_data_uri,
      thumbnail: Storage::Service.presigned_download_url(key: @photo.thumbnail_key, expires_in: 1.hour.to_i),
      preview: imgproxy_url(:preview),
      full: imgproxy_url(:full),
      avif_preview: imgproxy_url(:avif_preview),
      avif_full: imgproxy_url(:avif_full),
      download: Storage::Service.presigned_download_url(key: @photo.original_key, expires_in: 1.hour.to_i, filename: @photo.original_filename)
    }
  end

  private

  def imgproxy_url(preset)
    source = Storage::Service.public_url(key: @photo.original_key)
    preset_config = ImgproxyService::PRESETS[preset]
    ImgproxyService.url_for(source, **preset_config)
  end
end
```

- [ ] Thumbnail URL: signed download URL from storage provider
- [ ] Preview/full URLs: signed Imgproxy URLs (fetches from `STORAGE_PUBLIC_URL`)
- [ ] Download URL: signed URL to original with `Content-Disposition: attachment`
- [ ] All URLs are provider-agnostic — switching provider changes nothing in this service

**Acceptance:** Returns all 7 URL variants for any photo. Works regardless of storage provider.

---

### PHOTO-7: Build photo listing endpoint (paginated)
**Priority:** Urgent | **Estimate:** 1 point

`GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos`

Uses cursor-based pagination (not offset) for infinite scroll.

Response per photo:
```json
{
  "id": "uuid",
  "urls": {
    "blur": "data:image/webp;base64,...",
    "thumbnail": "https://signed-url...",
    "preview": "https://imgproxy-signed...",
    "full": "https://imgproxy-signed...",
    "avif_preview": "https://imgproxy-signed...",
    "avif_full": "https://imgproxy-signed..."
  },
  "width": 5472,
  "height": 3648,
  "aspect_ratio": 1.500,
  "sort_order": 1,
  "is_cover": false,
  "is_liked": false,
  "is_shortlisted": false,
  "comment_count": 0
}
```

- [ ] Use `PhotoUrlBuilder` to generate all URL variants
- [ ] Cursor-based pagination using `sort_order` as cursor
- [ ] Only return photos with `status = 'ready'`
- [ ] Include like/shortlist status for current session (gallery endpoints)
- [ ] Include comment count per photo

**Acceptance:** Returns paginated photos with all URL variants. Works with any storage provider.

---

### PHOTO-8: Build photo management endpoints
**Priority:** High | **Estimate:** 1 point

**`DELETE /api/v1/photos/:id`**
- Delete record + enqueue storage cleanup job

**`PATCH /api/v1/photos/:id`**
- Update `sort_order`, `is_cover`

**`PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/reorder`**
```json
{ "order": ["photo-uuid-1", "photo-uuid-3", "photo-uuid-2"] }
```

**`POST /api/v1/photos/:id/set_cover`**
- Unset current cover, set this as cover

- [ ] On delete: collect `[original_key, thumbnail_key]` and enqueue cleanup
- [ ] Bulk reorder accepts array of photo UUIDs
- [ ] Cover photo: only one per ceremony

**Acceptance:** Delete removes record + enqueues storage cleanup. Reorder persists. Cover toggles correctly.

---

### PHOTO-9: Build storage cleanup job
**Priority:** Medium | **Estimate:** 1 point

`StorageCleanupJob` — runs when photos/ceremonies/weddings are deleted.

- [ ] Accept list of storage keys to delete
- [ ] Use `Storage::Service.delete_batch(keys:)` — provider-agnostic batch delete
- [ ] Log deletions for audit
- [ ] Handle missing keys gracefully (already deleted = no error)

**Acceptance:** Deleted photos are cleaned from storage within minutes. Works on any provider.

---

### PHOTO-10: Build upload batch tracking
**Priority:** Medium | **Estimate:** 1 point

```ruby
create_table :upload_batches, id: :uuid do |t|
  t.references :ceremony, type: :uuid, foreign_key: true, null: false
  t.references :studio, type: :uuid, foreign_key: true, null: false
  t.integer :total_files, null: false, default: 0
  t.integer :completed_files, null: false, default: 0
  t.integer :failed_files, null: false, default: 0
  t.string :status, null: false, default: 'in_progress'  # in_progress | completed | partial
  t.timestamps
end
```

- [ ] Create batch on presign request, track progress
- [ ] Update counters as photos complete/fail processing
- [ ] Mark batch as `completed` when all photos done
- [ ] Photographer dashboard shows: "Uploading 342 photos to Haldi... 280/342 complete"

**Acceptance:** Batch progress trackable. Status updates as photos process.

---

## Epic 7: Gallery Public Access (Client-Facing)

### GALLERY-1: Build gallery password verification endpoint
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
      "ceremonies": [ { "name": "Haldi", "slug": "haldi", "cover_url": "...", "photo_count": 342 } ],
      "allow_download": "shortlist",
      "allow_comments": true
    }
  }
}
```

- [ ] Find wedding by studio_slug + wedding_slug combo
- [ ] Check `is_active` and `expires_at` — return 410 (Gone) if expired
- [ ] Verify password against `password_hash`
- [ ] Create `GallerySessions` record with secure random token
- [ ] Return session token + full gallery metadata in one shot
- [ ] Include studio branding (colors, fonts, logo) so frontend can theme immediately

**Acceptance:** Correct password returns session + gallery data. Wrong password returns 401. Expired gallery returns 410.

---

### GALLERY-2: Create gallery_sessions table
**Priority:** Urgent | **Estimate:** 0.5 points

```ruby
create_table :gallery_sessions, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.string :session_token, null: false, index: { unique: true }
  t.string :visitor_name
  t.string :role, default: "guest"  # couple | family | guest
  t.datetime :last_active_at, default: -> { "now()" }
  t.timestamps
end
```

- [ ] Token generated via `SecureRandom.urlsafe_base64(32)`
- [ ] Session expires after 24 hours of inactivity
- [ ] Touch `last_active_at` on each API call

**Acceptance:** Sessions create and expire correctly.

---

### GALLERY-3: Build gallery authentication middleware
**Priority:** Urgent | **Estimate:** 1 point

Separate from studio JWT auth — this is for gallery visitors.

- [ ] Create `authenticate_gallery_session!` method
- [ ] Extract token from `X-Gallery-Token` header
- [ ] Find session, check not expired, check wedding still active
- [ ] Set `current_session` and `current_wedding`
- [ ] Touch `last_active_at`
- [ ] Return 401 if invalid, 410 if gallery expired

**Acceptance:** Gallery endpoints reject invalid/expired sessions. `current_wedding` available.

---

### GALLERY-4: Build public ceremony listing endpoint
**Priority:** Urgent | **Estimate:** 0.5 points

`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies`

Header: `X-Gallery-Token: <session_token>`

- [ ] Return ceremonies ordered by `sort_order`
- [ ] Include cover image signed URLs, photo counts
- [ ] No authentication required beyond gallery session

**Acceptance:** Returns ceremony list for authenticated gallery session.

---

### GALLERY-5: Build public photo browsing endpoint
**Priority:** Urgent | **Estimate:** 1 point

`GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos`

- [ ] Paginated (cursor-based for infinite scroll — use `sort_order` as cursor)
- [ ] Return thumbnail + preview signed URLs + blur hash + dimensions
- [ ] Only `completed` processing status

```json
{
  "data": [
    {
      "id": "uuid",
      "thumbnail_url": "signed...",
      "preview_url": "signed...",
      "blur_hash": "base64...",
      "width": 4000,
      "height": 2667,
      "is_liked": false,
      "is_shortlisted": false,
      "comment_count": 2
    }
  ],
  "meta": { "next_cursor": "abc123", "has_more": true }
}
```

- [ ] Cursor-based pagination (not offset — better for infinite scroll)
- [ ] Include like/shortlist status for current session
- [ ] Include comment count per photo

**Acceptance:** Infinite-scroll ready endpoint with signed URLs and interaction state.

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

**`POST /api/v1/g/.../photos/:photo_id/like`** — toggle like
**`DELETE /api/v1/g/.../photos/:photo_id/like`** — unlike
**`GET /api/v1/g/.../likes`** — all liked photos for session

- [ ] Toggle pattern: like if not liked, unlike if liked
- [ ] Return liked photos list (paginated)

**Acceptance:** Like/unlike works. Duplicate likes prevented. Liked photos retrievable.

---

### SHORT-1: Create shortlists table and endpoints
**Priority:** High | **Estimate:** 2 points

```ruby
create_table :shortlists, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.references :gallery_session, type: :uuid, foreign_key: true, null: false
  t.string :name, default: "My Shortlist"
  t.boolean :is_shared, default: false
  t.string :share_token, index: { unique: true }
  t.timestamps
end

create_table :shortlist_photos, id: :uuid do |t|
  t.references :shortlist, type: :uuid, foreign_key: true, null: false
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.integer :sort_order, default: 0
  t.string :note
  t.timestamps
end
add_index :shortlist_photos, [:shortlist_id, :photo_id], unique: true
```

**`POST /api/v1/g/.../shortlist/photos`** — add photo to shortlist
```json
{ "photo_id": "uuid" }
```

**`DELETE /api/v1/g/.../shortlist/photos/:photo_id`** — remove

**`GET /api/v1/g/.../shortlist`** — view current shortlist

**`PATCH /api/v1/g/.../shortlist/reorder`** — reorder photos

**`POST /api/v1/g/.../shortlist/share`** — generate share link

- [ ] Auto-create shortlist on first add (lazy creation)
- [ ] Multi-add endpoint: accept array of photo_ids
- [ ] Share generates `share_token` and sets `is_shared: true`
- [ ] Photographer can view client shortlists (separate endpoint in studio namespace)

**Acceptance:** Add/remove photos from shortlist. Share link generates. Photographer can view.

---

### SHORT-2: Build photographer shortlist view
**Priority:** High | **Estimate:** 1 point

`GET /api/v1/weddings/:wedding_slug/shortlists`

- [ ] List all shortlists created by gallery visitors
- [ ] Include visitor name, photo count, created date
- [ ] Detail view with all shortlisted photos + notes

**Acceptance:** Photographer sees all client shortlists for a wedding.

---

## Epic 9: Downloads

### DL-1: Build single photo download endpoint
**Priority:** High | **Estimate:** 1 point

`GET /api/v1/g/.../photos/:id/download`

- [ ] Check wedding `allow_download` permission
- [ ] Generate signed URL via `Storage::Service.presigned_download_url` with `filename:` param
- [ ] Return redirect to signed URL (or return URL in JSON)
- [ ] Log download event

**Acceptance:** Downloads respect permission settings. Provider-agnostic signed URL generated.

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
- [ ] Enqueue `ZipGenerationJob`
- [ ] Job: download photos via `Storage::Service.download_to_tempfile` → create ZIP in tmp → upload ZIP via `Storage::Service.upload` → generate signed URL
- [ ] Status polling endpoint: `GET /api/v1/g/.../downloads/:id`
- [ ] ZIP expires after 24 hours (cleanup job deletes from storage)
- [ ] Limit: check download permission per wedding settings
- [ ] Full gallery ZIP may be large — chunk into multiple ZIPs if > 2GB

**Acceptance:** Request ZIP → job processes → poll status → download via provider-agnostic signed URL.

---

## Epic 10: Comments

### COMMENT-1: Create comments table and endpoints
**Priority:** Medium | **Estimate:** 1 point

```ruby
create_table :comments, id: :uuid do |t|
  t.references :photo, type: :uuid, foreign_key: true, null: false
  t.references :gallery_session, type: :uuid, foreign_key: true, null: false
  t.text :body, null: false
  t.timestamps
end
```

**`POST /api/v1/g/.../photos/:photo_id/comments`**
**`GET /api/v1/g/.../photos/:photo_id/comments`**
**`DELETE /api/v1/g/.../comments/:id`** (own comments only)

- [ ] Check `allow_comments` on wedding
- [ ] Limit comment length (500 chars)
- [ ] Include visitor name in response
- [ ] Photographer view: `GET /api/v1/weddings/:slug/comments` (all comments across wedding)

**Acceptance:** Comments create/list/delete. Respect permission. Photographer sees all.

---

## Epic 11: Gallery Expiry & Housekeeping

### EXPIRY-1: Build gallery expiry cron job
**Priority:** High | **Estimate:** 1 point

`GalleryExpiryJob` — runs daily via Solid Queue recurring schedule.

- [ ] Find weddings where `expires_at < Time.current AND is_active = true`
- [ ] Set `is_active = false`
- [ ] Invalidate all gallery sessions
- [ ] Send notification to photographer (optional, Phase 2)

**Acceptance:** Expired galleries deactivate automatically. Sessions invalidated.

---

### EXPIRY-2: Build storage cleanup cron job
**Priority:** Medium | **Estimate:** 1 point

`StorageCleanupJob` — runs weekly.

- [ ] Find weddings where `is_active = false AND expires_at < 30.days.ago`
- [ ] Use `Storage::Service.list(prefix:)` with `Storage::KeyBuilder.wedding_prefix` to find all objects
- [ ] Use `Storage::Service.delete_batch(keys:)` to bulk delete — provider-agnostic
- [ ] Delete all photo/ceremony records (cascade)
- [ ] Mark wedding as `"archived"` or delete
- [ ] Log storage reclaimed

**Acceptance:** Old expired galleries cleaned from any configured storage provider automatically.

---

## Epic 12: Family Share Links

### SHARE-1: Create share_links table and endpoints
**Priority:** Medium | **Estimate:** 2 points

```ruby
create_table :share_links, id: :uuid do |t|
  t.references :wedding, type: :uuid, foreign_key: true, null: false
  t.references :created_by, type: :uuid, foreign_key: { to_table: :gallery_sessions }
  t.string :token, null: false, index: { unique: true }
  t.string :permissions, default: "view"  # view | view_like | view_download
  t.string :label  # "For Mom & Dad"
  t.datetime :expires_at
  t.timestamps
end
```

**`POST /api/v1/g/.../share`**
```json
{ "label": "For Mom & Dad", "permissions": "view_like" }
```

**`GET /api/v1/g/shared/:token`** — public, no password needed
- Returns gallery data (same as GALLERY-1 response)
- Creates gallery session with limited permissions

- [ ] Shared links bypass password but respect permission level
- [ ] Shared link can be scoped to specific ceremonies (optional enhancement)
- [ ] Expiry defaults to wedding expiry

**Acceptance:** Family member opens shared link → sees gallery (no password) → limited permissions.

---

## Epic 13: Deployment & DevOps

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
| **Sprint 8** | Epic 13 (Deploy) + Polish + Bug Fixes | Week 8 |

**Total: ~45 tasks · ~50 story points · 8 weeks**

---

*Each task is independently shippable. Work top-to-bottom within each epic. Don't skip ahead to later epics before the current one is solid.*
