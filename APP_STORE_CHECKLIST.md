# 🚀 RackOff App Store Submission Checklist

Complete guide for submitting RackOff to the Mac App Store.

## Prerequisites

### 1. Apple Developer Account
- [ ] Enrolled in Apple Developer Program ($99/year)
- [ ] Account in good standing
- [ ] Access to App Store Connect

### 2. Developer Certificates
```bash
# Check your signing identities
security find-identity -v -p codesigning
```

You need:
- [ ] **Developer ID Application** certificate (for notarization)
- [ ] **Mac App Distribution** certificate (for App Store)

**Get certificates:**
1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Create "Mac App Distribution" certificate
3. Download and install in Keychain Access

### 3. App Store Connect Setup
- [ ] Create app record in [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Bundle ID: `com.pablo.rackoff`
- [ ] App name: "RackOff - Desktop Cleaner" (or "RackOff" if available)
- [ ] SKU: `rackoff-v1` (internal identifier)

---

## Phase 1: Code Compliance ✅

### Already Completed:
- ✅ Sandboxed with proper entitlements
- ✅ Privacy manifest (PrivacyInfo.xcprivacy)
- ✅ Usage descriptions for file access
- ✅ No deprecated APIs
- ✅ Memory-safe code
- ✅ Hardened runtime flags set

### Remaining:
- [ ] **Create app icon** - See `ICON_REQUIREMENTS.md`
  - Need 1024x1024 PNG source
  - Generate .icns with all resolutions
  - Add to build script
- [ ] **Test sandbox behavior**
  - Verify file access prompts work
  - Test Desktop/Documents/Downloads access
  - Ensure security-scoped bookmarks persist

---

## Phase 2: Build & Sign

### Update Developer ID

1. Open `build.sh`
2. Find line: `CODESIGN_IDENTITY="-"`
3. Replace with your Developer ID:
   ```bash
   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
   ```

### Build for Distribution

```bash
# Clean build
rm -rf RackOff.app

# Build with your Developer ID
./build.sh
```

### Verify Signing

```bash
# Check signature
codesign --verify --deep --strict --verbose=2 RackOff.app

# Check Gatekeeper will accept it
spctl --assess --type execute --verbose RackOff.app

# Verify entitlements
codesign -d --entitlements - RackOff.app
```

Expected output: `satisfies its Designated Requirement`

---

## Phase 3: Notarization

Apple requires notarization for all apps distributed outside the App Store. This validates your app doesn't contain malware.

### Create App-Specific Password

1. Go to [Apple ID account page](https://appleid.apple.com)
2. Sign in → Security section
3. Generate "App-Specific Password" for notarization
4. Save it securely

### Notarize the App

```bash
# Create a ZIP of the app
ditto -c -k --keepParent RackOff.app RackOff.zip

# Submit for notarization
xcrun notarytool submit RackOff.zip \
  --apple-id "your-email@example.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait

# If successful, staple the notarization ticket
xcrun stapler staple RackOff.app
```

**Track notarization:**
```bash
# Get submission ID from previous command, then:
xcrun notarytool info <submission-id> \
  --apple-id "your-email@example.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID"
```

---

## Phase 4: App Store Assets

### Required Screenshots

Need 3-5 screenshots for Mac App Store listing:

**Sizes Required:**
- 1280 x 800 px (or higher, 16:10 aspect ratio)
- 2560 x 1600 px (Retina recommended)

**Screenshot Ideas:**
1. **Main popover** - Show the clean button and file type toggles
2. **Before/After desktop** - Messy desktop → clean desktop
3. **Preferences window** - Show customization options
4. **Organization modes** - Quick Archive, Sort by Type, Smart Clean
5. **Menu bar integration** - Show the sparkles icon in menu bar

**Capture Screenshots:**
```bash
# Use built-in screenshot tool (Cmd+Shift+4)
# Or for specific window:
Cmd+Shift+5 → Select window

# Resize if needed
magick input.png -resize 2560x -quality 90 output.png
```

See `~/Documents/reference/WORKFLOW-screenshot-standards.md` for processing.

### App Preview Video (Optional but Recommended)

15-30 second video showing:
1. Click menu bar icon
2. Select files to organize
3. Click "Clean Desktop" button
4. Show clean desktop result

**Specs:**
- 1920x1080 or 2560x1600
- .mov or .mp4 format
- Max 500 MB
- No audio required (captions preferred)

### Marketing Copy

**App Name:** RackOff

**Subtitle:** (30 characters max)
"Desktop chaos? Not anymore."

**Description:** (4000 characters max - use README.md content)
```
Your desktop's chaos nemesis. Finally.

You know that desktop situation? The one where screenshots multiply like rabbits and random PDFs just... appear?

RackOff swoops in, sorts it all into tidy dated folders, then gets out of your way. One click. Desktop's clean. You're back to work (or whatever).

THREE WAYS TO ORGANIZE
• Quick Archive – everything into daily folders
• Sort by Type – files find their tribes
• Smart Clean – you decide what goes where

WHAT IT HANDLES
• Screenshots that pile up during debugging
• Documents that drift in from who knows where
• Media files having a party on your desktop
• Archives that seemed important last Tuesday

SCHEDULING OPTIONS
• Manual (when the mood strikes)
• On launch (fresh start every time)
• Daily at 9 AM (set it and forget it)

Everything lands safe in Documents/Archive/[organized by date or type]
Nothing's deleted. Just... relocated.

NO BS INCLUDED
• No accounts to make
• No cloud to feed
• No AI watching
• Just a clean desktop when you need one

Built in Bangkok with plenty of coffee and mild frustration at my own desktop.
```

**Keywords:** (100 characters max)
```
desktop,cleaner,organizer,files,productivity,utility,screenshots,workspace,tidy,automation
```

**What's New:** (4000 characters max - for updates)
```
Initial release - RackOff is here to clean your desktop chaos!
```

**Promotional Text:** (170 characters max - editable without review)
```
Launch special! Desktop chaos got you down? RackOff organizes your files with one click. No accounts, no cloud, no drama.
```

### Privacy Policy

Required even though you collect zero data.

**Simple template:**
```
Privacy Policy for RackOff

Last updated: [DATE]

RackOff does not collect, store, or transmit any personal data.

Data Storage:
- All file organization happens locally on your Mac
- No data is sent to external servers
- No analytics or tracking of any kind

File Access:
- RackOff accesses your Desktop, Documents, and Downloads folders
  only when you explicitly run a cleaning operation
- All file operations use Apple's security-scoped bookmarks
- You control which folders RackOff can access via macOS permissions

Contact:
For questions about this privacy policy: [your-email]
```

Host this at: `https://yourwebsite.com/rackoff/privacy`

---

## Phase 5: App Store Connect Submission

### Upload Build

**Method 1: Via Xcode (Recommended)**
1. Open Xcode
2. Window → Organizer
3. Click "Distribute App"
4. Select "App Store Connect"
5. Upload

**Method 2: Via Transporter App**
1. Download [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)
2. Sign in with Apple ID
3. Drag RackOff.app into Transporter
4. Click "Deliver"

**Method 3: Via Command Line**
```bash
# Create an archive first
xcodebuild archive \
  -scheme RackOff \
  -archivePath RackOff.xcarchive

# Then export
xcodebuild -exportArchive \
  -archivePath RackOff.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist exportOptions.plist
```

### Complete App Store Connect Listing

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Fill in all metadata:
   - [ ] App name
   - [ ] Subtitle
   - [ ] Description
   - [ ] Keywords
   - [ ] Screenshots (3-5 required)
   - [ ] App icon (1024x1024)
   - [ ] Category: Productivity or Utilities
   - [ ] Age rating (4+)
   - [ ] Privacy policy URL
   - [ ] Support URL
   - [ ] Marketing URL (optional)

4. Set pricing:
   - [ ] Free or paid ($0.99 - $1.99 recommended)
   - [ ] Available in which countries

5. Add build:
   - [ ] Select uploaded build
   - [ ] Export compliance: No encryption
   - [ ] Content rights: Yes, I own all rights

6. Complete review information:
   - [ ] Contact information
   - [ ] Demo account (if needed - N/A for RackOff)
   - [ ] Notes for reviewer (see below)

### Review Notes Template

```
NOTES FOR APP REVIEW:

RackOff is a simple desktop cleaning utility that organizes files into folders.

TESTING INSTRUCTIONS:
1. Launch RackOff (menu bar icon appears)
2. Grant file access permissions when prompted
3. Place test files on Desktop
4. Click menu bar icon → "Clean Desktop" button
5. Verify files moved to ~/Documents/Archive/

FILE ACCESS PERMISSIONS:
The app will request access to:
- Desktop (source for files to organize)
- Documents (destination for Archive folder)
- Downloads (optional, if enabled in preferences)

This is the core functionality - organizing user files into dated folders.
No data is collected or transmitted. All operations are local.

Thank you for reviewing!
```

---

## Phase 6: Submit for Review

1. Review everything one last time
2. Click "Submit for Review"
3. Wait (usually 24-48 hours)

### If Rejected

Common rejection reasons:
- **Missing icon**: Add proper .icns file
- **Metadata incomplete**: Fill all required fields
- **Privacy policy missing**: Add URL
- **Functionality unclear**: Better screenshots + description
- **Crashes**: Test thoroughly before resubmit

Fix issues and resubmit. Most apps get approved within 2-3 submission cycles.

---

## Phase 7: Post-Approval

### When Approved
- [ ] Click "Release" in App Store Connect
- [ ] App goes live within 24 hours
- [ ] Share on social media
- [ ] Add "Download on Mac App Store" badge to website

### Ongoing Maintenance
- [ ] Monitor reviews
- [ ] Respond to user feedback
- [ ] Plan updates (bug fixes, features)
- [ ] Keep Developer Program membership active

---

## Quick Checklist Summary

**Before Submitting:**
- [ ] App icon created and integrated
- [ ] Build signed with Developer ID
- [ ] App notarized successfully
- [ ] Screenshots captured (3-5 images)
- [ ] Privacy policy published
- [ ] App Store Connect listing complete
- [ ] Tested on clean macOS install

**Submission:**
- [ ] Build uploaded
- [ ] All metadata filled
- [ ] Review notes added
- [ ] Submitted for review

**After Approval:**
- [ ] Released to App Store
- [ ] Marketing materials prepared
- [ ] Support channels ready

---

## Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Mac App Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)

---

**Estimated Timeline:**
- Icon creation: 2-4 hours
- Screenshots: 1 hour
- Build/sign/notarize: 30 minutes
- App Store Connect setup: 1 hour
- Review wait: 1-3 days
- **Total: ~1 week from start to approved**

Good luck with your App Store submission! 🚀
