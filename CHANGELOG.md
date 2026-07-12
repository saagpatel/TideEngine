# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Interactive gravitational tide visualization, NOAA prediction views, and WidgetKit extension.
- Optional user-initiated nearby-station lookup with visible permission and location errors.
- Xcode test, release-build, archive, and CodeQL automation.

### Changed

- Limited live prediction coverage to supported NOAA regions and removed the unsafe client-side international purchase and credential path.
- Hardened NOAA request construction, timeouts, response-size checks, privacy disclosures, signing defaults, and App Store metadata.
