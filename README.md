# DuoFlow for iPhone

**Two screens. One smarter you.**

The iPhone app is DuoFlow's personal command center: an adaptive dashboard for calendar, reminders, notes, projects, and Stand Mode.

## Product scope

- Home dashboard with clock, date, weather, next event, priorities, and quick capture
- Adaptive layouts for compact and expanded available space
- Manually activated Stand Mode with time-aware dashboard profiles
- Calendar, tasks, projects, notes, and settings
- Widget customization and accessibility support
- Companion data exchange with [DuoFlow for watchOS](https://github.com/Skeeb32/DuoFlow-watchOS)

## Technical direction

- Native Swift and SwiftUI
- SwiftData for local-first app data where appropriate
- EventKit and WeatherKit only after clear permission flows
- WatchConnectivity for nearby iPhone–Watch updates; CloudKit sync is optional
- WidgetKit and App Intents for supported system integrations

Layouts should adapt to the space reported by SwiftUI. Do not assume private fold, hinge, or posture APIs, or show fabricated live personal data.

## Development status

Repository foundation. Implementation and supported deployment targets are to be defined as development begins.

## Related repository

- [DuoFlow for watchOS](https://github.com/Skeeb32/DuoFlow-watchOS) — glanceable companion, quick actions, widgets, and complications.
