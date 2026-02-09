# Changelog

All notable changes to neom_bank will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-02-08

### Changed
- **Repository Pattern Enhancement**: `BankController` now uses injected `WalletRepository` instead of direct `WalletFirestore()` instantiation
- **Dependency Injection**: `WalletController` uses `WalletRepository` interface for wallet operations
- **Translation Constants**: Added `createdCoupon` and `createdCouponMsg` translation keys

### Fixed
- **Deprecated API Migration**: Replaced all `withOpacity()` calls with `withValues(alpha:)` in:
  - `wallet_card.dart` - Gradient colors, shadows, and borders
  - `wallet_history_page.dart` - Overlay color

### Technical
- Updated `flutter_lints` to ^6.0.0
- Improved testability through repository abstraction

## [1.1.0] - Previous Release

### Added
- Wallet status validation with overlay for inactive wallets
- Enhanced wallet card UI with gradient design

## [1.0.0] - Initial Release & Architectural Specialization

This release marks the initial official release (v1.0.0) of neom_bank as a new, independent module within the Open Neom ecosystem.

### Added

#### Major Architectural Changes
- Dedicated, self-contained module for banking and transaction processes
- Clear separation of concerns from main modules

#### Decoupling from Main Modules
- Banking logic extracted and centralized
- Improved modularity and scope clarity

#### Service-Oriented Architecture
- Controllers interact through service interfaces (WalletService, BankService)
- Promotes Dependency Inversion Principle (DIP)

#### Foundational Wallet Capabilities
- Wallet balance viewing and transaction history
- Wallet retrieval and creation via WalletFirestore

#### Module-Specific Translations
- BankTranslationConstants for banking-specific UI text

### Technical
- Built upon neom_core and neom_commons
- Foundation for future internal transfers and in-app purchases
