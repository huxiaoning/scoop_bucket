Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ClipWatcher : Form
{
    private const int WM_CLIPBOARDUPDATE = 0x031D;
    private static IntPtr HWND_MESSAGE = new IntPtr(-3);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    public ClipWatcher() {
        this.Visible = false;
        this.ShowInTaskbar = false;
        this.WindowState = FormWindowState.Minimized;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        AddClipboardFormatListener(this.Handle);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_CLIPBOARDUPDATE)
        {
            ClipboardEvent?.Invoke(this, EventArgs.Empty);
        }
        base.WndProc(ref m);
    }

    public static event EventHandler ClipboardEvent;
}
"@ -ReferencedAssemblies System.Windows.Forms

# ----------------------------------------
# PowerShell 监听逻辑
# ----------------------------------------

# 记录最近一次 Ctrl+C 的时间和进程
$global:lastCopy = @{
    Time = Get-Date 0
    Process = $null
}

function Get-ForegroundProcess {
    $h = [ClipWatcher]::GetForegroundWindow()
    if ($h -eq 0) { return $null }

    [uint32]$pid = 0
    [ClipWatcher]::GetWindowThreadProcessId($h, [ref]$pid) | Out-Null

    try {
        return Get-Process -Id $pid -ErrorAction Ignore
    } catch { return $null }
}

# 启动隐藏窗口
$watcher = New-Object ClipWatcher
$null = $watcher.Handle   # 强制创建句柄

# 订阅剪贴板事件
Register-ObjectEvent -InputObject ([ClipWatcher]) -EventName ClipboardEvent -Action {
    $now = Get-Date

    # 时间差
    $diff = ($now - $global:lastCopy.Time).TotalMilliseconds

    if ($diff -lt 800 -and $global:lastCopy.Process) {
        Write-Host "剪贴板由: $($global:lastCopy.Process.ProcessName).exe  写入（Ctrl+C 推断）"
    } else {
        $p = Get-ForegroundProcess
        if ($p) {
            Write-Host "剪贴板可能由: $($p.ProcessName).exe 写入（推断）"
        } else {
            Write-Host "剪贴板更新，但无法推断来源"
        }
    }
}

Write-Host "正在监听 Ctrl+C 和剪贴板变化..."
Write-Host "按 Ctrl+C 复制后，脚本即可推断来源。"
Write-Host ""

# 键盘监听（轮询方式）
while ($true) {
    Start-Sleep -Milliseconds 30

    # 检查 Ctrl+C（使用 GetAsyncKeyState）
    if ([console]::KeyAvailable) {
        $key = [console]::ReadKey($true)
        if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq "C") {
            $p = Get-ForegroundProcess
            if ($p) {
                $global:lastCopy.Time = Get-Date
                $global:lastCopy.Process = $p
            }
        }
    }

    # 处理窗口消息
    [System.Windows.Forms.Application]::DoEvents()
}
