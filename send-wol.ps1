
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MacAddress,

    [string]$BroadcastAddress = "255.255.255.255",

    [ValidateRange(1, 65535)]
    [int]$Port = 9
)

try {
    # Validate and normalise MAC address
    $mac = $MacAddress -replace '[:-]', ''

    if ($mac -notmatch '^[0-9A-Fa-f]{12}$') {
        throw "Invalid MAC address: $MacAddress"
    }

    # Validate broadcast IP address
    $ip = $null
    if (-not [System.Net.IPAddress]::TryParse(
        $BroadcastAddress, [ref]$ip
    ) -or $ip.AddressFamily -ne 'InterNetwork') {
        throw "Invalid IPv4 address: $BroadcastAddress"
    }

    # Convert MAC address into bytes
    [byte[]]$macBytes = for ($i = 0; $i -lt 12; $i += 2) {
        [Convert]::ToByte($mac.Substring($i, 2), 16)
    }

    # Magic packet: 6 x FF followed by MAC repeated 16 times
    [byte[]]$packet = @(255) * 6
    for ($i = 0; $i -lt 16; $i++) {
        $packet += $macBytes
    }

    # Send UDP broadcast packet
    $udp = [System.Net.Sockets.UdpClient]::new()
    try {
        $udp.EnableBroadcast = $true
        $udp.Connect($ip, $Port)

        $sent = $udp.Send($packet, $packet.Length)

        if ($sent -ne 102) {
            throw "Incomplete packet sent: $sent bytes"
        }

        Write-Host "WOL packet sent successfully!" -ForegroundColor Green
        Write-Host "MAC: $MacAddress"
        Write-Host "Destination: ${BroadcastAddress}:$Port"
    }
    finally {
        $udp.Dispose()
    }
}
catch {
    Write-Error "Wake-on-LAN failed: $($_.Exception.Message)"
    exit 1
}
