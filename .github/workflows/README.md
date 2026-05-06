# GitHub Actions Workflows

This directory contains automated build workflows for the ShiPlus application.

## Workflows

### 1. Build and Release (`build-release.yml`)

Automatically builds and releases the application for macOS and Windows when a new tag is pushed.

**Triggers:**
- Push tags matching `v*` (e.g., `v1.0.0`, `v1.2.3`)
- Manual workflow dispatch with custom version

**Outputs:**
- **macOS**: DMG installer package
- **Windows**: 
  - Portable ZIP package (extract and run)
  - NSIS installer EXE (traditional installer)

**Usage:**

To create a new release:

```bash
# Create and push a new tag
git tag v1.0.0
git push origin v1.0.0
```

Or manually trigger from GitHub Actions tab with a custom version number.

### 2. Build Test (`build-test.yml`)

Tests the build process on every push to main branches and pull requests.

**Triggers:**
- Push to `main`, `master`, or `develop` branches
- Pull requests to these branches

**Purpose:**
- Verify builds work on both platforms
- Run tests
- Catch build issues early

## Release Process

### Automatic Release (Recommended)

1. Update version in `pubspec.yaml`
2. Commit changes:
   ```bash
   git add pubspec.yaml
   git commit -m "Bump version to 1.0.0"
   ```
3. Create and push tag:
   ```bash
   git tag v1.0.0
   git push origin main
   git push origin v1.0.0
   ```
4. GitHub Actions will automatically:
   - Build macOS DMG
   - Build Windows portable ZIP
   - Build Windows NSIS installer
   - Create GitHub release with all artifacts

### Manual Release

1. Go to GitHub Actions tab
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. Enter version number (e.g., `1.0.0`)
5. Click "Run workflow"

## Build Artifacts

### macOS DMG
- **File**: `shiplus-{version}-macos.dmg`
- **Type**: Disk image installer
- **Usage**: Double-click to mount, drag app to Applications folder

### Windows Portable ZIP
- **File**: `shiplus-{version}-windows-portable.zip`
- **Type**: Portable application
- **Usage**: 
  1. Extract ZIP to any folder
  2. Run `shiplus.exe`
  3. No installation required

### Windows NSIS Installer
- **File**: `shiplus-{version}-windows-setup.exe`
- **Type**: Traditional Windows installer
- **Usage**:
  1. Run the installer
  2. Follow installation wizard
  3. Creates Start Menu shortcuts
  4. Creates Desktop shortcut
  5. Adds to Programs and Features for easy uninstall

## Requirements

### For macOS builds:
- macOS runner (provided by GitHub)
- Flutter SDK 3.35.1 (Dart SDK 3.9.0)
- Xcode (pre-installed on runner)

### For Windows builds:
- Windows runner (provided by GitHub)
- Flutter SDK 3.35.1 (Dart SDK 3.9.0)
- NSIS 3.09 (automatically installed)
- Visual Studio build tools (pre-installed on runner)

## Troubleshooting

### Build fails on macOS
- Check Flutter version compatibility
- Verify macOS build settings in `macos/` directory
- Check Xcode project configuration

### Build fails on Windows
- Verify Windows build settings in `windows/` directory
- Check Visual Studio project configuration
- Ensure all dependencies are properly declared

### NSIS installer fails
- Check `installer.nsi` script syntax
- Verify all files exist in build directory
- Check LICENSE.txt file exists

### Release not created
- Ensure tag starts with `v` (e.g., `v1.0.0`)
- Check GitHub token permissions
- Verify workflow completed successfully

## Customization

### Change Flutter version
Edit both workflow files:
```yaml
flutter-version: '3.35.1'  # Change to desired version
```

**Note**: Current version uses Flutter 3.35.1 (Dart SDK 3.9.0) for compatibility with all dependencies.

### Modify NSIS installer
Edit the NSIS script section in `build-release.yml`:
- Change app name, publisher, icons
- Add/remove installation components
- Customize installer pages

### Add more platforms
Create new jobs in `build-release.yml`:
- Linux (AppImage, Snap, Flatpak)
- Android (APK, AAB)
- iOS (IPA)

## Notes

- Artifacts are retained for 7 days in workflow runs
- Release artifacts are permanent (until manually deleted)
- Build times: ~10-15 minutes per platform
- Concurrent builds supported (macOS and Windows build in parallel)
