# WorldCup pass — authoring & signing

A FIFA World Cup 2026 ticket as a real Apple Wallet pass bundle. `pass.json` is the single
source of truth: the WalletDemo app decodes it for the in-app card, and `build-pass.sh`
packages it (plus the images) into a `.pkpass`.

```
WorldCupPass.pass/        raw bundle source (committed)
  pass.json               the eventTicket definition
  icon / logo / strip PNGs (generated — see step 1)
gen_pass_assets.swift     headless PNG generator (CoreGraphics + ImageIO)
build-pass.sh             packages WorldCupPass.pass/ -> .pkpass (signs only if a cert is given)
```

The built bundle lives at `../Resources/WorldCupPass.pkpass` (bundled into the app).

## 1. Regenerate the image assets (only if missing/changed)

Not wired into any build — run it manually. It overwrites the PNGs in the `.pass` dir:

```bash
swift Pass/gen_pass_assets.swift Pass/WorldCupPass.pass
```

## 2. Build the bundle

**Unsigned** (structurally complete, "ready to sign" — this is what's committed):

```bash
Pass/build-pass.sh Pass/WorldCupPass.pass Resources/WorldCupPass.pkpass
```

`manifest.json` (SHA-1 of every payload file) is written; the only missing piece is `signature`.

**Signed** (needs a paid Apple Developer Program → a Pass Type ID certificate):

```bash
Pass/build-pass.sh Pass/WorldCupPass.pass Resources/WorldCupPass.pkpass \
  passcert.pem passkey.pem AppleWWDRCAG3.pem [keyPassword]
```

## 3. Get the three PEMs (for signing)

Export the Pass Type ID certificate + key from Keychain Access as `pass.p12`, then:

```bash
openssl pkcs12 -in pass.p12 -clcerts -nokeys -out passcert.pem   # certificate
openssl pkcs12 -in pass.p12 -nocerts        -out passkey.pem    # private key
# Apple WWDR intermediate (download the .cer from Apple PKI), then:
openssl x509 -inform DER -in AppleWWDRCAG3.cer -out AppleWWDRCAG3.pem
```

## 4. Reconcile the placeholders before signing

`pass.json` ships with demo placeholders that **must** match your signing certificate, or
Wallet rejects even a correctly-signed pass:

- `passTypeIdentifier` — currently `pass.com.pablo.walletdemo.worldcup2026`
- `teamIdentifier` — currently `ABCDE12345`

Set both to the registered Pass Type ID and your 10-character Team ID, then rebuild (step 2).

> A self-signed certificate produces a structurally valid signature but Wallet still rejects
> it — PassKit pins Apple's WWDR PKI, even on the Simulator. A real Pass Type ID cert is required.
