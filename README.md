# qbittorrent-nox

qBittorrent on the shared [alpine-base](https://github.com/Rake-Pro/alpine-base) image, built in-house from the upstream release.

```
ghcr.io/rake-pro/qbittorrent-nox
```

## Tags / releases

| Tag | Meaning |
| --- | --- |
| `X.Y.Z` | Immutable release, built from git tag `vX.Y.Z` |
| `X.Y` | Latest patch of that minor |
| `latest` | Latest release |
| `<upstream-version>` | The exact upstream qBittorrent version baked into that release (currently `5.3.0`) |
| `sha-<short>` | Commit the image was built from |

- `dev` is the integration branch (default); `ci.yml` builds, smoke-tests and Trivy-scans on every push and PR.
- `version-check.yml` polls upstream daily and opens a PR into `dev` bumping the pinned `VERSION` build arg.
- `sync-main.yml` opens a promotion PR from `dev` to `main`. Merging it (merge commit) mints the next patch tag and `release.yml` builds, scans and pushes the image. A fixable CRITICAL finding blocks the push.
- Label the promotion PR `release:minor` or `release:major` to change the bump.
- `trivy-rescan.yml` re-scans the released image weekly (CRITICAL+HIGH) so CVEs disclosed after release still surface.
- Dependabot bumps the base image digest and the GitHub Actions weekly.
- Pin `X.Y.Z` in deployments; `latest` is a convenience pointer.

## Image facts

| Item | Value |
| --- | --- |
| Base | `ghcr.io/rake-pro/alpine-base` (Alpine, patched weekly) |
| Init | `catatonit` as PID 1 |
| User | `65534:65534` from the first process (no s6, no privilege drop, no added capabilities) |
| Data | `/config/qBittorrent` (qBittorrent.conf, BT_backup, logs) |
| Port | `8080` |
| Upstream | <https://github.com/qbittorrent/qBittorrent> |
| Upstream version | `5.3.0` (build arg `VERSION`) |
| Platform | linux/amd64 |

## Run

```
docker run -d --name qbittorrent-nox \
  -p 8080:8080 \
  -v /path/to/config:/config \
  ghcr.io/rake-pro/qbittorrent-nox:latest
```

- The `/config` mount must be writable by uid 65534 (`chown -R 65534:65534 /path/to/config`).

## Notes

- Built from source with libtorrent 1.2 (tag `v1.2.20`, static) on Boost 1.86 and Qt from Alpine packages, following the official `docker-qbittorrent-nox` recipe. Build args `LIBTORRENT_TAG` and `BOOST_VERSION` select the libtorrent line (the 2.x line builds on current Boost).
- `WEBUI_PORT` (default 8080) and `TORRENTING_PORT` (unset) are passed as `--webui-port` / `--torrenting-port`.
- `/sbom.txt` in the image lists the build inputs (boost, libtorrent commit, qBittorrent version, Alpine packages).
