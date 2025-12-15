param(
    [Parameter(Mandatory = $true)]
    [string]$Url
)

ytdownloader
Set-Clipboard $Url

$wshell = New-Object -ComObject WScript.Shell
$wshell.SendKeys('^v')


