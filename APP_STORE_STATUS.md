# RackOff App Store Submission Checklist

- **Original readiness snapshot:** October 7, 2025
- **Reframed:** May 14, 2026

This is now a submission checklist, not the live project status. App Store work is parked while RackOff goes through product sanity, Preferences cleanup, and real-desktop testing.

Use `PROJECT_STATUS.md` and `TESTING.md` for the current working state.

---

## Previously Completed Submission Prep

These items existed in the October 2025 submission pass. Revalidate them after the product/testing pass before treating the app as release-ready.

### Code Compliance
- ✅ **Sandboxed** - App runs in Apple sandbox with proper entitlements
- ✅ **Entitlements** - Desktop, Documents, Downloads read-write access configured
- ✅ **Privacy Manifest** - `PrivacyInfo.xcprivacy` created with file timestamp/disk space API usage
- ✅ **Usage Descriptions** - All file access prompts have clear user-facing descriptions
- ✅ **No Deprecated APIs** - Last checked during the previous submission pass
- ✅ **Memory Safe** - Last checked during the previous submission pass
- ✅ **Hardened Runtime** - Security flags configured in entitlements
- ✅ **Info.plist Complete** - All required keys present (bundle ID, version, copyright, category)

### Documentation
- ✅ **APP_STORE_CHECKLIST.md** - Complete submission guide with all steps
- ✅ **ICON_REQUIREMENTS.md** - Icon creation workflow and specifications
- ✅ **RECOVERY_GUIDE.md** - User documentation for sandbox file recovery
- ✅ **GLOSSARY.md** - Codebase reference for developers
- ✅ **README.md** - Marketing copy ready for App Store description

### Build System
- ✅ **build.sh Updated** - Copies privacy manifest, handles icon, shows readiness checklist
- ✅ **Version Control** - All changes committed and pushed to GitHub
- ✅ **Automated Checks** - Build script verifies signature and reports App Store status

---

## ❌ Required Before Submission

### 1. App Icon (Critical)
**Status:** Not created yet
**Blocker:** Yes - App Store will reject without proper icon

**What's needed:**
- 1024x1024 PNG source image
- Generate .icns with all resolutions (16x16 to 512x512 @2x)
- Place `RackOff.icns` in project root
- Rebuild with `./build.sh`

**Resources:**
- See `ICON_REQUIREMENTS.md` for complete instructions
- Design ideas: Sparkles + desktop, organized grid, magic broom
- Colors: Orange (#FF9933) to pink (#FF6699) gradient

**Time estimate:** 2-4 hours

### 2. Distribution Signing
**Status:** Using ad-hoc signing (for local development)
**Blocker:** Yes - Required before any real distribution

**What's needed:**
1. Apple Developer Program membership ($99/year)
2. For Mac App Store: Apple Distribution or Mac App Distribution signing
3. For direct downloads: Developer ID Application signing plus notarization
4. Update `CODESIGN_IDENTITY` in build.sh with the right certificate for the distribution path

**Instructions:**
```bash
# Check your certificates
security find-identity -v -p codesigning

# Mac App Store examples:
CODESIGN_IDENTITY="Apple Distribution: Your Name (TEAM_ID)"
CODESIGN_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAM_ID)"

# Direct distribution outside the Mac App Store:
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
```

**Time estimate:** 30 minutes (if you have Developer account)

### 3. App Store Connect Setup
**Status:** Not created yet
**Blocker:** Yes - Need app record to upload build

**What's needed:**
1. Create app in [App Store Connect](https://appstoreconnect.apple.com)
2. Bundle ID: `com.pablo.rackoff`
3. App name: "RackOff" or "RackOff - Desktop Cleaner"
4. SKU: `rackoff-v1`

**Time estimate:** 15 minutes

---

## 📸 Nice to Have (Not Blockers)

### Screenshots (Recommended)
**Status:** Not created
**Impact:** Medium - Increases conversion, but can submit with 1 screenshot minimum

**What's needed:**
- 3-5 screenshots at 2560x1600 (Retina)
- Show: main popover, before/after desktop, preferences, organization modes
- See `APP_STORE_CHECKLIST.md` Phase 4 for capture instructions

**Time estimate:** 1 hour

### App Preview Video (Optional)
**Status:** Not created
**Impact:** Low - Nice to have but not essential for launch

**What's needed:**
- 15-30 second demo video
- Show: click icon → select files → clean → result
- Format: .mov or .mp4, 1920x1080 or higher

**Time estimate:** 2 hours

### Privacy Policy Page (Required but Simple)
**Status:** Template provided in APP_STORE_CHECKLIST.md
**Impact:** High - Required field in App Store Connect

**What's needed:**
- Host simple privacy policy at `https://yourwebsite.com/rackoff/privacy`
- Template ready in `APP_STORE_CHECKLIST.md`
- Can use GitHub Pages, Netlify, or any hosting

**Time estimate:** 15 minutes

---

## 📋 Submission Timeline

### Historical Minimum Path

This estimate assumes the product behavior and Preferences UI have already been revalidated. That is not true right now.

1. **Create app icon** → 2-4 hours
2. **Get the right distribution certificate** → 30 minutes
3. **Set up App Store Connect** → 15 minutes
4. **Build, sign, upload** → 30 minutes
5. **Fill metadata** → 1 hour
6. **Submit for review** → 5 minutes
7. **Wait for approval** → 1-3 days

**Historical active-time estimate:** ~5 hours after product/test signoff
**Total elapsed time:** ~1 week

### Recommended Path (Icon + Assets)
Same as above, plus:
- **Screenshots** → 1 hour
- **Privacy policy page** → 15 minutes

**Historical active-time estimate:** ~6.5 hours after product/test signoff
**Total elapsed time:** ~1 week

---

## Current Submission State

- **Product/testing:** In progress; not ready for submission yet
- **Preferences UI:** Needs wiring/simplification before release
- **Code compliance:** Previously prepared, needs revalidation after product work
- **Documentation:** Current working docs live in `PROJECT_STATUS.md` and `TESTING.md`
- **Assets:** 0% complete ❌
- **Signing:** Not configured ❌
- **App Store listing:** Not created ❌

**Readiness:** Paused until product/test pass is complete

**Current blockers before returning to App Store work:**
1. Real-desktop screenshot test
2. Preferences wiring/simplification
3. Organization model decision for screenshots/docs
4. App icon
5. Distribution signing
6. App Store Connect setup

---

## 🚀 Next Steps

### Immediate
1. Run the safe smoke test and real Desktop screenshot test
2. Fix or simplify Preferences controls that are not wired to behavior
3. Decide whether screenshots/docs should default to daily, weekly, type, or another model
4. Revisit this checklist after the product pass

### Soon (Before Submission)
1. ❌ Design and create app icon
2. ❌ Enroll in Apple Developer Program (if not already)
3. ❌ Get signing certificate
4. ❌ Create App Store Connect listing

### Later (Post-Approval)
- Marketing website or landing page
- Social media announcement
- Product Hunt launch
- Consider promotional pricing

---

## 📞 Questions?

See `APP_STORE_CHECKLIST.md` for the complete step-by-step submission guide, including:
- Detailed icon creation workflow
- Certificate setup instructions
- Notarization process
- App Store Connect walkthrough
- Marketing copy templates
- Review notes template

Do not treat this as submission-ready until `PROJECT_STATUS.md` no longer lists product/testing and Preferences gaps.
