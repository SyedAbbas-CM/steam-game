**Build Matrix**

Project root:
- [new-game-project](/Users/developer-cloudprimero/Desktop/Godot/new-game-project)

Reusable export script:
- [build_exports.sh](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/tools/build_exports.sh)

Current local Godot toolchain used on this machine:
- Godot binary:
  - `/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot`
- Export templates:
  - `/Users/developer-cloudprimero/Library/Application Support/Godot/export_templates/4.6.1.stable`
- Android SDK:
  - `/Users/developer-cloudprimero/Library/Android/sdk`
- Java SDK used for Android export:
  - `/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home`

Android-specific Godot editor settings on this machine:
- `export/android/android_sdk_path = "/Users/developer-cloudprimero/Library/Android/sdk"`
- `export/android/java_sdk_path = "/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home"`

**How To Export**

From project root:

```bash
scripts/tools/build_exports.sh
```

Manual one-off export:

```bash
'/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot' \
  --headless \
  --path /Users/developer-cloudprimero/Desktop/Godot/new-game-project \
  --export-release 'Android'
```

Replace `Android` with any preset from [export_presets.cfg](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/export_presets.cfg).

**Current Presets**

- `Windows Desktop`
- `Windows Desktop (Compat x86_32)`
- `macOS`
- `Linux`
- `Linux (Compat x86_32)`
- `Android`
- `Web`

**Output Paths**

- [builds/windows](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/windows)
- [builds/macos](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/macos)
- [builds/linux](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/linux)
- [builds/android](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/android)
- [builds/web](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/web)

**Known Issues / Notes**

- macOS/headless export may print:
  - `cannot connect to daemon at tcp:5037`
  - `Cannot save editor_settings-4.6.tres`
  These did not block successful exports on this machine.

- Android export was previously blocked by:
  - missing Java SDK path in Godot editor settings
  - malformed upgrade `.tres` resources under [resources/upgrades](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/upgrades)

- The upgrade resources now use valid dictionary syntax for `stat_bonuses`.

- Linux and Windows have both `x86_64` and compatibility `x86_32` export presets.
- macOS remains 64-bit only in practice for Godot 4.
- Web builds must be served over HTTP locally for testing. Do not open `index.html` directly with `file://`.

**Latest Successful Build Outputs**

- [DungeonCrawl.exe](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/windows/DungeonCrawl.exe)
- [DungeonCrawl_x86_32.exe](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/windows/DungeonCrawl_x86_32.exe)
- [DungeonCrawl.app](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/macos/DungeonCrawl.app)
- [DungeonCrawl.x86_64](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/linux/DungeonCrawl.x86_64)
- [DungeonCrawl.x86_32](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/linux/DungeonCrawl.x86_32)
- [DungeonCrawl.apk](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/android/DungeonCrawl.apk)
- [index.html](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/builds/web/index.html)
