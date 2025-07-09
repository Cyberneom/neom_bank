import 'package:neom_core/domain/model/app_transaction.dart';
import '../../domain/models/wallet.dart';

abstract class WalletRepository {

  Future<Wallet?> getOrCreate(String walletId);
  Future<Wallet?> getWallet(String walletId);
  Future<Wallet?> createWallet(String email);
  Future<bool> deleteWallet(String walletId);
  Future<bool> addTransaction(AppTransaction transaction);

}
