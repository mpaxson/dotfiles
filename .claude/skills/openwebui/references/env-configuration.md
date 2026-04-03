# Environment Variables Reference

## App Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV` | `prod` | `dev` or `prod` |
| `WEBUI_NAME` | `Open WebUI` | Name shown in UI |
| `WEBUI_URL` | `http://localhost:3000` | Full instance URL |
| `DATA_DIR` | `./data` | Base data directory |
| `WEBUI_SECRET_KEY` | auto-generated | Secret for JWT signing |
| `JWT_EXPIRES_IN` | `-1` (never) | JWT expiration |
| `ENABLE_SIGNUP` | `true` | Allow new signups |
| `ENABLE_LOGIN_FORM` | `true` | Show login form |
| `DEFAULT_USER_ROLE` | `pending` | New user role (`pending`/`user`/`admin`) |
| `ENABLE_ADMIN_EXPORT` | `true` | Allow admin data export |
| `ENABLE_ADMIN_CHAT_ACCESS` | `true` | Admin access to all chats |
| `ENABLE_COMMUNITY_SHARING` | `true` | Share to community |
| `BYPASS_MODEL_ACCESS_CONTROL` | `false` | Skip model ACL |
| `RESET_CONFIG_ON_START` | `false` | Reset config DB on startup |
| `DEFAULT_LOCALE` | `en-US` | Default language |
| `WEBUI_AUTH` | `true` | Enable authentication |
| `CORS_ALLOW_ORIGIN` | `*` | Allowed CORS origins |

## Ollama Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_OLLAMA_API` | `true` | Enable Ollama integration |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API URL |
| `OLLAMA_BASE_URLS` | (empty) | Semicolon-separated URLs for load balancing |
| `OLLAMA_API_KEY` | (empty) | Ollama API key |

## OpenAI Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_OPENAI_API` | `true` | Enable OpenAI-compatible API |
| `OPENAI_API_BASE_URL` | `https://api.openai.com/v1` | Base URL |
| `OPENAI_API_BASE_URLS` | (empty) | Semicolon-separated URLs |
| `OPENAI_API_KEY` | (empty) | API key |
| `OPENAI_API_KEYS` | (empty) | Semicolon-separated keys (matching URL order) |

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///${DATA_DIR}/webui.db` | SQLAlchemy DB URL |
| `DATABASE_POOL_SIZE` | `0` (unlimited) | Connection pool size |
| `DATABASE_POOL_MAX_OVERFLOW` | `-1` (unlimited) | Max overflow connections |
| `DATABASE_POOL_TIMEOUT` | `30` | Pool wait timeout (seconds) |
| `DATABASE_POOL_RECYCLE` | `3600` | Connection recycle interval |

## Speech-to-Text (STT)

| Variable | Default | Description |
|----------|---------|-------------|
| `AUDIO_STT_ENGINE` | (empty/local whisper) | ``, `openai`, `whisper` |
| `AUDIO_STT_MODEL` | `whisper-1` | Model name |
| `AUDIO_STT_OPENAI_API_BASE_URL` | `${OPENAI_API_BASE_URL}` | STT API URL |
| `AUDIO_STT_OPENAI_API_KEY` | `${OPENAI_API_KEY}` | STT API key |
| `WHISPER_MODEL` | `base` | Local Whisper model |

## Text-to-Speech (TTS)

| Variable | Default | Description |
|----------|---------|-------------|
| `AUDIO_TTS_ENGINE` | (empty) | ``, `openai`, `elevenlabs`, `azure` |
| `AUDIO_TTS_MODEL` | `tts-1` | TTS model |
| `AUDIO_TTS_VOICE` | `alloy` | TTS voice |
| `AUDIO_TTS_OPENAI_API_BASE_URL` | `${OPENAI_API_BASE_URL}` | TTS API URL |
| `AUDIO_TTS_OPENAI_API_KEY` | `${OPENAI_API_KEY}` | TTS API key |

## Image Generation

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_IMAGE_GENERATION` | `false` | Enable image gen |
| `IMAGE_GENERATION_ENGINE` | `openai` | `openai`, `comfyui`, `automatic1111` |
| `IMAGE_GENERATION_MODEL` | `dall-e-3` | Model name |
| `IMAGE_SIZE` | `512x512` | Default size |
| `IMAGE_STEPS` | `50` | Generation steps |
| `AUTOMATIC1111_BASE_URL` | (empty) | A1111 API URL |
| `COMFYUI_BASE_URL` | (empty) | ComfyUI API URL |

## Logging / Telemetry

| Variable | Default | Description |
|----------|---------|-------------|
| `GLOBAL_LOG_LEVEL` | (empty) | Python logging level |
| `LOG_LEVEL` | `INFO` | uvicorn log level |
| `SRC_LOG_LEVELS` | (empty) | Per-module levels (e.g., `RAG:DEBUG,MAIN:INFO`) |
| `SCARF_NO_ANALYTICS` | `true` | Disable Scarf analytics |
| `DO_NOT_TRACK` | `true` | Disable telemetry |

## WebSocket / Redis

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_WEBSOCKET_SUPPORT` | `true` | Enable WebSockets |
| `WEBSOCKET_MANAGER` | (empty) | `redis` for multi-node |
| `WEBSOCKET_REDIS_URL` | `redis://localhost:6379/0` | Redis URL |

## Task Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TASK_MODEL` | (empty, uses chat model) | Model for auto tasks |
| `TASK_MODEL_EXTERNAL` | (empty) | External task model |
| `ENABLE_TAGS_GENERATION` | `true` | Auto tag generation |
| `ENABLE_SEARCH_QUERY_GENERATION` | `true` | RAG query generation |

## Proxy

| Variable | Description |
|----------|-------------|
| `http_proxy` | HTTP proxy URL |
| `https_proxy` | HTTPS proxy URL |
| `no_proxy` | Bypass proxy hosts |

## Docker Compose Patterns

### Basic with Ollama
```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports: ["3000:8080"]
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=your-secret-key
    volumes:
      - open-webui:/app/backend/data
  ollama:
    image: ollama/ollama
    ports: ["11434:11434"]
    volumes:
      - ollama:/root/.ollama
```

### OpenAI Only (No Ollama)
```yaml
environment:
  - ENABLE_OLLAMA_API=false
  - OPENAI_API_KEY=sk-your-key
```

### Multiple Endpoints
```yaml
environment:
  - OPENAI_API_BASE_URLS=https://api.openai.com/v1;https://other-api/v1
  - OPENAI_API_KEYS=sk-key1;sk-key2
```

### PostgreSQL
```yaml
environment:
  - DATABASE_URL=postgresql://user:password@db:5432/openwebui
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auths/signin` | POST | Sign in |
| `/api/v1/auths/signup` | POST | Sign up |
| `/api/v1/chats` | GET | List chats |
| `/api/v1/models` | GET | List models |
| `/api/v1/files` | POST | Upload file |
| `/api/v1/users` | GET | List users (admin) |
| `/ollama/api/chat` | POST | Proxy to Ollama |
| `/openai/v1/chat/completions` | POST | Proxy to OpenAI |
