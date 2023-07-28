![App Icon](/goalie/goalie/Assets.xcassets/AppIcon.appiconset/512.png)

# Goalie

Goalie is a bespoke time tracking app for macOS. It supports macOS Ventura 13.3+.

I created Goalie for myself to track my daily Japanese language studying.

[Download the latest version from GitHub](TODO)

Today view|Today view (expanded)|Set a goal|History
-|-|-|-
![Today](/extra/main.png)|![Today](/extra/main-expanded.png)|![Set goal](/extra/set-goal.png)|![History](/extra/history.png)

## Features

- Track the time you've spent on one _topic_ over multiple _sessions_.
- Remove sessions created today.
- Set or remove a daily time goal.
- View your time tracking history week-by-week.

## Disclaimers/limitations/improvements

- I don't intended the app to be a full-featured time tracking app for every purpose. 
- The app hasn't been thoroughly QA tested, integration tested, or unit tested.
- You can only track one _topic_.
- It's a single window app (intentionally not a MenuBarExtra).
- Moving between time zones often may cause issues.
- Using non-Gregorian calendars may cause issues.
- There may be localization issues.
- The history view should use a graph.
- Proper macOS menu items should be available.

## Brief notes about the implementation

- The app is written in Swift and SwiftUI.
- Data is saved to a single file in the app's container using Codable.

## Getting started

1. Clone the repo. `$ git clone git://github.com/twocentstudios/goalie.git`
2. Open `goalie.xcodeproj`.
3. Wait for packages to resolve.
4. Build!

## License

License for source is MIT.

All rights are reserved for image assets.

## About

Goalie was created by [Christopher Trott](https://hachyderm.io/@twocentstudios). My development shop is called [twocentstudios](http://twocentstudios.com).
