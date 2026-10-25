---
title: "Business Vault"
aliases:
  - "Business Vault"
tags:
  - architektur/business-vault
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Mandanten-Architektur & Projekt](../00-mandant-architektur.md)

# Business Vault

Abgeleitete Objekte dieses Projekts. Muster: [Objekte anlegen → Business Vault](../../02-entwickler/04-objekte-anlegen/business-vault/00-business-vault.md).

## Fachliche Regeln

| Objekt | Quelle | Inhalt | Konsument |
|--------|--------|--------|-----------|
| `<thema>_v` | Seed/Satellite | <Regel> | `dim_<…>` |

## Current Views

| Domäne | Views |
|--------|-------|
| <Domäne> | `sat_<entity>__<quelle>_current_v` |

## PIT und Bridges

| Objekt | Hub | Satellites | Grund |
|--------|-----|------------|-------|
| — | | | |
