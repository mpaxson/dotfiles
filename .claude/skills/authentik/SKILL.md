---
name: authentik
description: >-
  Authentik self-hosted identity provider for Kubernetes. This skill should be
  used when deploying Authentik via Helm, configuring SAML/OAuth2 providers,
  setting up blueprints for declarative configuration, integrating Traefik
  forward auth middleware, configuring Google Workspace SAML federation as
  login source, setting up SSO for ArgoCD/Grafana/Gitea/MinIO, writing
  property mappings, managing flows/stages/policies, or protecting apps
  behind Authentik proxy outpost.
---

# Authentik

Self-hosted identity provider supporting SAML, OAuth2/OIDC, LDAP, and proxy authentication. Designed for Kubernetes deployment via Helm with declarative configuration through blueprints.

## Quick Start

### Helm Deployment

```bash
helm repo add authentik https://charts.goauthentik.io
helm repo update
helm upgrade --install authentik authentik/authentik -f values.yaml -n authentik --create-namespace
```

Initial setup: `https://<host>/if/flow/initial-setup/`

For Helm values reference and ArgoCD app-of-apps integration, see [deployment.md](references/deployment.md).

## Task Reference

### SAML Provider Setup
Configure SAML providers for SSO with applications (ArgoCD, Grafana, etc.).
- Provider settings, NameID policies, signing certificates
- Metadata URL: `/application/saml/<slug>/metadata/`
- ACS URL: `/application/saml/<slug>/sso/binding/post/`
- See [saml.md](references/saml.md)

### Blueprints (Declarative Config)
YAML-based declarative configuration for flows, stages, providers, applications.
- v1 schema: `version`, `metadata`, `context`, `entries`
- Tags: `!KeyOf`, `!Find`, `!Env`, `!Context`, `!Format`, `!If`, `!Condition`, `!Enumerate`
- Mount via ConfigMap at `/blueprints/custom/` in server + worker pods
- See [blueprints.md](references/blueprints.md)

### Traefik Forward Auth Middleware
Protect apps behind Traefik using Authentik proxy provider outpost.
- Proxy provider → embedded or standalone outpost
- Traefik `forwardAuth` middleware pointing to outpost
- Headers: `X-authentik-username`, `X-authentik-groups`, `X-authentik-email`
- See [middleware.md](references/middleware.md)

### Google Workspace SAML Login
"Login with Google" via SAML federation source.
- Google Admin Console: custom SAML app → ACS URL + Entity ID
- Authentik: SAML source with Google SSO URL + signing certificate
- See [google-source.md](references/google-source.md)

### Application Integrations
SAML/OIDC setup for common self-hosted apps.
- ArgoCD (OIDC via Dex), Grafana, Gitea, MinIO, Proxmox
- See [integrations.md](references/integrations.md)

### Property Mappings & Policies
Custom attribute statements and access control.
- SAML mappings: Python expressions with `request`, `user`, `provider` variables
- 7 default SAML mappings (Email, Groups, Name, UPN, User ID, Username, WindowsAccountName)
- Expression policies for conditional access
- See [saml.md](references/saml.md)

## Key URLs

| Endpoint | URL Pattern |
|----------|-------------|
| Admin UI | `/if/admin/` |
| User UI | `/if/user/` |
| SAML Metadata | `/application/saml/<slug>/metadata/` |
| SAML SSO (POST) | `/application/saml/<slug>/sso/binding/post/` |
| SAML SSO (Redirect) | `/application/saml/<slug>/sso/binding/redirect/` |
| SAML SLO | `/application/saml/<slug>/slo/binding/[post\|redirect]/` |
| IdP-initiated SSO | `/application/saml/<slug>/sso/binding/init/` |
| OAuth2 Authorize | `/application/o/authorize/` |
| OIDC Discovery | `/application/o/<slug>/.well-known/openid-configuration` |
| Outpost health | `outpost:9300/metrics` |
