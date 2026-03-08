# Authentik OIDC Integration for Grafana

## Authentik Setup

### 1. Create OAuth2/OIDC Provider

In Authentik Admin UI (`/if/admin/`):

1. **Providers > Create > OAuth2/OIDC**
2. Settings:
   - Name: `Grafana`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: Confidential
   - Redirect URIs (Strict): `https://grafana.home.kettle.sh/login/generic_oauth`
   - Scopes: `openid`, `profile`, `email`
   - Signing Key: select authentik self-signed certificate
3. Note: Client ID and Client Secret

### 2. Create Application

1. **Applications > Create**
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: select `Grafana` provider
   - Launch URL: `https://grafana.home.kettle.sh`

### 3. Create Groups (Role Mapping)

Create Authentik groups for Grafana role mapping:
- `Grafana Admins` - full admin access
- `Grafana Editors` - dashboard edit access
- `Grafana Viewers` - read-only (optional, default role)

Assign users to groups in Authentik Admin.

## Authentik Blueprint (Declarative)

```yaml
# ConfigMap for Authentik blueprint
version: 1
metadata:
  name: Grafana OIDC Provider
entries:
  - model: authentik_providers_oauth2.oauth2provider
    state: present
    identifiers:
      name: Grafana
    id: provider-grafana
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: grafana
      client_secret: !Env [GRAFANA_OAUTH_SECRET]
      redirect_uris: !Format ["https://%s/login/generic_oauth", !Env [GRAFANA_HOST, grafana.home.kettle.sh]]
      signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]

  - model: authentik_core.application
    state: present
    identifiers:
      slug: grafana
    attrs:
      name: Grafana
      provider: !KeyOf provider-grafana
      meta_launch_url: !Format ["https://%s", !Env [GRAFANA_HOST, grafana.home.kettle.sh]]
```

## Grafana Helm Values

Add to kube-prometheus-stack `grafana` section:

```yaml
grafana:
  grafana.ini:
    server:
      root_url: https://grafana.home.kettle.sh
    auth:
      signout_redirect_url: "https://auth.home.kettle.sh/application/o/grafana/end-session/"
      oauth_auto_login: true
    auth.generic_oauth:
      enabled: true
      name: Authentik
      client_id: grafana
      client_secret: "${GRAFANA_OAUTH_SECRET}"
      scopes: openid profile email
      auth_url: https://auth.home.kettle.sh/application/o/authorize/
      token_url: https://auth.home.kettle.sh/application/o/token/
      api_url: https://auth.home.kettle.sh/application/o/userinfo/
      role_attribute_path: "contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'"
      allow_assign_grafana_admin: true
  envFromSecrets:
    - name: grafana-oauth-secret  # K8s secret with GRAFANA_OAUTH_SECRET key
```

### Secret for OAuth Client Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-oauth-secret
  namespace: monitoring
type: Opaque
stringData:
  GRAFANA_OAUTH_SECRET: "<client-secret-from-authentik>"
```

## Role Mapping Expression

The `role_attribute_path` uses JMESPath:

```
contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'
```

Evaluation order: Admin first, then Editor, fallback Viewer.

To also grant Grafana Server Admin to the Admins group:
```
contains(groups[*], 'Grafana Admins') && 'GrafanaAdmin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'
```

Requires `allow_assign_grafana_admin: true` in `auth.generic_oauth`.

## Disable Default Admin

Once OIDC works, optionally disable built-in login:

```yaml
grafana:
  grafana.ini:
    auth:
      disable_login_form: true
    auth.generic_oauth:
      oauth_auto_login: true
```
