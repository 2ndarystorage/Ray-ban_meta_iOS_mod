# QuickCapture Lite Sample

QuickCapture Lite is a stripped-down example built on top of the Meta Wearables Device Access Toolkit. It focuses on the essentials required to:

- Register or unregister an app with Meta AI glasses
- Watch device availability and show the currently active headset
- Start or stop a low-bandwidth video session
- Capture an on-demand JPEG photo frame
- Apply real-time video filters (mono/comic) and overlay a basic AI face-detection demo

## Why this sample exists

The original CameraAccess sample in this repo offers a full streaming UI. QuickCapture Lite keeps the logic minimal so you can more easily:

- Embed the DAT flow inside an existing SwiftUI app
- Understand the life cycle of `Wearables.shared`, `AutoDeviceSelector`, and `StreamSession`
- Experiment with the SDK without pulling in extra debug menus or multi-screen navigation

## Running the sample

1. Open the workspace in Xcode 15 or newer.
2. Select the `QuickCaptureLite` target.
3. Update the bundle identifier, `MetaAppID`, and `ClientToken` in `Info.plist` so they match your organization.
4. Build & run on an iOS 17+ device. The simulator works for UI checks, but you need real hardware for streaming.

Once the app launches:

- Tap **Connect** to run through the registration flow.
- Use **Start stream** to request camera permission and begin streaming.
- Toggle the **Visual effects** card to experiment with mono/comic filters and switch the face-detection overlay on/off.
- Tap **Capture photo** any time to save the latest filtered frame in-memory.
- Use **Disconnect** once you are done to reset the session.

Refer to the main README for full documentation links and licensing details.
