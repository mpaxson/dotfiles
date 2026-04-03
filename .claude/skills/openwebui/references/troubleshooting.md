# Troubleshooting Reference

## Connection Errors

### Ollama Connection
| Issue | Fix |
|-------|-----|
| Can't reach Ollama | Set `OLLAMA_HOST=0.0.0.0` on Ollama server |
| Docker can't reach host Ollama | Use `http://host.docker.internal:11434` |
| 502 Bad Gateway | Use internal URLs, not localhost from backend |
| Podman on macOS | Use `http://host.containers.internal:11434` |

### Model List Loading
| Issue | Fix |
|-------|-----|
| Infinite spinner | `AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST=3` |
| 500 error on /api/models | Remove unreachable endpoints in Admin > Connections |
| Config corruption | `RESET_CONFIG_ON_START=true` + `ENABLE_PERSISTENT_CONFIG=false` |

---

## HTTPS / TLS / CORS

### Required Settings for HTTPS
```bash
WEBUI_URL=https://your-domain.com
CORS_ALLOW_ORIGIN="https://yourdomain.com;http://localhost:3000"
WEBUI_SESSION_COOKIE_SECURE=true
WEBUI_AUTH_COOKIE_SECURE=true
WEBUI_SESSION_COOKIE_SAME_SITE=lax
```

### Garbled Markdown / Streaming Issues
**Cause**: Nginx proxy buffering breaks SSE stream.
**Fix**: Add `proxy_buffering off; proxy_cache off;` to nginx config.

### SSL Certificate Issues (Internal Tools)
```bash
REQUESTS_VERIFY=false              # Sync requests
AIOHTTP_CLIENT_SESSION_SSL=false   # Async requests (Ollama)
```
Only for trusted internal networks.

### Web Search SSL Errors
```bash
ENABLE_WEB_LOADER_SSL_VERIFICATION=false
NO_PROXY=api.tavily.com,api.search.brave.com
```

---

## Multi-Replica Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Login loops / 401 errors | Different `WEBUI_SECRET_KEY` per instance | Set same key on all replicas |
| WebSocket 403 errors | Redis not configured | Add `WEBSOCKET_MANAGER=redis` |
| Database locked | SQLite with multiple instances | Switch to PostgreSQL |
| Config mismatch | No shared state | Configure Redis |
| RAG files inaccessible | No shared storage | Mount shared volume or use S3 |
| Worker crashes on upload | Default ChromaDB not fork-safe | Switch to external vector DB |

---

## Performance

### Slow on Low-Spec Hardware
```bash
DATABASE_ENABLE_SESSION_SHARING=false
```

### Memory Leaks at Scale
Use external extraction and embedding engines:
```bash
CONTENT_EXTRACTION_ENGINE=tika
RAG_EMBEDDING_ENGINE=openai  # or ollama
```

---

## Password Reset

### Admin Reset via Docker
```bash
docker exec -it open-webui \
  python -c "from open_webui.internal.db import Session; \
  from open_webui.models.auths import Auths; \
  Auths.update_user_password_by_id('USER_ID', 'new_password')"
```

### Headless Admin (Fresh Install)
```bash
WEBUI_ADMIN_EMAIL=admin@example.com
WEBUI_ADMIN_PASSWORD=your-secure-password
```

---

## SSO / OAuth

| Issue | Fix |
|-------|-----|
| Redirect URI mismatch | Set `WEBUI_URL` correctly before enabling OAuth |
| Config not updating from env | `ENABLE_OAUTH_PERSISTENT_CONFIG=true` means DB overrides env vars |
| Cookie too large (AD FS) | Server-side session storage handles this automatically |
| Token refresh fails (Microsoft) | Add `offline_access` to `MICROSOFT_OAUTH_SCOPE` |

---

## RAG Issues

| Issue | Fix |
|-------|-----|
| Short/truncated responses | Increase Ollama context: set to 8192+ tokens |
| Empty content in KB | Wait for async file processing before adding to KB |
| Re-indexing needed | Change embedding model requires full re-index |
| Standalone chat files | Must re-upload (re-index only affects KB files) |

---

## Offline Mode

```bash
# Pre-pull required resources, then:
HF_HUB_OFFLINE=1
TRANSFORMERS_OFFLINE=1
```

Disable telemetry:
```bash
SCARF_NO_ANALYTICS=true
DO_NOT_TRACK=true
ANONYMIZED_TELEMETRY=false
```

---

## S3 Storage

```bash
STORAGE_PROVIDER=s3
S3_BUCKET_NAME=your-bucket
S3_ACCESS_KEY_ID=your-key
S3_SECRET_ACCESS_KEY=your-secret
S3_REGION_NAME=us-east-1
S3_ENDPOINT_URL=https://s3.amazonaws.com  # or MinIO/R2 URL
```

---

## Backups

### SQLite Database
```bash
# Copy the data volume
docker cp open-webui:/app/backend/data ./backup

# Or backup just the DB
sqlite3 /path/to/webui.db ".backup '/path/to/backup.db'"
```

### PostgreSQL
```bash
pg_dump -h db-host -U user openwebui > backup.sql
```

---

## Database Schema (SQLite)

Key tables: `user`, `auth`, `chat`, `chat_message`, `document`, `file`, `memory`, `model`, `prompt`, `tool`, `function`, `knowledge`, `group`, `config`

```bash
# Explore schema
sqlite3 webui.db ".schema"
sqlite3 webui.db ".tables"
```
