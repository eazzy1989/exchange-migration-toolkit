<#
.SYNOPSIS
    Konsolen-Dashboard für eine Exchange-Migrationsbatch inkl. Enterprise-Vault-Zuweisung.

.DESCRIPTION
    Zeigt für eine Batch die Anzahl der Move-Requests je Status, wie viele
    Benutzer bereits der Enterprise-Vault-Archivgruppe zugewiesen sind und
    die Verteilung nach Quelldatenbank und Status.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.PARAMETER EVGroup
    AD-Gruppe für die Enterprise-Vault-Archivierung.

.EXAMPLE
    .\Migrations-Dashboard.ps1 -BatchName 'Migration_Batch01' -EVGroup 'EV-Archiv-Standard'

.NOTES
    Autor:    eazzy1989
    Erstellt: 07/2026
    Benötigt: Exchange Management Shell, ActiveDirectory-Modul
#>

param(
    [string]$BatchName = 'Migration_Batch01',
    [string]$EVGroup   = 'EV-Archiv-Standard'
)

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ' Exchange Migration Dashboard' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host "Batch: $BatchName"
Write-Host ''

# ----------------------------
# MoveRequests laden
# ----------------------------

$moveRequests = @(Get-MoveRequest -BatchName $BatchName -ResultSize Unlimited)

$total      = $moveRequests.Count
$completed  = @($moveRequests | Where-Object { $_.Status -like 'Completed*' }).Count
$synced     = @($moveRequests | Where-Object { $_.Status -eq 'Synced' }).Count
$inProgress = @($moveRequests | Where-Object { $_.Status -eq 'InProgress' }).Count
$failed     = @($moveRequests | Where-Object { $_.Status -eq 'Failed' }).Count
$suspended  = @($moveRequests | Where-Object { $_.Status -in @('Suspended', 'AutoSuspended') }).Count

# ----------------------------
# EV-Gruppe laden
# ----------------------------

$evHash = @{}

foreach ($dn in (Get-ADGroup $EVGroup -Properties member).member) {
    try {
        $sam = (Get-ADUser $dn -Properties SamAccountName -ErrorAction Stop).SamAccountName
        $evHash[$sam] = $true
    }
    catch {
        # Mitglied ist kein Benutzer (z. B. verschachtelte Gruppe) - ignorieren
    }
}

# ----------------------------
# EV-Zuweisung prüfen
# ----------------------------

$evAssigned = 0

foreach ($mr in $moveRequests) {
    try {
        $sam = (Get-Mailbox -Identity $mr.Alias -ErrorAction Stop).SamAccountName

        if ($evHash.ContainsKey($sam)) {
            $evAssigned++
        }
    }
    catch {
        Write-Warning "Mailbox nicht gefunden: $($mr.Alias)"
    }
}

# ----------------------------
# Übersicht
# ----------------------------

Write-Host 'MoveRequests'
Write-Host '------------'
Write-Host ('Gesamt       : {0}' -f $total)
Write-Host ('Completed    : {0}' -f $completed)  -ForegroundColor Green
Write-Host ('Synced       : {0}' -f $synced)     -ForegroundColor Yellow
Write-Host ('InProgress   : {0}' -f $inProgress) -ForegroundColor Cyan
Write-Host ('Failed       : {0}' -f $failed)     -ForegroundColor Red
Write-Host ('Suspended    : {0}' -f $suspended)  -ForegroundColor Magenta

Write-Host ''
Write-Host 'Enterprise Vault'
Write-Host '----------------'
Write-Host ('EV zugewiesen : {0}' -f $evAssigned)
Write-Host ('Noch offen    : {0}' -f ($total - $evAssigned))

# Statistiken nur einmal abrufen (langsamer Aufruf)
$stats = $moveRequests | Get-MoveRequestStatistics

Write-Host ''
Write-Host 'Datenbanken'
Write-Host '-----------'

$stats |
    Group-Object SourceDatabase |
    Sort-Object Count -Descending |
    Select-Object Name, Count |
    Format-Table -AutoSize

Write-Host ''
Write-Host 'Status pro Datenbank'
Write-Host '--------------------'

$stats |
    Group-Object SourceDatabase, Status |
    Sort-Object Name |
    Select-Object Name, Count |
    Format-Table -AutoSize

Write-Host ''
Write-Host '=========================================='
