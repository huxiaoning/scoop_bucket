$inbound = @("--mode", "socks5", "--listen-host", "0.0.0.0", "--listen-port", "38080")
$web = @("--web-host", "127.0.0.1", "--web-port", "38081")
$outbound = @("--upstream", "socks5://127.0.0.1:7890")
mitmweb @inbound @web @outbound
