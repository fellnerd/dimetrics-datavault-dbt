---
title: "Reference Table erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Reference Table erstellen

📄 **Beispiele im Repository:** [seeds/](../../../../seeds) (Reference Data als CSV) und `models/raw_vault/_common/refs`

**Schritt 1:** CSV-Datei erstellen

```csv
role_code,role_name,role_description
CLIENT,Kunde,Unternehmen das Dienstleistungen bezieht
CONTRACTOR,Auftragnehmer,Unternehmen das Aufträge ausführt
SUPPLIER,Lieferant,Unternehmen das Waren liefert
```

📄 **Speichern als:** `seeds/ref_<name>.csv`

**Schritt 2:** Konfiguration in dbt_project.yml

📄 **Datei:** [dbt_project.yml](../../../../dbt_project.yml)

```yaml
seeds:
  datavault:
    +schema: vault
    ref_<name>:
      +column_types:
        <column>: VARCHAR(50)
```

**Schritt 3:** Deployment

```bash
dbt seed --select ref_<name>
```

---

◀ [Multi-Active Satellite (MA Sat) erstellen](07-multi-active-satellite.md) · [Übersicht](00-raw-vault.md) · [Attribut hinzufügen](09-attribut-hinzufuegen.md) ▶
