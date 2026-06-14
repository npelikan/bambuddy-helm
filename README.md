# bambuddy-helm — Helm repository

This branch (`gh-pages`) is the published Helm chart repository for
[bambuddy-helm](https://github.com/npelikan/bambuddy-helm). It is maintained
automatically by [chart-releaser](https://github.com/helm/chart-releaser-action)
via the `Release Chart` GitHub Actions workflow — do not edit it by hand.

## Usage

```bash
helm repo add bambuddy https://npelikan.github.io/bambuddy-helm
helm repo update
helm install bambuddy bambuddy/bambuddy
```
