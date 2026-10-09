# 这是一个私人scoop软件桶
```
scoop bucket add huxiaoning_scoop_bucket https://github.com/huxiaoning/scoop_bucket
scoop install huxiaoning_scoop_bucket/yt-dlp-ChromeCookieUnlock
scoop uninstall huxiaoning_scoop_bucket/yt-dlp-ChromeCookieUnlock
```

## TDM Fast 官方便携版

清单：`bucket/tdmfast.json`。

```powershell
scoop install huxiaoning_scoop_bucket/tdmfast
& 'TDM Fast-portable'
```

- 使用官网当前提供的便携包；安装时将带版本号的 EXE 重命名为稳定入口，快捷方式指向 `current`。
- 上游未提供可靠的递增应用版本，Scoop 使用便携包 HTTP `Last-Modified` 的 UTC 时间作为版本号，并据此自动更新下载链接与哈希。
- 下载功能需要官方授权激活，不是免费软件。
- 官方程序将配置、任务和授权存放在 `%APPDATA%\freedm`，不使用 Scoop `persist`；普通卸载不会删除该目录。与其他官方副本共用这份数据，不要同时运行。

## TDM Fast 修改测试版

清单：`bucket/tdmfast-modified-test.json`，与原版 `tdmfast` 分开安装。

```powershell
scoop install huxiaoning_scoop_bucket/tdmfast-modified-test
tdmfast-modified-test
scoop uninstall tdmfast-modified-test
```

- 安装完成后调用 `Launch.cmd`；命令和开始菜单快捷方式也通过该脚本启动。
- `UserData` 由 Scoop 持久化，普通卸载保留配置；不要直接运行 `TDM Fast.exe`，否则会使用另一份配置。
- 安装、更新和卸载前完全退出所有 TDM Fast 进程，包括托盘程序。
- 卸载先调用 `Restore-original.cmd` 恢复包内原始 ASAR，再删除本副本；不会修改另行安装的原版。
- 这是非官方实验版本。上游已知问题：重启后续传可能损坏文件，请新建下载；强制更新逻辑仍存在，稳定性未确认。原版和测试版不可同时运行（共用端口 `37651`）。
- 项目与使用说明：[yangshulin2333/tdm-fast-modified-test](https://github.com/yangshulin2333/tdm-fast-modified-test)。
