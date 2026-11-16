import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:neom_commons/utils/constants/translations/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/data/firestore/user_firestore.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/repository/transaction_repository.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/domain/use_cases/bank_service.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';
import 'package:sint_sentinel/sint_sentinel_core.dart';

import '../../utils/constants/bank_constants.dart';
import '../firestore/wallet_firestore.dart';

/// Bank controller implementing [BankService] for transaction processing.
///
/// Uses repository pattern for wallet operations, enabling easier testing
/// and potential backend changes without affecting business logic.
class BankController implements BankService {

  static final BankController _instance = BankController._internal();

  factory BankController() {
    _instance.init();
    return _instance;
  }

  BankController._internal()
      : _walletRepository = WalletFirestore(),
        _transactionRepository = TransactionFirestore();

  @visibleForTesting
  BankController.forTesting({
    required WalletRepository walletRepository,
    required TransactionRepository transactionRepository,
  })  : _walletRepository = walletRepository,
        _transactionRepository = transactionRepository,
        _isInitialized = true;

  bool _isInitialized = false;

  /// Repositories for wallet and transaction operations (injectable for testing)
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;

  TransactionStatus transactiontStatus = TransactionStatus.pending;
  Wallet wallet = Wallet();

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    AppConfig.logger.t('AppBankController Controller Initialization');

    try {

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'init');
    }
  }

  @override
  Future<bool> processTransaction(AppTransaction transaction) async {
    AppConfig.logger.d('Processing transaction: ${transaction.id}');

    if (!WalletFirestore.isValidTransactionAmount(transaction.amount)) {
      AppConfig.logger.e(
        'Rejected invalid transaction amount (${transaction.amount}) for ${transaction.id}',
      );
      transaction.status = TransactionStatus.failed;
      return false;
    }

    if (WalletFirestore.isSelfTransfer(
      transaction.senderId,
      transaction.recipientId,
    )) {
      AppConfig.logger.e(
        'Rejected self-transfer transaction for ${transaction.id}',
      );
      transaction.status = TransactionStatus.failed;
      return false;
    }

    final rawSender = transaction.senderId;
    if (rawSender != null &&
        rawSender.trim().isNotEmpty &&
        !WalletFirestore.isSafeWalletId(rawSender)) {
      AppConfig.logger.e('Rejected unsafe senderId for ${transaction.id}');
      transaction.status = TransactionStatus.failed;
      return false;
    }

    final rawRecipient = transaction.recipientId;
    if (rawRecipient != null &&
        rawRecipient.trim().isNotEmpty &&
        !WalletFirestore.isSafeWalletId(rawRecipient)) {
      AppConfig.logger.e('Rejected unsafe recipientId for ${transaction.id}');
      transaction.status = TransactionStatus.failed;
      return false;
    }

    try {
      Wallet? senderWallet;
      if (BankConstants.userTransactions.contains(transaction.type)) {
        final senderWalletId = (transaction.senderId ?? '').trim();
        if (!WalletFirestore.isSafeWalletId(senderWalletId)) {
          AppConfig.logger.e('Cannot process debit transaction without safe senderId');
          transaction.status = TransactionStatus.failed;
          return false;
        }
        senderWallet = await SintSentinel.guard(
          () => _walletRepository.getOrCreate(senderWalletId),
          tag: 'BankController.getOrCreateSenderWallet',
        );
        if (senderWallet == null || !senderWallet.balance.isFinite) {
          AppConfig.logger.e('Sender wallet unavailable for $senderWalletId');
          transaction.status = TransactionStatus.failed;
          return false;
        }
        wallet = senderWallet;
        if (senderWallet.balance < transaction.amount) {
          AppConfig.logger.e(MessageTranslationConstants.notEnoughFundsMsg.tr);
          transaction.status = TransactionStatus.failed;
          if (transaction.id.isNotEmpty) {
            await SintSentinel.guardWrite(
              () => _transactionRepository.updateStatus(
                transaction.id,
                transaction.status,
              ),
              tag: 'BankController.updateStatusInsufficientFunds',
            );
          }
          return false;
        }
      }

      final added = await SintSentinel.guardWrite(
        () => _walletRepository.addTransaction(transaction),
        tag: 'BankController.addTransaction',
      );
      if (added) {
        AppConfig.logger.d('Transaction added successfully: ${transaction.id}');
        transaction.status = TransactionStatus.completed;
        if (senderWallet != null && senderWallet.id == (transaction.senderId ?? '').trim()) {
          senderWallet.balance =
              (senderWallet.balance - transaction.amount).clamp(0.0, double.infinity);
          wallet = senderWallet;
        }
      } else {
        AppConfig.logger.d('Failed to add transaction: ${transaction.id}');
        transaction.status = TransactionStatus.failed;
      }

      if (transaction.id.isNotEmpty) {
        await SintSentinel.guardWrite(
          () => _transactionRepository.updateStatus(
            transaction.id,
            transaction.status,
          ),
          tag: 'BankController.updateStatus',
        );
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'processTransaction');
      transaction.status = TransactionStatus.failed;
      return false;
    }

    return transaction.status == TransactionStatus.completed;
  }

  @override
  Future<bool> addCoinsToWallet(
    String walletId,
    double amount, {
    TransactionType transactionType = TransactionType.purchase,
  }) async {
    if (!WalletFirestore.isSafeWalletId(walletId) ||
        !WalletFirestore.isValidTransactionAmount(amount)) {
      AppConfig.logger.e(
        'Rejected addCoinsToWallet(amount: $amount)',
      );
      return false;
    }
    var trimmedWalletId = walletId.trim();
    if (!trimmedWalletId.contains('@')) {
      try {
        final byProfile = await SintSentinel.guard(
          () => UserFirestore().getByProfileId(trimmedWalletId),
          tag: 'BankController.resolveProfileOwnerEmail',
        );
        if (byProfile.email.trim().contains('@')) {
          trimmedWalletId = byProfile.email.trim();
        } else {
          final byId = await SintSentinel.guard(
            () => UserFirestore().getById(trimmedWalletId),
            tag: 'BankController.resolveUserEmail',
          );
          if (byId.email.trim().contains('@')) {
            trimmedWalletId = byId.email.trim();
          }
        }
      } catch (e, st) {
        NeomErrorLogger.recordError(
          e,
          st,
          module: 'neom_bank',
          operation: 'addCoinsToWallet.resolveEmail',
        );
      }
      if (!trimmedWalletId.contains('@')) {
        AppConfig.logger.e(
          'Rejected addCoinsToWallet: canonical user.email required, got non-email ID',
        );
        return false;
      }
    }
    AppConfig.logger.d('Adding $amount coins to wallet: $trimmedWalletId');

    final effectiveType = transactionType == TransactionType.purchase
        ? TransactionType.deposit
        : transactionType;

    final AppTransaction transaction = AppTransaction(
      amount: amount,
      recipientId: trimmedWalletId,
      type: effectiveType,
    );

    try {
      transaction.id = await SintSentinel.guardWrite(
        () => _transactionRepository.insert(transaction),
        tag: 'BankController.insertCreditTransaction',
      );
      if (transaction.id.isEmpty) {
        return false;
      }
      final added = await SintSentinel.guardWrite(
        () => _walletRepository.addTransaction(transaction),
        tag: 'BankController.addCoinsTransaction',
      );
      if (added) {
        AppConfig.logger.d('Coins added to wallet: $trimmedWalletId');
        transaction.status = TransactionStatus.completed;
      } else {
        AppConfig.logger.e('Failed to add coins to wallet: $trimmedWalletId');
        transaction.status = TransactionStatus.failed;
      }
      await SintSentinel.guardWrite(
        () => _transactionRepository.updateStatus(
          transaction.id,
          transaction.status,
        ),
        tag: 'BankController.updateCreditStatus',
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'addCoinsToWallet');
      return false;
    }

    return transaction.status == TransactionStatus.completed;
  }

}
