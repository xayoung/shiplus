# ShiPlus Windows Installer Guide

This guide explains how to create the ShiPlus Windows installer with NSIS.

## Prerequisites

1. Install the Flutter SDK and configure Windows desktop development.
2. Install NSIS (Nullsoft Scriptable Install System).

## Quick start

To build the Flutter application, install NSIS when necessary, and create the
installer in one step, run:

```batch
scripts\build-installer.bat --build-app --install-nsis
```

## Build in separate steps

Build the Flutter Windows application:

```batch
scripts\build-installer.bat --build-app
```

Create the installer from an existing Flutter release build:

```batch
scripts\build-installer.bat
```

## Options

- `--build-app`: Build the Flutter Windows application first.
- `--install-nsis`: Install NSIS automatically when necessary.
- `--help`: Show command-line help.

## Files

- `scripts/shiplus_installer.nsi`: NSIS installer definition.
- `scripts/build-installer.bat`: Main installer build script.
- `build/windows/installer/ShiPlus_Setup.exe`: Generated installer.

## Troubleshooting

### NSIS is not found

Install NSIS or run the script with `--install-nsis`.

### The build fails

Confirm that the Flutter Windows release build succeeds and that
`build\windows\x64\runner\Release` contains all required files.

### Customize the installer

Edit `scripts\shiplus_installer.nsi`.
