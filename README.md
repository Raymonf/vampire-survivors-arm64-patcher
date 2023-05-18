# Vampire Survivors arm64 Patcher

This not-very-pretty bash script takes care of patching Vampire Survivors to work natively on arm64 (i.e., Apple silicon) Macs. If you're a bash wizard, please feel free to improve the script.

**Verified working with v0.14.** The Unity version has native arm64 support, so this patch is unnecessary when using the new engine beta branch.

### Why?

The FPS is too good under Rosetta 2 once you hit mid-round. I guess better power efficiency is a good reason too.

### Quick Start

Open up a Terminal window and run this command:

```bash
bash <(curl -s https://raw.githubusercontent.com/Raymonf/VS-arm64-patcher/main/patcher.sh)
```

The script assumes that you've installed Vampire Survivors to the default location (the app in the local user's `steamapps` folder). If this is not where your game is installed, you'll have to open the folder in Steam and drag the `Vampire_Survivors` app to the Terminal window or edit the script.

### Security Warning

For the security conscious out there, you may want to read into the script a bit. It:
* Targets the Electron v19.x series (v19.0.13 currently)
* Downloads a precompiled arm64 version of Greenworks (tested on Monterey 12.4)
* Downloads an arm64-compatible version of the Steamworks redistributable libraries from an external source

Depending on your mindset, you may decide against running the script as-is. The script lets you place your own versions of these libraries in the folder - just flip the `CLEANUP` variable.

### WIP

