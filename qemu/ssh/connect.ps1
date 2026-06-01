param(
  [string]$HostName = "127.0.0.1",
  [int]$Port = 2222,
  [string]$User = "mospli",
  [string]$Key = "$PSScriptRoot\mospli_ai"
)

$args = @("-p", "$Port", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=$PSScriptRoot\known_hosts")
if (Test-Path $Key) {
  $args += @("-i", $Key)
}
$args += "$User@$HostName"

ssh @args
