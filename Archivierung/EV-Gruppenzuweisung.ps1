<#
.SYNOPSIS
    Fügt alle Benutzer einer Migrationsbatch der Enterprise-Vault-Archivgruppe hinzu.

.DESCRIPTION
    Liest alle Move-Requests einer Batch, ermittelt die zugehörigen AD-Benutzer
    und fügt sie der Archivierungsgruppe hinzu. Bereits vorhandene Mitglieder
    werden übersprungen. Unterstützt -WhatIf für einen Testlauf.

.PARAMETER BatchName
    Name der Exchange-Migrationsbatch.

.PARAMETER Group
    AD-Gruppe für die Enterprise-Vault-Archivierung.

.EXAMPLE
    .\EV-Gruppenzuweisung.ps1 -BatchName 'Migration_Batch01' -WhatIf

.NOTES
    Autor:    Ismail Yildiz
    Erstellt: 15.07.2026
    Benötigt: Exchange Management Shell, ActiveDirectory-Modul
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BatchName = 'Migration_Batch01',
    [string]$Group     = 'EV-Archiv-Standard'
)

# Vorhandene Mitglieder laden
$existingMembers = @((Get-ADGroup $Group -Properties member).member)

Get-MoveRequest -BatchName $BatchName |
    Get-Mailbox |
    ForEach-Object {

        $user = Get-ADUser $_.SamAccountName

        if ($user.DistinguishedName -notin $existingMembers) {
            if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Zu Gruppe '$Group' hinzufügen")) {
                Add-ADGroupMember -Identity $Group -Members $user
                Write-Host "[HINZUGEFÜGT] $($user.SamAccountName)" -ForegroundColor Green
            }
        }
        else {
            Write-Host "[BEREITS MITGLIED] $($user.SamAccountName)" -ForegroundColor Yellow
        }
    }
