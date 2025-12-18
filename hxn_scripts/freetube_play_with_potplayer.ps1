param(
    [string]$Url
)

$scoop_home = scoop config root_path

$yt = $scoop_home + "\apps\yt-dlp\current\yt-dlp.exe"
$pot = $scoop_home + "\apps\potplayer-np\current\PotPlayerMini64.exe"

& $yt --cookies-from-browser chrome -f best -o - $Url | & $pot -

