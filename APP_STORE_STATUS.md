# 🍎 RackOff App Store Readiness Status

**Last Updated:** October 7, 2025

> 2026-05-14 note: App Store submission is not the active focus right now. The current priority is product sanity, repo/docs cleanup, and proving RackOff handles real screenshot-heavy desktops safely. Keep this file as the App Store checklist, but use `PROJECT_STATUS.md` and `TESTING.md` for the current working state.

---

## ✅ Completed (Ready for Submission)

### Code Compliance
- ✅ **Sandboxed** - App runs in Apple sandbox with proper entitlements
- ✅ **Entitlements** - Desktop, Documents, Downloads read-write access configured
- ✅ **Privacy Manifest** - `PrivacyInfo.xcprivacy` created with file timestamp/disk space API usage
- ✅ **Usage Descriptions** - All file access prompts have clear user-facing descriptions
- ✅ **No Deprecated APIs** - Clean build with no warnings
- ✅ **Memory Safe** - No leaks, proper ARC memory management
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

### 2. Developer Signing
**Status:** Using ad-hoc signing (for local development)
**Blocker:** Yes - Required for notarization and App Store

**What's needed:**
1. Apple Developer Program membership ($99/year)
2. "Mac App Distribution" certificate
3. Update `CODESIGN_IDENTITY` in build.sh with your Developer ID

**Instructions:**
```bash
# Check your certificates
security find-identity -v -p codesigning

# Update build.sh line 14:
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

### Minimum Path (Icon Only)
1. **Create app icon** → 2-4 hours
2. **Get Developer ID certificate** → 30 minutes
3. **Set up App Store Connect** → 15 minutes
4. **Build, sign, upload** → 30 minutes
5. **Fill metadata** → 1 hour
6. **Submit for review** → 5 minutes
7. **Wait for approval** → 1-3 days

**Total active time:** ~5 hours
**Total elapsed time:** ~1 week

### Recommended Path (Icon + Assets)
Same as above, plus:
- **Screenshots** → 1 hour
- **Privacy policy page** → 15 minutes

**Total active time:** ~6.5 hours
**Total elapsed time:** ~1 week

---

## 🎯 Current State Summary

**Code:** 100% ready ✅
**Documentation:** 100% ready ✅
**Assets:** 0% complete ❌
**Signing:** Not configured ❌
**App Store listing:** Not created ❌

**Readiness:** ~40%

**Biggest blockers:**
1. App icon (2-4 hours to create)
2. Developer ID signing (need Apple Developer membership)
3. App Store Connect setup (15 min once you have account)

---

## 🚀 Next Steps

### Immediate (This Session)
1. ✅ GLOSSARY.md committed
2. ✅ Branch merged to main
3. ✅ All changes pushed to GitHub
4. ✅ Privacy manifest created
5. ✅ Build script updated
6. ✅ Documentation complete

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

**You're ~5 hours of active work away from App Store submission!** 🎉
