---
name: openwebui
description: Open WebUI self-hosted AI chat interface deployment, configuration, and administration. Use when deploying Open WebUI with Docker/Kubernetes/pip, configuring environment variables (OLLAMA_BASE_URL, OPENAI_API_KEY, DATABASE_URL, RAG_*, AUDIO_*, IMAGE_*), setting up SSO/OAuth/LDAP/SCIM authentication, configuring RBAC (roles, groups, permissions), managing RAG/embeddings/vector databases (ChromaDB, Milvus, PGVector, Qdrant), setting up web search providers (SearXNG, Brave, Tavily, DDGS), writing plugins (Tools, Functions, Pipes, Filters), configuring MCP servers, setting up image generation (AUTOMATIC1111, ComfyUI, OpenAI DALL-E), configuring TTS/STT (Whisper, OpenAI, Edge-TTS, Kokoro), scaling with Redis WebSockets, reverse proxy setup (Nginx, Caddy, HAProxy), troubleshooting connection errors, or managing Open WebUI pipelines and extensibility.
---

# Open WebUI

Self-hosted AI chat interface supporting Ollama, OpenAI-compatible APIs, and custom pipelines. Provides RAG, web search, code execution, image generation, TTS/STT, RBAC, SSO, and extensibility via plugins/MCP.

## Quick Reference

### Installation
```bash
# Docker (with Ollama)
docker run -d -p 3000:8080 \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  --name open-webui ghcr.io/open-webui/open-webui:main

# Docker (OpenAI only)
docker run -d -p 3000:8080 \
  -e ENABLE_OLLAMA_API=false \
  -e OPENAI_API_KEY=sk-xxx \
  --name open-webui ghcr.io/open-webui/open-webui:main

# pip
pip install open-webui && open-webui serve
```

### Key Environment Variables
| Variable | Default | Purpose |
|----------|---------|---------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API endpoint |
| `OPENAI_API_KEY` | (empty) | OpenAI API key |
| `WEBUI_SECRET_KEY` | auto | JWT signing secret (**must set in production**) |
| `DATABASE_URL` | `sqlite:///...` | Database connection string |
| `DEFAULT_USER_ROLE` | `pending` | New user role: `pending`/`user`/`admin` |
| `ENABLE_SIGNUP` | `true` | Allow new registrations |

See [references/env-configuration.md](references/env-configuration.md) for complete list.

## Reference Files

Load relevant reference files based on the task at hand:

| Reference | When to Load |
|-----------|-------------|
| [env-configuration.md](references/env-configuration.md) | Configuring env vars, Docker compose, database, proxy, API endpoints |
| [auth-security.md](references/auth-security.md) | Setting up OAuth/OIDC/SSO (Google, Microsoft, GitHub, Keycloak, Authentik), LDAP, SCIM, RBAC roles/groups/permissions, trusted headers, banners, webhooks, analytics |
| [rag-data-controls.md](references/rag-data-controls.md) | Configuring RAG (chunking, embeddings, reranking), vector databases (ChromaDB, Milvus, PGVector, Qdrant, Elasticsearch), document extraction (Tika, Docling, Mistral OCR), import/export, memory, direct connections |
| [chat-features.md](references/chat-features.md) | Code execution (Pyodide/Jupyter/Terminal), artifacts, multi-model chats, URL params, chat parameters hierarchy, reasoning models, temporal awareness, autocomplete, message queue |
| [web-search.md](references/web-search.md) | Web search providers (SearXNG, Brave, Tavily, DDGS, Jina, 20+ providers), agentic search vs traditional RAG, provider env vars and setup |
| [workspace.md](references/workspace.md) | Models (capabilities, system prompts, Jinja2 variables), Prompts (slash commands, custom input types, versioning), Knowledge (retrieval modes, agentic tools), Skills, Notes, Channels, Open Terminal |
| [plugins-extensibility.md](references/plugins-extensibility.md) | Writing Tools, Functions (Action/Filter/Pipe), Valves, Events, OpenAPI servers, MCP integration, Pipelines |
| [media-generation.md](references/media-generation.md) | Image generation (AUTOMATIC1111, ComfyUI, OpenAI, Gemini), STT (Whisper, OpenAI), TTS (OpenAI, Edge-TTS, Kokoro, OpenedAI Speech) |
| [deployment.md](references/deployment.md) | Docker deployment, scaling, reverse proxy (Nginx, Caddy), OTEL monitoring, updating |
| [troubleshooting.md](references/troubleshooting.md) | Connection errors, password reset, RAG issues, SSO debugging, multi-replica, performance, offline mode, S3 storage, backups, database schema |

## Common Tasks

### Add an LLM Provider
```yaml
# docker-compose.yml
environment:
  - OPENAI_API_BASE_URLS=https://api.openai.com/v1;https://other-provider/v1
  - OPENAI_API_KEYS=sk-key1;sk-key2
```

### Enable Web Search
```yaml
environment:
  - ENABLE_RAG_WEB_SEARCH=true
  - RAG_WEB_SEARCH_ENGINE=brave  # or searxng, tavily, ddgs, etc.
  - BRAVE_SEARCH_API_KEY=your-key
```
See [references/web-search.md](references/web-search.md) for all 22 providers.

### Enable SSO
```yaml
environment:
  - WEBUI_URL=https://chat.example.com
  - ENABLE_OAUTH_SIGNUP=true
  - OAUTH_CLIENT_ID=your-client-id
  - OAUTH_CLIENT_SECRET=your-secret
  - OPENID_PROVIDER_URL=https://idp.example.com/.well-known/openid-configuration
```
See [references/auth-security.md](references/auth-security.md) for Google, Microsoft, GitHub, Keycloak, LDAP, SCIM.

### Switch Vector Database
```yaml
environment:
  - VECTOR_DB=pgvector  # or milvus, qdrant, elasticsearch, etc.
  - PGVECTOR_DB_URL=postgresql://user:pass@db:5432/openwebui
```
See [references/rag-data-controls.md](references/rag-data-controls.md) for all vector DB options.

### Scale with Redis
```yaml
environment:
  - WEBSOCKET_MANAGER=redis
  - WEBSOCKET_REDIS_URL=redis://redis:6379/0
```

### Use PostgreSQL
```yaml
environment:
  - DATABASE_URL=postgresql://user:password@db:5432/openwebui
```
