# neom_bank
neom_bank is a core module within the Open Neom ecosystem, dedicated to managing the platform's financial
and transaction-related functionalities. In its current version, it provides users with a transparent
view of their Wallet, including its balance and a complete history of transactions. 

This module is the foundational layer for all monetary interactions within the application,
such as purchases, contributions, and rewards. Looking ahead, neom_bank is designed for significant
future expansion. The long-term vision is to evolve into a comprehensive internal banking system,
enabling users to perform in-app transactions, send and receive AppCoins, and manage various forms
of value exchange. This aligns with the Tecnozenism philosophy of creating a self-sustaining
and decentralized ecosystem where conscious contributions are recognized and rewarded.
neom_bank strictly adheres to Open Neom's Clean Architecture principles, ensuring its logic is robust,
testable, and decoupled from direct UI presentation. It seamlessly integrates with neom_core
for core services and data models, and neom_commons for shared UI components,
providing a cohesive and secure financial experience.

🌟 Features & Responsibilities
In its current version (v1.0.0), neom_bank primarily offers:
•	Wallet Display: Presents a user's wallet with their current balance of AppCoins.
•	Transaction History: Displays a detailed, time-ordered list of all transactions associated with the user's wallet.
•	Wallet Status Monitoring: Shows the status of the user's wallet (e.g., active, inactive) and provides a warning if it's not active.
•	Order Processing (Future): Includes hooks and initial logic to process orders and initiate payments for products or subscriptions.
•	Data Persistence: Handles the storage and retrieval of Wallet and AppTransaction data to/from the backend (Firestore).

Future Expansion (Roadmap)
neom_bank is envisioned to grow significantly, with ambitious plans to incorporate a full suite of financial functionalities:
•	Internal Transfers: Allowing users to send and receive AppCoins between their wallets.
•	In-App Purchases: Enabling seamless purchases of digital/physical items, subscriptions, or event covers using fiat currency or AppCoins.
•	Transaction Management: Providing tools for users to view, search, and manage their transaction history.
•	Ecosystem Rewards: Implementing a system to reward users for loyalty, contributions, or specific in-app activities.
•	Payment Gateway Integration: Integrating with external payment gateways for processing fiat transactions.
•	Administrative Tools: Providing administrative functionalities for managing wallets, transactions, and product/coupon pricing.

🛠 Technical Highlights / Why it Matters (for developers)
For developers, neom_bank serves as an excellent case study for:
•	Financial Data Modeling: Demonstrates how to model and manage financial entities like Wallet,
    AppTransaction, AppOrder, and AppProduct in a structured way.
•	GetX for State Management: Utilizes GetX's WalletController for managing reactive state
    (isLoading, wallet, transactions, orders) and orchestrating asynchronous financial operations.
•	Service Layer Interaction: Shows seamless interaction with various core services
    (UserService, OrderFirestore, TransactionFirestore, ProductFirestore, WalletFirestore) 
    through their defined interfaces, maintaining strong architectural separation.
•	Firestore Transactional Integrity: The core WalletFirestore uses Firestore's transactional model
    to ensure atomicity and integrity of financial transactions
    (i.e., a transaction either completes fully or fails entirely).
•	Role-Based Logic: Implements logic to conditionally display or enable functionalities
    based on user roles or wallet status.
•	Secure and Decoupled Design: As a module handling sensitive financial data,
    its architecture is designed for security, with clear separation between
    business logic (neom_core) and data implementation (neom_bank).

How it Supports the Open Neom Initiative
neom_bank is vital to the Open Neom ecosystem and the broader Tecnozenismo vision by:
•	Enabling a Self-Sustaining Ecosystem: Provides the necessary framework for a virtual economy,
    supporting the project's sustainability through in-app purchases and value exchange.
•	Fostering Conscious Contributions: The ability to reward users for their contributions
    (e.g., via coupons, loyalty points) aligns with the philosophy of recognizing and valuing community engagement.
•	Driving Platform Growth: A clear and secure financial system is crucial for a scalable platform,
    enabling business models that support continued innovation.
•	Showcasing Architectural Excellence: As a module handling critical and complex financial functionalities,
    it exemplifies how to build secure, robust, and maintainable systems within Open Neom's modular framework.

🚀 Usage
This module provides routes and UI components for viewing the wallet history (WalletHistoryPage).
Its WalletController implements WalletService (from neom_core), allowing other modules
(e.g., neom_events, neom_admin, neom_commerce) to interact with financial services through the service interface.

📦 Dependencies
neom_bank relies on neom_core for core services, models, and routing constants, and on neom_commons
for reusable UI components, themes, and utility functions.

🤝 Contributing
We welcome contributions to the neom_bank module! If you're passionate about digital wallets,
payment systems, transaction management, or financial modeling, your contributions
can significantly strengthen Open Neom's economic backbone.

To understand the broader architectural context of Open Neom and how neom_bank fits into
the overall vision of Tecnozenism, please refer to the main project's MANIFEST.md.

For guidance on how to contribute to Open Neom and to understand the various levels
of learning and engagement possible within the project, consult our comprehensive guide: Learning Flutter Through Open Neom: A Comprehensive Path.

📄 License
This project is licensed under the Apache License, Version 2.0, January 2004. See the LICENSE file for details.