### 1.0.0 - Initial Release & Architectural Specialization
This release marks the initial official release (v1.0.0) of neom_bank as a new, independent module within the Open Neom ecosystem. This module is introduced to centralize and manage the platform's financial functionalities, serving as the foundational layer for all internal monetary interactions.

Key Architectural & Feature Improvements:

Major Architectural Changes:

neom_bank is now a dedicated, self-contained module for banking and transaction processes, ensuring a clear separation of concerns from main modules.

Decoupling from Main Modules:

Banking logic, which may have been scattered across main modules, has been extracted and centralized here. This improves modularity and clarifies each module's scope, allowing for a focus on wallet history.

Service-Oriented Architecture:

The module's controllers exclusively interact with core functionalities through service interfaces (e.g., WalletService, BankService), promoting the Dependency Inversion Principle (DIP).

Foundational Wallet Capabilities:

Provides initial functionalities for viewing wallet balance and transaction history.

Implements logic for retrieving and creating a user's wallet (WalletFirestore).

Module-Specific Translations:

Introduced BankTranslationConstants to centralize and manage all UI text strings specific to banking functionalities.

Future-Oriented Development:

This initial release lays the groundwork for a future expansion to include internal transfers, in-app purchases, and integration with an internal economy.

Leverages Core Open Neom Modules:

Built upon neom_core for foundational services and neom_commons for shared utilities, ensuring seamless integration within the ecosystem.