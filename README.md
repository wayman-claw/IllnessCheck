# IllnessCheck

A lean, modern iPhone app concept for daily health journaling with a quick end-of-day flow.

## Goals

- Fast and low-friction evening check-in
- Structured data for future analysis
- Easy editing of any recorded day
- Simple reminders at configurable times
- iPhone 13 compatible target
- Modern SwiftUI design

## Planned Stack

- SwiftUI
- SwiftData (iOS 17+)
- UserNotifications
- Export-friendly domain model

## Current Status

This repository was generated in a non-macOS environment, so the project cannot be built or validated here with Xcode yet.
However, the code and Xcode project structure are prepared for opening on a Mac with Xcode.

## Features in v2

- Daily entry list with richer summaries
- Create and edit daily entries
- Food quality tracking
- Faster drink flow:
  - overall drinking level
  - coffee yes/no
  - softdrinks yes/no
  - alcohol none/little/medium/much
  - water none/little/medium/much
  - free-text for other drinks
- Symptom severity tracking
- Symptom presets for quicker input
- Notes for custom context
- Reminder scheduling UI
- Export-friendly structure for later analytics

## Development note

The data model changed between iterations. If you see a SwiftData container load error on a simulator/device with older local app data, the current app now attempts to reset the incompatible local store and recover automatically.

## Open in Xcode

1. Open `IllnessCheck.xcodeproj`
2. Select an iPhone simulator (e.g. iPhone 13)
3. Build and run
4. Allow notifications when prompted

## Recommended next steps

- Validate the project in Xcode on macOS
- Refine spacing, colors and typography after first device test
- Add JSON / CSV export
- Add weekly trends and simple correlations
- Consider optional Apple Health integration later
