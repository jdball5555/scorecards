# Changelog

All notable changes to this project are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org): **major** for redesigns, **minor** for new features, **patch** for fixes.

## [1.0.5] — 2026-11-26

### Added
- README screenshot of split-screen scoring

### Fixed
- The website sidebar showing v1.0.3 after the 1.0.4 release

## [1.0.4] — 2026-11-25

### Changed
- Feedback no longer lives in Scorecards' database: the app sends it to Axis Optic, my developer project, through its `feedback` function, which checks the user's sign-in and shows them only their own tickets. The feedback collection is gone from the rules and tests
- The admin connection for my developer app, Console, is `functions/console.js` (was `optic.js`), and it accepts calls only from Axis Optic's Google-signed service accounts, with no shared secrets

## [1.0.3] — 2026-11-25

### Changed
- Split screen redesigned: the two pages sit edge to edge with no black bar between them, separated by a thin line with a small six-dot grip for resizing
- On the website, the left pane keeps the frame's rounded corner and sidebar border; stacked panes round the top page's bottom-left corner into the divider
- In split screen, Metrics and its stat pages hide the scope / game / player subtitle so both panes' top bars line up (the tune button opens the same settings)
- Each pane lays out for its own width, so the Customize Scorecard tiles fill their pane, and the divider stops where a page would no longer fit
- Stacked split screen puts the scorecard on top again (Flip Screens swaps it)

### Fixed
- The website's left border line stopping at the scorecard's bottom bar instead of running to the bottom of the page
- In the app, split screen panes reserving space for the notch or home indicator on edges they don't touch

## [1.0.2] — 2026-11-22

### Fixed
- Spades ignoring the 1st and 2nd bidder picked during setup: quick bid and the highlighted starting bidder now follow the chosen order, games already in progress pick it up, and rematches keep it

## [1.0.1] — 2026-11-16

### Security
- Database rules rewritten so each person only reaches what the app needs: personal scorecards, mail, settings and templates are private to their owner, groups and their scorecards are visible only to members, and joining a group needs a real invite (a pending invite from a member, or an unused invite link)
- Profiles can no longer be listed or searched; finding an account by email for an invite goes through a new Cloud Function
- In-app mail and notifications can only come from someone in the same group, and premium beta can't be switched on from the app
- Removed two old one-time admin tools from the Axis migration screen that worked across everyone's scorecards

### Added
- Tests for the database rules, run against the Firestore emulator (`firestore_tests/`)

### Changed
- Accepting an invite joins the group first, then takes the local player's place, so the rules can check the invite

### Fixed
- New scorecards not offering the custom games a group has already played

## [1.0.0] — 2026-11-15

### Added
- "Invite with a link" for local players: the person opens the link, signs in or makes an account, and takes the player's place in the group along with their past games
- Redesigned stats screen (Average Score, Win Rate): range picker, headline numbers with a comparison to the previous period, a chart of every game with a rolling average, a score-spread chart, and a games list that opens 10 at a time
- Premium beta, a developer testing mode switched on per account from Axis Optic, for trying features before they're released to everyone; custom templates (template builder, saved templates and rulebook scanner) are behind it for now, and premium beta accounts see a small "Premium beta" note in Settings
- Database rules that only let premium beta accounts save templates
- Tests for premium beta and the stats screen

### Changed
- Sign-in page: the form sits in a compact, rounded card on the tinted background, matching the rest of the website
- App icons: a rounded square on the website and desktop, a circle on Android, and a full square on iPhone
- Folding the website sidebar is smooth, and the page content glides with it
- Website pages switch instantly instead of sliding in from the side
- Invite links point to scorecards.axisoptic.com
- The website's version file can be read by the Optic dashboard
- Cloud Functions run on Node.js 22, and the Optic admin endpoint only accepts calls from Optic

### Fixed
- Metrics freezing for a few seconds when opened with lots of games (now about 0.2 seconds)
- A brief flash of the wrong page when switching pages from the sidebar
- Overflow errors in the group member pop-up on phones
- A white strip around the bottom gesture bar in Android Chrome
- The Home greeting showing "Player" right after making a new account
- The version shown in Settings

## [0.2.0] — 2026-11-13

### Added
- Scorecards for Spades, Nerts, Nines, Pit, Poker, Wavelength, Yahtzee and a standard points game
- Custom template builder for any game's setup, data entry and scoring
- Rulebook scanner using on-device text recognition
- Per-game metrics and charts, with customizable views
- Split-screen scoring with live stats
- Group customization
- Axis migration, importing game history from Axis App
- Responsive web version with a sidebar layout, hosted at scorecards.axisoptic.com
- In-app feedback form connected to the Optic developer dashboard
- Group notifications with the results when a game is finished
- Unit tests for templates, the rulebook parser and the feedback form

### Changed
- New branding: app logo, app mark and icons
- Refreshed home, groups, settings and sign-in screens

## [0.1.0] — 2026-06-02

### Added
- Firebase Authentication with email/password and Google sign-in
- Global and local notification system with a mail inbox
- Game groups and invitations
- Feature-first project structure

[1.0.1]: https://github.com/jdball5555/scorecards/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/jdball5555/scorecards/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/jdball5555/scorecards/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jdball5555/scorecards/releases/tag/v0.1.0
