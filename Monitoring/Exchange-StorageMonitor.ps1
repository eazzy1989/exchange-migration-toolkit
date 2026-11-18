<#
.SYNOPSIS
    Prüft den freien Speicherplatz auf Exchange-Datenbank-, Log- und Restore-Volumes.

.DESCRIPTION
    Fragt per CIM die Volumes der angegebenen Exchange-Server ab, deren Label mit
    DB, Logs oder Restore beginnt. Gibt einen Gesamtstatus (OK / WARNUNG / KRITISCH)
    aus, eine farbige Übersicht je Server sowie eigene Listen für auffällige
    Datenbank-Volumes und alle Log-Volumes.

.PARAMETER Servers
    FQDNs der Exchange-Server.

.PARAMETER CriticalPercent
    Unter diesem freien Speicher (%) gilt ein Volume als kritisch. Standard: 40.

.PARAMETER WarningPercent
    Bis zu diesem freien Speicher (%) gilt ein Volume als Warnung. Standard: 55.

.EXAMPLE
    .\Exchange-StorageMonitor.ps1 -Servers 'EX01.contoso.local','EX02.contoso.local'

.NOTES
    Autor:    Ismail Yildiz
    Erstellt: 11.06.2026
    Benötigt: WinRM/CIM-Zugriff auf die Server
#>

param(
    [Parameter(Mandatory)]
    [string[]]$Servers,

    [double]$CriticalPercent = 40,
    [double]$WarningPercent  = 55
)

$Critical = $CriticalPercent
$Warning  = $WarningPercent

function Get-LineColor([double]$FreePercent) {
    if ($FreePercent -lt $Critical)   { 'Red' }
    elseif ($FreePercent -le $Warning) { 'Yellow' }
    else                               { 'White' }
}

$Result = @(foreach ($Server in $Servers) {
    try {
        Get-CimInstance Win32_Volume -ComputerName $Server -ErrorAction Stop |
        Where-Object { $_.Label -match '^(DB|Logs|Restore)' -and $_.Capacity -gt 0 } |
        Select-Object @{Name='Server';Expression={$Server}},
                      Label,
                      @{Name='TotalGB';Expression={[math]::Round($_.Capacity / 1GB, 2)}},
                      @{Name='UsedGB';Expression={[math]::Round(($_.Capacity - $_.FreeSpace) / 1GB, 2)}},
                      @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                      @{Name='FreePercent';Expression={[math]::Round(($_.FreeSpace / $_.Capacity) * 100, 2)}}
    }
    catch {
        Write-Warning "$Server konnte nicht abgefragt werden."
    }
})

if ($Result.Where({ $_.FreePercent -lt $Critical }).Count -gt 0) {
    $Status = 'KRITISCH'
    $Color  = 'Red'
}
elseif ($Result.Where({ $_.FreePercent -le $Warning }).Count -gt 0) {
    $Status = 'WARNUNG'
    $Color  = 'Yellow'
}
else {
    $Status = 'OK'
    $Color  = 'Green'
}

Write-Host "`n$('=' * 56)" -ForegroundColor DarkGray
Write-Host "STATUS: $Status" -ForegroundColor $Color
Write-Host "$('=' * 56)" -ForegroundColor DarkGray

$Result | Group-Object Server | ForEach-Object {
    Write-Host "`n$('=' * 56)" -ForegroundColor DarkGray
    Write-Host $_.Name -ForegroundColor Cyan
    Write-Host "$('=' * 56)" -ForegroundColor DarkGray

    Write-Host ("{0,-12} {1,10} {2,10} {3,10} {4,10}" -f 'Label','TotalGB','UsedGB','FreeGB','Free %')

    $_.Group |
    Sort-Object {
        switch -Regex ($_.Label) {
            '^DB'      { 1 }
            '^Logs'    { 2 }
            '^Restore' { 3 }
            default    { 4 }
        }
    }, Label |
    ForEach-Object {
        Write-Host ("{0,-12} {1,10:N2} {2,10:N2} {3,10:N2} {4,9:N2}%" -f $_.Label,$_.TotalGB,$_.UsedGB,$_.FreeGB,$_.FreePercent) -ForegroundColor (Get-LineColor $_.FreePercent)
    }
}

$DbAttention = $Result |
    Where-Object { $_.Label -match '^DB' -and $_.FreePercent -le $Warning } |
    Sort-Object FreePercent

$LogVolumes = $Result |
    Where-Object { $_.Label -match '^Logs' } |
    Sort-Object Server, Label

if ($DbAttention) {
    Write-Host "`nDATENBANKEN UNTER ODER GLEICH $Warning%" -ForegroundColor Yellow
    Write-Host ('-' * 80) -ForegroundColor DarkGray
    Write-Host ("{0,-28} {1,-8} {2,10} {3,10} {4,10}" -f 'Server','Label','TotalGB','FreeGB','Free %')

    $DbAttention | ForEach-Object {
        Write-Host ("{0,-28} {1,-8} {2,10:N2} {3,10:N2} {4,9:N2}%" -f $_.Server,$_.Label,$_.TotalGB,$_.FreeGB,$_.FreePercent) -ForegroundColor (Get-LineColor $_.FreePercent)
    }
}

Write-Host "`nLOG-VOLUMES" -ForegroundColor Cyan
Write-Host ('-' * 80) -ForegroundColor DarkGray
Write-Host ("{0,-28} {1,-8} {2,10} {3,10} {4,10}" -f 'Server','Label','TotalGB','FreeGB','Free %')

$LogVolumes | ForEach-Object {
    Write-Host ("{0,-28} {1,-8} {2,10:N2} {3,10:N2} {4,9:N2}%" -f $_.Server,$_.Label,$_.TotalGB,$_.FreeGB,$_.FreePercent) -ForegroundColor (Get-LineColor $_.FreePercent)
}
