# Bug-Position-Challenge-Play-Not-Disabled

Status: untriaged
Filed: 2026-09-18

`PlaneControlView` already has an `isChallengeActive` parameter that disables Play/Pause, with a
doc comment noting it exists so "an active position challenge's guess placement can't be disturbed
by an animated flight." `MapView`'s own call site hardcodes `isChallengeActive: false`, and
`Cockpit-And-App-Shell-2-Mode-Navigation` Task 3 explicitly keeps `MapView` free of
Position-Challenge-specific state or conditional branches, so `PositionChallengeView` has no way to
pass this flag through today. A player can press Play during an active Position Challenge and have
the plane fly away from their guess marker.
