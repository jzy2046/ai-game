# Accessibility Requirements: 爽刷地牢

## Accessibility Tier
**Tier**: Basic

**Commitment**: Minimum viable accessibility — remapping and subtitles only.

---

## Required Features (Basic Tier)

### Input Remapping
- [ ] Touch input gestures cannot be remapped (touch-only game, no alternative input)
- [ ] No keyboard/gamepad support required

### Visual Accessibility
- [ ] Text legibility: Minimum 16px font size for all player-facing text
- [ ] No subtitle requirements (game has no dialogue audio)

### Audio Accessibility
- [ ] Volume controls per category (Music/SFX/UI) via AudioBusLayout
- [ ] No audio cues required for gameplay (visual feedback sufficient)

---

## Scope Notes

This is a touch-only mobile idle game. Core accessibility concerns:
- Touch targets must be minimum 44×44 points (iOS HIG standard)
- Important feedback must be visual + vibration (audio is supplementary)
- No time-sensitive inputs — player controls pace

**Post-MVP Consideration**:
- If player feedback requests colorblind modes, upgrade to Standard tier
- If motor accessibility concerns arise, add gesture simplification options

---

## Verification

| TR ID | Requirement | Verification |
|-------|-------------|--------------|
| TR-access-001 | Touch targets ≥44×44 | Manual check in HUD design |
| TR-access-002 | Visual+Vibration feedback | GDD feedback-system.md covers dual feedback |
| TR-access-003 | Volume per bus | AudioPool ADR-0004 covers bus layout |