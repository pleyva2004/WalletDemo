# CLAUDE.md

Guidance for Claude (and other agents) working in this repository.

## Product

**WalletDemo** is a SwiftUI iOS app that demonstrates a **FIFA World Cup 2026 match ticket** in two forms (the "hybrid"):

1. **In-app mock pass card** — a SwiftUI view styled like an Apple Wallet `eventTicket` (team flags, kickoff, seat, QR). Long-pressing the card gives haptic feedback and reveals a Liquid-Glass "Ticket Details" island with a Siri rainbow glow.
2. **A real, ready-to-sign `.pkpass`** — an actual Apple Wallet pass bundle (`pass.json` + images + SHA-1 `manifest.json`), unsigned today and signable later with a Pass Type ID certificate.

`pass.json` is the **single source of truth**: the app decodes the same file that gets packaged into the `.pkpass`, so the mock always matches the real ticket.

The whole project is built and run **from the command line** (no Xcode GUI) via the `build-ios` harness on Apple Silicon (Xcode 26.x / iOS 26.x).

## Layout

```
Sources/
  WalletDemoApp.swift   @main entry point (WindowGroup -> ContentView)
  ContentView.swift     Home screen: pass card + "touch and hold" hint; long-press ->
                        haptic + Ticket Details island overlay (no Add-to-Wallet button)
  PassCardView.swift    The mock pass card: tap-logo header, sunburst hero, field rows,
                        CoreImage QR. Decodes everything from the PassDocument.
  PassHero.swift        TapLogo, SunburstSplit (Canvas rays), SunburstHero (match-day art)
  PassModel.swift       PassDocument (Codable subset of pass.json), Color(passRGB:),
                        date formatting (venue time via ignoresTimeZone), PassStore loader
  TicketDetails.swift   HapticsController (retained generators), SiriGlowBorder, GlassPanel
                        (iOS 26 Liquid Glass), TicketDetailsIsland
Pass/
  WorldCupPass.pass/pass.json   THE source of truth (also bundled into the app)
  WorldCupPass.pass/*.png       generated icon/logo/strip assets (committed)
  gen_pass_assets.swift         headless CoreGraphics PNG generator (run with `swift`)
  build-pass.sh                 packages .pass -> .pkpass (SHA-1 manifest; signs iff a cert is passed)
  README.md                     signing guide (free vs paid, the exact commands)
Resources/
  WorldCupPass.pkpass   built unsigned pass, bundled into the app
project.yml             XcodeGen spec (iOS 26 target, bundles pass.json + Resources)
run.sh                  build + run + screenshot harness (SIMULATOR ONLY)
```

## Build & run

```bash
./run.sh                 # regenerate project -> build -> boot sim -> install -> launch -> screenshot
./run.sh "iPhone Air"    # name a specific simulator (default prefers iPhone 17 Pro)
```

`run.sh` writes `WalletDemo-screenshot.png` — **always Read that PNG to visually confirm UI changes.** It builds for `generic/platform=iOS Simulator`; never hardcode a named device destination.

To regenerate pass assets / rebuild the `.pkpass` after editing `pass.json` or the art:
```bash
swift Pass/gen_pass_assets.swift Pass/WorldCupPass.pass          # (re)draw the PNGs
Pass/build-pass.sh Pass/WorldCupPass.pass Resources/WorldCupPass.pkpass   # repackage (unsigned)
```

## Coding standards

- **Macro-free SwiftUI.** Do NOT use `#Preview`, `@Observable`, SwiftData `@Model`, or other Swift macros — headless `xcodebuild` can fail on the macro plugin server. Use `@State`, `@Binding`, `ObservableObject`, `UIViewRepresentable`, etc.
- **pass.json is the single source of truth.** Render from the decoded `PassDocument`; don't hardcode ticket data in views. Keep `PassDocument.fallback` in parity with `pass.json`.
- **Colors** come from `pass.json` `rgb(r, g, b)` strings via `Color(passRGB:fallback:)`. Date fields use `ignoresTimeZone` to show venue-local time.
- **No force-unwraps in UI code.** Guard and degrade gracefully (see `AddPassesSheet`'s pattern in git history, and `PassStore`'s fallback).
- **Haptics** use a retained `HapticsController` (prepare on press-down, impact on reveal). They are silent no-ops on the Simulator — only a physical device plays them.
- Match the surrounding style: 4-space indent, `// MARK:` section headers, small private computed-view properties.
- After any UI change, run `./run.sh` and Read the screenshot before claiming it works.

## Git / commit conventions

- **Commits are authored solely by `pleyva2004` (Pablo Leyva).** Do **NOT** add a `Co-Authored-By: Claude ...` trailer, and do **NOT** add "Generated with Claude Code" or any Claude attribution to commit messages or PR bodies. This is a firm preference — keep Claude off the contributor list.
- Commit/push only when asked. Branch from `main`; mockup work goes on `mockup/<feature>` branches.
- The generated `.pkpass` and pass PNGs are intentionally committed (the app build needs them); `build/`, `*.xcodeproj`, and `*-screenshot.png` are gitignored.

## Signing & device notes

- The bundled `.pkpass` is **unsigned** ("ready to sign"). `PKPass(data:)` throws on an unsigned pass (`PKPassKitErrorDomain`, code 1) — expected until signed.
- Adding a pass to Wallet needs **no entitlement**; signing a real pass needs a paid **Pass Type ID** cert (see `Pass/README.md`).
- Installing on a physical device needs code signing (a free Apple ID Personal Team + `DEVELOPMENT_TEAM` + Developer Mode on the phone). `run.sh` is Simulator-only; use Xcode or `xcodebuild -destination 'id=<UDID>' -allowProvisioningUpdates` + `devicectl` for device installs.

## Gotchas

- Right after a Simulator runtime install, named `-destination`s may not resolve — the generic Simulator destination always does (`run.sh` handles this).
- Never `xcrun simctl runtime delete` a runtime image (can nuke the shared backing asset).
- Keep builds deterministic and headless — the macro-free rule above exists for this reason.
