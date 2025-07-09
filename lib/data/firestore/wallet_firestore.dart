import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_constants.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import '../../domain/models/wallet.dart';
import '../../domain/repository/wallet_repository.dart';
import '../../utils/constants/bank_constants.dart';
import '../../utils/enums/wallet_status.dart';

class WalletFirestore implements WalletRepository {

  final walletReference = FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.wallets);

  @override
  Future<Wallet?> getOrCreate(String walletId) async {
    AppConfig.logger.t("Retrieving or creating wallet: $walletId");
    Wallet? wallet;
    try {
      wallet = await getWallet(walletId);

      if(wallet == null) {
        createWallet(walletId);
      }
    } catch (e) {
      AppConfig.logger.e("Error retrieving or creating wallet $walletId: ${e.toString()}");
    }

    return wallet;
  }

  @override
  Future<Wallet?> getWallet(String walletId) async {
    if (walletId.isEmpty) {
      AppConfig.logger.w("Wallet ID (email) is empty, cannot retrieve.");
      return null;
    }

    AppConfig.logger.t("Retrieving wallet: $walletId");
    try {
      DocumentSnapshot docSnapshot = await walletReference.doc(walletId).get();
      if (docSnapshot.exists) {
        Wallet wallet = Wallet.fromJSON(docSnapshot.data() as Map<String, dynamic>);
        AppConfig.logger.d("Wallet ${wallet.id} retrieved successfully.");
        return wallet;
      } else {
        AppConfig.logger.w("Wallet with ID $walletId not found.");
        return null;
      }
    } catch (e) {
      AppConfig.logger.e("Error retrieving wallet $walletId: ${e.toString()}");
      return null;
    }
  }

  @override
  Future<Wallet?> createWallet(String email) async {
    AppConfig.logger.t("Creating wallet for email: $email");
    Wallet? wallet;

    try {
      if (email.isEmpty) {
        AppConfig.logger.e("Email cannot be empty for wallet creation.");
        return null;
      }

      AppConfig.logger.i("Wallet for $email not found, creating new one.");
      wallet = Wallet(
          id: email, // El email es el ID de la billetera
          createdTime: DateTime.now().millisecondsSinceEpoch,
          lastUpdated: DateTime.now().millisecondsSinceEpoch
      );

      await walletReference.doc(wallet.id).set(wallet.toJSON());
      AppConfig.logger.i("Wallet for $email created successfully.");
      return wallet;
    } catch (e) {
      AppConfig.logger.e("Error checking wallet existence for $email: ${e.toString()}");
    }

    return wallet;
  }

  @override
  Future<bool> deleteWallet(String walletId) async {
    if (walletId.isEmpty) {
      AppConfig.logger.e("Wallet ID (email) cannot be empty for deletion.");
      return false;
    }
    AppConfig.logger.w("Attempting to delete wallet $walletId. NOTE: This will NOT delete its transactions subcollection from client-side code efficiently.");
    try {
      await walletReference.doc(walletId).delete();
      AppConfig.logger.i("Wallet document $walletId deleted successfully. Transactions subcollection needs separate handling (e.g., Cloud Function).");
      return true;
    } catch (e) {
      AppConfig.logger.e("Error deleting wallet $walletId: ${e.toString()}");
      return false;
    }
  }

  @override
  Future<bool> addTransaction(AppTransaction transaction) async {
    AppConfig.logger.d("addTransaction ${transaction.toString()}");

    bool isSuccess = false;

    // Validaciones básicas
    if (transaction.amount <= 0) {
      AppConfig.logger.e("Transaction amount must be positive: ${transaction.amount}");
      return false;
    }

    if ((transaction.senderId?.isEmpty ?? true) &&
        ![TransactionType.deposit, TransactionType.coupon, TransactionType.loyaltyPoints, TransactionType.refund].contains(transaction.type)) {
      AppConfig.logger.e("SenderId is required for transaction type: ${transaction.type.name}");
      return false;
    }

    if ((transaction.recipientId?.isEmpty ?? true) &&
        ![TransactionType.withdrawal, TransactionType.purchase].contains(transaction.type)) {
      AppConfig.logger.e("RecipientId is required for transaction type: ${transaction.type.name}");
      return false;
    }

    try {
      isSuccess = await FirebaseFirestore.instance.runTransaction((firestoreTransaction) async {
        DocumentReference senderWalletRef;
        DocumentSnapshot? senderWalletSnapshot;
        Wallet? senderWallet;
        double senderInitialBalance = 0;

        DocumentReference recipientWalletRef;
        DocumentSnapshot? recipientWalletSnapshot;
        Wallet? recipientWallet;
        double recipientInitialBalance = 0;


        // --- Lógica del Remitente (Sender) ---
        if (transaction.senderId?.isNotEmpty ?? false) {
          senderWalletRef = walletReference.doc(transaction.senderId!);
          senderWalletSnapshot = await firestoreTransaction.get(senderWalletRef);

          if (!senderWalletSnapshot.exists) {
            AppConfig.logger.e("Sender wallet ${transaction.senderId} not found.");
            throw FirebaseException(plugin: 'WalletFirestore', code: 'sender-wallet-not-found', message: "Sender wallet ${transaction.senderId} not found.");
          }

          senderWallet = Wallet.fromJSON(senderWalletSnapshot.data() as Map<String, dynamic>);
          if(senderWallet.id.isEmpty) senderWallet.id = senderWalletSnapshot.id;

          senderInitialBalance = senderWallet.balance;


          if (senderWallet.status != WalletStatus.active) {
            AppConfig.logger.e("Sender wallet ${transaction.senderId} is not active (status: ${senderWallet.status.name}).");
            throw FirebaseException(plugin: 'WalletFirestore', code: 'sender-wallet-not-active', message: "Sender wallet ${transaction.senderId} is not active.");
          }

          if (senderWallet.balance < transaction.amount) {
            AppConfig.logger.e("Insufficient funds in sender wallet ${transaction.senderId}. Has: ${senderWallet.balance}, Needs: ${transaction.amount}");
            throw FirebaseException(plugin: 'WalletFirestore', code: 'insufficient-funds', message: "Insufficient funds in sender wallet ${transaction.senderId}.");
          }
        } else if (!BankConstants.bankTransactions.contains(transaction.type)) {
          // Si no es un tipo de transacción que pueda tener un sender nulo/sistema, es un error.
          AppConfig.logger.e("SenderId is null or empty for a transaction type that requires it: ${transaction.type.name}");
          throw FirebaseException(plugin: 'WalletFirestore', code: 'missing-sender-id', message: "SenderId is required for this transaction type.");
        }


        // --- Lógica del Destinatario (Recipient) ---
        if (transaction.recipientId?.isNotEmpty ?? false) {
          recipientWalletRef = walletReference.doc(transaction.recipientId!);
          recipientWalletSnapshot = await firestoreTransaction.get(recipientWalletRef);

          if(recipientWalletSnapshot.exists) {
            recipientWallet = Wallet.fromJSON(recipientWalletSnapshot.data() as Map<String, dynamic>);
            if(recipientWallet.id.isEmpty) recipientWallet.id = recipientWalletSnapshot.id;
            recipientInitialBalance = recipientWallet.balance;
          } else if (BankConstants.bankTransactions.contains(transaction.type)) {
            AppConfig.logger.i("Recipient wallet ${transaction.recipientId} not found. Creating it for transaction type ${transaction.type.name}.");
            recipientWallet = Wallet(
                id: transaction.recipientId!,
                balance: 0, // Se actualizará más adelante
                currency: transaction.currency,
                status: WalletStatus.active, // o WalletStatus.unclaimed
                createdTime: transaction.createdTime,
                lastUpdated: DateTime.now().millisecondsSinceEpoch
            );
            firestoreTransaction.set(recipientWalletRef, recipientWallet.toJSON());
            recipientInitialBalance = 0;
          } else {
            AppConfig.logger.e("Recipient wallet ${transaction.recipientId} not found.");
            throw FirebaseException(plugin: 'WalletFirestore', code: 'recipient-wallet-not-found', message: "Recipient wallet ${transaction.recipientId} not found.");
          }

          if (recipientWallet.status != WalletStatus.active) {
            AppConfig.logger.e("Recipient wallet ${transaction.recipientId} is not active or unclaimed (status: ${recipientWallet.status.name}).");
            throw FirebaseException(plugin: 'WalletFirestore', code: 'recipient-wallet-not-active', message: "Recipient wallet ${transaction.recipientId} is not in an active/unclaimed state.");
          }
        } else if (![TransactionType.withdrawal, TransactionType.purchase].contains(transaction.type)){
          AppConfig.logger.e("RecipientId is null or empty for a transaction type that requires it: ${transaction.type.name}");
          throw FirebaseException(plugin: 'WalletFirestore', code: 'missing-recipient-id', message: "RecipientId is required for this transaction type.");
        }

        // Actualizar billetera del remitente (si aplica)
        if (senderWallet != null && senderWalletSnapshot != null) {
          double newSenderBalance = senderInitialBalance - transaction.amount;
          firestoreTransaction.update(senderWalletSnapshot.reference, {
            AppFirestoreConstants.balance: newSenderBalance,
            AppFirestoreConstants.lastUpdated: DateTime.now().millisecondsSinceEpoch,
            AppFirestoreConstants.lastTransactionId: transaction.id,
          });
        }

        // Actualizar billetera del destinatario (si aplica)
        if (recipientWallet != null && (recipientWalletSnapshot != null ||
            (BankConstants.bankTransactions.contains(transaction.type) && !recipientWalletSnapshot!.exists))) { // Si se creó en esta transacción
          double newRecipientBalance = recipientInitialBalance + transaction.amount;
          firestoreTransaction.update(walletReference.doc(transaction.recipientId!), {
          AppFirestoreConstants.balance: newRecipientBalance,
          AppFirestoreConstants.lastUpdated: DateTime.now().millisecondsSinceEpoch,
          AppFirestoreConstants.lastTransactionId: transaction.id,
          });
        }

        return true;
      });
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    return isSuccess;
  }

}
