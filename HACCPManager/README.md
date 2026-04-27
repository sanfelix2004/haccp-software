# HACCPManager

Professional HACCP app for restaurants.

## Architecture

This project follows a feature-based architecture pattern using SwiftUI and MVVM.

### Structure
- **Core**: Shared logic, networking, auth, local storage, components, extensions.
- **Features**: Distinct feature modules (Authentication, Dashboard, Users, Products, Labels, Temperatures, Defrost, BlastChilling, Cleaning, Checklists, Reports, Settings).
- **App**: App lifecycle, routing, global state, configuration.

## Versioning

The versioning follows the MAJOR.MINOR.PATCH format with automatic version bumps via GitHub Actions on push to `main`.
- `MAJOR` is fixed to 1.
- `PATCH` bumps from 0 to 10.
- `MINOR` increments automatically when `PATCH` exceeds 10.

## Development Strategy
- **Stable branch:** `main`
- **Feature branches:** `feature/*` (e.g., `feature/users`, `feature/labels`)

Merge feature branches into `main` to trigger an automatic version bump and a new git tag.
