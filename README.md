# DuoFlow for iPhone

**Two screens. One smarter you.**

DuoFlow for iPhone is the personal command center: an adaptive dashboard for daily priorities, tasks, notes, and a manually activated Stand Mode.

## Current MVP

- Adaptive dashboard that switches between compact and two-column layouts based on available width
- Manual Stand Mode with clock, agenda preview, and priority tasks
- Add, complete, and delete tasks; task state persists locally
- Quick notes and a three-tab Today / Tasks / Notes navigation
- WatchConnectivity task snapshots and watch-to-phone task completion / quick-note messages
- Sample agenda and weather are labeled as previews; no live personal data is fabricated

## Open and run

Open `DuoFlow.xcodeproj` in Xcode and run the `DuoFlow` scheme on an iOS 17 or later simulator or device. Set the development team in Signing & Capabilities for device installation.

To pair the companion app, use the matching bundle identifiers configured in [DuoFlow for watchOS](https://github.com/Skeeb32/DuoFlow-watchOS), sign both apps with the same team, and install them on a paired iPhone and Apple Watch.

## Next

Connect EventKit and WeatherKit through contextual permission flows, then expand dashboard customization and persistence. Layouts use reported SwiftUI space; they do not depend on private hinge or posture APIs.

## Companion

- [DuoFlow for watchOS](https://github.com/Skeeb32/DuoFlow-watchOS)
