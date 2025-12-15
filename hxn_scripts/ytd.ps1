param(
    [Parameter(Mandatory = $true)]
    [string]$Url
)

ytdownloader
Set-Clipboard [HREF]

$wshell = New-Object -ComObject WScript.Shell
$wshell.SendKeys('^v')


