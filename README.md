# Alice's Camera

A minimal black-and-white Bayer RAW camera for iPhone Duo.

## Features

**Black-and-white live view.** The viewfinder shows the rear camera in black and white at 30 fps.

**Bayer RAW capture.** The shutter takes a Bayer RAW photo, not ProRAW. The app saves a black-and-white JPEG and the DNG together as one Photos asset, with the JPEG in front. It asks only for add-only Photos access and never reads the library. If the current camera has no Bayer RAW format, the shutter is disabled.

**0.5x, 1x and 2x.** The lens button cycles through the three. 0.5x is the ultra wide camera and 1x is the main camera. 2x is a center crop of the main camera: the preview and the JPEG are cropped and the DNG stays the full 1x frame. Bayer RAW needs the camera at 1x zoom, so there is no 2x RAW.

**Duo Preview.** When the phone is fully open, the outer display shows the live view edge to edge, so the person in front of the camera can see the shot. A button next to the lens button turns it on and off. The button shows only in that state. Duo Preview is on by default and the button is dimmed when the system reports Duo Preview as unavailable.

**Layouts.** The layout follows the app's own window and the fold.

- Open, landscape: viewfinder on the left, last photo on the right, controls over the viewfinder.
- Open, portrait: viewfinder on top, last photo below.
- Half open: viewfinder on one side of the fold, controls on the other.
- Closed: full-screen viewfinder with the controls at the bottom and a thumbnail of the last photo in the top corner. Tapping the thumbnail shows the photo and tapping the photo goes back to the viewfinder.
- Split screen: the closed layout, sized to the app's window.

**Hinge.** Duo Preview pauses while the phone is half open or the app is in a split window. It comes back when the phone is fully open and the app has the whole screen, unless it was turned off with its button.

**Slide to show camera.** With Duo Preview on, its view on the outer display covers the system's Slide to show camera bar. To move the camera to the outer display, turn Duo Preview off with its button, then flip the phone and slide. After the move the app shows the closed layout with the rear camera, and Duo Preview stays off.

**Camera Control.** A click on Camera Control takes a photo, the same as the shutter button. The volume buttons do too. Alice's Camera shows up in Settings → Camera → Camera Control as a camera to launch.

**Lock screen.** An Alice's Camera control can go on the Lock Screen or in Control Center. On a locked phone it opens the locked camera, which has the same viewfinder, lenses and shutter as the app. Its photos go straight to Photos when the app already has Photos access. Otherwise they wait, and the app adds them to Photos the next time it opens. Launching it with Camera Control on a locked phone hasn't been tried by hand yet.

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

`DEVELOPER_DIR` points the command line tools at Xcode instead of the standalone Command Line Tools. `<device>` is the phone's name or UDID from `xcrun devicectl list devices`. The app embeds two extensions, the locked camera and the control, so the build signs three bundle IDs. Signing uses the team in `project.yml`. A different team needs its own `DEVELOPMENT_TEAM` and bundle IDs for all three targets in `project.yml`, and the project regenerated with `xcodegen`.

With a free personal team, the install stops opening after 7 days until it's reinstalled.
