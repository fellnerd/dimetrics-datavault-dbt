---
title: "Technische Referenz"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Technische Referenz

### Verbindungsdaten
- **Server:** `<sql-server>.database.windows.net`
- **Database:** `<datenbank>`
- **Auth:** Azure CLI (az login)

### VM Zugang
```bash
ssh <projekt>-dev  # Alias in ~/.ssh/config
cd ~/projects/<projekt>
source .venv/bin/activate
```

### GitHub Actions Runner
```bash
# Runner Service Status prüfen
sudo systemctl status actions.runner.<github-org>-<repo>.<runner-name>

# Runner neu starten
sudo systemctl restart actions.runner.<github-org>-<repo>.<runner-name>

# Runner Logs
journalctl -u actions.runner.<github-org>-<repo>.<runner-name> -f
```

---

◀ [CI/CD Pipeline (GitHub Actions)](12-ci-cd-pipeline-github-actions.md) · [Übersicht](00-lessons-learned.md) · [Multi-Active Satellite: Load Date muss ein BATCH-Wert sein](14-multi-active-satellite-load-date.md) ▶
