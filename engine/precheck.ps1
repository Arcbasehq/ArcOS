function Invoke-Precheck {

    Write-ArcLog "Running environment validation."

    $os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$os.CurrentBuild

    if ($build -lt 19041) {
        throw "Unsupported Windows build: $build"
    }

    Write-ArcLog "Windows build $build validated."
}