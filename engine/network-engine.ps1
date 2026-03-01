function Invoke-NetworkEngine {
    param (
        [object]$Config
    )

    Write-ArcLog "Applying network latency optimizations."

    function Initialize-RegPath ([string]$Path) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
    }

    # =====================================================
    # Disable Network Throttling
    # =====================================================

    try {
        $MP = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $MP -Name "NetworkThrottlingIndex" -Type DWord -Value 0xFFFFFFFF
        Set-ItemProperty -Path $MP -Name "SystemResponsiveness"   -Type DWord -Value 0
        Write-ArcLog "Network throttling disabled."
    }
    catch { Write-ArcLog "Network throttling tweak failed." "WARN" }

    # =====================================================
    # Disable QoS Packet Scheduler Reservation
    # =====================================================

    try {
        $QoS = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        Initialize-RegPath $QoS
        Set-ItemProperty -Path $QoS -Name "NonBestEffortLimit" -Type DWord -Value 0
        Write-ArcLog "QoS bandwidth reservation disabled."
    }
    catch {}

    # =====================================================
    # Nagle's Algorithm Disable (per active adapter)
    # TCP Ack Frequency — reduces batching delay
    # =====================================================

    try {
        $adapters = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue

        $nagleCount = 0
        foreach ($adapter in $adapters) {
            $adapterPath = $adapter.PSPath

            # Only apply to adapters that have an IP address set
            $ip = (Get-ItemProperty -Path $adapterPath -Name "IPAddress" -ErrorAction SilentlyContinue)?.IPAddress
            if (-not $ip) { continue }

            Set-ItemProperty -Path $adapterPath -Name "TcpAckFrequency" -Type DWord -Value 1 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $adapterPath -Name "TCPNoDelay"      -Type DWord -Value 1 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $adapterPath -Name "TcpDelAckTicks"  -Type DWord -Value 0 -ErrorAction SilentlyContinue
            $nagleCount++
        }

        if ($nagleCount -gt 0) {
            Write-ArcLog "Nagle's algorithm disabled on $nagleCount network adapter(s)."
        }
        else {
            Write-ArcLog "No active IP adapters found for Nagle tweak." "WARN"
        }
    }
    catch { Write-ArcLog "Nagle disable failed: $($_.Exception.Message)" "WARN" }

    # =====================================================
    # Global TCP Parameters
    # =====================================================

    try {
        $TcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $TcpParams -Name "DefaultTTL"                -Type DWord -Value 64
        Set-ItemProperty -Path $TcpParams -Name "Tcp1323Opts"               -Type DWord -Value 1
        Set-ItemProperty -Path $TcpParams -Name "TcpMaxDupAcks"             -Type DWord -Value 2
        Set-ItemProperty -Path $TcpParams -Name "GlobalMaxTcpWindowSize"    -Type DWord -Value 65535
        Set-ItemProperty -Path $TcpParams -Name "TcpWindowSize"             -Type DWord -Value 65535
        Write-ArcLog "Global TCP parameters optimized."
    }
    catch { Write-ArcLog "TCP parameter tweak failed." "WARN" }

    # =====================================================
    # DNS Client Cache Optimization
    # =====================================================

    try {
        $DnsCache = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        Initialize-RegPath $DnsCache
        Set-ItemProperty -Path $DnsCache -Name "MaxCacheEntryTtlLimit"         -Type DWord -Value 86400
        Set-ItemProperty -Path $DnsCache -Name "MaxCachedSockets"              -Type DWord -Value 0
        Set-ItemProperty -Path $DnsCache -Name "NegativeCacheTime"             -Type DWord -Value 0
        Set-ItemProperty -Path $DnsCache -Name "NegativeSOACacheTime"          -Type DWord -Value 0
        Set-ItemProperty -Path $DnsCache -Name "NetFailureCacheTime"           -Type DWord -Value 0
        Write-ArcLog "DNS client cache optimized (negative TTL = 0)."
    }
    catch {}

    # =====================================================
    # Auto-Tuning (normal = optimal for most connections)
    # =====================================================

    try {
        Start-Process netsh -ArgumentList "int tcp set global autotuninglevel=normal" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        Write-ArcLog "TCP auto-tuning set to normal."
    }
    catch {}

    # =====================================================
    # Disable Large Send Offload (LSO) — reduces CPU spikes
    # =====================================================

    try {
        $nics = Get-NetAdapterAdvancedProperty -DisplayName "Large Send Offload*" -ErrorAction SilentlyContinue
        foreach ($nic in $nics) {
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $nic.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        }
        Write-ArcLog "Large Send Offload (LSO) disabled on all adapters."
    }
    catch {}

    Write-ArcLog "Network engine complete."
}
