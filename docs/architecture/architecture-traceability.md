# Architecture Traceability Index

## Purpose

This document maps Technical Requirements (TR IDs) from GDDs to Architecture Decision Records (ADRs), ensuring every design requirement has architectural coverage.

---

## TR → ADR Coverage Matrix

### Foundation Layer (Complete Coverage Required)

| TR ID | GDD Source | Requirement | ADR Coverage | Status |
|-------|------------|-------------|--------------|--------|
| TR-save-001 | save-system.md | JSON serialization format | ADR-0001 | ✅ |
| TR-save-002 | save-system.md | Atomic write pattern | ADR-0001 | ✅ |
| TR-save-003 | save-system.md | SHA-256 checksum integrity | ADR-0001 | ✅ |
| TR-save-004 | save-system.md | Time anomaly detection | ADR-0001 | ✅ |
| TR-save-005 | save-system.md | Save version migration | ADR-0001 | ✅ |
| TR-fileaccess-001 | breaking-changes.md | FileAccess 4.4 error handling | ADR-0001 | ✅ |
| TR-signal-001 | systems-index.md | Signal naming convention | ADR-0002 | ✅ |
| TR-signal-002 | systems-index.md | Direct subscription pattern | ADR-0002 | ✅ |
| TR-particle-001 | particle-system.md | GPUParticles2D pooling | ADR-0003 | ✅ |
| TR-particle-002 | particle-system.md | Preset configuration | ADR-0003 | ✅ |
| TR-particle-003 | breaking-changes.md | .restart(keep_seed) usage | ADR-0003 | ✅ |
| TR-audio-001 | audio-system.md | AudioStreamPlayer pool sizing | ADR-0004 | ✅ |
| TR-audio-002 | audio-system.md | Bus layout configuration | ADR-0004 | ✅ |
| TR-ui-001 | ui-layout-system.md | Anchor preset application | ADR-0005 | ✅ |
| TR-ui-002 | ui-layout-system.md | Safe area handling | ADR-0005 | ✅ |

**Foundation Layer Status**: ✅ COMPLETE (15 TR IDs → 5 ADRs)

---

### Core Layer (Coverage Required Before Implementation)

| TR ID | GDD Source | Requirement | ADR Coverage | Status |
|-------|------------|-------------|--------------|--------|
| TR-input-001 | touch-input-system.md | Touch gesture thresholds | ADR-0006 | ❌ GAP |
| TR-input-002 | touch-input-system.md | Layer routing | ADR-0006 | ❌ GAP |
| TR-input-003 | touch-input-system.md | Modal blocking | ADR-0006 | ❌ GAP |
| TR-combat-001 | combat-system.md | Timer-driven combat loop | ADR-0007 | ❌ GAP |
| TR-combat-002 | combat-system.md | Damage variance formula | ADR-0007 | ❌ GAP |
| TR-combat-003 | combat-system.md | Skip mechanism compression | ADR-0007 | ❌ GAP |
| TR-state-001 | enemy-system.md | Enemy state machine | ADR-0008 | ❌ GAP |
| TR-state-002 | enemy-system.md | State transition timing | ADR-0008 | ❌ GAP |
| TR-enhance-001 | enhancement-formula.md | Enhancement formula | ADR-0009 | ❌ GAP |
| TR-enhance-002 | enhancement-formula.md | Material cost tiers | ADR-0009 | ❌ GAP |
| TR-offline-001 | offline-yield-system.md | Offline duration capping | ADR-0010 | ❌ GAP |
| TR-offline-002 | offline-yield-system.md | Material stack cap | ADR-0010 | ❌ GAP |
| TR-regist-001 | item-database.md | Registry ownership model | ADR-0011 | ❌ GAP |

**Core Layer Status**: ❌ 6 ADRs Required (ADR-0006 through ADR-0011)

---

### Feature/Presentation Layer (Can defer to Implementation)

| TR ID | GDD Source | Requirement | ADR Coverage | Status |
|-------|------------|-------------|--------------|--------|
| TR-feedback-001 | visual-feedback.md | Feedback coordination | ADR-0012 | ⏳ Deferred |
| TR-feedback-002 | visual-feedback.md | Layered feedback queue | ADR-0012 | ⏳ Deferred |
| TR-drop-001 | drop-table-system.md | RNG strategy | ADR-0013 | ⏳ Deferred |
| TR-dungeon-001 | dungeon-advancement.md | Floor state persistence | ADR-0014 | ⏳ Deferred |
| TR-slot-001 | equipment-slot-system.md | Slot compatibility matrix | ADR-0015 | ⏳ Deferred |

**Feature Layer Status**: ⏳ 4 ADRs Deferred (implementation-phase)

---

## Summary

| Layer | TR IDs | ADRs Required | ADRs Written | Gaps |
|-------|--------|---------------|--------------|------|
| Foundation | 15 | 5 | 5 | 0 ✅ |
| Core | 13 | 6 | 0 | 6 ❌ |
| Feature | 5 | 4 | 0 | 4 ⏳ |
| **Total** | **33** | **15** | **5** | **10** |

**Gate Status**: Foundation layer complete. Core layer ADRs required before Pre-Production → Production transition.

---

## Last Updated
- Date: 2026-05-02
- Updated by: gate-check (automated traceability generation)