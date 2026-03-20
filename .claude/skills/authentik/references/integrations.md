# Application Integrations

## ArgoCD (OIDC via Dex)

ArgoCD uses OIDC through its built-in Dex connector (enables both UI and CLI auth).

### Authentik Setup
1. Create **OAuth2/OIDC Provider**
2. Redirect URIs (Strict):
   - `https://argocd.example.com/api/dex/callback`
   - `https://localhost:8085/auth/callback`
3. Select signing key
4. Note: Client ID, Client Secret, Application Slug

### Authentik Groups
- `ArgoCD Admins` → maps to `role:admin`
- `ArgoCD Viewers` → maps to `role:readonly`

### ArgoCD Configuration

`argocd-secret` (add to `data`):
```yaml
dex.authentik.clientSecret: <base64-encoded-client-secret>
```

`argocd-cm` ConfigMap:
```yaml
dex.config: |
  connectors:
  - config:
      issuer: https://auth.example.com/application/o/<app-slug>/
      clientID: <client-id>
      clientSecret: $dex.authentik.clientSecret
      insecureEnableGroups: true
      scopes:
        - openid
        - profile
        - email
    name: authentik
    type: oidc
    id: authentik
```

`argocd-rbac-cm` ConfigMap:
```yaml
policy.csv: |
  g, ArgoCD Admins, role:admin
  g, ArgoCD Viewers, role:readonly
```

### Helm Values (argo-cd chart)

```yaml
configs:
  secret:
    extra:
      dex.authentik.clientSecret: "<client-secret>"
  cm:
    dex.config: |
      connectors:
      - config:
          issuer: https://auth.example.com/application/o/<app-slug>/
          clientID: <client-id>
          clientSecret: $dex.authentik.clientSecret
          insecureEnableGroups: true
          scopes: [openid, profile, email]
        name: authentik
        type: oidc
        id: authentik
  rbac:
    policy.csv: |
      g, ArgoCD Admins, role:admin
      g, ArgoCD Viewers, role:readonly
```

---

## Grafana (OAuth2/OIDC)

### Authentik Setup
1. Create **OAuth2/OIDC Provider**
2. Redirect URI: `https://grafana.example.com/login/generic_oauth`
3. Scopes: `openid`, `profile`, `email`

### Grafana Config (`grafana.ini`)
```ini
[auth.generic_oauth]
enabled = true
name = authentik
client_id = <client-id>
client_secret = <client-secret>
scopes = openid profile email
auth_url = https://auth.example.com/application/o/authorize/
token_url = https://auth.example.com/application/o/token/
api_url = https://auth.example.com/application/o/userinfo/
role_attribute_path = contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'
```

---

## Gitea (OAuth2/OIDC)

### Authentik Setup
1. Create **OAuth2/OIDC Provider**
2. Redirect URI: `https://gitea.example.com/user/oauth2/authentik/callback`
3. Scopes: `openid`, `profile`, `email`

### Gitea Setup
Admin → Authentication Sources → Add:
- Type: OAuth2
- Provider: OpenID Connect
- Client ID/Secret from Authentik
- Discovery URL: `https://auth.example.com/application/o/<slug>/.well-known/openid-configuration`

---

## MinIO (OpenID Connect)

### Authentik Setup
1. Create **OAuth2/OIDC Provider**
2. Redirect URI: `https://minio-console.example.com/oauth_callback`
3. Add scope mapping for `minio` claim with policy attribute

### Custom Scope Mapping (Python expression)
```python
# Map groups to MinIO policies
if ak_is_group_member(request.user, name="MinIO Admins"):
    return {"policy": "consoleAdmin"}
return {"policy": "readonly"}
```

### MinIO Environment
```
MINIO_IDENTITY_OPENID_CONFIG_URL=https://auth.example.com/application/o/<slug>/.well-known/openid-configuration
MINIO_IDENTITY_OPENID_CLIENT_ID=<client-id>
MINIO_IDENTITY_OPENID_CLIENT_SECRET=<client-secret>
MINIO_IDENTITY_OPENID_SCOPES=openid,profile,email,minio
MINIO_IDENTITY_OPENID_CLAIM_NAME=policy
```

---

## Generic SAML App Template

For apps supporting SAML but without specific integration docs:

### Authentik SAML Provider
| Setting | Value |
|---------|-------|
| ACS URL | App's SAML callback URL |
| Issuer | `https://auth.example.com` |
| Audience | App's entity ID |
| NameID | Email (most common) |
| Signing Certificate | authentik Self-signed Certificate |

### App Configuration
Provide to the app:
- IdP Metadata URL: `https://auth.example.com/application/saml/<slug>/metadata/`
- IdP SSO URL: `https://auth.example.com/application/saml/<slug>/sso/binding/redirect/`
- IdP Certificate: download from authentik admin
- IdP Entity ID: `https://auth.example.com`

### Blueprint Pattern
```yaml
- model: authentik_providers_saml.samlprovider
  state: present
  identifiers:
    name: <app>-saml
  id: provider-<app>
  attrs:
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    acs_url: https://<app>.example.com/<saml-callback>
    issuer: !Format ["https://%s", !Env [AUTHENTIK_HOST]]
    sp_binding: post
    signing_kp: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

- model: authentik_core.application
  state: present
  identifiers:
    slug: <app>
  attrs:
    name: <App Name>
    provider: !KeyOf provider-<app>
```
