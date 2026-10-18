param(
    [ValidateSet('Download', 'Import', 'Grow', 'Configure', 'Start')]
    [string]$Phase = 'Download',
    [string]$WorkFolder = (Join-Path $env:USERPROFILE 'codex-work'),
    [string]$KeyPath = (Join-Path $env:USERPROFILE 'codex-work\keys\cs554_vm'),
    [string]$VmFolder = 'C:\VMs\cs554-vm',
    [ValidateSet('GuestInfo', 'OvfProperties')]
    [string]$Route = 'GuestInfo',
    [int]$WaitSeconds = 180
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$vmware = Join-Path ${env:ProgramFiles(x86)} 'VMware\VMware Workstation'
$vmxPath = Join-Path $VmFolder 'cs554-vm.vmx'
$ova = Join-Path $WorkFolder 'images\noble-server-cloudimg-amd64.ova'
$sums = Join-Path $WorkFolder 'images\SHA256SUMS'
$log = Join-Path $WorkFolder 'reports\02-vm-create.txt'
$serialLog = Join-Path $WorkFolder 'logs\cs554-vm-serial.log'
foreach ($directory in @('images', 'reports', 'logs', 'cloud-init')) {
    $path = Join-Path $WorkFolder $directory
    if (-not (Test-Path -LiteralPath $path)) { [void](New-Item -ItemType Directory -Path $path) }
}

function Write-Record {
    param([string]$Text)
    foreach ($identity in @($env:USERNAME, $env:COMPUTERNAME)) {
        if ($identity) { $Text = [regex]::Replace($Text, [regex]::Escape($identity), '[REDACTED]', 'IgnoreCase') }
    }
    [System.IO.File]::AppendAllText($log, $Text + [Environment]::NewLine, $utf8)
    Write-Output $Text
}

function Invoke-Tool {
    param([string]$File, [string[]]$Arguments)
    Write-Record ('Host: ' + (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz') + [Environment]::NewLine + '$ ' + $File + ' ' + ($Arguments -join ' '))
    $output = & $File @Arguments 2>&1
    $exit = $LASTEXITCODE
    $text = $output | Out-String -Width 220
    Write-Record $text
    Write-Record ('Exit code: ' + $exit)
    if ($exit -ne 0) { throw ('Tool failed: ' + $File + ', exit ' + $exit) }
    $script:ToolOutput = $text
}

function Assert-Image {
    $line = @(Get-Content -LiteralPath $sums -Encoding UTF8 | Where-Object { $_ -match '^([a-fA-F0-9]{64})\s+\*?noble-server-cloudimg-amd64\.ova$' })
    if ($line.Count -ne 1) { throw 'Expected one official OVA checksum.' }
    $hash = Get-FileHash -LiteralPath $ova -Algorithm SHA256
    Write-Record ('$ Get-FileHash -LiteralPath ' + $ova + ' -Algorithm SHA256' + [Environment]::NewLine + ($hash | Format-List | Out-String) + 'Published: ' + $line[0])
    if ($hash.Hash -ne ($line[0] -split '\s+')[0]) { throw 'OVA checksum mismatch; do not import.' }
}

function Read-VmxValue {
    param([string]$Key)
    $found = [regex]::Match([System.IO.File]::ReadAllText($vmxPath, $utf8), '(?m)^' + [regex]::Escape($Key) + '\s*=\s*\x22([^\x22]+)\x22')
    if (-not $found.Success) { throw ('Missing VMX key: ' + $Key) }
    $found.Groups[1].Value
}

function Render-CloudInit {
    $publicKey = [System.IO.File]::ReadAllText($KeyPath + '.pub', $utf8).Trim()
    if ($publicKey -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?: .*)?$') { throw 'Expected an ed25519 public key.' }
    $userData = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'cloud-init\user-data.template'), $utf8).Replace('__SSH_PUBKEY__', $publicKey).Replace("`r`n", "`n")
    $metadata = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'cloud-init\meta-data.template'), $utf8).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText((Join-Path $WorkFolder 'cloud-init\user-data'), $userData, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $WorkFolder 'cloud-init\meta-data'), $metadata, $utf8)
    $script:UserBase64 = [Convert]::ToBase64String($utf8.GetBytes($userData))
    $script:MetadataBase64 = [Convert]::ToBase64String($utf8.GetBytes($metadata))
}

switch ($Phase) {
    'Download' {
        $base = 'https://cloud-images.ubuntu.com/noble/current/'
        Invoke-Tool (Join-Path $env:WINDIR 'System32\curl.exe') @('--fail', '--location', '--silent', '--show-error', '--output', $sums, ($base + 'SHA256SUMS'))
        Invoke-Tool (Join-Path $env:WINDIR 'System32\curl.exe') @('--fail', '--location', '--silent', '--show-error', '--output', $ova, ($base + 'noble-server-cloudimg-amd64.ova'))
        Assert-Image
    }
    'Import' {
        Assert-Image
        if (Test-Path -LiteralPath $VmFolder) { throw 'VM folder exists; refusing to overwrite an existing VM.' }
        $parent = Split-Path -Parent $VmFolder
        if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent) }
        $arguments = @('--lax', '--acceptAllEulas', '--maxVirtualHardwareVersion=21', '--name=cs554-vm')
        if ($Route -eq 'OvfProperties') {
            Render-CloudInit
            $arguments += @(('--prop:user-data=' + $script:UserBase64), '--prop:hostname=cs554-vm', '--prop:instance-id=cs554-vm-001')
        }
        $arguments += @($ova, ($parent + [char]92))
        Invoke-Tool (Join-Path $vmware 'OVFTool\ovftool.exe') $arguments
        if (-not (Test-Path -LiteralPath $vmxPath)) { throw 'Expected VMX missing after import.' }
    }
    'Grow' {
        $disk = Read-VmxValue 'scsi0:0.fileName'
        Invoke-Tool (Join-Path $vmware 'vmware-vdiskmanager.exe') @('-x', '25GB', (Join-Path $VmFolder $disk))
    }
    'Configure' {
        Render-CloudInit
        $settings = [ordered]@{
            displayName = 'cs554-vm'
            memsize = '4096'
            numvcpus = '2'
            'ethernet0.present' = 'TRUE'
            'ethernet0.connectionType' = 'nat'
            'ethernet0.virtualDev' = 'vmxnet3'
            'serial0.present' = 'TRUE'
            'serial0.startConnected' = 'TRUE'
            'serial0.fileType' = 'file'
            'serial0.fileName' = $serialLog
            'serial0.tryNoRxLoss' = 'TRUE'
        }
        if ($Route -eq 'GuestInfo') {
            $settings['guestinfo.metadata'] = $script:MetadataBase64
            $settings['guestinfo.metadata.encoding'] = 'base64'
            $settings['guestinfo.userdata'] = $script:UserBase64
            $settings['guestinfo.userdata.encoding'] = 'base64'
        }
        $lines = [System.IO.File]::ReadAllLines($vmxPath, $utf8)
        $newLines = @()
        foreach ($line in $lines) {
            $match = [regex]::Match($line, '^([^\s=]+)\s*=')
            if ($match.Success -and $settings.Contains($match.Groups[1].Value)) { continue }
            $newLines += $line
        }
        foreach ($key in $settings.Keys) {
            $newLines += $key + ' = ' + [char]34 + $settings[$key] + [char]34
        }
        [System.IO.File]::WriteAllLines($vmxPath, $newLines, $utf8)
        Write-Record 'VMX configured: cs554-vm, 2 vCPU, 4096 MiB, NAT/vmxnet3; generated cloud-init and serial log under codex-work.'
    }
    'Start' {
        Invoke-Tool (Join-Path $vmware 'vmrun.exe') @('-T', 'ws', 'start', $vmxPath, 'nogui')
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = Join-Path $vmware 'vmrun.exe'
        $start.Arguments = '-T ws getGuestIPAddress ' + [char]34 + $vmxPath + [char]34 + ' -wait'
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        Write-Record ('$ ' + $start.FileName + ' ' + $start.Arguments)
        $process = [System.Diagnostics.Process]::Start($start)
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($WaitSeconds * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            Write-Record ($stdout.Result + $stderr.Result)
            throw 'Guest IP wait timed out; inspect serial log and follow the documented cloud-init fallback.'
        }
        Write-Record ($stdout.Result + $stderr.Result + 'Exit code: ' + $process.ExitCode)
        if ($process.ExitCode -ne 0) { throw 'Guest IP query failed.' }
        $ip = $stdout.Result.Trim()
        if ($ip -notmatch '^192\.168\.197\.\d+$') { throw 'Unexpected guest subnet; do not modify host networking.' }
        [System.IO.File]::WriteAllText((Join-Path $WorkFolder 'logs\cs554-vm-ip.txt'), $ip, $utf8)
    }
}
