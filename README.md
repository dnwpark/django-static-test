# Django Static Tests

Test projects for Django static file handling via Vercel CDN.

## Setup

```bash
uv sync
```

## Local dev

```bash
uv run manage.py runserver
```

## Building locally

In `vercel/`:
```bash
pnpm install
pnpm build
```

In `vercel/packages/cli`:
```bash
VERCEL_USE_EXPERIMENTAL_FRAMEWORKS=1 pnpm vercel pull --yes --cwd ~/project/django-static/test/<project>
VERCEL_USE_EXPERIMENTAL_FRAMEWORKS=1 pnpm vercel build --cwd ~/project/django-static/test/<project>
```

In the test project directory:
```bash
vercel deploy --prebuilt
```

## Test Cases

CDN output files should have the same size and content as their source files. 

### 1. `no-static-strategy`

No `STATIC_ROOT`, `WHITENOISE_USE_FINDERS=False`.

- **CDN output:** none (collectstatic skipped)
- **Lambda bundle:** source static dirs included (not excluded — no static strategy configured)
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: / }` (catch-all to `index.func`, added by CLI defaultRoutes)

### 2. `standard-app-static`

`StaticFilesStorage` with `STATIC_ROOT`, app static dirs.

- **CDN output:** `static/app/style.css`
- **Lambda bundle:** app static dirs and `STATIC_ROOT` excluded
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 3. `standard-staticfiles-dirs`

`StaticFilesStorage` with `STATIC_ROOT` and `STATICFILES_DIRS`.

- **CDN output:** `static/style.css`
- **Lambda bundle:** `STATICFILES_DIRS` and `STATIC_ROOT` excluded
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 4. `manifest-app-static`

`ManifestStaticFilesStorage` with `STATIC_ROOT`, app static dirs.

- **CDN output:** original + hashed CSS, `staticfiles.json`
- **Lambda bundle:** app static dirs and `STATIC_ROOT` excluded except `staticfiles/staticfiles.json` re-injected
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 5. `manifest-staticfiles-dirs`

`ManifestStaticFilesStorage` with `STATIC_ROOT` and `STATICFILES_DIRS`.

- **CDN output:** original + hashed CSS, `staticfiles.json`
- **Lambda bundle:** `STATICFILES_DIRS` and `STATIC_ROOT` excluded except `staticfiles/staticfiles.json` re-injected
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 6. `whitenoise-with-static-root-app-static`

`WHITENOISE_USE_FINDERS=True` with `STATIC_ROOT`, app static dirs.

- **CDN output:** `static/app/style.css`
- **Lambda bundle:** app static dirs and `STATIC_ROOT` excluded
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 7. `whitenoise-with-static-root-staticfiles-dirs`

`WHITENOISE_USE_FINDERS=True` with `STATIC_ROOT` and `STATICFILES_DIRS`.

- **CDN output:** `static/style.css`
- **Lambda bundle:** `STATICFILES_DIRS` and `STATIC_ROOT` excluded
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 8. `whitenoise-empty-static-root-app-static`

`WHITENOISE_USE_FINDERS=True`, no `STATIC_ROOT`, app static dirs.

- **CDN output:** `static/app/style.css`
- **Lambda bundle:** app static dirs excluded, no `STATIC_ROOT` to exclude
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 9. `whitenoise-empty-static-root-staticfiles-dirs`

`WHITENOISE_USE_FINDERS=True`, no `STATIC_ROOT`, `STATICFILES_DIRS`.

- **CDN output:** `static/style.css`
- **Lambda bundle:** `STATICFILES_DIRS` excluded, no `STATIC_ROOT` to exclude
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 10. `whitenoise-manifest-with-static-root-app-static`

`CompressedManifestStaticFilesStorage` with `STATIC_ROOT`, app static dirs.

- **CDN output:** original + hashed CSS, `staticfiles.json`
- **Lambda bundle:** app static dirs and `STATIC_ROOT` excluded except `staticfiles/staticfiles.json` re-injected
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 11. `whitenoise-manifest-with-static-root-staticfiles-dirs`

`CompressedManifestStaticFilesStorage` with `STATIC_ROOT` and `STATICFILES_DIRS`.

- **CDN output:** original + hashed CSS, `staticfiles.json`
- **Lambda bundle:** `STATICFILES_DIRS` and `STATIC_ROOT` excluded except `staticfiles/staticfiles.json` re-injected
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: /app/wsgi }` (catch-all to detected entrypoint, returned by builder)

### 12. `django-storages`

`django-storages` S3 backend.

- **CDN output:** none (files uploaded to S3 directly)
- **Lambda bundle:** source static dirs and `STATIC_ROOT` excluded
- **Routes:** `{ handle: filesystem }`, `{ src: /(.*), dest: / }` (catch-all to `index.func`, added by CLI defaultRoutes)

#### S3 setup

1. Create an S3 bucket (e.g. `django-storages-test`) in your preferred region.
2. Create an IAM user with an inline policy granting `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, and `s3:ListBucket` on the bucket:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::django-storages-test",
           "arn:aws:s3:::django-storages-test/*"
         ]
       }
     ]
   }
   ```
3. Generate an access key for the user and note the key ID and secret.

#### Vercel project setup

Add the following environment variables to the Vercel project (Settings → Environment Variables):

| Variable | Example value |
|----------|---------------|
| `AWS_STORAGE_BUCKET_NAME` | `django-storages-test` |
| `AWS_S3_REGION_NAME` | `us-east-2` |
| `AWS_ACCESS_KEY_ID` | `...` |
| `AWS_SECRET_ACCESS_KEY` | `...` |

During `vercel build`, collectstatic runs with these env vars and uploads files directly to S3. No static files are written to `.vercel/output/static/`.
