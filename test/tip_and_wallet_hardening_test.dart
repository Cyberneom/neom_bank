import 'package:flutter_test/flutter_test.dart';
import 'package:neom_bank/data/implementations/tip_controller.dart';
import 'package:neom_bank/domain/repository/tip_repository.dart';
import 'package:neom_bank/utils/tip_message_sanitizer.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/repository/transaction_repository.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/utils/enums/wallet_status.dart';

class _StubTipRepository implements TipRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubWalletRepository implements WalletRepository {
  final Map<String, Wallet> store = {};

  @override
  Future<Wallet?> getWallet(String walletId) async => store[walletId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TipMessageSanitizer & Wallet fail-closed hardening', () {
    test('TipMessageSanitizer.sanitize strips <think>, <memory_recall>, [BIOCHIP], Bidi overrides & preserves emoji runes', () {
      final msg = TipMessageSanitizer.sanitize(
        '<think>plan</think><memory_recall>ctx</memory_recall>[BIOCHIP: v1] Gracias\u202E por el libro 🚀',
      );
      expect(msg, 'Gracias por el libro 🚀');

      expect(TipMessageSanitizer.sanitize('<think>only</think>   '), isNull);

      final longEmoji = '🔥' * 520;
      final truncated = TipMessageSanitizer.sanitize(longEmoji)!;
      expect(truncated.runes.length, TipMessageSanitizer.maxTipMessageLength);
    });

    test('TipMessageSanitizer.clampLimit bounds negative, zero & excessive limits', () {
      expect(TipMessageSanitizer.clampLimit(-10), 1);
      expect(TipMessageSanitizer.clampLimit(0), 1);
      expect(TipMessageSanitizer.clampLimit(25), 25);
      expect(
        TipMessageSanitizer.clampLimit(99999),
        TipMessageSanitizer.maxTipQueryLimit,
      );
    });

    test('Wallet.fromJSON fails closed to suspended on unknown/corrupted status and sanitizes non-finite balance', () {
      final missingStatus = Wallet.fromJSON({'id': 'w1', 'balance': 50.0});
      expect(missingStatus.status, WalletStatus.active);
      expect(missingStatus.balance, 50.0);

      final invalidStatus = Wallet.fromJSON({
        'id': 'w2',
        'status': 'tampered_status',
        'balance': double.nan,
      });
      expect(invalidStatus.status, WalletStatus.suspended);
      expect(invalidStatus.balance, 0.0);
    });

    test('TipController.resolveRecipientWalletEmail maps profileId to owner email and rejects unsafe/orphan IDs', () async {
      final walletRepo = _StubWalletRepository();
      final controller = TipController(
        tipRepository: _StubTipRepository(),
        transactionRepository: _StubTransactionRepository(),
        walletRepository: walletRepo,
        recipientEmailResolver: (id) async =>
            id == 'profile_author_1' ? 'autor@emxi.mx' : null,
      );

      expect(
        await controller.resolveRecipientWalletEmail('profile_author_1'),
        'autor@emxi.mx',
      );
      expect(
        await controller.resolveRecipientWalletEmail('unknown_profile'),
        isNull,
      );
      expect(
        await controller.resolveRecipientWalletEmail('../traversal'),
        isNull,
      );
    });
  });
}
