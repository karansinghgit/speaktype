# 🚀 Production Build Setup

This guide explains how to configure licensing credentials for building and distributing SpeakType.

---

## 🔐 Configuration Methods

### Method 1: xcconfig File (Recommended for Production)

**For maintainers building releases:**

1. Copy the template:
   ```bash
   cp Config.xcconfig.template Config.xcconfig
   ```

2. Edit `Config.xcconfig` with your real values:
   ```
   POLAR_ORGANIZATION_ID = bf5894db-32cc-4117-93ee-d89efd98a03d
   POLAR_PURCHASE_URL = https://buy.polar.sh/polar_cl_5xXVrqmxABEotyU8zHHfkoQg9qqEzWDuca3fd0jaBgB
   ```

3. In Xcode, **add the xcconfig to your target:**
   - Select project in navigator
   - Go to Info tab
   - Under "Configurations" → expand "Debug" and "Release"
   - For the "speaktype" target, select `Config.xcconfig`
   
4. Build your app - credentials are now baked in! 🎉

**Security:** `Config.xcconfig` is gitignored. Your credentials stay private.

---

### Method 2: Xcode Scheme Environment Variables (Development)

**For local development and testing:**

1. In Xcode: Scheme dropdown → "Edit Scheme..."
2. Select "Run" → "Arguments" tab
3. Add to "Environment Variables":
   ```
   POLAR_ORGANIZATION_ID = your-test-id
   POLAR_PURCHASE_URL = https://polar.sh
   ```
4. ✅ Check both boxes to enable

**Note:** These override Info.plist values (useful for testing).

---

## 📦 For Open Source Contributors

If you're contributing and need to test:

1. Copy the template:
   ```bash
   cp Config.xcconfig.template Config.xcconfig
   ```

2. Use test/dummy values (license validation will fail gracefully)

3. OR get your own Polar test organization ID from https://polar.sh

---

## 🏗️ How It Works

The app reads credentials in this priority order:

1. **Environment Variables** (Xcode scheme) - Highest priority
2. **Info.plist** (populated from xcconfig at build time)
3. **Fallback** - Logs warning, license features won't work

This means:
- ✅ Production builds have credentials baked in
- ✅ Developers can override with test values
- ✅ Open source code stays clean

---

## 🔑 Where to Find Your Credentials

### Polar Organization ID
1. Go to https://polar.sh
2. Sign in
3. Settings → Organization
4. Copy the UUID (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

### Purchase URL
Your unique checkout link from Polar.sh (starts with `https://buy.polar.sh/polar_cl_...`)

---

## ✅ Verifying Configuration

Run the app and check Console.app for:

**Success:**
```
✅ Using Polar Organization ID from Info.plist
```

**Needs setup:**
```
⚠️ Warning: POLAR_ORGANIZATION_ID not configured
```

---

## 🚨 Security Notes

- ✅ `Config.xcconfig` is gitignored
- ✅ The Organization ID is NOT a secret admin key - it's used for API validation
- ✅ Worst case if leaked: someone could validate licenses (not create/revoke them)
- ⚠️ Still keep it private as a best practice

---

## 📝 Quick Reference

**Files you SHOULD commit:**
- ✅ `Config.xcconfig.template` (template for contributors)
- ✅ `Info.plist` (with `$(VARIABLE)` placeholders)

**Files you should NOT commit:**
- ❌ `Config.xcconfig` (your real credentials)
- ❌ Modified scheme files with environment variables

---

## 🐛 Troubleshooting

### "POLAR_ORGANIZATION_ID not configured"

**Check 1:** Is `Config.xcconfig` in your project?
```bash
ls Config.xcconfig
```

**Check 2:** Is it applied to your target in Xcode?
- Project → Info tab → Configurations
- Should show "Config.xcconfig" next to your target

**Check 3:** Did you restart Xcode after adding it?

**Check 4:** Are the values correct (no quotes, no trailing spaces)?

### "License validation failed"

This means the app is running but the Org ID might be wrong. Double-check:
1. Copy from Polar.sh settings (the full UUID)
2. No extra quotes or spaces in `Config.xcconfig`
3. Try cleaning build folder (Cmd+Shift+K)

---

Need help? Check the code in `LicenseManager.swift` to see the exact logic! 🔍

