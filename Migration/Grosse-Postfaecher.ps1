<#
.SYNOPSIS
    Zeigt große Postfächer in aktiven Move-Requests einer Migrationsbatch.

.DESCRIPTION
    Listet alle aktiven Move-Requests (InProgress, Synced, CompletionInProgress,
    AutoSuspended) einer Batch auf, deren Postfach mindestens die angegebene
    Größe hat. Sortiert absteigend nach Größe.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.PARAMETER MinSizeGB
    Mindestgröße des Postfachs in GB. Standard: 4.

.EXAMPLE
    .\Grosse-Postfaecher.ps1 -BatchName 'Migration_Batch01' -MinSizeGB 10

.NOTES
    Autor:    eazzy1989
    Erstellt: 15.07.2026
    Benötigt: Exchange Management Shell
#>

param(
    [string]$BatchName = 'Migration_Batch01',
    [double]$MinSizeGB = 4
)

Get-MoveRequest -BatchName $BatchName |
    Where-Object {
        $_.Status -in @(
            'InProgress',
            'Synced',
            'CompletionInProgress',
            'AutoSuspended'
        )
    } |
    ForEach-Object {

        $MoveRequest = $_

        $MailboxStats = Get-MailboxStatistics `
            -Identity $MoveRequest.Alias `
            -ErrorAction SilentlyContinue

        if (
            $MailboxStats -and
            $MailboxStats.TotalItemSize -and
            $MailboxStats.TotalItemSize.Value.ToBytes() -ge ($MinSizeGB * 1GB)
        ) {

            [PSCustomObject]@{
                Postfach     = $MoveRequest.DisplayName
                'Größe (GB)' = [math]::Round(
                    $MailboxStats.TotalItemSize.Value.ToBytes() / 1GB,
                    2
                )
                Quelle       = $MoveRequest.SourceDatabase
                Ziel         = $MoveRequest.TargetDatabase
                Status       = $MoveRequest.Status
            }
        }
    } |
    Sort-Object 'Größe (GB)' -Descending |
    Format-Table -AutoSize
