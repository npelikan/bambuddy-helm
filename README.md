# Bambuddy Helm Chart

A Helm chart for [Bambuddy](https://github.com/maziggy/bambuddy) — a self-hosted command center for
Bambu Lab 3D printers. *"Your printers. No cloud. Your rules."*

- **Image:** `ghcr.io/maziggy/bambuddy`, pinned to a specific version via the chart's `appVersion`
  (currently `0.2.4.9`). Override with `image.tag`.
- **Default datastore:** SQLite (on a persistent volume), with optional external PostgreSQL.
- **Persistence:** enabled by default for both `/app/data` and `/app/logs`.

## TL;DR

```bash
# From the published Helm repository:
helm repo add bambuddy https://npelikan.github.io/bambuddy-helm
helm repo update
helm install bambuddy bambuddy/bambuddy

# ...or directly from a checkout of this repo:
helm install bambuddy .
```

By default this deploys Bambuddy with SQLite and two persistent volumes (10Gi data, 2Gi logs).

## Installing

```bash
# SQLite (default), with a custom timezone and storage class
helm install bambuddy . \
  --set config.tz=Europe/Berlin \
  --set persistence.data.storageClass=fast-ssd

# External PostgreSQL
helm install bambuddy . \
  --set database.type=postgresql \
  --set database.externalDatabase.host=postgres.db.svc \
  --set database.externalDatabase.user=bambuddy \
  --set database.externalDatabase.database=bambuddy \
  --set database.externalDatabase.password=changeme
```

## Database

The chart defaults to SQLite (`database.type: sqlite`), which lives on the data PVC and needs no
configuration. To use PostgreSQL, set `database.type: postgresql` and provide connection details
under `database.externalDatabase`. The chart does **not** deploy a PostgreSQL server — point it at an
existing one. The connection string is assembled as
`postgresql+asyncpg://user:pass@host:port/database` and injected via the `DATABASE_URL` env var.

Three ways to supply credentials, in order of precedence:

1. **`externalDatabase.existingSecret`** — reference an existing Secret containing the full
   `DATABASE_URL` (key configurable via `externalDatabase.existingSecretUrlKey`, default
   `database-url`). The chart stores nothing itself. *Recommended for production.*
2. **`externalDatabase.url`** — provide the full URL inline; stored in a chart-managed Secret.
3. **`externalDatabase.host/port/user/database/password`** — the chart builds the URL and stores it
   in a chart-managed Secret.

## Persistence

| Path        | Purpose                              | Value key            | Default size |
|-------------|--------------------------------------|----------------------|--------------|
| `/app/data` | Database, print archive, app data    | `persistence.data`   | `10Gi`       |
| `/app/logs` | Application logs                     | `persistence.logs`   | `2Gi`        |

Both are persistent by default (`ReadWriteOnce`). Set `persistence.<x>.enabled=false` to use an
`emptyDir` (ephemeral), `persistence.<x>.existingClaim` to reuse a PVC, or `persistence.<x>.retain=true`
to keep the PVC after `helm uninstall`. The Deployment uses the `Recreate` strategy so the RWO volume
is released before a new pod starts.

> ⚠️ Bambuddy is a single-instance application. Keep `replicaCount: 1` unless you are using an external
> database **and** a `ReadWriteMany` volume.

## Networking & printer discovery

Automatic printer discovery uses SSDP/multicast, which generally requires host networking:

```bash
helm install bambuddy . --set hostNetwork=true
```

When `hostNetwork: true`, `dnsPolicy` is set to `ClusterFirstWithHostNet` automatically. The container
runs with the `NET_BIND_SERVICE` capability so it can bind privileged virtual-printer ports (322, 990)
as a non-root user.

If you cannot use host networking, you can still expose the **virtual printer** by setting
`service.virtualPrinter.enabled=true` (this opens ports 3000, 3002, 990, 8883, 6000, 322, 2024–2026
and 50000–50029 on the container and Service) and `config.virtualPrinterPasvAddress` to the node's
LAN IP for FTP passive mode.

## Configuration

All documented Bambuddy environment variables are exposed under `config` (and `database`). Empty
values are omitted so the app falls back to its own defaults.

| Value key                            | Env var                        | Default            |
|--------------------------------------|--------------------------------|--------------------|
| `config.tz`                          | `TZ`                           | `UTC`              |
| `config.port`                        | `PORT`                         | `8000`             |
| `config.debug`                       | `DEBUG`                        | `false`            |
| `config.logLevel`                    | `LOG_LEVEL`                    | `INFO`             |
| `config.trustedFrameOrigins`         | `TRUSTED_FRAME_ORIGINS`        | _(unset)_          |
| `config.useSystemTrustStore`         | `USE_SYSTEM_TRUST_STORE`       | `false`            |
| `config.externalRoots`               | `BAMBUDDY_EXTERNAL_ROOTS`      | _(unset)_          |
| `config.virtualPrinterPasvAddress`   | `VIRTUAL_PRINTER_PASV_ADDRESS` | _(unset)_          |
| `config.slicerApiUrl`                | `SLICER_API_URL`               | _(unset)_          |
| `config.homeAssistant.url`           | `HA_URL`                       | _(unset)_          |
| `config.homeAssistant.token`         | `HA_TOKEN` (Secret)            | _(unset)_          |
| `config.mfa.encryptionKey`           | `MFA_ENCRYPTION_KEY` (Secret)  | _(unset)_          |
| `config.puid` / `config.pgid`        | `PUID` / `PGID`                | _(unset)_          |
| `database.externalDatabase.*`        | `DATABASE_URL` (Secret)        | _(SQLite default)_ |

Use `extraEnv`, `extraEnvFrom`, `extraVolumes`, and `extraVolumeMounts` for anything not covered.

### Secrets

`HA_TOKEN`, `MFA_ENCRYPTION_KEY`, and the PostgreSQL `DATABASE_URL` are placed in a chart-managed
Secret when provided inline. Each can instead reference an existing Secret
(`config.homeAssistant.existingSecret`, `config.mfa.existingSecret`,
`database.externalDatabase.existingSecret`).

## extraObjects

Inject arbitrary manifests (NetworkPolicy, ServiceMonitor, an extra LoadBalancer Service for printer
ports, ExternalSecret, etc.). Provide each entry as a YAML block-scalar string; entries are run
through `tpl`, so Helm templating works:

```yaml
extraObjects:
  - |
    apiVersion: v1
    kind: Service
    metadata:
      name: {{ include "bambuddy.fullname" . }}-printer-lb
      labels:
        {{- include "bambuddy.labels" . | nindent 8 }}
    spec:
      type: LoadBalancer
      selector:
        {{- include "bambuddy.selectorLabels" . | nindent 8 }}
      ports:
        - name: mqtt
          port: 8883
          targetPort: vp-mqtt
```

## Testing

```bash
helm lint .
helm template bambuddy .
helm test bambuddy            # after install — checks the web port is reachable
```

## CI / releasing

Two GitHub Actions workflows live in `.github/workflows/`:

- **`lint.yaml`** — on pull requests, runs `helm lint` and `helm template` against the default
  values and both `ci/` value sets (which also validates `values.schema.json`).
- **`release.yaml`** — on pushes to `main` that change the chart, packages the chart with
  `helm package` and runs [`helm/chart-releaser-action`](https://github.com/helm/chart-releaser-action)
  (`skip_packaging: true`) to create a GitHub Release and update the Helm repo index on the
  `gh-pages` branch.

To cut a release, bump `version` in `Chart.yaml` and merge to `main`; chart-releaser skips versions
that already have a release.

**One-time setup:** in the repository settings, enable **GitHub Pages** serving from the `gh-pages`
branch. That branch is created automatically on the first successful `release.yaml` run.
