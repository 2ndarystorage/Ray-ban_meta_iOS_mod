# Meta Wearables Device Access Toolkit for iOS

[![Swift Package](https://img.shields.io/badge/Swift_Package-0.4.0-brightgreen?logo=swift&logoColor=white)](https://github.com/facebook/meta-wearables-dat-ios/tags)
[![Docs](https://img.shields.io/badge/API_Reference-0.4-blue?logo=meta)](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.4)

The Meta Wearables Device Access Toolkit enables developers to utilize Meta's AI glasses to build hands-free wearable experiences into their mobile applications.
By integrating this SDK, developers can reliably connect to Meta's AI glasses and leverage capabilities like video streaming and photo capture.

The Wearables Device Access Toolkit is in developer preview.
Developers can access our SDK and documentation, test on supported AI glasses, and create organizations and release channels to share with test users.

## Current implementation & samples

This repository includes sample apps that demonstrate the current set of features and flows available in the SDK.
You can use these as reference implementations or starting points.

- `samples/CameraAccess`: Full streaming UI that connects to Meta AI glasses, streams the camera feed, captures photos, and shares captured media.
- `samples/QuickCapture`: CameraAccess-based variant with the same core streaming and capture flow.
- `samples/QuickCaptureLite`: Minimal SwiftUI sample that covers registration/unregistration, device discovery, start/stop low-bandwidth streaming, on-demand JPEG capture, and simple real-time effects (mono/comic + face-detection overlay).
- `samples/PhotoTextScan`: Standalone OCR sample (no glasses required) that extracts text from photo-library images and saves results as `.txt` files.

## Documentation & Community

Find our full [developer documentation](https://wearables.developer.meta.com/docs/develop/) on the Wearables Developer Center.

You can find an overview of the Wearables Developer Center [here](https://wearables.developer.meta.com/).
Create an account to stay informed of all updates, report bugs and register your organization.
Set up a project and release channel to share your integration with test users.

For help, discussion about best practices or to suggest feature ideas visit our [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions).

See the [changelog](CHANGELOG.md) for the latest updates.

## Including the SDK in your project

The easiest way to add the SDK to your project is by using Swift Package Manager.

1. In Xcode, select **File** > **Add Package Dependencies...**
1. Search for `https://github.com/facebook/meta-wearables-dat-ios` in the top right corner
1. Select `meta-wearables-dat-ios`
1. Set the version to one of the [available versions](https://github.com/facebook/meta-wearables-dat-ios/tags)
1. Click **Add Package**
1. Select the target to which you want to add the packages
1. Click **Add Package**

## Developer Terms

- By using the Wearables Device Access Toolkit, you agree to our [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms),
  including our [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy).
- By enabling Meta integrations, including through this SDK, Meta may collect information about how users' Meta devices communicate with your app.
  Meta will use this information collected in accordance with our [Privacy Policy](https://www.meta.com/legal/privacy-policy/).
- You may limit Meta's access to data from users' devices by following the instructions below.

### Opting out of data collection

To configure analytics settings in your Meta Wearables DAT iOS app, you can modify your app's `Info.plist` file using either of these two methods:

**Method 1:** Using Xcode (Recommended)

1. In Xcode, select your app target in the **Project** navigator
1. Go to the **Info** tab
1. Navigate to **Custom iOS Target Properties**  and find the `MWDAT` key
1. Add a new key under `MWDAT` called `Analytics` of type `Dictionary`
1. Add a new key to the `Analytics` dictionary called `OptOut` of type `Boolean` and set the value to `YES`

**Method 2:** Direct XML editing

Add or modify the following in your `Info.plist` file.

```XML
<key>MWDAT</key>
<dict>
    <key>Analytics</key>
    <dict>
        <key>OptOut</key>
        <true/>
    </dict>
</dict>
```

**Default behavior:** If the `OptOut` key is missing or set to `NO`/`<false/>`, analytics are enabled
(i.e., you are **not** opting out). Set to `YES`/`<true/>` to disable data collection.

**Note:** In other words, this setting controls whether or not you're opting out of analytics:

- `YES`/`<true/>` = Opt out (analytics **disabled**)
- `NO`/`<false/>` = Opt in (analytics **enabled**)

## License

See the [LICENSE](LICENSE) file.

## Program Summary

- iOS SDK and sample apps for integrating Meta AI glasses via the Meta Wearables Device Access Toolkit.
- Samples cover streaming from glasses, photo capture/sharing, low-bandwidth streaming with effects, and a standalone photo OCR utility (no glasses required).

## How to Use

- Open a sample project in Xcode (e.g., `samples/CameraAccess`, `samples/QuickCapture`, `samples/QuickCaptureLite`, `samples/PhotoTextScan`) and build/run.
- For glasses-based samples: enable Developer Mode in the Meta AI app, then use the in-app Connect flow to register and stream.
- For `QuickCaptureLite`: update `MetaAppID` and `ClientToken` in `Info.plist` to match your organization.
- For `PhotoTextScan`: set signing, update bundle ID, and run on device or simulator.

## Completion Status

- **Partial** — the SDK is explicitly in developer preview and the repo focuses on sample apps and reference flows rather than a production-ready product.

## Program Summary

- iOS sample apps demonstrating the Meta Wearables Device Access Toolkit: connect to Meta AI glasses, stream camera video, capture photos, and manage sessions.
- Includes a standalone PhotoTextScan app that performs OCR on photo library images and saves text files (no glasses required).

## How to Use

- Not verified: open a sample Xcode project in `samples/*`, select the target, set signing/bundle ID, then build/run on iOS 17+.
- For glasses-based samples: enable Developer Mode in the Meta AI app and complete the in-app Connect/registration flow.
- For `QuickCaptureLite`: update `MetaAppID` and `ClientToken` in `Info.plist` to match your organization.

## Completion Status

- **Partial** — repository is primarily sample/reference apps and the underlying SDK is labeled developer preview.

## Program Summary

- iOS SDK samples for Meta AI glasses using the Meta Wearables Device Access Toolkit (streaming video, photo capture, device/session flows).
- Includes `PhotoTextScan`, a standalone OCR utility for photo-library images (no glasses required).

## How to Use

- Not verified: open a sample Xcode project in `samples/*`, set signing/bundle ID, then build/run.
- For glasses-based samples: enable Developer Mode in the Meta AI app and complete the in-app Connect/registration flow.
- For `QuickCaptureLite`: set `MetaAppID` and `ClientToken` in `Info.plist` for your organization.

## Completion Status

- **Partial** — focused on reference/sample apps, and the SDK is explicitly marked developer preview.

## Program Summary

- Meta Wearables Device Access Toolkit iOS samples for connecting to Meta AI glasses, streaming video, and capturing photos.
- Includes `QuickCaptureLite` for minimal streaming/registration flows and `PhotoTextScan` for on-device OCR of photo library images (no glasses required).

## How to Use

- Not verified: open a sample Xcode project under `samples/` (e.g., `CameraAccess`, `QuickCapture`, `QuickCaptureLite`, `PhotoTextScan`) and build/run on iOS 17+.
- For glasses-based samples: enable Developer Mode in the Meta AI app, then use the app's **Connect** flow to register and stream.
- For `QuickCaptureLite`: set `MetaAppID` and `ClientToken` in `Info.plist` to match your organization.
- For `PhotoTextScan`: configure signing/bundle ID in Xcode before running.

## Completion Status

- **Partial** — the repository centers on sample/reference apps and the SDK is described as developer preview; production readiness is not indicated.

## Program Summary

- Meta Wearables Device Access Toolkit iOS SDK with sample apps for connecting to Meta AI glasses, streaming video, and capturing photos.
- Includes a standalone `PhotoTextScan` sample for OCR on photo-library images (no glasses required).

## How to Use

- Not verified: open a sample Xcode project under `samples/`, set signing/bundle ID, then build and run in Xcode.
- For glasses-based samples: enable Developer Mode in the Meta AI app and complete the app's Connect/registration flow.
- For `QuickCaptureLite`: set `MetaAppID` and `ClientToken` in `Info.plist` for your organization.

## Completion Status

- **Partial** — the SDK is labeled developer preview and the repository is primarily sample/reference apps rather than a production-ready product.

## Program Summary

- iOS sample projects showcasing the Meta Wearables Device Access Toolkit for Meta AI glasses (streaming, capture, and session flows).
- Includes `PhotoTextScan`, a standalone OCR sample that scans photo library images without glasses.

## How to Use

- Not verified: open a sample Xcode project under `samples/`, set signing/bundle ID, then build and run in Xcode.
- For glasses-based samples: enable Developer Mode in the Meta AI app and complete the Connect/registration flow.
- For `QuickCaptureLite`: configure `MetaAppID` and `ClientToken` in `Info.plist` for your organization.

## Completion Status

- **Partial** — repository is oriented around reference/sample apps and the SDK is explicitly marked developer preview.

## Program Summary

- iOS SDK and sample apps for Meta Wearables Device Access Toolkit, focused on connecting to Meta AI glasses, streaming video, and capturing photos.
- Includes `PhotoTextScan`, a standalone OCR sample that extracts text from photo-library images (no glasses required).

## How to Use

- Not verified: open a sample Xcode project under `samples/` (e.g., `CameraAccess`, `QuickCapture`, `QuickCaptureLite`, `PhotoTextScan`), set signing/bundle ID, then build/run in Xcode.
- For glasses-based samples: enable Developer Mode in the Meta AI app and complete the in-app Connect/registration flow.
- For `QuickCaptureLite`: set `MetaAppID` and `ClientToken` in `Info.plist` for your organization.

## Completion Status

- **Partial** — the SDK is labeled developer preview and the repo centers on sample/reference apps rather than a production-ready product.
