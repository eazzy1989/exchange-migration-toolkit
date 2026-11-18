<#
.SYNOPSIS
    Fügt Benutzer einer Migrationsbatch ab einer Postfachgröße der Enterprise-Vault-Archivgruppe hinzu.

.DESCRIPTION
    Berücksichtigt nur Move-Requests, die weder abgeschlossen noch fehlgeschlagen
    sind. Benutzer, deren Postfach größer als -SizeLimitGB ist, werden der
    AD-Gruppe hinzugefügt. Vorhandene Mitglieder werden übersprungen.
    Am Ende gibt es eine Zusammenfassung. Unterstützt -WhatIf für einen Testlauf.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.PARAMETER Group
    AD-Gruppe für die Enterprise-Vault-Archivierung.

.PARAMETER SizeLimitGB
    Nur Postfächer größer als dieser Wert (GB) werden berücksichtigt. Standard: 4.

.EXAMPLE
    .\EV-Gruppenzuweisung-NachGroesse.ps1 -BatchName 'Migration_Batch01' -SizeLimitGB 4 -WhatIf

.NOTES
    Autor:    Ismail Yildiz
    Erstellt: 16.07.2026
    Benötigt: Exchange Management Shell, ActiveDirectory-Modul
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BatchName   = 'Migration_Batch01',
    [string]$Group       = 'EV-Archiv-Standard',
    [double]$SizeLimitGB = 4
)

$sizeLimit = $SizeLimitGB * 1GB

# Zähler
$added    = 0
$existing = 0
$skipped  = 0
$errors   = 0

# Vorhandene Gruppenmitglieder laden
$existingMembers = @((Get-ADGroup -Identity $Group -Properties Member).Member)

# MoveRequest-Statistiken laden
$moveStats = Get-MoveRequest -BatchName $BatchName |
    Where-Object {
        $_.Status -notlike 'Completed*' -and
        $_.Status -ne 'Failed'
    } |
    Get-MoveRequestStatistics

foreach ($move in $moveStats) {

    # Bytezahl aus "1.416 GB (1,520,731,308 bytes)" extrahieren
    if ([string]$move.TotalMailboxSize -match '\(([\d,\.]+)\sbytes\)') {

        $bytes = [int64]($matches[1] -replace '[^\d]', '')

        if ($bytes -le $sizeLimit) {
            Write-Host "[ÜBERSPRUNGEN] $($move.DisplayName) - $($move.TotalMailboxSize)" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        try {
            $user = Get-ADUser -Identity $move.DistinguishedName -ErrorAction Stop

            if ($user.DistinguishedName -notin $existingMembers) {

                if ($PSCmdlet.ShouldProcess($move.DisplayName, "Zu Gruppe '$Group' hinzufügen")) {
                    Add-ADGroupMember -Identity $Group -Members $user -ErrorAction Stop

                    Write-Host "[HINZUGEFÜGT] $($move.DisplayName) - $($move.TotalMailboxSize)" -ForegroundColor Green
                    $added++

                    # Mitgliedsliste aktualisieren, damit doppelte Einträge
                    # innerhalb desselben Laufs vermieden werden
                    $existingMembers += $user.DistinguishedName
                }
            }
            else {
                Write-Host "[BEREITS MITGLIED] $($move.DisplayName) - $($move.TotalMailboxSize)" -ForegroundColor Yellow
                $existing++
            }
        }
        catch {
            Write-Host "[FEHLER] $($move.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
    else {
        Write-Host "[FEHLER] Größe konnte nicht gelesen werden: $($move.DisplayName)" -ForegroundColor Red
        $errors++
    }
}

Write-Host ''
Write-Host '==============================' -ForegroundColor Cyan
Write-Host 'Zusammenfassung' -ForegroundColor Cyan
Write-Host '==============================' -ForegroundColor Cyan
Write-Host ('Hinzugefuegt             : {0}' -f $added)    -ForegroundColor Green
Write-Host ('Bereits Mitglied         : {0}' -f $existing) -ForegroundColor Yellow
Write-Host ('Uebersprungen (<= {0} GB) : {1}' -f $SizeLimitGB, $skipped) -ForegroundColor DarkGray
Write-Host ('Fehler                   : {0}' -f $errors)   -ForegroundColor Red
