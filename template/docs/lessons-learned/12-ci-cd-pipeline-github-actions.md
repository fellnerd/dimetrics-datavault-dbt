---
title: "CI/CD Pipeline (GitHub Actions)"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# CI/CD Pipeline (GitHub Actions)

### Implementierte Workflows

| Workflow | Datei | Trigger | Funktion |
|----------|-------|---------|----------|
| **CI** | `.github/workflows/ci.yml` | PR nach main/dev + Path Filter | dbt compile + dbt test |
| **Deploy Dev** | `.github/workflows/deploy-dev.yml` | Push auf main + manual | dbt run → Vault DB |
| **Deploy Prod** | `.github/workflows/deploy-prod.yml` | Tag v* + manual + Approval | dbt run → Prod-DB |
| **Docs** | `.github/workflows/docs.yml` | Push auf main + manual | dbt docs → GitHub Pages |

### Path Filter Konfiguration
Workflows werden **nur** bei Änderungen an folgenden Pfaden getriggert:
- `models/**`, `macros/**`, `seeds/**`, `snapshots/**`, `tests/**`
- `dbt_project.yml`, `packages.yml`

**Kein Trigger bei:** `docs/**`, `*.md`

### Wichtige Ressourcen

| Ressource | Wert |
|-----------|------|
| **Service Principal** | `sp-github-<projekt>` |
| **Self-hosted Runner** | `<runner-name>` auf eigener VM |
| **GitHub Secrets** | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |
| **GitHub Pages** | `https://<github-org>.github.io/<repo>/` |
| **Environments** | `development`, `production` (mit Approval) |

### CI/CD Lessons Learned

1. **Profile-Name muss übereinstimmen:** `profiles.yml` Profile-Name muss mit `dbt_project.yml` → `profile:` übereinstimmen (z. B. `datavault`, nicht eine abweichende Variante wie `datavault_prod`)

2. **DBT_PROFILES_DIR beachten:** Wenn `DBT_PROFILES_DIR` gesetzt ist, muss `profiles.yml` dort erstellt werden, nicht in `~/.dbt/`

3. **GitHub Pages vorher aktivieren:** Docs-Workflow schlägt fehl, wenn GitHub Pages nicht aktiviert ist

4. **Seeds in Prod:** `ref_role` Seed existiert nur in Dev - bei Prod-Deployment müssen Seeds mit `dbt seed --target prod` geladen werden

5. **Runner Version:** Aktuelle Runner-Version dynamisch ermitteln statt hardcoden

---

◀ [Best Practices (gelernt)](10-best-practices-gelernt.md) · [Übersicht](00-lessons-learned.md) · [Technische Referenz](13-technische-referenz.md) ▶
