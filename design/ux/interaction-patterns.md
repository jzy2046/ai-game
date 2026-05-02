# Interaction Pattern Library: 爽刷地牢

## Overview

This document catalogs UI interaction patterns used in the game. Each pattern defines:
- Touch gesture
- Visual feedback
- Expected outcome
- Edge cases

---

## Pattern 1: Tap to Select

**Gesture**: Single tap on UI element
**Visual Feedback**:
- Button: Scale bounce (0.95→1.0, 100ms)
- Audio: UI click sound (button_clicked signal)
**Outcome**: Element selected, action triggered
**Edge Cases**:
- Tap on disabled element: No feedback, no action
- Tap during modal: Blocked if target not in modal layer

---

## Pattern 2: Tap to Collect Drop

**Gesture**: Tap on equipment drop item in drop panel
**Visual Feedback**:
- Item: Glow pulse (1.0→1.2 scale, 200ms)
- Audio: collect sound
**Outcome**: Item added to inventory, panel updates
**Edge Cases**:
- Tap on already-collected item: No action
- Tap when inventory full: Error tooltip, no collection

---

## Pattern 3: Skip Combat (Hold)

**Gesture**: Hold skip button for 500ms (HOLD_DURATION_MIN)
**Visual Feedback**:
- Progress ring fills during hold
- Audio: skip_start when threshold reached
**Outcome**: Combat timeline compressed to 0.3s batches
**Edge Cases**:
- Release before threshold: No skip, combat continues normal
- Skip during boss fight: Allowed, same compression

---

## Pattern 4: Enhancement Confirmation (Tap)

**Gesture**: Tap "Enhance" button in enhancement panel
**Visual Feedback**:
- Button: Pressed state
- Particle: Enhancement Flash (tier based on level)
- Audio: enhance_success
**Outcome**: Equipment level +1, stats updated
**Edge Cases**:
- Insufficient materials: Error tooltip, no action
- Insufficient gold: Error tooltip, no action
- Already at MAX_ENHANCEMENT_LEVEL: Button disabled

---

## Pattern 5: Claim Offline Reward (Tap)

**Gesture**: Tap "Claim" button on offline reward panel
**Visual Feedback**:
- Button: Pressed state
- Particle: Gold Burst (tier based on reward size)
- Audio: gold_collect
**Outcome**: Gold/materials added, panel dismissed
**Edge Cases**:
- Tap before calculation complete: Blocked, calculation async
- Multiple claims: Panel singleton, no duplicate

---

## Touch Target Size Standards

| Element Type | Minimum Size | Recommended |
|--------------|--------------|-------------|
| Primary buttons | 44×44 pt | 48×48 pt |
| Drop items | 60×60 pt | 64×64 pt |
| Skip button | 44×44 pt | 50×50 pt |
| HUD stats | 32×32 pt (icon only) | N/A (display, not interactive) |

---

## Layer Blocking Rules

| Layer | Priority | Blocks Lower? |
|-------|----------|---------------|
| Game (0) | Lowest | No |
| Popup (1) | Medium | Yes (game layer blocked) |
| Modal (2) | Highest | Yes (all layers blocked) |

**Modal examples**: Offline reward panel, enhancement panel
**Popup examples**: Drop comparison panel