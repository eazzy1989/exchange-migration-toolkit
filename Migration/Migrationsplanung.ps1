<#
.SYNOPSIS
    Erstellt eine Planungsübersicht für eine Exchange-Datenbankmigration mit CSV-Export.

.DESCRIPTION
    - Zeigt alle primären Mailboxen auf den Quelldatenbanken
    - Ermittelt die aktuelle Mailboxgröße
    - Prüft vorhandene Move-Requests
    - Zeigt den Migrationsstatus und die Zieldatenbank
    - Berechnet den Gesamtfortschritt der Migration
    - Exportiert die Ergebnisse und eine Zusammenfassung nach CSV

.PARAMETER SourceDatabasePattern
    Namensmuster der Quelldatenbanken (Wildcard), z. B. 'EX2019-MDB*'.

.PARAMETER TargetDatabasePattern
    Namensmuster der Zieldatenbanken (Wildcard), z. B. 'DAG01-DB*'.

.PARAMETER ExportPath
    Ordner für die CSV-Exporte. Wird angelegt, falls nicht vorhanden.

.PARAMETER LargeMailboxGB
    Ab dieser Größe (GB) gilt ein Postfach in der Zusammenfassung als groß. Standard: 10.

.EXAMPLE
    .\Migrationsplanung.ps1 -SourceDatabasePattern 'EX2019-MDB*' -TargetDatabasePattern 'DAG01-DB*' -ExportPath 'D:\Reports'

.NOTES
    Autor:    eazzy1989
    Erstellt: 15.07.2026
    Benötigt: Exchange Management Shell
#>

param(
    [string]$SourceDatabasePattern = 'OLD-MDB*',
    [string]$TargetDatabasePattern = 'NEW-DAG*',
    [string]$ExportPath            = '.\Migrationsplanung',
    [double]$LargeMailboxGB        = 10
)

$OldDatabases = Get-MailboxDatabase |
    Where-Object { $_.Name -like $SourceDatabasePattern } |
    Select-Object -ExpandProperty Name

if (-not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmm'

Write-Host 'Lese vorhandene Move-Requests...' -ForegroundColor Cyan

$MoveRequests = Get-MoveRequest -ResultSize Unlimited

$MoveLookup = @{}

foreach ($Move in $MoveRequests) {
    $MoveLookup[$Move.Alias.ToLower()] = $Move
}

Write-Host 'Ermittle Mailboxen auf den Quelldatenbanken...' -ForegroundColor Cyan

$Result = @(Get-Mailbox -ResultSize Unlimited |
    Where-Object { $OldDatabases -contains $_.Database.Name } |
    ForEach-Object {

        $Mailbox = $_

        Write-Progress -Activity 'Analysiere Mailboxen' -Status $Mailbox.DisplayName

        $Stats = Get-MailboxStatistics -Identity $Mailbox.PrimarySmtpAddress.ToString() -ErrorAction SilentlyContinue

        $Move = $null

        if ($MoveLookup.ContainsKey($Mailbox.Alias.ToLower())) {
            $Move = $MoveLookup[$Mailbox.Alias.ToLower()]
        }

        $MailboxGB = 0

        if ($Stats -and $Stats.TotalItemSize) {

            # In Remote-Sessions ist TotalItemSize ein String wie
            # "1.416 GB (1,520,731,308 bytes)" - daher Bytes per Regex auslesen
            $SizeString = [string]$Stats.TotalItemSize

            if ($SizeString -match '\(([0-9\.,]+)\sbytes\)') {

                $Bytes = [int64](($matches[1]) -replace '[^\d]', '')

                $MailboxGB = [math]::Round($Bytes / 1GB, 2)
            }
        }

        [PSCustomObject]@{
            DisplayName        = $Mailbox.DisplayName
            PrimarySmtpAddress = $Mailbox.PrimarySmtpAddress.ToString()
            'Größe (GB)'       = $MailboxGB
            SourceDatabase     = $Mailbox.Database.Name
            MoveStatus         = if ($Move) { $Move.Status } else { 'Nicht eingeplant' }
            TargetDatabase     = if ($Move) { $Move.TargetDatabase } else { '-' }
        }
    })

Write-Progress -Activity 'Analysiere Mailboxen' -Completed

$Result = @($Result | Sort-Object 'Größe (GB)' -Descending)

$NotPlanned = @($Result | Where-Object { $_.MoveStatus -eq 'Nicht eingeplant' }).Count
$Planned    = $Result.Count - $NotPlanned
$LargeCount = @($Result | Where-Object { $_.'Größe (GB)' -gt $LargeMailboxGB }).Count

$RemainingSizeGB = [math]::Round(
    [double](
        $Result |
        Where-Object { $_.MoveStatus -eq 'Nicht eingeplant' } |
        Measure-Object 'Größe (GB)' -Sum
    ).Sum,
    2
)

$TargetMailboxes = @(Get-Mailbox -ResultSize Unlimited |
    Where-Object { $_.Database.Name -like $TargetDatabasePattern })

$TotalMailboxes    = $Result.Count + $TargetMailboxes.Count
$MigratedMailboxes = $TargetMailboxes.Count

$ProgressPercent = if ($TotalMailboxes -gt 0) {
    [math]::Round(($MigratedMailboxes / $TotalMailboxes) * 100, 2)
}
else {
    0
}

$Summary = [PSCustomObject]@{
    Datum                  = Get-Date -Format 'yyyy-MM-dd HH:mm'
    Gesamt_Mailboxen       = $TotalMailboxes
    Migriert               = $MigratedMailboxes
    Auf_Quelle_gesamt      = $Result.Count
    Bereits_eingeplant     = $Planned
    Noch_nicht_eingeplant  = $NotPlanned
    Grosse_Mailboxen       = $LargeCount
    Restvolumen_GB         = $RemainingSizeGB
    Fortschritt_Prozent    = $ProgressPercent
}

$Result | Format-Table -AutoSize

Write-Host ''
Write-Host ('=' * 60) -ForegroundColor DarkGray
Write-Host 'Datum                  : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Datum -ForegroundColor White
Write-Host 'Gesamt_Mailboxen       : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Gesamt_Mailboxen -ForegroundColor Cyan
Write-Host 'Migriert               : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Migriert -ForegroundColor Green
Write-Host 'Auf_Quelle_gesamt      : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Auf_Quelle_gesamt -ForegroundColor Cyan
Write-Host 'Bereits_eingeplant     : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Bereits_eingeplant -ForegroundColor Green
Write-Host 'Noch_nicht_eingeplant  : ' -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Noch_nicht_eingeplant -ForegroundColor Yellow
Write-Host ("Groesser {0} GB        : " -f $LargeMailboxGB) -NoNewline -ForegroundColor DarkGray
Write-Host $Summary.Grosse_Mailboxen -ForegroundColor Magenta
Write-Host 'Restvolumen_GB         : ' -NoNewline -ForegroundColor DarkGray
Write-Host ('{0:N2}' -f $Summary.Restvolumen_GB) -ForegroundColor Cyan
Write-Host 'Fortschritt_Prozent    : ' -NoNewline -ForegroundColor DarkGray
Write-Host ('{0:N2} %' -f $Summary.Fortschritt_Prozent) -ForegroundColor Green
Write-Host ('=' * 60) -ForegroundColor DarkGray

$MailboxFile = Join-Path $ExportPath "Migrationsplanung_$Timestamp.csv"
$SummaryFile = Join-Path $ExportPath "Migrationsplanung_Summary_$Timestamp.csv"

$Result  | Export-Csv -Path $MailboxFile -Delimiter ';' -NoTypeInformation -Encoding UTF8
$Summary | Export-Csv -Path $SummaryFile -Delimiter ';' -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host 'Export gespeichert:' -ForegroundColor Cyan
Write-Host $MailboxFile -ForegroundColor Green
Write-Host $SummaryFile -ForegroundColor Green
