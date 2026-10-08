# Moonlight+ for macOS

> [!IMPORTANT]
> This is a fork of [MichaelMKenny/moonlight-macos](https://github.com/MichaelMKenny/moonlight-macos) with the following changes:
> - **Stream statistics overlay** (ported from moonlight-ios): video resolution, FPS and codec, frames dropped by the network, network latency and host processing latency. Toggle it with `Control-Shift-E` or *View → Stream Statistics*; the setting is remembered. Without the overlay, a warning is shown when the connection to the PC is poor.
> - **macOS Game Mode** support.
> - **Fixed mouse wheel scrolling** with classic (notched) mice: exactly one scroll click is sent per notch, so slow scrolls no longer get lost and fast ones no longer overshoot.
> - **Fixed stuck keys** on the host when the stream window or the app loses focus (e.g. a global shortcut steals it) or the mouse gets released.
> - **Fixed a crash** when launching an app that is already being streamed: the existing stream is brought back into focus instead. Launching a different app properly tears down the current stream first.
> - **No app sandbox**.
> - **Build script** (`build.sh`) producing Developer ID signed, notarized and stapled builds.

Moonlight+ is a native macOS client for NVIDIA's GameStream. It allows you to stream games from your desktop computer to your Mac.

![](readme-assets/images/app-list-and-game.jpg)

## Features

- Apple Silicon support
- Up to 4K streaming at 144fps
- Native AppKit app
- Hardware decoding
- HEVC and H.264
- HDR
- Keyboard and mouse support
- Custom HID driver to support popular controllers on older macOS versions that offer limited or no native gamepad (MFi) support.
- Local network host PC detection
- Adding hosts manually
- Wake-on-LAN support
- Dark Mode
- Support for older macOS versions, back to 10.14 (Mojave)

## Screenshots

<img src="readme-assets/images/host-list.png" width="600">

<img src="readme-assets/images/app-list.png" width="600">

<img src="readme-assets/images/preferences.png" width="500">

## Notes

- To release the mouse cursor from the stream, press both `Control` and `Option` at the same time.
- To quit an app and disconnect from stream in one keystroke press `Control-Shift-W`.
- To just disconnect from the stream (leaving the app running) press `Control-Option-W`.
- To toggle the stream statistics overlay press `Control-Shift-E`.
- To quit apps from the apps grid, right-click on the running app and choose *Quit.*
- You can increase/decrease the app grid size with `Command +` and `Command -`.

## Known Issues

- At the moment, the HID driver doesn’t support multiple gamepads at once.
- Only Bluetooth Xbox controllers are supported.
- Xbox controllers don’t support wired mode.
- DualSense (PS5) rumble is different intensity in wired vs wireless modes.
- Switch Pro controllers are only supported in wireless mode.
- There is a bug with some PlayStation controllers where in first-person-shooter games the camera overshoots at times. This doesn’t happen to all my PlayStation controllers. I currently don’t know how to fix this. If this happens to you, change *Controller Driver to* MFi in Moonlight+'s Preferences.
- Controller rumble sometimes stops working. Rebooting your PC fixes this. This seems to be an NVIDIA issue.
- Side mouse buttons don't work.
- I haven’t added support for higher refresh-rates than 60Hz, yet. However, I don’t think it will be that hard.

## Build instructions

1. Run the following line in your Terminal:

   ```Bash
   git clone --recursive https://github.com/deseven/moonlight-macos.git
   ```
1. Install XCFramework dependencies by downloading [the latest built frameworks](https://github.com/coofdy/moonlight-mobile-deps/releases/download/latest/moonlight-apple-xcframeworks.zip). Unzip that file, and place the `.xcframework` files into the `xcframeworks` directory in this project.

### Using the build script

1. Copy `.env.example` to `.env` and fill in your Developer ID signing identity and notarization credentials.
2. Run one of:
   - `./build.sh dev` (or just `./build.sh`) for a debug build in `.build/DerivedData`. It's ad-hoc signed if no signing identity is set.
   - `./build.sh dev-release` for a release build. It's signed with your Developer ID, notarized and stapled (if notarization credentials are set), packed to `dist/moonlight-macos.zip` and installed to `/Applications`.

### Using Xcode

1. Open `Moonlight.xcodeproj`  in Xcode.
3. Open the Project file (the first item in the sidebar, labelled “Moonlight”).
4. Go to the *Signing & Capabilities* tab.
5. Change the *Team* to your own team (probably your name).
6. Change the *Bundle Identifier* from `com.coofdylabs.MoonlightMac`  to start with your own name or domain.
7. Select the Moonlight target in Xcode’s toolbar, then “My Mac” and press `Command-R`, to build and run.

## Acknowledgements

- This fork is based on the [original macOS port](https://github.com/MichaelMKenny/moonlight-macos) by Michael Kenny and Martin Kenny.
- This project is a fork of the main [moonlight-ios project](https://github.com/moonlight-stream/moonlight-ios), by the [Moonlight Stream team](https://github.com/moonlight-stream), made to work on macOS and use a Native AppKit UI. This is not a Mac Catalyst app.
- In addition, this project also uses the following Open-Source projects:
   - [MASPreferences](https://github.com/shpakovski/MASPreferences) to help handle preference-panes in preferences.
   - [Functional](https://github.com/leuchtetgruen/Functional.m) to add Objective-C helpers, to make my life easier.
