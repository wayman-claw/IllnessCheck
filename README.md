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

## Features in v4

- Visual home screen with hero card and recent-day cards
- Dedicated day detail screen instead of only list-to-form flow
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
- Cleaner card-based editor UI
- Reminder scheduling UI with a more polished layout
- Deeplink support from notifications straight into today's check-in
- JSON export preview for later analysis workflows
- Small overview metrics on the home screen

## Development note

The data model changed between iterations. If you see a SwiftData container load error on a simulator/device with older local app data, the current app now attempts to reset the incompatible local store and recover automatically.

## Open in Xcode

1. Open `IllnessCheck.xcodeproj`
2. Select an iPhone simulator (e.g. iPhone 13)
3. Build and run
4. Allow notifications when prompted
5. Tap a reminder notification to jump directly into today's check-in

## Recommended next steps

- Validate deeplink behavior on a real device and simulator
- Add share sheet / file export for JSON and CSV
- Add weekly trends and simple correlations
- Add app icon and brand polish
- Consider optional Apple Health integration later
