import 'package:neom_core/utils/enums/transaction_type.dart';

class BankConstants {

  static List<TransactionType> bankTransactions = [TransactionType.deposit, TransactionType.coupon, TransactionType.loyaltyPoints, TransactionType.refund];
  static List<TransactionType> userTransactions = [TransactionType.withdrawal, TransactionType.purchase, TransactionType.transfer];
}
