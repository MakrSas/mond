<p align="right">
  <img align="right" height="140" src="https://github.com/rooootdev/mond/blob/main/mond.png?raw=true" style="float: right;"/>
</p>

<div style="width: calc(100% - 180px);">
  <h1 style="margin-bottom: 0;">mond</h1>
</div>

<p align="left">
  Edit MobileGestalt on iOS 27.0 beta 1 - 4!<br>
  <a href="https://discord.gg/gw8PcRF3Jr">
    <img src="https://img.shields.io/badge/Discord-Join%20Server-7289DA.svg" alt="Discord">
  </a>
  <a href="https://github.com/rooootdev/mond/stargazers">
    <img src="https://img.shields.io/github/stars/rooootdev/mond?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/rooootdev/mond/issues">
    <img src="https://img.shields.io/github/issues/rooootdev/mond" alt="GitHub issues">
  </a>
</p>

> [!WARNING]  
> Some of the tweaks have the potential to brick your device!<br>Use at your own risk.

>[!NOTE]
> No questions regarding Apple Intelligence will be answered in GitHub issues anymore.<br>Ask in the [discord server](https://discord.gg/gw8PcRF3Jr).

**Version Support:**
| iOS Version | Support |
|---|---|
| iOS ≤ 26.x | unsupported |
| iOS 27.0 dev beta 1–4 | supported |
| iOS 27.0 public beta 1–2 | supported |
| iOS 27.0 dev beta ≥ 5 | unupported |
| iOS 27.0 public beta ≥ 3 | unsupported |

**Planned:**<br>
&#45; HouseArrest file browser<br>

**Implemented:**<br>
&#45; Pocket Poster<br>
&#45; MobileGestalt Editor<br>
&#45; Apple Intelligence one-click diagnostic and preparation flow with persistent logs<br>

<details><summary>MobileGestalt Tweaks:</summary>
  
**Device Artwork**<br>
&#45; Subtype: Changes the reported device artwork/model.<br>
&#45; Custom Device Name: Changes the reported device name.<br>

**Software-Oriented Features**<br>
&#45; Dynamic Island: Enables Dynamic Island.<br>
&#45; Always-On Display: Enables Always-On Display.<br>
&#45; AOD Vibrancy: Enables Always-On Display vibrancy.<br>
&#45; Charge Limit: Enables the charge limit feature.<br>
&#45; Boot Chime: Enables the boot sound.<br>
&#45; Liquid Glass LPM: Enables Liquid Glass in Low Power Mode.<br>

**Hardware-Oriented Features**<br>
&#45; Camera Control: Enables Camera Control.<br>
&#45; Action Button: Enables the Action Button.<br>
&#45; Crash Detection: Enables Crash Detection.<br>
&#45; Tap to Wake: Enables tap-to-wake.<br>
&#45; Pulse Width Modulation: Enables PWM functionality.<br>

**Eligibility**<br>
&#45; Security Research Device UI: Enables the Security Research Device interface.<br>
&#45; Disable Region Restrictions: Enables the US/LL/A region configuration.<br>
&#45; Apple Intelligence: Enables Apple Intelligence eligibility.<br>
&#45; Device Spoofing: Makes the device report a different supported model.<br>

**iPadOS Features**<br>
&#45; Allow Installing iPadOS Apps: Enables iPadOS app installation.<br>
&#45; Apple Pencil Settings: Enables Apple Pencil settings.<br>
&#45; Stage Manager: Enables Stage Manager on supported iPads.<br>
&#45; iPadOS UI: Enables the iPadOS-style UI and multitasking.<br>

**Internal**<br>
&#45; Internal Storage: Enables internal storage features.<br>
&#45; Internal Features: Enables internal Apple features.<br>
&#45; Metal HUD in All Apps: Enables the Metal HUD across apps.<br>
</details>
<sup>NOTE: Some tweaks may not appear on your device because they aren't supported.</sup>

**Known Issues:**<br>
&#45; Tweaks require a respring to take effect and may disappear after a full reboot<br>
&#45; Base iPhone 15 Apple Intelligence spoofing is experimental: use the **Apple Intelligence** one-click diagnostic flow to apply and verify the complete iOS 27 MobileGestalt identity payload, save the diagnostic log in `Documents/mond/AppleIntelligenceDiagnostics`, and respring after the write. A 7 GB model download or visible buttons do not prove that the downstream Siri generation gate is enabled; on iOS 27 beta 4 the authoritative `assistantd`/capability-service gate may still reject the physical A16 device, and full on-device features are not guaranteed.<br>
&#45; In diagnostics, `-254` means the probed path was not present when the legacy existence check ran, while `-3` means containermanager rejected the requested path as outside the app's sandbox. Neither result proves that GREYMATTER or the downloaded model is broken.<br>
&#45; Disable Region restrictions may be broken on some versions/devices<br>
&#45; iPadOS UI and related tweaks may not work and/or **bootloop** you!<br>

**Credits:**<br>
&#45; [forcequit](https://github.com/forcequitOS) for his work on bad_query<br>
&#45; [johnny](https://github.com/0xjohnnydev) for his work on the MCM bug class<br>
&#45; [jailbreak.party](https://github.com/jailbreakdotparty) for PartyUI, GestaltView and the implementation of [neon](https://github.com/neonmodder123)'s respring method<br>

<i>btw, you should like totally star this repo and stuff</i>
