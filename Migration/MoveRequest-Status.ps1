<#
.SYNOPSIS
    Zeigt den Status aller noch laufenden Move-Requests einer Batch.

.DESCRIPTION
    Listet alle Move-Requests einer Batch, die weder abgeschlossen noch
    fehlgeschlagen sind, nummeriert und sortiert nach Status und Fortschritt.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.EXAMPLE
    .\MoveRequest-Status.ps1 -BatchName 'Migration_Batch01'

.NOTES
    Autor:    Ismail Yildiz
    Erstellt: 16.06.2026
    Benötigt: Exchange Management Shell
#>

param(
    [string]$BatchName = 'Migration_Batch01'
)

$i = 1

Get-MoveRequest -BatchName $BatchName |
    Where-Object {
        $_.Status -notlike 'Completed*' -and
        $_.Status -ne 'Failed'
    } |
    Get-MoveRequestStatistics |
    Sort-Object Status, PercentComplete |
    ForEach-Object {
        [PSCustomObject]@{
            Nr              = $i
            DisplayName     = $_.DisplayName
            Status          = $_.Status
            PercentComplete = $_.PercentComplete
        }

        $i++
    } |
    Format-Table -AutoSize
