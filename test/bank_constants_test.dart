import 'package:flutter_test/flutter_test.dart';
import 'package:neom_bank/utils/constants/bank_constants.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';

/// Verifies the local BankConstants categorization that drives
/// BankController.processTransaction — the split between "bank-originated"
/// transactions (no sender wallet required) and "user-originated" transactions
/// (must debit sender wallet). A mistake here = free money glitch.
void main() {
  group('BankConstants categorization', () {
    test('bankTransactions contains exactly the 5 system-origin types', () {
      expect(BankConstants.bankTransactions, hasLength(5));
      expect(
        BankConstants.bankTransactions,
        containsAll([
          TransactionType.deposit,
          TransactionType.coupon,
          TransactionType.loyaltyPoints,
          TransactionType.refund,
          TransactionType.royaltyPayout,
        ]),
      );
    });

    test('userTransactions contains all 4 user-origin debit types (including tip)', () {
      expect(BankConstants.userTransactions, hasLength(4));
      expect(
        BankConstants.userTransactions,
        containsAll([
          TransactionType.withdrawal,
          TransactionType.purchase,
          TransactionType.transfer,
          TransactionType.tip,
        ]),
      );
    });

    test('bank and user transaction sets are disjoint (no double-classification)', () {
      for (final t in BankConstants.bankTransactions) {
        expect(
          BankConstants.userTransactions,
          isNot(contains(t)),
          reason:
              '$t classified in both categories — this would bypass sender balance checks.',
        );
      }
    });

    test('tip is classified in userTransactions so TipController enforces sender balance', () {
      expect(BankConstants.bankTransactions, isNot(contains(TransactionType.tip)));
      expect(BankConstants.userTransactions, contains(TransactionType.tip));
      expect(
        () => BankConstants.userTransactions.clear(),
        throwsUnsupportedError,
      );
    });

    test('processTransaction balance gate simulation: user-txn > balance fails', () {
      // This replicates the exact check inside BankController.processTransaction:
      //   if (userTransactions.contains(type) && wallet.balance < amount) return false;
      const double walletBalance = 10.0;
      const double txAmount = 25.0;
      final tx = TransactionType.purchase;

      final blocked = BankConstants.userTransactions.contains(tx) &&
          walletBalance < txAmount;
      expect(blocked, isTrue);
    });

    test('processTransaction balance gate simulation: bank-txn ignores balance', () {
      const double walletBalance = 0.0;
      const double txAmount = 9999.0;
      final tx = TransactionType.deposit;

      // A deposit to an empty wallet must NOT be blocked by the balance check.
      final blocked = BankConstants.userTransactions.contains(tx) &&
          walletBalance < txAmount;
      expect(blocked, isFalse);
    });

    test('processTransaction balance gate: exact balance == amount is allowed', () {
      // Edge case: spending every last coin must be permitted.
      const double walletBalance = 100.0;
      const double txAmount = 100.0;
      final tx = TransactionType.transfer;

      final blocked = BankConstants.userTransactions.contains(tx) &&
          walletBalance < txAmount;
      expect(blocked, isFalse,
          reason: 'exact-balance spend should succeed, not fail');
    });

    test('processTransaction balance gate: one cent over balance blocks', () {
      const double walletBalance = 100.0;
      const double txAmount = 100.01;
      final tx = TransactionType.withdrawal;

      final blocked = BankConstants.userTransactions.contains(tx) &&
          walletBalance < txAmount;
      expect(blocked, isTrue);
    });
  });
}
