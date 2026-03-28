# WhereAreYou? for LB-Phone

Japanese README: [README_ja.md](README_ja.md)

Find out where your friends are right away.
Meet up faster, chat more, and keep the game session connected.

WhereAreYou? is a location-sharing app for FiveM + LB-Phone.
It combines map visibility, ghost mode controls, friend management, timeline posts, and reactions in one app.

This project was built mainly with **GitHub Copilot** and reached a working state in about **15 hours**.

## Installation

### 1. Place the release ZIP

1. Download the latest ZIP from GitHub Releases.
2. Extract the ZIP file.
3. The ZIP filename includes the version tag, but the extracted folder name is always `lb-app-where-are-you`.
4. Put the extracted resource folder under your FiveM server's `resources` directory.
5. Add `ensure lb-app-where-are-you` to `server.cfg`.

### 2. Run SQL

Execute `sql.sql` against your current database (typically the one connected via oxmysql).

This SQL creates tables for player profiles, friend relationships, groups, posts, and reactions.

### 3. Minimum folder check

After placement, confirm that the resource root includes at least the following:

```text
lb-app-where-are-you/
	fxmanifest.lua
	config.lua
	client/
	server/
	ui/dist/
	sql.sql
```

## Configuration (`config.lua`)

Main configuration entries:

| Item                            |                 Default value | Description                                           |
| ------------------------------- | ----------------------------: | ----------------------------------------------------- |
| `Config.Identifier`             |                 `whereareyou` | App identifier in LB-Phone (unique value recommended) |
| `Config.Name`                   |                `WhereAreYou?` | App display name                                      |
| `Config.Description`            | `Friend location sharing app` | App description                                       |
| `Config.Developer`              |        `lb-app-where-are-you` | Developer/resource name label                         |
| `Config.DefaultApp`             |                       `false` | Auto-install for all players                          |
| `Config.PositionPushIntervalMs` |                        `2000` | Position push interval (ms)                           |
| `Config.BlurGridSize`           |                       `200.0` | Coordinate rounding size for blurred display          |
| `Config.WalkSpeedThreshold`     |                         `1.2` | Minimum speed threshold for walking state             |
| `Config.VehicleSpeedThreshold`  |                         `8.0` | Minimum speed threshold for vehicle movement          |
| `Config.NearbyRadiusDefault`    |                        `30.0` | Default nearby notification radius                    |
| `Config.NearbyNotifyEnabled`    |                       `false` | Initial nearby notification ON/OFF                    |
| `Config.NearbyNotifyIntervalMs` |                       `10000` | Nearby check interval (ms)                            |
| `Config.NearbyNotifyCooldownMs` |                       `60000` | Cooldown before notifying about the same player again |
| `Config.PostCooldownMs`         |                       `30000` | Check-in post cooldown (ms)                           |

## Features

### Core features

| Map screen                                                     | Ghost mode settings                                                     |
| -------------------------------------------------------------- | ----------------------------------------------------------------------- |
| <img src="docs/images/1_en.png" alt="Map screen" height="360"> | <img src="docs/images/6_en.png" alt="Ghost mode settings" height="360"> |

- First-run consent flow (only on first launch)
- Friend location rendering on map (Leaflet tile map)
- One-tap return to your own location (GPS button)
- View filters (All / Friends / Groups)

### Ghost mode and visibility control

- Global status switch (Normal / Hidden)
- Friend visibility mode switch (GPS / Offline / Cell Tower)
- Per-group visibility mode switch
- Stop location sharing on emergency off

### Friends

| Add friend                                                     | Friends list                                                     |
| -------------------------------------------------------------- | ---------------------------------------------------------------- |
| <img src="docs/images/2_en.png" alt="Add friend" height="360"> | <img src="docs/images/3_en.png" alt="Friends list" height="360"> |

- Send requests from nearby player candidates
- Send requests by ID/name search
- Accept / Decline / Block / Unblock
- Friend detail dialog
- Friend removal confirmation dialog

### Timeline

| Timeline                                                     |
| ------------------------------------------------------------ |
| <img src="docs/images/7_en.png" alt="Timeline" height="360"> |

- Current location check-in posts
- Post list (relative timestamps)
- Jump map view to post location
- Delete posts
- Send reactions (stamp + short message)
- Delete reactions

### Groups

| Join or create group                                                     | Groups list                                                     |
| ------------------------------------------------------------------------ | --------------------------------------------------------------- |
| <img src="docs/images/4_en.png" alt="Join or create group" height="360"> | <img src="docs/images/5_en.png" alt="Groups list" height="360"> |

- Create / join groups (modal input)
- Joined group list
- Member display
- Leave group

### Settings

- Nearby notification ON/OFF
- Nearby notification radius
- Nearby check interval
- Withdraw account (delete related data)

## Operational Notes

- The location tracking implementation is designed to keep game server and database server load as low as possible.
- Large-scale testing with many concurrent players has not been fully completed yet, so please monitor server load after introducing this resource.
- Feedback and pull requests are always welcome.

----

## Development and Build (when editing UI)

The UI (React + Vite) is under `src/ui`.

### 1. Install dependencies

```bash
cd src/ui
npm install
```

### 2. Start development server

```bash
npm run dev
```

### 3. Production build

```bash
npm run build
```

Build output is generated in `src/ui/dist`.

### 4. Required directories for deployment

If you update UI and deploy to server, ensure the final resource structure is:

```text
lb-app-where-are-you/
	fxmanifest.lua
	config.lua
	client/
	server/
	ui/
		dist/
			index.html
			assets/
			map-tiles/   (bundle as needed for your environment)
```

`fxmanifest.lua` references `ui/dist/index.html`, so do not remove `ui/dist`.