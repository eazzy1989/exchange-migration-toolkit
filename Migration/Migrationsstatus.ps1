<#
.SYNOPSIS
    Zeigt den Gesamtfortschritt einer Exchange-Datenbankmigration.

.DESCRIPTION
    Vergleicht primäre Mailboxen auf den Quelldatenbanken mit den bereits
    auf die Zieldatenbanken migrierten Mailboxen, prüft aktive Move-Requests
    einer Batch und zeigt offene Mailboxen sowie den Fortschritt in Prozent.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.PARAMETER SourceDatabasePattern
    Namensmuster der Quelldatenbanken (Wildcard), z. B. 'EX2019-MDB*'.

.PARAMETER TargetDatabasePattern
    Namensmuster der Zieldatenbanken (Wildcard), z. B. 'DAG01-DB*'.

.EXAMPLE
    .\Migrationsstatus.ps1 -BatchName 'Migration_Batch01' -SourceDatabasePattern 'EX2019-MDB*' -TargetDatabasePattern 'DAG01-DB*'

.NOTES
    Autor:    eazzy1989
    Erstellt: 15.07.2026
    Benötigt: Exchange Management Shell
#>

param(
    [string]$BatchName             = 'Migration_Batch01',
    [string]$SourceDatabasePattern = 'OLD-MDB*',
    [string]$TargetDatabasePattern = 'NEW-DAG*'
)

$OldDatabases = Get-MailboxDatabase |
    Where-Object { $_.Name -like $SourceDatabasePattern } |
    Select-Object -ExpandProperty Name

# Mailboxen auf den Quelldatenbanken
$OldMailboxes = @(Get-Mailbox -ResultSize Unlimited |
    Where-Object { $OldDatabases -contains $_.Database.Name })

# Bereits migrierte Mailboxen auf den Zieldatenbanken
$MigratedMailboxes = @(Get-Mailbox -ResultSize Unlimited |
    Where-Object { $_.Database.Name -like $TargetDatabasePattern })

# Aktive Move-Requests der definierten Batch
$OpenMoves = @(Get-MoveRequest -BatchName $BatchName -ErrorAction SilentlyContinue |
    Where-Object { $_.Status -notin @('Completed', 'CompletedWithWarning') })

$OpenAliases = $OpenMoves | Select-Object -ExpandProperty Alias

# Mailboxen auf den Quelldatenbanken ohne Move-Request in dieser Batch
$Pending = @($OldMailboxes |
    Where-Object { $_.Alias -notin $OpenAliases })

$Total = $OldMailboxes.Count + $MigratedMailboxes.Count

$Progress = if ($Total -gt 0) {
    [math]::Round(($MigratedMailboxes.Count / $Total) * 100, 2)
}
else {
    0
}

$Result = [PSCustomObject]@{
    Datum                 = Get-Date -Format 'yyyy-MM-dd HH:mm'
    BatchName             = $BatchName
    Gesamt_Mailboxen      = $Total
    Migriert              = $MigratedMailboxes.Count
    Auf_Quelle_gesamt     = $OldMailboxes.Count
    Aktive_MoveRequests   = $OpenMoves.Count
    Noch_nicht_eingeplant = $Pending.Count
    Fortschritt_Prozent   = $Progress
}

Write-Host ''
Write-Host ('=' * 60) -ForegroundColor DarkGray

Write-Host 'Datum                 : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Datum -ForegroundColor White

Write-Host 'BatchName             : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.BatchName -ForegroundColor Cyan

Write-Host 'Gesamt_Mailboxen      : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Gesamt_Mailboxen -ForegroundColor Cyan

Write-Host 'Migriert              : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Migriert -ForegroundColor Green

Write-Host 'Auf_Quelle_gesamt     : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Auf_Quelle_gesamt -ForegroundColor Yellow

Write-Host 'Aktive_MoveRequests   : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Aktive_MoveRequests -ForegroundColor Green

Write-Host 'Noch_nicht_eingeplant : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Result.Noch_nicht_eingeplant -ForegroundColor Yellow

Write-Host 'Fortschritt_Prozent   : ' -NoNewline -ForegroundColor DarkGray
Write-Host ('{0:N2} %' -f $Result.Fortschritt_Prozent) -ForegroundColor Magenta

Write-Host ('=' * 60) -ForegroundColor DarkGray
