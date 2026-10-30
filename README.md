# Alice's Camera

A minimal black-and-white Bayer RAW camera for iPhone Duo.

## Features

**Black-and-white live view.** The viewfinder shows the rear camera in black and white at 30 fps.

**Bayer RAW capture.** The shutter takes a Bayer RAW photo, not ProRAW. The app saves a black-and-white JPEG and the DNG together as one Photos asset, with the JPEG in front. It asks only for add-only Photos access and never reads the library. If the current camera has no Bayer RAW format, the shutter is disabled.

**0.5x, 1x and 2x.** The lens button cycles through the three. 0.5x is the ultra wide camera and 1x is the main camera. 2x is a center crop of the main camera: the preview and the JPEG are cropped and the DNG stays the full 1x frame. Bayer RAW needs the camera at 1x zoom, so there is no 2x RAW.

**Duo Preview.** When the phone is fully open, the outer display shows the live view edge to edge, so the person in front of the camera can see the shot. A button next to the lens button turns it on and off. It's on by default and dimmed when the system reports Duo Preview as unavailable.

**Layouts.** The layout follows the app's own window and the fold.

- Open, landscape: viewfinder on the left, last photo on the right, controls over the viewfinder.
- Open, portrait: viewfinder on top, last photo below.
- Half open: viewfinder above the fold, controls below it.
- Closed: full-screen viewfinder with the controls at the bottom and a thumbnail of the last photo in the top corner. Tapping the thumbnail shows the photo and tapping the photo goes back to the viewfinder.
- Split screen: the closed layout, sized to the app's window.

**Hinge and Slide to show camera.** Duo Preview turns off when the phone is half open and comes back when it's fully open. It also turns off when the open phone is turned around so the rear cameras face the person holding it. Then the system's Slide to show camera bar on the outer display works: sliding moves the app to the outer display in the closed layout, and Duo Preview stays off while it's there.

**Camera Control.** A click on Camera Control takes a photo, the same as the shutter button. The volume buttons do too.

In progress: launching from the lock screen and picking Alice's Camera as the Camera Control camera.

## Build and install

This needs Xcode 27.2 and a phone on iOS 27.1 or later. The Xcode project is generated from `project.yml` with XcodeGen and committed, so a build needs only Xcode.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project AlicesCamera.xcodeproj -scheme AlicesCamera \
  -destination generic/platform=iOS -derivedDataPath build \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <device> \
  build/Build/Products/Debug-iphoneos/AlicesCamera.app
xcrun devicectl device process launch --device <device> com.aliceisjustplaying.camera
```

`DEVELOPER_DIR` points the command line tools at Xcode instead of the standalone Command Line Tools. `<device>` is the phone's name or UDID from `xcrun devicectl list devices`. Signing uses the team in `project.yml`. A different team needs `DEVELOPMENT_TEAM=<team id>` and its own `PRODUCT_BUNDLE_IDENTIFIER` on the xcodebuild line.

With a free personal team, the install stops opening after 7 days until it's reinstalled.
