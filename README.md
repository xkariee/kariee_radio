# SOPHISTICATED RADIO SYSTEM
This radio system is based on YT search engine using Google API
To make it work, please put your key in .env.example i remove .example

YouTube Data API v3 key used for in-app music search.
 1. Go to https://console.cloud.google.com/apis/credentials
 2. Create a project (or pick one), enable the "YouTube Data API v3"
 3. Create an API key and restrict it to that API

## Commands

| Command | Who | What it does |
| --- | --- | --- |
| `F6` (`kradio`) | Everyone | Open your radio, or the car radio when you're in a vehicle |
| `/dj` | Everyone | Open the DJ booth you're standing at |
| `/radiohud` | Everyone | Show or hide the nearby "now playing" widget |
| `/createdj` | DJ permission | Place a new DJ booth (placement tool) |
| `/removedj` | Booth owner / admin | Remove the booth you're standing at |
| `/radioadmin` | Radio admins | Open the admin panel |

## Nearby "now playing" widget

When you're in range of a DJ booth (or inside the room it's in), a small card shows the song, artist,
cover and time. Players can turn it off, switch to a compact style, show it for any radio nearby, or
drag it anywhere on screen from the radio's **Settings → Nearby now playing → Move widget**.
Turn it off server-wide with `Config.NowPlayingWidget = false`.

## Admin panel

Radio admins (`Config.AdminAce` ACE permission, or an ESX group listed in `Config.AdminGroups`) get an
**Admin** section in the radio, also reachable with `/radioadmin`:

- **Live radios**: everything playing on the server, with who started it, where it is, distance from
  you, players nearby and whether you can hear it. Set a waypoint, teleport, stop it, or ban the player.
  Also "Stop near me" and "Stop all" for emergencies.
- **DJ booths**: every booth with its location, owner and what it's playing. Rename, remove, locate,
  stop, or place a new one.
- **Bans**: ban players from DJ booths only, or from every radio, for 1 hour to permanent, with a
  reason they're shown. Bans are enforced server-side and saved in the `radio_bans` table (created
  automatically).
- **Activity**: recent plays, admin actions, bans and booth changes, so you can see who played what.


![Preview](https://github.com/xkariee/kariee_radio/blob/main/preview.png)
