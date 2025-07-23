# Scoop Bucket Template
Template bucket for [Scoop](https://scoop.sh), the Windows command-line installer.

## How do I install these manifests?

After manifests have been committed and pushed, run the following:

```pwsh
scoop bucket add huxiaoning_scoop_bucket https://github.com/huxiaoning/scoop_bucket
scoop install huxiaoning_scoop_bucket/yt-dlp-chrome-cookie-unlock
scoop uninstall huxiaoning_scoop_bucket/yt-dlp-chrome-cookie-unlock
```
