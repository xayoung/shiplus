# Titillium Web font files

ShiPlus uses Titillium Web as its global font.

## Download the font

Download the family from
[Google Fonts](https://fonts.google.com/specimen/Titillium+Web) or obtain the
TTF files from the
[Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/titilliumweb).

Place these files in `assets/fonts/`:

```text
assets/fonts/
├── TitilliumWeb-Regular.ttf
├── TitilliumWeb-Bold.ttf
├── TitilliumWeb-Light.ttf
└── TitilliumWeb-SemiBold.ttf
```

## Flutter configuration

The family is configured in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Titillium Web
      fonts:
        - asset: assets/fonts/TitilliumWeb-Regular.ttf
          weight: 400
        - asset: assets/fonts/TitilliumWeb-Light.ttf
          weight: 300
        - asset: assets/fonts/TitilliumWeb-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/TitilliumWeb-Bold.ttf
          weight: 700
```

Titillium Web is distributed under the SIL Open Font License 1.1.

## Troubleshooting

If the font is not applied:

1. Confirm that every configured TTF file exists in `assets/fonts/`.
2. Verify the font declarations in `pubspec.yaml`.
3. Run `flutter clean` followed by `flutter pub get`.
4. Rebuild the application.
