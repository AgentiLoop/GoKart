# Auto-pilot session — 2026-10-07 12:29
Goal: for GoKart, create a multi player peer-to-peer mode with 2-4 players with player's names above their heads. make it work cross-platform. use gokart.games to find players who want to play, but all the interaction of the in game racing will be peer-to-peer. search the internet how peer-to-peer works in gdscript and godot4. can you do it? yes you can!
Budget: no time limit, unlimited cycles

## Cycle 1 — DONE (commit e58355f)
- Research: Godot 4 P2P = WebRTCMultiplayerPeer mesh; desktop needs webrtc-native GDExtension; signaling via own server.
- addons/webrtc_native 1.2.2 vendored (release libs mac/win/linux x86_64+arm64).
- website/src/lobby.js Durable Object (/api/mp WebSocket, /api/mp/status) — DEPLOYED to gokart.games.
- scripts/net.gd autoload `Net` (signals room_updated, match_started, mesh_ready, peer_left, failed; my_id, host_id, names).
- tests/net_smoke.sh N [lobby] — 2/3/4 players pass locally + against production.

## Next
1. Race sync: online race mode in main.gd — spawn one kart per peer (seed/course from match_info), local kart driven by input, remote karts driven by unreliable state packets (send_bytes) with interpolation; host-synced start countdown; no AI (or AI fill?).
2. Name tags above karts (Label3D billboard).
3. Menu: ONLINE entry — name entry (saved user://), Quick Match / Create room / Join code, lobby screen with players + countdown.
4. Items/hits over network, results/finish order, disconnect handling.
5. Export check (mac signing of framework), README.
## Cycle 1 — 2026-10-07 12:38
Cycle 1 finished (commit e58355f): the online networking layer is built and working. 2, 3 and 4 game instances found each other through gokart.games and then exchanged data directly with each other. You can't race online in the game yet.

**How it works:** I looked up how Godot 4 does peer-to-peer. The standard way is WebRTC connecting every player to every other player. Desktop builds need Godot's official webrtc-native add-on, which I added in `addons/webrtc_native/` (only the macOS, Windows and Linux files GoKart exports, about 20 MB).

**What's done:**
- **Matchmaking on gokart.games (already deployed):** a new lobby at `/api/mp`, plus `/api/mp/status` showing how many people are waiting. It supports quick match or a private room code for 2–4 players. A public room starts 20 seconds after the second player joins, and the host can start sooner. The server only passes along the connection setup messages; it never carries race data.
- **Game side (`scripts/net.gd`, loaded at startup as `Net`):** it joins the lobby, connects every player directly to every other player, then closes the lobby connection. After that, all game traffic is peer-to-peer. It tracks each player's ID and name and treats the lowest ID as host.
- **Checks:**
  - `tests/net_smoke.sh N [lobby-url]` starts N headless copies of the game, which quick-match and send each other messages.
    - 2, 3 and 4 players passed against a local test lobby.
    - 3 players passed against the live gokart.games lobby.
  - The existing tests still pass (14,589 passed, 0 failed). I also added `tests/test_net.gd` for name cleanup and to confirm the add-on loads.

**Choices I made:**
- **No relay server:** connections use only public Google and Cloudflare lookup servers, with no relay server. Players behind very strict routers or firewalls may fail to connect; they get an error after 25 seconds.
- **Desktop only:** I did not add or test a web (browser) build.

**Still to do (next cycles):**
1. Online race mode: one kart per player, your kart from your controls, other karts moved by data from their players, and a start countdown everyone shares.
2. Player names floating above each kart.
3. An Online menu: enter and save your name, Quick Match or Create/Join with a code, and a lobby screen showing players and the countdown.
4. Items and hits shared across players, finish order and results, and handling players who drop out.
5. Check that exported builds include the add-on (including Mac signing), and update the README.

**Blockers:** none.


## Cycle 2 — DONE (commit 5a704eb)
- scripts/online_race.gd (OnlineRace.active flag, packets, Puppet interpolation, make_tag), kart.gd puppet mode, main.gd online branch.
- Online rules: course = room course name or seed % count; 3 laps 150cc; grid by sorted peer id; no AI, no items yet; no intro; Esc/Enter on results -> Net.leave() + menu.
- tests/race_smoke.sh N [lobby]: 2/4 local, 3 live gokart.games pass; unit tests 14606/0.
## Next
1. Menu ONLINE entry (name saved user://, Quick Match / Create / Join code, lobby screen) -> set OnlineRace.active, change to main.tscn on Net.mesh_ready.
2. Items over network; results/finish order from reported finish times; disconnect UI.
3. Export check + README.
## Cycle 2 — 2026-10-07 12:46
Cycle 2 finished (commit 5a704eb). Online races now work from start to finish: 2–4 players each drive their own kart, the other players' karts move from data sent directly between the players' games, a name floats over each other player's kart, and everyone gets the same start countdown. There's still no menu button to start an online race; that's the next step.

**Testing:**
- I added `tests/race_smoke.sh N [lobby-url]`. It starts N copies of the game without a window, finds a match, loads the race and lets each kart drive itself. It passes when every copy sees each other kart drive at least 40 m with the right name over it.
- 2 and 4 players passed against a local test lobby, and 3 players passed against the live gokart.games lobby. Every copy saw each kart in nearly the same spot, within about 0.2 m.
- The existing tests still pass (14,606 passed, 0 failed), including new ones in `tests/test_online.gd`.
- I did not look at the name tags in a normal game window; the tests only check that they exist and show the right name.

**What changed:**
- **New `scripts/online_race.gd`:** the online race rules and the data sent between players.
  - Each game sends its kart's position about 30 times a second.
  - Other karts are shown 100 ms behind and smoothed between updates, so they don't jump around.
  - The name tag above each kart always faces the camera.
- **`scripts/kart.gd`:** a kart can now be driven by another player's data instead of the keyboard or physics.
- **`scripts/main.gd`:** a separate online path.
  - **Course:** everyone gets the same track, either the room's chosen course or one picked at random by the server.
  - **Starting grid:** places are set by player ID, with a different colour for each slot.
  - **Start:** each game tells the others when it has loaded, and the host sends GO once everyone is ready (or after 15 seconds). Then everyone counts down 3-2-1.
  - **Players who drop out:** their kart disappears from the track.

**Choices I made:**
- Online races are 3 laps at 150cc for everyone, with no computer-driven karts and no item boxes yet.
- The course fly-over intro is skipped.
- An online race can't be paused, so Esc leaves it. On the results screen, Enter also returns to the menu.
- You don't see a name over your own kart, only over the others.
- No other project folders needed copies of these changes, since none were configured.

**Still to do:**
1. An Online menu: enter and save your name, Quick Match or Create/Join with a room code, and a lobby screen showing the players and countdown.
2. Items and hits shared across players.
3. Finish order based on each player's own finish time, and a message when someone leaves.
4. Check that exported builds include the add-on (including Mac signing), and update the README.

**Blockers:** none.


## Cycle 3 — DONE (commit 40a7849)
- ONLINE screen scenes/online.tscn + scripts/online_lobby.gd; menu O key (hint updated). tests/lobby_smoke.sh (2p live pass). Unit tests 14614/0.
## Next
1. Items over network (item boxes + projectiles/hits) — or keep items off and do finish order/results from reported finish times + 'X left' toast.
2. Export check (webrtc_native in exports, mac signing) + README section.
## Cycle 3 — 2026-10-07 12:49
Cycle 3 is finished (commit 40a7849). Players can now start an online race from the game's menu: press **O** on the course select screen to open the new Online screen. Two copies of the game got through this screen and into the same race using the live gokart.games lobby.

**Tests:**
- New `tests/lobby_smoke.sh N [lobby-url]`. It runs N copies of the game without a window through the Online screen: each one enters a name and presses Quick Match, and the host presses Start Now. It passes when every copy loads the race in online mode. 2 players passed against gokart.games.
- The existing tests still pass (14,614 passed, 0 failed), including new checks in `tests/test_online.gd`.
- I set up a sample lobby with 3 players and read its values back. It showed "Todd (host, you) / Alice / Bob", the countdown and the room code, and the screen layout fit inside its panel. I saved screenshots to `/tmp/gokart_online_setup.png` and `/tmp/gokart_online_lobby.png` but did not look at them.
- Not tested: Create Room and Join by Code with two real players, and using the screen in a normal game window.

**What changed:**
- **New Online screen** (`scenes/online.tscn` and `scripts/online_lobby.gd`):
  - Enter your name; it's saved for next time.
  - **Quick Match** joins any open room.
  - **Create Private Room** makes a 5-letter room code, and that room races the course you highlighted on the select screen.
  - **Join** with a code another player gives you.
  - The lobby lists the players, marks the host and you, and shows the countdown and how many players have joined. Only the host sees **Start Now**, and only once 2 or more players are in.
  - It shows "Connecting directly to the other players…" while the games connect, then the race loads.
  - If something fails, the error appears on the screen.
  - Esc or Leave leaves the room; Esc on the first screen goes back to the menu.
- **`scripts/menu.gd`:** the O key opens the Online screen, and the key hint line now mentions it.

**Choices I made:**
- I used a key (O) instead of adding a 5th mode tab, so the existing menu layout and its tests didn't need changing.
- Your saved name starts as your computer user name.
- A Quick Match room can also be joined by its code.
- No other project folders needed copies of these changes, since none were configured.

**Still to do:**
1. Items and hits shared across players (item boxes are still off in online races).
2. Finish order based on each player's own finish time, and a message when someone leaves.
3. Check that exported builds include the add-on (including Mac signing), and add an online section to the README.

**Blockers:** none.

## Cycle 4 — DONE (commit 4915bee)
- FINISH packet (reliable, f64 race time); puppets rank by reported times; online board via OnlineRace.results_text (board_name upper-case word, LEFT +0, "WAITING FOR n" footer), redrawn on finish/leave; "X left the race" notice 4 s in cup line.
- race_smoke.gd --finish / --leave-at=S; race_smoke.sh 3rd arg. Live: 2p full race boards identical; 3p with Carol leaving -> LEFT on both boards + notice. Unit 14622/0.
## Next
1. Items over network (item boxes + shells/hits) — biggest remaining gameplay gap.
2. Export check (webrtc_native in exports, mac signing) + README online section.
## Cycle 4 — 2026-10-07 12:58
Cycle 4 is finished (commit 4915bee). Online races now end with correct results: everyone's results screen ranks the players by the finish time each player's own game measured. If someone leaves, the others see a notice saying so, and that player is marked LEFT in the results.

**Tests (all against the live gokart.games lobby):**
- **2-player full race:** both results screens were identical — Bob 1:31.850 first, Alice 1:31.883 second.
- **3-player race where Carol quits 20 s after GO:** Alice and Bob both showed "Carol left the race", and their results screens matched: Bob 1:41.500, Alice 1:41.767, Carol LEFT with 0 points.
- The original 2-player test still passes, and all unit tests pass (14,622 passed, 0 failed, including new ones in `tests/test_online.gd`).
- Not tested: a race with 4 players to the finish, and how the results screen looks in a normal game window.

**What changed:**
- **Finish times are shared:** when a player crosses the line, their game sends their finish time to the others once. Everyone ranks the finishers by those times instead of guessing from where the other karts appear on their own screen. Players still racing are ranked by how far along the course they are.
- **Results screen keeps updating:** it refreshes whenever someone else finishes or leaves. While others are still racing it shows "WAITING FOR N"; Enter goes back to the menu.
- **Bug fixed — names on the results screen:** that screen only recognises a name written as a single upper-case word, so online names like "Alice" were landing in the time column. Names now show in capitals, with spaces and symbols turned into "_" (for example "Todd B." shows as TODD_B_).
- **Leaving:** "X left the race" appears for 4 seconds where the cup info line normally goes.
- **Test tools:** `tests/race_smoke.sh N <lobby> --finish` races all 3 laps and passes once every player's results screen has everyone's time. `tests/race_smoke.gd` also accepts `--leave-at=S`, which makes a player quit S seconds after GO.

**Choices I made:**
- A player who leaves before finishing gets 0 points.
- A player who leaves after finishing keeps their time.
- I didn't change anything outside this project folder, since no others were configured.

**Still to do:**
1. Items and hits shared between players (item boxes are still off in online races).
2. Check that exported builds include the add-on (including Mac signing), and add an online section to the README.

When a player leaves, Godot prints a harmless "channel->isClosed()" error for messages already on their way to them.

**Blockers:** none.


## Cycle 5 — DONE (commit 54f8943)
- Items online: boxes on; own items rolled/fired locally, ITEM packet replays on puppet; victim-authoritative hits + HIT packet; held/charges + star/ghost flags in state; lightning/blue blast/star only affect own kart; Boo victim by peer id.
- Unit 14634/0 (test_item_packets, test_online_items). Live: race_smoke 2p/3p --items pass (counts match across peers, HIT packets seen); 2p plain + --finish still pass.
## Next
1. Export check (webrtc_native in exports, mac signing) + README online section.
## Cycle 5 — 2026-10-07 13:10
Cycle 5 is finished (commit 54f8943). Item boxes now work in online races: each player's game rolls and fires that player's own items, and every item thrown shows up in the other players' games too.

**Tests:**
- **Live 3-player race on gokart.games with every item fired as soon as it's picked up:** all three games agreed on the counts. Alice fired 7 and both others received 7; Bob fired 9 and both others received 9. "Item hit me" messages also came through, so hits were reported and the item was removed for everyone.
- A 2-player run of the same item test also passed.
- The earlier online tests still pass: the 2-player race, and the full 3-lap race, where both results screens matched (Alice 1:49.400, Bob 1:49.417).
- All unit tests pass (14,634 passed, 0 failed), including new ones in `tests/test_online.gd`.
- Not tested: playing with items by hand in a normal game window.

**How it works:**
- **Using an item:** your game sends one message saying what you used, which way, where your kart was, and the target for a blue shell or Boo. The other games create the same shell, banana or fake box on your kart. Each item gets an ID that's the same in every game, including the bananas placed on the course.
- **Hits:** only the hit player's own game decides whether they were hit. It spins that player's kart and tells the others to remove the item. When an item reaches someone else's kart in your game, it's just used up there, without spinning them.
- **Shown on other players' karts:**
  - The item they're holding, so a dangling banana or circling shells still block shells.
  - Whether they have a star or a Boo, so items pass through them.
- **Effects on other players:** lightning, a blue shell blast or touching a star kart only affect each game's own kart, so everyone still sees the bolts and blasts. A Boo takes the item from the targeted player in their own game.
- **Test tool:** `tests/race_smoke.sh N <lobby> --items`.

**Choices I made:**
- Item boxes are on in every online race, with each player's own random rolls.
- Small differences between games are allowed:
  - Red shells aim at a target separately in each game.
  - A Boo's victim might use their item just before it arrives.
  - A remote shell appears where the thrower's kart really was, which can be slightly ahead of where that kart is drawn on your screen (other karts are shown 0.1 s behind).
- Nothing outside this project folder was changed, since no others were configured.

**Still to do:** check that exported builds include the add-on (including Mac signing), and add an online section to the README.

**Blockers:** none.


## Cycle 6 — DONE (commit e8c8c7a)
- Export check: 4 presets export with the webrtc lib (mac framework signed; dll/so beside binary). Signed mac release export ↔ editor P2P mesh over gokart.games passed. Win/Linux not runnable here.
- README: Online play section, O key, online smoke tests, download note (dll/so must stay next to binary).
## Next
1. Release packaging must include libwebrtc_native dll/so in win/linux archives (next release).
2. Optional: TURN relay for strict NATs; manual playtest in windowed game.
## Cycle 6 — 2026-10-07 13:16
I checked that the exported game builds include the online add-on, and added an online section to the README (commit e8c8c7a). There was no parity folder to copy changes to.

**Export check:**
- **All four builds export with the add-on:** macOS, Windows, Linux x86_64 and Linux arm64.
  - **macOS:** the add-on is inside the app. The app is signed with your Developer ID, passes Apple's strict signature check, and has the setting that lets it load the add-on.
  - **Windows and Linux:** the add-on is a separate file (`.dll` or `.so`) written next to the game program, and both files are the right type for their platform.
- **Live test:** a signed release Mac build joined a room on gokart.games with a copy run from the Godot editor. They connected directly and swapped messages both ways.
- **Not run:** the Windows and Linux builds. This Mac has no Docker or Wine to start them, so I only checked their files.
- **How I tested the Mac build:** exported games ignore Godot's `-s` test-script option, and release builds don't show print output until they exit. So I used a temporary copy of the project with a small check scene, outside this folder and not committed.

**README:**
- A new "Online play" section covers:
  - The O key, name entry, Quick Match, private room codes and the lobby countdown.
  - gokart.games only finding players and passing the connection setup, while the race runs directly between players.
  - How karts, items and results are shared, and which platforms can play together.
  - The `GOKART_LOBBY` setting for a local lobby.
- It says players behind very strict home routers or firewalls may not connect. The game only uses public servers to find a direct route, with no relay to fall back on.
- I added an O row to the controls table and the three online test scripts to the testing list.
- I corrected the download note: the Windows and Linux downloads are no longer a single file, because the online library has to stay next to the game program.

I also saved these findings to project memory (`multiplayer.md`).

**What remains:**
1. At the next release, the Windows and Linux zip and tarball must include the `libwebrtc_native` file, or online play won't work in them.
2. Nobody has run online play on Windows or Linux, or played it by hand in a normal game window.
3. Optionally, add a relay server for players behind strict routers.

**Blockers:** none.


## Cycle 7 — DONE
- race_smoke GOKART_SHOTS windowed mode: 3 windowed games over gokart.games, every on-screen name tag rendered (white px 35-210). Unit tests 14634 passed.
## Cycle 7 — 2026-10-07 13:19
I ran an online race in normal game windows to check that each player's name shows above their kart, and it does. Commit 6ae37ed.

**What I added:** setting `GOKART_SHOTS` to a folder makes `tests/race_smoke.sh` run in small visible windows instead of headless. When each game passes its check, it saves that player's view and counts the white letter pixels inside every name tag that's on screen. Normal headless runs work as before.

**Result:** three windowed games (Alice, Bob and Carol) found each other on gokart.games, connected directly and raced on Green Hills. The test passed for all three.
- Every name tag on screen had white letters drawn:
  - Alice saw "Bob" (210 pixels).
  - Bob saw "Alice" (139).
  - Carol saw "Alice" (46) and "Bob" (35), from about 15 m back.
- The other two tags were about 2–4 m from the camera and counted as off screen, so they had nothing to measure.
- The saved views are `/tmp/gk_shots/race_1.png` to `race_3.png`. I couldn't open the images myself, so I checked the tags by pixel count.

I also re-ran the 2-player headless race over gokart.games (passed) and the unit tests (14,634 passed, 0 failed). The README test list explains the new option, and I added the finding to project memory (`multiplayer.md`). There was no parity folder to update.

**What remains:**
1. Nobody has run online play on Windows or Linux. Those builds export with the online library, but this Mac has no Docker or Wine to start them. Cross-platform play is only proven on macOS so far, so I haven't marked the goal as reached.
2. The Windows and Linux downloads for the next release must include the `libwebrtc_native` file next to the game program.
3. Optionally, add a relay server for players behind strict routers.

**Blockers:** testing on Windows or Linux needs one of those machines, or Docker or Wine installed here.


## Cycle 8 — DONE
- brew install lima; tests/cross_smoke.sh: Linux arm64 (Lima VM, Godot 4.7.2 linux editor + vendored .so) + macOS peers in one gokart.games match. 1L+1M plain, 2L+2M --items and --finish all passed. Commits d4b1d58, 79e8248.
- Found Mac karts falling through the ground once (y -105 km); main.gd FELL_THROUGH_Y=-20 Lakitu rescue + tools/fall_check.gd (PASS). Unit tests 14634 passed.
- Remaining: Windows never run (no Rosetta/Wine/VM); release packaging must include libwebrtc_native; optional TURN relay; exported Linux template (vs editor) not run.
## Cycle 8 — 2026-10-07 13:34
Linux and macOS players can now race each other online. I tested it in a Linux virtual machine on this Mac, and it worked. Commits d4b1d58 and 79e8248.

**What I did:**
- **Linux test setup:** this Mac has no Docker, Wine or Rosetta, so I installed Lima with Homebrew and created a Linux virtual machine (Ubuntu, arm64). Inside it I ran the Linux build of the same Godot 4.7.2 with the project's own Linux online library.
- **Mixed races passed:** players on Linux and on this Mac found each other on gokart.games, connected directly and raced. Each player saw every other kart drive with its name tag over it.
  - 1 Linux + 1 Mac, plain race: passed.
  - 2 Linux + 2 Mac, items race: every player's items reached all three other games.
  - 2 Linux + 2 Mac, full 3 laps: all four results boards were identical with every finish time.
- **New test script:** `tests/cross_smoke.sh [linux] [mac] [lobby] [--items|--finish]`. On the first run it creates the virtual machine `gokart` and downloads the matching Linux Godot. Each run copies the last commit into the machine, so changes must be committed first. I tested it from scratch: 2 Linux + 2 Mac with items passed.
- **Bug found and fixed:** in one mixed items race, both Mac karts fell through the ground and kept falling (about 105 km down). I think another player's kart was moved on top of them and pushed them through, but I couldn't make it happen again.
  - Fix: a kart more than 20 m below the road (`FELL_THROUGH_Y` in `scripts/main.gd`) is now rescued by Lakitu, the same way as falling in the water.
  - New check `tools/fall_check.gd` passes: the kart fell to -20.4 m, was rescued once and was put back on the road.
- **Other updates:** I added both new tests to the README list and noted that Windows hasn't been run yet. I recorded the setup and the bug in project memory (`multiplayer.md`) and this tab's progress log. There was no parity folder to update.

The unit tests passed (14,634, 0 failed). The virtual machine is stopped.

**What remains:**
1. Windows online play has never been run.
2. The Linux test used the Godot program from the download page, not GoKart's exported Linux release build. Both use the same online library.
3. The Windows and Linux downloads for the next release must include the `libwebrtc_native` file next to the game program.
4. Optionally, add a relay server for players behind strict routers.

**Blockers:** testing Windows needs a Windows machine, or Wine, which can't run here without Rosetta. Because of that I haven't marked the goal as reached.

## Cycle 9 — DONE
- Built Wine 11.19 in the Lima VM (Ubuntu Wine 10 hangs on M4). Godot windows arm64 + webrtc arm64 dll raced macOS (+Linux): 1L+1W+2M plain & --items, 2W+2M --finish all passed with identical boards. tests/cross_smoke.sh GOKART_WINDOWS=N; --finish now fails on any LEFT row. Commits 900af2d, 8acc7d2, 7693588.
- Remaining: Windows x86_64 build / exported release exes not run (only editor binaries); TURN relay optional.
## Cycle 9 — 2026-10-07 14:34
Windows players can now race Mac and Linux players online. I tested it with the Windows arm64 (ARM) build of Godot running under Wine. The Windows x86_64 build, which is the one released to players, has still never been run. Commits 900af2d, 8acc7d2 and 7693588.

**What I did:**
- **Got Windows running here:** this Mac has no Rosetta, so I ran Windows programs with Wine inside the existing Linux virtual machine. Ubuntu's Wine 10 got stuck at startup on this Mac (an M4), so I built Wine 11.19 from source inside the machine instead. With it, Godot 4.7.2's Windows arm64 build ran using the project's Windows arm64 online library.
- **Mixed races over gokart.games passed:**
  - 1 Linux + 1 Windows + 2 Mac, plain race: every player saw all three other karts drive.
  - 1 Linux + 1 Windows + 2 Mac, items race: every player's items reached the other three games.
  - 2 Windows + 2 Mac, full 3 laps: all four results boards were identical, with every finish time.
- **Test script update:** `GOKART_WINDOWS=N tests/cross_smoke.sh [linux] [mac] [lobby] [--items|--finish]` adds N Windows players. On the first run it builds Wine (about 20 minutes) and downloads the Windows Godot.
  - Godot under Wine never closes on its own, so the script reads each Windows player's log to see if it passed, then stops Wine.
- **Bug in my own test, fixed:** my first full-race run reported a pass even though both Windows players showed as LEFT (quit mid-race). The script had stopped Wine too early. Now Windows players are only stopped after their full race finishes, and any LEFT on a results board fails a full race.
- **Other updates:** I updated the README (cross-platform line and the test command list), project memory (`multiplayer.md`) and this tab's progress log. There was no parity folder to update. The virtual machine is stopped.
- **Assumptions:** this cycle only changed test scripts and docs, so I didn't re-run the unit tests. The `--items` race ran before the last script fix, which only changes full races.

**What remains:**
1. The Windows x86_64 build and the exported release programs (`GoKart.exe`, `GoKart.x86_64`) have never been run. Only Godot's downloaded programs were tested, and they use the same online library files.
2. The Windows and Linux downloads for the next release must include the `libwebrtc_native` file next to the game program.
3. Optionally, add a relay server for players behind strict routers.

**Blockers:** running the Windows x86_64 build needs Rosetta or a real Windows x86_64 machine. Because of that I haven't marked the goal as reached.

## Cycle 10 — DONE
- Export templates ignore -s, so added Net `--smoke=res://tests/...` user arg (599cc81). tests/export_smoke.sh exports HEAD (macOS, Linux arm64, Windows arm64) and races the release builds: 1L+1W+2M plain and --finish passed over gokart.games with identical boards. README 68709df. x86_64 exports carry libwebrtc next to the binary. Remaining: x86_64 binaries never executed (no Rosetta); TURN optional.
## Cycle 10 — 2026-10-07 14:46
The exported release builds (the programs players download, not the Godot editor) now race each other online. A Linux arm64 game, a Windows arm64 game (under Wine) and two macOS games, all exported from the committed code, finished full 3-lap races over gokart.games with identical results boards. The x86_64 programs have still never been run. Commits 599cc81 and 68709df.

**What I did:**
- **Why a game change was needed:** Godot 4.7's exported games ignore the `-s` option, so the online test script couldn't be started in a release build. They also hold back all printed output until the game quits.
  - Fix: the release game now takes `-- --smoke=res://tests/race_smoke.gd`, which runs that test script from inside the game in place of the normal game loop (in `scripts/net.gd`). Only scripts under `res://tests/` are accepted.
- **New test, `tests/export_smoke.sh [linux] [windows] [mac] [lobby] [--finish|--items]`:** it exports the committed code for macOS, Linux arm64 and Windows (switched to arm64 in a temporary copy, since this machine can't run x86_64), then races those builds. It reuses the virtual machine, Godot and Wine that `cross_smoke.sh` sets up.
- **Results over gokart.games:**
  - Plain race with 1 Linux + 1 Windows + 2 Mac: every player saw all three other karts drive with their name tags.
  - `--finish` with the same four: all four boards were identical (MILO 1:31.183, MABEL 1:31.483, WADE 1:31.933, LOTTE 1:33.700) and there were no LEFT rows.
  - Before writing the test, two exported macOS apps also raced each other.
- **Library check:** fresh Windows x86_64, Linux x86_64 and Linux arm64 exports each put the `libwebrtc_native` file next to the game program. On macOS it goes inside the app.
- **Other updates:** the unit tests passed (14,634, 0 failed). I updated the README (cross-platform line and test list), project memory (`multiplayer.md`) and this tab's progress log. There was no parity folder to update. The virtual machine is stopped and the temporary builds are deleted.
- **Assumptions:** I only switched Windows to arm64 inside the test's temporary copy. The real Windows export settings are unchanged and still build x86_64, and I didn't run `--items` with the exported builds.

**What remains:**
1. Run the x86_64 programs (`GoKart.exe`, `GoKart.x86_64`). They are built from the same game data and library files as the arm64 builds that passed, but haven't been run themselves.
2. Optionally, add a relay server for players behind strict routers.

**Blocker:** running x86_64 programs needs Rosetta or a real x86_64 Windows/Linux machine, so I haven't marked the goal as reached.

Session ended — Stop All (2026-10-07 15:28)

