# DayTrace

A lean, modern iPhone app for daily health journaling with a fast end-of-day flow.

## Positioning

DayTrace is designed as a personal health reflection app:
- quick evening check-in
- structured health signals
- visual trends over time
- lightweight motivation through streaks and badges

## Current Product Direction

- Working app concept built in SwiftUI
- iPhone-focused UI
- reminder-to-check-in flow
- editable historic day entries
- optional profile-based cycle tracking
- dashboard with first charts
- gamification foundation
- export-ready data model

## Suggested App Store Direction

### Name
- **Primary recommendation:** DayTrace
- Home screen display name: **DayTrace**
- Alternatives:
  - Evening Check
  - Daily Pulse
  - Health Mark
  - Quiet Check

### Core value proposition
- Track food, drinking, symptoms, and day quality in under a minute
- Spot patterns before they are forgotten
- Build consistency with light motivation, not pressure

### Publishing preparation checklist
- Replace placeholder app icon with final branded icon
- Add tint/color system and final typography pass
- Add privacy policy
- Add export/share flow
- Add onboarding and notification explanation
- Prepare App Store screenshots
- Define subscription/free strategy if needed
- Validate notification and deeplink behavior on real devices
- Add proper migration strategy for SwiftData model changes

## Features currently implemented

- Daily entry list and detail views
- Create and edit daily entries, including past dates
- Food quality tracking
- Drink flow with more visual hydration selection
- Symptom severity tracking
- Mood/day score
- Reminder scheduling
- Deeplink path into today’s check-in
- Dashboard metrics
- First chart-based history view
- Achievement/gamification foundation
- JSON export preview

## Technical stack

- SwiftUI
- SwiftData
- Charts
- UserNotifications

## Open in Xcode

1. Open `IllnessCheck.xcodeproj`
2. Select an iPhone simulator or device
3. Build and run
4. Allow notifications when prompted

## Important note

This project is created from a non-macOS coding environment, so final device validation still needs to happen in Xcode on macOS.
