Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ClipboardOwner {
    [DllImport("user32.dll")]
    public static extern IntPtr GetClipboardOwner();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@

try
{
    # 获取剪贴板所有者窗口句柄
    $hWnd = [ClipboardOwner]::GetClipboardOwner()

    if ($hWnd -eq 0)
    {
        "当前没有剪贴板所有者（可能被系统清空或暂无程序占用）"
        return
    }

    # 获取进程 ID
    [uint32]$pid = 0
    [ClipboardOwner]::GetWindowThreadProcessId($hWnd, [ref]$pid) | Out-Null

    # 获取进程对象
    $p = Get-Process -Id $pid -ErrorAction Ignore

    if ($p)
    {
        "剪贴板由进程写入：$( $p.ProcessName ).exe (PID: $pid)"
    }
    else
    {
        "无法获取进程（可能已经退出），PID=$pid"
    }

}
catch
{
    "发生错误：$_"
}
