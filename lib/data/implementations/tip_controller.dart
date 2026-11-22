import 'package:flutter/widgets.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/cloud_properties.dart';
import 'package:neom_core/data/api/app_platform_api.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/data/firestore/user_firestore.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/tip.dart';
import 'package:neom_core/domain/repository/transaction_repository.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/domain/use_cases/bank_service.dart';
import 'package:neom_core/domain/use_cases/tip_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/tip_tier.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';
import 'package:sint_sentinel/sint_sentinel_core.dart';

import '../../domain/repository/tip_repository.dart';
import '../../ui/wallet_controller.dart';
import '../../ui/widgets/tip_sheet.dart';
import '../../utils/tip_message_sanitizer.dart';
import '../firestore/tip_firestore.dart';
import '../firestore/wallet_firestore.dart';
import 'bank_controller.dart';

/// Tip controller implementing [TipService] for tip processing.
///
/// Handles sending tips between users, including balance validation,
/// transaction creation, and wallet debit/credit operations standardized
/// on `user.email` as the canonical wallet key.
class TipController extends SintController implements TipService {
  TipController({
    TipRepository? tipRepository,
    TransactionRepository? transactionRepository,
    WalletRepository? walletRepository,
    Future<String?> Function(String recipientId)? recipientEmailResolver,
  })  : _usesCustomRepositories =
            tipRepository != null ||
            transactionRepository != null ||
            walletRepository != null,
        _tipFirestore = tipRepository ?? TipFirestore(),
        _transactionFirestore = transactionRepository ?? TransactionFirestore(),
        _walletRepository = walletRepository ?? WalletFirestore(),
        _recipientEmailResolver = recipientEmailResolver;

  static const int maxTipQueryLimit = TipMessageSanitizer.maxTipQueryLimit;

  final bool _usesCustomRepositories;
  final TipRepository _tipFirestore;
  final TransactionRepository _transactionFirestore;
  final WalletRepository _walletRepository;
  final Future<String?> Function(String recipientId)? _recipientEmailResolver;

  final topSupporters = <Tip>[].obs;
  final isLoading = false.obs;
  bool _isClosed = false;

  @override
  void onClose() {
    _isClosed = true;
    topSupporters.close();
    isLoading.close();
    super.onClose();
  }

  static String? sanitizeTipMessage(String? raw) =>
      TipMessageSanitizer.sanitize(raw);

  static String? _sanitizeMessage(String? raw) => sanitizeTipMessage(raw);

  static String? _sanitizeContextField(String? raw, {int maxChars = 64}) {
    if (raw == null) return null;
    final cleaned = raw
        .replaceAll(
          RegExp(
            r'[\x00-\x1F\x7F-\x9F\u061C\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF/\\]',
          ),
          '',
        )
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..' || cleaned.contains('..')) {
      return null;
    }
    if (cleaned.length <= maxChars) return cleaned;
    var end = maxChars;
    final prev = cleaned.codeUnitAt(end - 1);
    if (prev >= 0xD800 && prev <= 0xDBFF) {
      end -= 1;
    }
    return end <= 0 ? null : cleaned.substring(0, end);
  }

  /// Resolves the canonical email-keyed wallet identifier for [recipientId]
  /// (which may be passed as `toProfile.id` or already as an owner email).
  /// Never returns an unverified non-email ID so tips never create orphan
  /// profileId wallets.
  Future<String?> resolveRecipientWalletEmail(String recipientId) async {
    final trimmed = recipientId.trim();
    if (!WalletFirestore.isSafeWalletId(trimmed)) return null;

    if (_recipientEmailResolver != null) {
      final resolved = await _recipientEmailResolver(trimmed);
      final clean = resolved?.trim() ?? '';
      return WalletFirestore.isSafeWalletId(clean) ? clean : null;
    }

    if (trimmed.contains('@')) {
      return trimmed;
    }

    try {
      final toProfile = await SintSentinel.guard(
        () => ProfileFirestore().retrieve(trimmed),
        tag: 'TipController.retrieveRecipientProfile',
      );
      final profileEmail = toProfile.email.trim();
      if (profileEmail.contains('@') &&
          WalletFirestore.isSafeWalletId(profileEmail)) {
        return profileEmail;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'resolveRecipientWalletEmail.profile',
      );
    }

    try {
      final ownerUser = await SintSentinel.guard(
        () => UserFirestore().getByProfileId(trimmed),
        tag: 'TipController.getUserByProfileId',
      );
      final ownerEmail = ownerUser.email.trim();
      if (ownerEmail.contains('@') &&
          WalletFirestore.isSafeWalletId(ownerEmail)) {
        return ownerEmail;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'resolveRecipientWalletEmail.user',
      );
    }

    try {
      final legacyWallet = await SintSentinel.guard(
        () => _walletRepository.getWallet(trimmed),
        tag: 'TipController.legacyWalletFallback',
      );
      if (legacyWallet != null &&
          WalletFirestore.isSafeWalletId(legacyWallet.id)) {
        return legacyWallet.id.trim();
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_bank',
        operation: 'resolveRecipientWalletEmail.walletFallback',
      );
    }

    return null;
  }

  @override
  Future<void> showTipModal(
    BuildContext context, {
    required String recipientId,
    required String recipientName,
    String? contextType,
    String? contextId,
  }) {
    return TipSheet.show(
      context,
      recipientId: recipientId,
      recipientName: recipientName,
      contextType: contextType,
      contextId: contextId,
    );
  }

  @override
  Future<bool> sendTip({
    required String recipientId,
    required TipTier tier,
    String? message,
    String? contextType,
    String? contextId,
  }) async {
    if (!TipFirestore.isSafeTipPartyId(recipientId)) {
      AppConfig.logger.e("Cannot send tip: recipientId is empty or unsafe.");
      return false;
    }
    final trimmedRecipient = recipientId.trim();
    AppConfig.logger.d("Sending ${tier.name} tip to $trimmedRecipient");

    if (!Sint.isRegistered<UserService>() || !Sint.isRegistered<BankService>()) {
      AppConfig.logger.e("Cannot send tip: UserService or BankService unavailable.");
      return false;
    }

    try {
      if (!_isClosed) isLoading.value = true;

      /// Get current user info via UserService.
      final UserService userService = Sint.find<UserService>();
      final currentUser = userService.user;
      final currentProfile = userService.profile;

      final senderEmail = currentUser.email.trim();
      final senderProfileId = currentProfile.id.trim();
      if (!senderEmail.contains('@') ||
          !TipFirestore.isSafeTipPartyId(senderEmail) ||
          !TipFirestore.isSafeTipPartyId(senderProfileId)) {
        AppConfig.logger.e("Cannot send tip: sender identity is empty or unsafe.");
        return false;
      }

      if (trimmedRecipient.toLowerCase() == senderProfileId.toLowerCase() ||
          trimmedRecipient.toLowerCase() == senderEmail.toLowerCase()) {
        AppConfig.logger.e("Cannot send tip to self ($trimmedRecipient).");
        return false;
      }

      /// Validate tip amount is positive and finite.
      final double tipAmount = tier.coins.toDouble();
      if (!tipAmount.isFinite ||
          tipAmount <= 0 ||
          tipAmount > TipFirestore.maxTipAmount) {
        AppConfig.logger.e("Invalid tip tier amount: $tipAmount");
        return false;
      }

      if (AppPlatformApi.isEnabled) {
        final result = await AppPlatformApi.client('tips').mutate(
          'sendTip',
          {
            'recipientId': trimmedRecipient,
            'recipientProfileId': trimmedRecipient,
            'senderName': currentProfile.name,
            'senderAvatarUrl': currentProfile.photoUrl,
            'tier': tier.name,
            'amount': tipAmount,
            'message': _sanitizeMessage(message) ?? '',
            'contextType': _sanitizeContextField(contextType, maxChars: 64) ?? 'song',
            'contextId': _sanitizeContextField(contextId, maxChars: 128) ?? '',
          },
          durable: false,
        );
        if (result is Map && (result['tipId']?.toString().isNotEmpty ?? false)) {
          final newBalance = (result['balance'] as num?)?.toDouble();
          if (newBalance != null && newBalance.isFinite) {
            BankController().wallet.balance = newBalance;
            if (Sint.isRegistered<WalletController>()) {
              final wc = Sint.find<WalletController>();
              wc.wallet?.balance = newBalance;
              wc.update([AppPageIdConstants.walletHistory]);
            }
          }
          return true;
        }
        return false;
      }

      /// Resolve canonical recipient owner email (`user.email`) from `toProfile.id`.
      final recipientWalletEmail =
          await resolveRecipientWalletEmail(trimmedRecipient);

      // In live Firebase mode, transfer atomically server-side via `secureOps`
      // (`sendTip`) so normal fans never hit PERMISSION_DENIED writing to the
      // recipient artist's protected wallet document.
      if (!_usesCustomRepositories) {
        final cloudResult = await CloudProperties.sendTipViaCloud(
          recipientId: trimmedRecipient,
          recipientEmail: recipientWalletEmail,
          senderProfileId: senderProfileId,
          senderName: currentProfile.name,
          senderAvatarUrl: currentProfile.photoUrl,
          tier: tier.name,
          amount: tipAmount,
          message: _sanitizeMessage(message),
          contextType: _sanitizeContextField(contextType, maxChars: 64) ?? 'song',
          contextId: _sanitizeContextField(contextId, maxChars: 128),
        );
        if (cloudResult != null &&
            (cloudResult['tipId']?.toString().isNotEmpty ?? false)) {
          final newBalance = (cloudResult['balance'] as num?)?.toDouble();
          if (newBalance != null && newBalance.isFinite) {
            BankController().wallet.balance = newBalance;
            if (Sint.isRegistered<WalletController>()) {
              final wc = Sint.find<WalletController>();
              wc.wallet?.balance = newBalance;
              wc.update([AppPageIdConstants.walletHistory]);
            }
          }
          AppConfig.logger.i(
            "Cloud tip sent: ${tier.coins} GigCoins to ${cloudResult['recipientEmail']}",
          );
          return true;
        }
        AppConfig.logger.w(
          "Cloud sendTip failed or unavailable; aborting unsafe cross-wallet write.",
        );
        return false;
      }

      if (recipientWalletEmail == null || recipientWalletEmail.isEmpty) {
        AppConfig.logger.e(
          "Cannot send tip: could not resolve recipient wallet email for $trimmedRecipient.",
        );
        return false;
      }

      if (WalletFirestore.isSelfTransfer(senderEmail, recipientWalletEmail)) {
        AppConfig.logger.e("Cannot send tip to own wallet ($recipientWalletEmail).");
        return false;
      }

      /// Get BankService to process the transaction.
      final BankService bankService = Sint.find<BankService>();

      /// Ensure recipient's email-keyed wallet exists before debit/credit.
      if (recipientWalletEmail.contains('@')) {
        final recipientWallet = await SintSentinel.guardWrite(
          () => _walletRepository.getOrCreate(recipientWalletEmail),
          tag: 'TipController.ensureRecipientWallet',
        );
        if (recipientWallet == null) {
          AppConfig.logger.e(
            "Cannot send tip: recipient wallet unavailable for $recipientWalletEmail.",
          );
          return false;
        }
      }

      /// Create the Tip model (indexed by profile ID for profile feeds).
      final int now = DateTime.now().millisecondsSinceEpoch;
      final Tip tip = Tip(
        senderId: senderProfileId,
        senderName: currentProfile.name,
        senderAvatarUrl: currentProfile.photoUrl,
        recipientId: trimmedRecipient,
        tier: tier,
        amount: tipAmount,
        message: _sanitizeMessage(message),
        contextType: _sanitizeContextField(contextType, maxChars: 64),
        contextId: _sanitizeContextField(contextId, maxChars: 128),
        createdTime: now,
      );

      /// Create AppTransaction for the tip using canonical `user.email` wallet keys.
      final AppTransaction transaction = AppTransaction(
        amount: tipAmount,
        type: TransactionType.tip,
        senderId: senderEmail,
        recipientId: recipientWalletEmail,
        description: 'Tip: ${tier.name} (${tier.coins} coins)',
        currency: AppCurrency.appCoin,
        status: TransactionStatus.pending,
        createdTime: now,
      );

      /// Insert transaction record first.
      transaction.id = await SintSentinel.guardWrite(
        () => _transactionFirestore.insert(transaction),
        tag: 'TipController.insertTransaction',
      );

      if (transaction.id.isEmpty) {
        AppConfig.logger.e("Failed to create transaction record for tip.");
        return false;
      }

      /// Process the transaction (debit sender email wallet, credit recipient email wallet).
      final bool transactionSuccess = await SintSentinel.guardWrite(
        () => bankService.processTransaction(transaction),
        tag: 'TipController.processTransaction',
      );

      if (!transactionSuccess) {
        AppConfig.logger.e("Tip transaction failed for ${transaction.id}");
        return false;
      }

      /// Create the tip record in Firestore.
      final String tipId = await SintSentinel.guardWrite(
        () => _tipFirestore.createTip(tip),
        tag: 'TipController.createTip',
      );

      if (tipId.isEmpty) {
        AppConfig.logger.e("Failed to create tip record. Transaction ${transaction.id} was processed.");
        return false;
      }

      AppConfig.logger.i("Tip $tipId sent successfully. Transaction: ${transaction.id}");
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'sendTip');
      return false;
    } finally {
      if (!_isClosed) isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTopSupporters(String recipientId, {int limit = 10}) async {
    if (!TipFirestore.isSafeTipPartyId(recipientId)) return [];
    final trimmedRecipient = recipientId.trim();
    final safeLimit = TipMessageSanitizer.clampLimit(limit);
    AppConfig.logger.d("Getting top supporters for $trimmedRecipient");

    try {
      if (!_isClosed) isLoading.value = true;
      final supporters = await _tipFirestore.getTopSupporters(
        trimmedRecipient,
        limit: safeLimit,
      );
      if (!_isClosed) topSupporters.assignAll(supporters);
      return supporters;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTopSupporters');
      return [];
    } finally {
      if (!_isClosed) isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTipsForProfile(String recipientId, {int limit = 20}) async {
    if (!TipFirestore.isSafeTipPartyId(recipientId)) return [];
    final trimmedRecipient = recipientId.trim();
    final safeLimit = TipMessageSanitizer.clampLimit(limit);
    AppConfig.logger.d("Getting tips for profile $trimmedRecipient");

    try {
      if (!_isClosed) isLoading.value = true;
      return await _tipFirestore.getTipsForProfile(
        trimmedRecipient,
        limit: safeLimit,
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsForProfile');
      return [];
    } finally {
      if (!_isClosed) isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTipsSentBy(String senderId, {int limit = 20}) async {
    if (!TipFirestore.isSafeTipPartyId(senderId)) return [];
    final trimmedSender = senderId.trim();
    final safeLimit = TipMessageSanitizer.clampLimit(limit);
    AppConfig.logger.d("Getting tips sent by $trimmedSender");

    try {
      if (!_isClosed) isLoading.value = true;
      return await _tipFirestore.getTipsSentBy(
        trimmedSender,
        limit: safeLimit,
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsSentBy');
      return [];
    } finally {
      if (!_isClosed) isLoading.value = false;
    }
  }

  @override
  Future<double> getTotalTipsReceived(String recipientId) async {
    if (!TipFirestore.isSafeTipPartyId(recipientId)) return 0;
    final trimmedRecipient = recipientId.trim();
    AppConfig.logger.d("Getting total tips received for $trimmedRecipient");

    try {
      return await _tipFirestore.getTotalTipsReceived(trimmedRecipient);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTotalTipsReceived');
      return 0;
    }
  }

}
