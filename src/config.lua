Config = {}

-- LB-Phone app registration settings
Config.Identifier = 'whereareyou'           -- App identifier in LB-Phone (unique value recommended)
Config.Name = 'WhereAreYou?'                -- App display name
Config.Description = 'Friend location sharing app'
Config.Developer = 'lb-app-where-are-you'   -- Developer/resource name label
Config.DefaultApp = false                   -- Auto-install for all players

-- Location sharing settings
Config.PositionPushIntervalMs = 2000        -- Position push interval (ms)
Config.BlurGridSize = 200.0                 -- Coordinate rounding size for blurred display
Config.WalkSpeedThreshold = 1.2             -- Minimum speed threshold for walking state
Config.VehicleSpeedThreshold = 8.0          -- Minimum speed threshold for vehicle movement

-- Nearby notifications
Config.NearbyRadiusDefault = 30.0          -- Default nearby notification radius
Config.NearbyNotifyEnabled = false          -- Initial nearby notification ON/OFF
Config.NearbyNotifyIntervalMs = 10000       -- Nearby check interval (ms)
Config.NearbyNotifyCooldownMs = 60000       -- Cooldown before notifying about the same player again
Config.PostCooldownMs = 30000               -- Check-in post cooldown (ms)

