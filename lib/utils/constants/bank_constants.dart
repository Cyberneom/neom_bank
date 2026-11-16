import 'package:neom_core/utils/enums/transaction_type.dart';

class BankConstants {

  static const List<TransactionType> bankTransactions = [
    TransactionType.deposit,
    TransactionType.coupon,
    TransactionType.loyaltyPoints,
    TransactionType.refund,
    TransactionType.royaltyPayout,
  ];
  static const List<TransactionType> userTransactions = [
    TransactionType.withdrawal,
    TransactionType.purchase,
    TransactionType.transfer,
    TransactionType.tip,
  ];
}
