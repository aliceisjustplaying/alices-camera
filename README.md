# Alice's Camera

A small black-and-white RAW camera for iPhone Duo. The whole app, lock screen camera included, is 680 lines of Swift.

## What it does

**Live view.** The viewfinder shows the rear camera in black and white at 30 fps.

**Photos.** The shutter takes a 12 MP Bayer RAW photo. There's no ProRAW. The app saves a black-and-white JPEG and the DNG as one Photos item, with the JPEG in front. It only asks to add photos. If the camera can't shoot Bayer RAW, the shutter is grayed out.

**Lenses.** The lens button steps through 0.5x (ultra wide), 1x (main) and 2x. 2x crops the middle of the main camera. The view and the JPEG are cropped, and the DNG is the full 1x frame. The app uses the rear cameras because the front cameras don't shoot RAW.

**Duo Preview.** When the phone is fully open, the outer screen shows the live view, so the person you're shooting can see it. It's on by default. A button next to the lens button turns it on and off. It pauses while the phone is half open or in split screen.

**Layouts.**

- Open and wide: viewfinder on the left, last photo on the right.
- Open and tall: viewfinder on top, last photo below.
- Half open: viewfinder on one side of the fold, controls on the other.
- Closed: full-screen viewfinder with a thumbnail of the last photo beside the shutter.
- Split screen: full viewfinder with the thumbnail in the top corner.

Tap the thumbnail to see the photo and tap again to go back.

**Slide to show camera.** Duo Preview covers the system's Slide to show camera bar on the outer screen. Turn Duo Preview off to use the bar.

**Buttons.** Camera Control and the volume buttons take a photo too. The app shows up in Settings → Camera → Camera Control.

**Lock Screen.** You can add an Alice's Camera control to the Lock Screen or Control Center. On a locked phone it opens the same viewfinder, lenses and shutter. Photos go straight to Photos if the app has access. If not, the app adds them the next time it opens.

## Build and install

You need Xcode 27.2 and a phone on iOS 27.1 or later. The Xcode project is made from `project.yml` with XcodeGen and checked in.

The app has two extensions, the locked camera and the control, so the build signs three bundle IDs. To set your signing team, put a `DEVELOPMENT_TEAM` line in a `Local.xcconfig` file.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project AlicesCamera.xcodeproj -scheme AlicesCamera \
  -destination generic/platform=iOS -derivedDataPath build \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <device> \
  build/Build/Products/Debug-iphoneos/AlicesCamera.app
xcrun devicectl device process launch --device <device> com.aliceisjustplaying.camera
```

`<device>` is the phone's name or UDID from `xcrun devicectl list devices`.

With a free personal team, the app stops opening after 7 days until you install it again.
