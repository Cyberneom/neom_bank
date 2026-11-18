import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/api/app_platform_api.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_constants.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:neom_core/utils/enums/wallet_status.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint_sentinel/sint_sentinel_core.dart';

import '../../utils/constants/bank_constants.dart';

class WalletFirestore implements WalletRepository {
  static const double maxTransactionAmount = 1000000000.0; // 1e9 cap
  static const double maxWalletBalance = 10000000000.0; // 1e10 cap
  static final RegExp _rawUnsafeChars = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060-\u2069\uFEFF/\\]',
  );
  static final RegExp _encodedTraversalRe = RegExp(
    r'%(?:2e|2f|5c|25|00|c2%[89][0-9a-f]|d8%9c|e2%80%(?:8[b-f]|a[8-e])|e2%81%a[0-46-9]|ef%bb%bf)',
    caseSensitive: false,
  );
  static final RegExp _dunderDocIdRe = RegExp(r'^__.*__$');
  static const Set<String> _prototypePollutionKeys = {
    '__proto__',
    'constructor',
    'prototype',
  };

  CollectionReference<Map<String, dynamic>> get walletReference =>
      FirebaseFirestore.instance.collection(
        AppFirestoreCollectionConstants.wallets,
      );

  /// Validates a wallet identifier (email or profile/user ID).
  static bool isSafeWalletId(String raw) {
    if (raw.isEmpty || _rawUnsafeChars.hasMatch(raw)) return false;
    final clean = raw.trim();
    if (clean.isEmpty || clean.length > 254) return false;
    if (clean == '.' || clean == '..' || clean.contains('..')) return false;
    if (_encodedTraversalRe.hasMatch(clean)) return false;
    if (_dunderDocIdRe.hasMatch(clean)) return false;
    if (_prototypePollutionKeys.contains(clean.toLowerCase())) return false;
    return true;
  }

  /// Validates that a monetary transaction amount is finite, positive and bounded.
  ///
  /// Prevents `NaN` / `Infinity` from bypassing `amount <= 0` (since
  /// `double.nan <= 0` and `double.infinity <= 0` both evaluate to `false`).
  static bool isValidTransactionAmount(double amount) {
    return amount.isFinite && amount > 0 && amount <= maxTransactionAmount;
  }

  /// Detects self-transfers (`senderId == recipientId`, case-insensitive) that
  /// would otherwise overwrite the debit update with a credit update in the
  /// same transaction.
  static bool isSelfTransfer(String? senderId, String? recipientId) {
    final s = senderId?.trim().toLowerCase() ?? '';
    final r = recipientId?.trim().toLowerCase() ?? '';
    return s.isNotEmpty && r.isNotEmpty && s == r;
  }

  @override
  Future<Wallet?> getOrCreate(String walletId) async {
    if (!isSafeWalletId(walletId)) return null;
    final cleanId = walletId.trim();
    AppConfig.logger.t('Retrieving or creating wallet: $cleanId');
    if (AppPlatformApi.isEnabled) {
      try {
        return await AppPlatformApi.client('wallets').read<Wallet?>(
          'getOrCreate',
          {'walletId': cleanId},
          decode: (res) {
            final raw = res['value'];
            if (raw is Map) {
              return Wallet.fromJSON(Map<String, dynamic>.from(raw));
            }
            return null;
          },
          fallback: () => null,
        );
      } catch (e, st) {
        NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getOrCreate.platform');
        return null;
      }
    }

    Wallet? wallet;
    try {
      wallet = await getWallet(cleanId);
      wallet ??= await createWallet(cleanId);
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'getOrCreate',
      );
    }

    return wallet;
  }

  @override
  Future<Wallet?> getWallet(String walletId) async {
    if (!isSafeWalletId(walletId)) {
      AppConfig.logger.w('Wallet ID is empty or unsafe, cannot retrieve.');
      return null;
    }
    if (AppPlatformApi.isEnabled) {
      return getOrCreate(walletId);
    }
    final cleanId = walletId.trim();

    AppConfig.logger.t('Retrieving wallet: $cleanId');
    try {
      final docSnapshot = await SintSentinel.guard(
        () => walletReference.doc(cleanId).get(),
        tag: 'WalletFirestore.getWallet',
      );
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final wallet = Wallet.fromJSON(docSnapshot.data()!);
        if (wallet.id.isEmpty) wallet.id = docSnapshot.id;
        AppConfig.logger.d('Wallet ${wallet.id} retrieved successfully.');
        return wallet;
      } else {
        AppConfig.logger.w('Wallet with ID $cleanId not found.');
        return null;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'getWallet',
      );
      return null;
    }
  }

  @override
  Future<Wallet?> createWallet(String email) async {
    if (!isSafeWalletId(email)) {
      AppConfig.logger.e('Email is empty or unsafe for wallet creation.');
      return null;
    }
    if (AppPlatformApi.isEnabled) {
      return getOrCreate(email);
    }
    Wallet? wallet;

    try {
      final cleanEmail = email.trim();
      AppConfig.logger.t('Creating wallet for email: $cleanEmail');

      AppConfig.logger.i('Wallet for $cleanEmail not found, creating new one.');
      final now = DateTime.now().millisecondsSinceEpoch;
      final newWallet = Wallet(id: cleanEmail, createdTime: now, lastUpdated: now);
      wallet = newWallet;

      await SintSentinel.guardWrite(
        () => walletReference.doc(newWallet.id).set(newWallet.toJSON()),
        tag: 'WalletFirestore.createWallet',
      );
      AppConfig.logger.i('Wallet for $cleanEmail created successfully.');
      return wallet;
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'createWallet',
      );
    }

    return wallet;
  }

  @override
  Future<bool> deleteWallet(String walletId) async {
    if (!isSafeWalletId(walletId)) {
      AppConfig.logger.e('Wallet ID is empty or unsafe for deletion.');
      return false;
    }
    final cleanId = walletId.trim();
    AppConfig.logger.w(
      'Attempting to delete wallet $cleanId. NOTE: This will NOT delete its transactions subcollection from client-side code efficiently.',
    );
    try {
      await SintSentinel.guardWrite(
        () => walletReference.doc(cleanId).delete(),
        tag: 'WalletFirestore.deleteWallet',
      );
      AppConfig.logger.i(
        'Wallet document $cleanId deleted successfully. Transactions subcollection needs separate handling (e.g., Cloud Function).',
      );
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'deleteWallet',
      );
      return false;
    }
  }

  @override
  Future<bool> addTransaction(AppTransaction transaction) async {
    AppConfig.logger.d('addTransaction id=${transaction.id} type=${transaction.type.name}');

    if (!isValidTransactionAmount(transaction.amount)) {
      AppConfig.logger.e(
        'Transaction amount must be finite and positive: ${transaction.amount}',
      );
      return false;
    }

    final rawSenderId = transaction.senderId ?? '';
    final rawRecipientId = transaction.recipientId ?? '';
    final cleanSenderId = rawSenderId.trim();
    final cleanRecipientId = rawRecipientId.trim();

    if (isSelfTransfer(cleanSenderId, cleanRecipientId)) {
      AppConfig.logger.e(
        'Self-transfer rejected for wallet: $cleanSenderId',
      );
      return false;
    }

    if (AppPlatformApi.isEnabled) {
      try {
        final result = await AppPlatformApi.client('wallets').mutate(
          'addTransaction',
          {'transaction': transaction.toJSON()},
          durable: false,
        );
        return result is Map && result['ok'] == true;
      } catch (e, st) {
        NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'addTransaction.platform');
        return false;
      }
    }

    if (cleanSenderId.isNotEmpty && !isSafeWalletId(rawSenderId)) {
      AppConfig.logger.e('Invalid senderId wallet path.');
      return false;
    }
    if (cleanRecipientId.isNotEmpty && !isSafeWalletId(rawRecipientId)) {
      AppConfig.logger.e('Invalid recipientId wallet path.');
      return false;
    }

    if (cleanSenderId.isEmpty &&
        !BankConstants.bankTransactions.contains(transaction.type)) {
      AppConfig.logger.e(
        'SenderId is required for transaction type: ${transaction.type.name}',
      );
      return false;
    }

    if (cleanRecipientId.isEmpty &&
        ![
          TransactionType.withdrawal,
          TransactionType.purchase,
        ].contains(transaction.type)) {
      AppConfig.logger.e(
        'RecipientId is required for transaction type: ${transaction.type.name}',
      );
      return false;
    }

    bool isSuccess = false;
    try {
      isSuccess = await SintSentinel.guardWrite(
        () => FirebaseFirestore.instance.runTransaction((
          firestoreTransaction,
        ) async {
        DocumentSnapshot<Map<String, dynamic>>? senderWalletSnapshot;
        Wallet? senderWallet;
        double senderInitialBalance = 0;

        DocumentReference<Map<String, dynamic>>? recipientWalletRef;
        DocumentSnapshot<Map<String, dynamic>>? recipientWalletSnapshot;
        Wallet? recipientWallet;
        double recipientInitialBalance = 0;
        bool recipientCreatedInTx = false;

        if (cleanSenderId.isNotEmpty) {
          final senderWalletRef = walletReference.doc(cleanSenderId);
          senderWalletSnapshot = await firestoreTransaction.get(
            senderWalletRef,
          );

          if (!senderWalletSnapshot.exists ||
              senderWalletSnapshot.data() == null) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'sender-wallet-not-found',
              message: 'Sender wallet $cleanSenderId not found.',
            );
          }

          senderWallet = Wallet.fromJSON(senderWalletSnapshot.data()!);
          if (senderWallet.id.isEmpty) {
            senderWallet.id = senderWalletSnapshot.id;
          }

          senderInitialBalance = senderWallet.balance;
          if (!senderInitialBalance.isFinite) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'corrupt-sender-balance',
              message: 'Sender wallet balance is non-finite.',
            );
          }

          if (senderWallet.status != WalletStatus.active) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'sender-wallet-not-active',
              message: 'Sender wallet $cleanSenderId is not active.',
            );
          }

          if (senderWallet.balance < transaction.amount) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'insufficient-funds',
              message: 'Insufficient funds in sender wallet $cleanSenderId.',
            );
          }
        } else if (!BankConstants.bankTransactions.contains(transaction.type)) {
          throw FirebaseException(
            plugin: 'WalletFirestore',
            code: 'missing-sender-id',
            message: 'SenderId is required for this transaction type.',
          );
        }

        if (cleanRecipientId.isNotEmpty) {
          recipientWalletRef = walletReference.doc(cleanRecipientId);
          recipientWalletSnapshot = await firestoreTransaction.get(
            recipientWalletRef,
          );

          if (recipientWalletSnapshot.exists &&
              recipientWalletSnapshot.data() != null) {
            recipientWallet = Wallet.fromJSON(recipientWalletSnapshot.data()!);
            if (recipientWallet.id.isEmpty) {
              recipientWallet.id = recipientWalletSnapshot.id;
            }
            recipientInitialBalance = recipientWallet.balance;
            if (!recipientInitialBalance.isFinite) {
              throw FirebaseException(
                plugin: 'WalletFirestore',
                code: 'corrupt-recipient-balance',
                message: 'Recipient wallet balance is non-finite.',
              );
            }
          } else if (BankConstants.bankTransactions.contains(
            transaction.type,
          )) {
            final now = DateTime.now().millisecondsSinceEpoch;
            recipientWallet = Wallet(
              id: cleanRecipientId,
              balance: transaction.amount,
              currency: transaction.currency,
              status: WalletStatus.active,
              createdTime: transaction.createdTime > 0
                  ? transaction.createdTime
                  : now,
              lastUpdated: now,
            );
            final initialJson = recipientWallet.toJSON();
            initialJson[AppFirestoreConstants.lastTransactionId] =
                transaction.id;
            firestoreTransaction.set(recipientWalletRef, initialJson);
            recipientCreatedInTx = true;
          } else {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'recipient-wallet-not-found',
              message: 'Recipient wallet $cleanRecipientId not found.',
            );
          }

          if (recipientWallet.status != WalletStatus.active) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'recipient-wallet-not-active',
              message:
                  'Recipient wallet $cleanRecipientId is not in an active state.',
            );
          }
        } else if (![
          TransactionType.withdrawal,
          TransactionType.purchase,
        ].contains(transaction.type)) {
          throw FirebaseException(
            plugin: 'WalletFirestore',
            code: 'missing-recipient-id',
            message: 'RecipientId is required for this transaction type.',
          );
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        if (senderWallet != null && senderWalletSnapshot != null) {
          final newSenderBalance = senderInitialBalance - transaction.amount;
          if (!newSenderBalance.isFinite || newSenderBalance < 0) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'invalid-post-balance',
              message: 'Invalid post-debit balance.',
            );
          }
          firestoreTransaction.update(senderWalletSnapshot.reference, {
            AppFirestoreConstants.balance: newSenderBalance,
            AppFirestoreConstants.lastUpdated: now,
            AppFirestoreConstants.lastTransactionId: transaction.id,
          });
        }

        if (recipientWallet != null &&
            recipientWalletRef != null &&
            !recipientCreatedInTx) {
          final newRecipientBalance =
              recipientInitialBalance + transaction.amount;
          if (!newRecipientBalance.isFinite ||
              newRecipientBalance < 0 ||
              newRecipientBalance > maxWalletBalance) {
            throw FirebaseException(
              plugin: 'WalletFirestore',
              code: 'invalid-post-balance',
              message: 'Invalid post-credit balance.',
            );
          }
          firestoreTransaction.update(recipientWalletRef, {
            AppFirestoreConstants.balance: newRecipientBalance,
            AppFirestoreConstants.lastUpdated: now,
            AppFirestoreConstants.lastTransactionId: transaction.id,
          });
        }

        return true;
        }),
        tag: 'WalletFirestore.addTransaction',
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'addTransaction',
      );
    }

    return isSuccess;
  }
}
