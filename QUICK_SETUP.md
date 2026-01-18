# ⚡ Quick Setup (2 Minutes)

## Step 1: Add xcconfig to Xcode

1. **In Xcode**, right-click on the project root (blue icon)
2. Select **"Add Files to speaktype..."**
3. Navigate to and select **`Config.xcconfig`**
4. ✅ Make sure **"Add to targets: speaktype"** is checked
5. Click **"Add"**

## Step 2: Apply Config to Target

1. Click the **project name** (blue icon) in the navigator
2. Select the **speaktype project** (not target) in the editor
3. Click **"Info"** tab at the top
4. Under **"Configurations"**, expand both **Debug** and **Release**
5. For the row with **"speaktype"** (your target):
   - Click the dropdown under **Debug** → Select **"Config"**
   - Click the dropdown under **Release** → Select **"Config"**

## Step 3: Build & Test

1. Press **Cmd + B** to build
2. Run the app
3. Check Console.app for:
   ```
   ✅ Using Polar Organization ID from Info.plist
   ```

## Done! 🎉

Your credentials are now:
- ✅ Baked into the app binary
- ✅ Private (Config.xcconfig is gitignored)
- ✅ Production-ready for distribution

---

## Troubleshooting

**Can't find Config.xcconfig in Xcode?**
- It's there, but hidden from git
- In Finder: Go to your project folder, you'll see `Config.xcconfig`
- Right-click → "Add Files to speaktype..."

**Still showing warning?**
- Clean build folder: **Cmd + Shift + K**
- Restart Xcode
- Verify the xcconfig has no quotes around values

**Need help?** See full guide: `PRODUCTION_SETUP.md`

