# Scoop Bucket Template
Template bucket for [Scoop](https://scoop.sh), the Windows command-line installer.

## How do I install these manifests?

After manifests have been committed and pushed, run the following:

```pwsh
scoop bucket add huxiaoning_scoop_bucket https://github.com/huxiaoning/scoop_bucket
scoop install huxiaoning_scoop_bucket/yt-dlp-chrome-cookie-unlock
scoop uninstall huxiaoning_scoop_bucket/yt-dlp-chrome-cookie-unlock
```

#### 软件清单
- [yt-dlp-chrome-cookie-unlock](https://github.com/seproDev/yt-dlp-ChromeCookieUnlock)
  - 使用 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 下载视频使用参数 --cookies-from-browser chrome 提示不能复制cookie数据库
  - 这时有两个办法：
  - 1是关闭chrome浏览器
  - 2 如果不想关闭chrome就安装一下这个软件，可以解锁chrome cookie 锁定
  - 除了可以配置合 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 也可以配合 [media-downloader](https://github.com/mhogomchungu/media-downloader)
