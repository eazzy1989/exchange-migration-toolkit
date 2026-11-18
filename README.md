# Exchange Migration Toolkit

PowerShell-Skripte für die Planung, Überwachung und Nachbereitung einer **Exchange-Postfachmigration** zwischen Datenbanken (z. B. von Exchange-2019-Einzeldatenbanken auf eine neue DAG), inklusive **Enterprise-Vault-Archivierung** und **Speicherplatz-Monitoring**.

Entstanden während meines Praktikums als Fachinformatiker für Systemintegration (2026), im Rahmen einer realen Mailbox-Migration. Alle Server-, Domänen-, Datenbank- und Gruppennamen wurden durch Platzhalter ersetzt; die Werte werden über Parameter übergeben.

## Übersicht

| Bereich | Skript | Zweck |
|---|---|---|
| Migration | [`Migrationsplanung.ps1`](Migration/Migrationsplanung.ps1) | Alle Postfächer auf den Quelldatenbanken mit Größe, Move-Status und Ziel; Fortschritt, Restvolumen; CSV-Export |
| Migration | [`Migrationsstatus.ps1`](Migration/Migrationsstatus.ps1) | Kompakter Gesamtfortschritt der Migration in Prozent |
| Migration | [`Migrations-Dashboard.ps1`](Migration/Migrations-Dashboard.ps1) | Konsolen-Dashboard einer Batch: Status je Move-Request, EV-Zuweisung, Verteilung je Datenbank |
| Migration | [`MoveRequest-Status.ps1`](Migration/MoveRequest-Status.ps1) | Laufende Move-Requests einer Batch mit Fortschritt |
| Migration | [`Grosse-Postfaecher.ps1`](Migration/Grosse-Postfaecher.ps1) | Aktive Move-Requests mit Postfächern ab einer Mindestgröße |
| Archivierung | [`EV-Gruppenzuweisung.ps1`](Archivierung/EV-Gruppenzuweisung.ps1) | Alle Benutzer einer Batch der Enterprise-Vault-Gruppe hinzufügen |
| Archivierung | [`EV-Gruppenzuweisung-NachGroesse.ps1`](Archivierung/EV-Gruppenzuweisung-NachGroesse.ps1) | Nur Benutzer ab einer Postfachgröße hinzufügen, mit Zusammenfassung |
| Monitoring | [`Exchange-StorageMonitor.ps1`](Monitoring/Exchange-StorageMonitor.ps1) | Freier Speicher auf DB-, Log- und Restore-Volumes mit Ampelstatus |

## Voraussetzungen

- Exchange Management Shell (Exchange Server 2016/2019)
- ActiveDirectory-PowerShell-Modul (für die Archivierungs-Skripte und das Dashboard)
- WinRM/CIM-Zugriff auf die Exchange-Server (für den Storage-Monitor)
- Entsprechende Berechtigungen in Exchange und AD

## Verwendung

Alle Skripte haben eine eingebaute Hilfe:

```powershell
Get-Help .\Migration\Migrationsplanung.ps1 -Full
```

Beispiele:

```powershell
# Planungsübersicht mit CSV-Export
.\Migration\Migrationsplanung.ps1 -SourceDatabasePattern 'EX2019-MDB*' -TargetDatabasePattern 'DAG01-DB*' -ExportPath 'D:\Reports'

# Dashboard einer Batch
.\Migration\Migrations-Dashboard.ps1 -BatchName 'Migration_Batch01' -EVGroup 'EV-Archiv-Standard'

# Testlauf: Wer würde der EV-Gruppe hinzugefügt?
.\Archivierung\EV-Gruppenzuweisung-NachGroesse.ps1 -BatchName 'Migration_Batch01' -SizeLimitGB 4 -WhatIf

# Speicherplatz prüfen
.\Monitoring\Exchange-StorageMonitor.ps1 -Servers 'EX01.contoso.local','EX02.contoso.local'
```

Die Skripte, die Änderungen im AD vornehmen, unterstützen `-WhatIf` und sollten zuerst damit getestet werden.

## Lizenz

[MIT](LICENSE)
