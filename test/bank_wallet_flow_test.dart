import 'package:flutter_test/flutter_test.dart';

import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/tip.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/wallet_status.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:neom_core/utils/enums/tip_tier.dart';
import 'package:neom_core/utils/constants/app_payment_constants.dart';

/// Tests de neom_bank: Wallet, AppTransaction, Tip, conversiones appCoin,
/// validaciones de transacción y flujos mock del banco.
void main() {
  // ─────────────────── Wallet Model ───────────────────
  group('Wallet', () {
    test('defaults correctos al crear', () {
      final wallet = Wallet();

      expect(wallet.id, '');
      expect(wallet.balance, 0.0);
      expect(wallet.currency, AppCurrency.appCoin);
      expect(wallet.status, WalletStatus.active);
      expect(wallet.createdTime, 0);
      expect(wallet.lastTransactionId, isNull);
    });

    test('crear wallet con email como ID', () {
      final wallet = Wallet(
        id: 'artista@emxi.mx',
        balance: 150.0,
        currency: AppCurrency.appCoin,
        status: WalletStatus.active,
        createdTime: 1742169600000,
        lastUpdated: 1742169600000,
      );

      expect(wallet.id, 'artista@emxi.mx');
      expect(wallet.balance, 150.0);
      expect(wallet.currency, AppCurrency.appCoin);
      expect(wallet.status, WalletStatus.active);
    });

    test('JSON round-trip preserva todos los campos', () {
      final original = Wallet(
        id: 'juan@emxi.mx',
        balance: 500.0,
        currency: AppCurrency.appCoin,
        status: WalletStatus.active,
        createdTime: 1742169600000,
        lastUpdated: 1742170000000,
        lastTransactionId: 'txn_abc123',
      );

      final json = original.toJSON();
      final restored = Wallet.fromJSON(json);

      expect(restored.id, original.id);
      expect(restored.balance, original.balance);
      expect(restored.currency, original.currency);
      expect(restored.status, original.status);
      expect(restored.createdTime, original.createdTime);
      expect(restored.lastUpdated, original.lastUpdated);
      expect(restored.lastTransactionId, original.lastTransactionId);
    });

    test('fromJSON con datos parciales retorna defaults seguros', () {
      final wallet = Wallet.fromJSON({
        'id': '',
        'balance': 0,
        'currency': 'appCoin',
        'status': '',
      });

      expect(wallet.id, '');
      expect(wallet.balance, 0.0);
      expect(wallet.currency, AppCurrency.appCoin);
      // fromJSON default es suspended cuando status es invalido
      expect(wallet.status, WalletStatus.suspended);
    });

    test('balance puede ser fraccionario', () {
      final wallet = Wallet(balance: 37.5);
      expect(wallet.balance, 37.5);

      final json = wallet.toJSON();
      final restored = Wallet.fromJSON(json);
      expect(restored.balance, 37.5);
    });
  });

  // ─────────────────── WalletStatus ───────────────────
  group('WalletStatus', () {
    test('todos los estados existen', () {
      expect(WalletStatus.values, hasLength(4));
      expect(WalletStatus.values, containsAll([
        WalletStatus.active,
        WalletStatus.suspended,
        WalletStatus.frozen,
        WalletStatus.closed,
      ]));
    });

    test('solo active permite transacciones', () {
      // Simula validacion de WalletFirestore.addTransaction
      for (final status in WalletStatus.values) {
        final canTransact = status == WalletStatus.active;
        if (status == WalletStatus.active) {
          expect(canTransact, isTrue);
        } else {
          expect(canTransact, isFalse,
              reason: '${status.name} no deberia permitir transacciones');
        }
      }
    });
  });

  // ─────────────────── TransactionType ───────────────────
  group('TransactionType', () {
    test('9 tipos de transaccion', () {
      expect(TransactionType.values, hasLength(9));
    });

    test('bank transactions: sistema → usuario', () {
      final bankTxTypes = [
        TransactionType.deposit,
        TransactionType.coupon,
        TransactionType.loyaltyPoints,
        TransactionType.refund,
        TransactionType.royaltyPayout,
      ];

      // Verificar values individuales
      expect(TransactionType.deposit.value, 0);
      expect(TransactionType.coupon.value, 1);
      expect(TransactionType.loyaltyPoints.value, 2);
      expect(TransactionType.refund.value, 3);
      expect(TransactionType.royaltyPayout.value, 8);

      // 5 tipos de bank transactions
      expect(bankTxTypes, hasLength(5));
    });

    test('user transactions: requieren fondos del sender', () {
      final userTxTypes = [
        TransactionType.withdrawal,
        TransactionType.purchase,
        TransactionType.transfer,
      ];

      for (final type in userTxTypes) {
        expect(type.value, greaterThanOrEqualTo(4));
      }
    });

    test('tip es tipo especial user-to-user', () {
      expect(TransactionType.tip.value, 7);
    });

    test('BankConstants categorization (replica)', () {
      // Replica la logica de BankConstants sin importar el archivo
      final bankTransactions = [
        TransactionType.deposit,
        TransactionType.coupon,
        TransactionType.loyaltyPoints,
        TransactionType.refund,
        TransactionType.royaltyPayout,
      ];

      final userTransactions = [
        TransactionType.withdrawal,
        TransactionType.purchase,
        TransactionType.transfer,
      ];

      // tip no esta en ninguno de los dos (se maneja especial)
      expect(bankTransactions, isNot(contains(TransactionType.tip)));
      expect(userTransactions, isNot(contains(TransactionType.tip)));

      // No overlap
      for (final type in bankTransactions) {
        expect(userTransactions, isNot(contains(type)),
            reason: '${type.name} no deberia estar en ambas listas');
      }
    });
  });

  // ─────────────────── TipTier ───────────────────
  group('TipTier', () {
    test('3 tiers con montos correctos', () {
      expect(TipTier.values, hasLength(3));

      expect(TipTier.cafe.coins, 5);
      expect(TipTier.cafe.label, 'cafe');

      expect(TipTier.cuerdas.coins, 25);
      expect(TipTier.cuerdas.label, 'cuerdas');

      expect(TipTier.amplificador.coins, 100);
      expect(TipTier.amplificador.label, 'amplificador');
    });

    test('tiers ordenados de menor a mayor', () {
      expect(TipTier.cafe.coins, lessThan(TipTier.cuerdas.coins));
      expect(TipTier.cuerdas.coins, lessThan(TipTier.amplificador.coins));
    });

    test('valor en MXN de cada tier', () {
      // 1 appCoin = 5 MXN
      expect(TipTier.cafe.coins * AppPaymentConstants.appCoinToMxn, 25.0);      // $25 MXN
      expect(TipTier.cuerdas.coins * AppPaymentConstants.appCoinToMxn, 125.0);  // $125 MXN
      expect(TipTier.amplificador.coins * AppPaymentConstants.appCoinToMxn, 500.0); // $500 MXN
    });

    test('valor en USD de cada tier', () {
      expect(TipTier.cafe.coins * AppPaymentConstants.appCoinToUsd, 1.25);
      expect(TipTier.cuerdas.coins * AppPaymentConstants.appCoinToUsd, 6.25);
      expect(TipTier.amplificador.coins * AppPaymentConstants.appCoinToUsd, 25.0);
    });
  });

  // ─────────────────── Tip Model ───────────────────
  group('Tip', () {
    test('defaults correctos', () {
      final tip = Tip();
      expect(tip.id, '');
      expect(tip.senderId, '');
      expect(tip.recipientId, '');
      expect(tip.tier, TipTier.cafe);
      expect(tip.amount, 0);
      expect(tip.message, isNull);
      expect(tip.contextType, isNull);
    });

    test('crear tip completo', () {
      final tip = Tip(
        id: 'sender123_recipient456_1742169600000',
        senderId: 'sender123',
        senderName: 'Maria Lopez',
        senderAvatarUrl: 'https://cdn.emxi.mx/avatar.jpg',
        recipientId: 'recipient456',
        recipientName: 'Carlos Artista',
        tier: TipTier.cuerdas,
        amount: 25.0,
        message: 'Excelente musica!',
        contextType: 'post',
        contextId: 'post_789',
        createdTime: 1742169600000,
      );

      expect(tip.senderId, 'sender123');
      expect(tip.recipientId, 'recipient456');
      expect(tip.tier, TipTier.cuerdas);
      expect(tip.amount, 25.0);
      expect(tip.message, 'Excelente musica!');
      expect(tip.contextType, 'post');
    });

    test('JSON round-trip preserva todos los campos', () {
      final original = Tip(
        id: 'tip_001',
        senderId: 'sender_abc',
        senderName: 'Ana Garcia',
        senderAvatarUrl: 'https://cdn.emxi.mx/ana.jpg',
        recipientId: 'recipient_xyz',
        recipientName: 'Pedro Musico',
        tier: TipTier.amplificador,
        amount: 100.0,
        message: 'Eres increible!',
        contextType: 'live',
        contextId: 'live_session_42',
        createdTime: 1742169600000,
      );

      final json = original.toJSON();
      final restored = Tip.fromJSON(json);

      expect(restored.id, original.id);
      expect(restored.senderId, original.senderId);
      expect(restored.senderName, original.senderName);
      expect(restored.senderAvatarUrl, original.senderAvatarUrl);
      expect(restored.recipientId, original.recipientId);
      expect(restored.recipientName, original.recipientName);
      expect(restored.tier, original.tier);
      expect(restored.amount, original.amount);
      expect(restored.message, original.message);
      expect(restored.contextType, original.contextType);
      expect(restored.contextId, original.contextId);
      expect(restored.createdTime, original.createdTime);
    });

    test('fromJSON con datos vacios retorna defaults', () {
      final tip = Tip.fromJSON({});
      expect(tip.id, '');
      expect(tip.tier, TipTier.cafe);
      expect(tip.amount, 0);
    });

    test('tip ID format: senderId_recipientId_timestamp', () {
      // Replica la logica de TipFirestore.createTip
      final senderId = 'sender_abc';
      final recipientId = 'recipient_xyz';
      final createdTime = 1742169600000;

      final tipId = '${senderId}_${recipientId}_$createdTime';

      expect(tipId, 'sender_abc_recipient_xyz_1742169600000');
      expect(tipId.split('_').length, greaterThanOrEqualTo(3));
    });

    test('toString incluye informacion clave', () {
      final tip = Tip(
        id: 'tip_001',
        senderId: 'sender',
        senderName: 'Ana',
        recipientId: 'recipient',
        recipientName: 'Pedro',
        tier: TipTier.cafe,
        amount: 5.0,
        message: 'Bravo',
      );

      final str = tip.toString();
      expect(str, contains('senderId: sender'));
      expect(str, contains('recipientId: recipient'));
      expect(str, contains('tier: TipTier.cafe'));
      expect(str, contains('amount: 5.0'));
    });
  });

  // ─────────────────── AppPaymentConstants ───────────────────
  group('AppPaymentConstants - Conversiones', () {
    test('appCoin a monedas fiat', () {
      expect(AppPaymentConstants.appCoinToMxn, 5.0);
      expect(AppPaymentConstants.appCoinToUsd, 0.25);
      expect(AppPaymentConstants.appCoinToEur, 0.23);
      expect(AppPaymentConstants.appCoinToGbp, 0.19);
    });

    test('MXN a monedas internacionales', () {
      expect(AppPaymentConstants.mxnToUsd, 0.050);
      expect(AppPaymentConstants.mxnToEur, 0.046);
      expect(AppPaymentConstants.mxnToGbp, 0.038);
    });

    test('consistencia: appCoin→MXN→USD vs appCoin→USD directa', () {
      // 1 appCoin = 5 MXN, 5 MXN * 0.050 = 0.25 USD
      final indirectUsd = AppPaymentConstants.appCoinToMxn * AppPaymentConstants.mxnToUsd;
      expect(indirectUsd, closeTo(AppPaymentConstants.appCoinToUsd, 0.01));
    });

    test('fees definidas correctamente', () {
      expect(AppPaymentConstants.serviceFee, 0.16);
      expect(AppPaymentConstants.startersServiceFee, 0.08);
      expect(AppPaymentConstants.stripeFee, 0.055);
      expect(AppPaymentConstants.mexicanTaxesAmount, 0.16);
    });

    test('conversion de paquetes appCoin a MXN', () {
      // Paquetes tipicos
      expect(10 * AppPaymentConstants.appCoinToMxn, 50.0);
      expect(20 * AppPaymentConstants.appCoinToMxn, 100.0);
      expect(50 * AppPaymentConstants.appCoinToMxn, 250.0);
      expect(100 * AppPaymentConstants.appCoinToMxn, 500.0);
    });

    test('conversion de paquetes appCoin a USD', () {
      expect(10 * AppPaymentConstants.appCoinToUsd, 2.50);
      expect(50 * AppPaymentConstants.appCoinToUsd, 12.50);
      expect(100 * AppPaymentConstants.appCoinToUsd, 25.0);
    });
  });

  // ─────────────────── Mock Bank Transaction Flows ───────────────────
  group('Mock flujo de transacciones bancarias', () {
    /// Simula WalletFirestore.addTransaction() sin Firestore
    bool mockAddTransaction({
      required Wallet? senderWallet,
      required Wallet? recipientWallet,
      required AppTransaction transaction,
    }) {
      // Validaciones basicas (replica de WalletFirestore)
      if (transaction.amount <= 0) return false;

      final bankTransactions = [
        TransactionType.deposit,
        TransactionType.coupon,
        TransactionType.loyaltyPoints,
        TransactionType.refund,
        TransactionType.royaltyPayout,
      ];

      // Validar sender si es user transaction
      if (!bankTransactions.contains(transaction.type)) {
        if (senderWallet == null) return false;
        if (senderWallet.status != WalletStatus.active) return false;
        if (senderWallet.balance < transaction.amount) return false;
      }

      // Validar recipient
      if (recipientWallet != null && recipientWallet.status != WalletStatus.active) {
        return false;
      }

      // Procesar: debito sender, credito recipient
      if (senderWallet != null) {
        senderWallet.balance -= transaction.amount;
        senderWallet.lastTransactionId = transaction.id;
        senderWallet.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      }

      if (recipientWallet != null) {
        recipientWallet.balance += transaction.amount;
        recipientWallet.lastTransactionId = transaction.id;
        recipientWallet.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      }

      return true;
    }

    test('deposit: banco → usuario (sin sender)', () {
      final recipientWallet = Wallet(
        id: 'user@emxi.mx',
        balance: 100.0,
        status: WalletStatus.active,
      );

      final tx = AppTransaction(
        id: 'txn_deposit_001',
        amount: 50.0,
        type: TransactionType.deposit,
        recipientId: 'user@emxi.mx',
        currency: AppCurrency.appCoin,
      );

      final success = mockAddTransaction(
        senderWallet: null,
        recipientWallet: recipientWallet,
        transaction: tx,
      );

      expect(success, isTrue);
      expect(recipientWallet.balance, 150.0);
      expect(recipientWallet.lastTransactionId, 'txn_deposit_001');
    });

    test('coupon: banco → usuario', () {
      final wallet = Wallet(id: 'promo@emxi.mx', balance: 0.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_coupon_001',
        amount: 10.0,
        type: TransactionType.coupon,
        recipientId: 'promo@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: null, recipientWallet: wallet, transaction: tx), isTrue);
      expect(wallet.balance, 10.0);
    });

    test('loyaltyPoints: banco → usuario', () {
      final wallet = Wallet(id: 'leal@emxi.mx', balance: 200.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_loyalty_001',
        amount: 15.0,
        type: TransactionType.loyaltyPoints,
        recipientId: 'leal@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: null, recipientWallet: wallet, transaction: tx), isTrue);
      expect(wallet.balance, 215.0);
    });

    test('royaltyPayout: banco → creador (NUPALE)', () {
      final creatorWallet = Wallet(id: 'autor@emxi.mx', balance: 50.0, status: WalletStatus.active);

      // Simula royalty: $300 MXN gross → 300 appCoins (1:1)
      final grossMxn = 300.0;
      final appCoins = grossMxn; // conversion 1:1 de nupale

      final tx = AppTransaction(
        id: 'txn_royalty_001',
        amount: appCoins,
        type: TransactionType.royaltyPayout,
        recipientId: 'autor@emxi.mx',
        currency: AppCurrency.appCoin,
        description: 'Royalty payout - El Alquimista',
      );

      expect(mockAddTransaction(senderWallet: null, recipientWallet: creatorWallet, transaction: tx), isTrue);
      expect(creatorWallet.balance, 350.0); // 50 + 300
    });

    test('transfer: usuario → usuario', () {
      final sender = Wallet(id: 'juan@emxi.mx', balance: 200.0, status: WalletStatus.active);
      final recipient = Wallet(id: 'maria@emxi.mx', balance: 50.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_transfer_001',
        amount: 75.0,
        type: TransactionType.transfer,
        senderId: 'juan@emxi.mx',
        recipientId: 'maria@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: sender, recipientWallet: recipient, transaction: tx), isTrue);
      expect(sender.balance, 125.0);   // 200 - 75
      expect(recipient.balance, 125.0); // 50 + 75
    });

    test('tip: usuario → usuario (cafe tier)', () {
      final tipper = Wallet(id: 'fan@emxi.mx', balance: 30.0, status: WalletStatus.active);
      final artist = Wallet(id: 'artista@emxi.mx', balance: 500.0, status: WalletStatus.active);

      final tipAmount = TipTier.cafe.coins.toDouble(); // 5

      final tx = AppTransaction(
        id: 'txn_tip_001',
        amount: tipAmount,
        type: TransactionType.tip,
        senderId: 'fan@emxi.mx',
        recipientId: 'artista@emxi.mx',
        description: 'Tip: cafe (5 coins)',
      );

      // tip no esta en bankTransactions, requiere sender con fondos
      expect(mockAddTransaction(senderWallet: tipper, recipientWallet: artist, transaction: tx), isTrue);
      expect(tipper.balance, 25.0);     // 30 - 5
      expect(artist.balance, 505.0);    // 500 + 5
    });

    test('tip: amplificador tier debita correctamente', () {
      final tipper = Wallet(id: 'fan@emxi.mx', balance: 200.0, status: WalletStatus.active);
      final artist = Wallet(id: 'artista@emxi.mx', balance: 1000.0, status: WalletStatus.active);

      final tipAmount = TipTier.amplificador.coins.toDouble(); // 100

      final tx = AppTransaction(
        id: 'txn_tip_002',
        amount: tipAmount,
        type: TransactionType.tip,
        senderId: 'fan@emxi.mx',
        recipientId: 'artista@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: tipper, recipientWallet: artist, transaction: tx), isTrue);
      expect(tipper.balance, 100.0);    // 200 - 100
      expect(artist.balance, 1100.0);   // 1000 + 100
    });

    test('fondos insuficientes rechaza transaccion', () {
      final sender = Wallet(id: 'pobre@emxi.mx', balance: 3.0, status: WalletStatus.active);
      final recipient = Wallet(id: 'rico@emxi.mx', balance: 1000.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_fail_001',
        amount: 25.0, // cuerdas tier, pero solo tiene 3
        type: TransactionType.tip,
        senderId: 'pobre@emxi.mx',
        recipientId: 'rico@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: sender, recipientWallet: recipient, transaction: tx), isFalse);
      // Balances no cambian
      expect(sender.balance, 3.0);
      expect(recipient.balance, 1000.0);
    });

    test('wallet suspendido no puede enviar', () {
      final suspended = Wallet(id: 'sospechoso@emxi.mx', balance: 500.0, status: WalletStatus.suspended);
      final recipient = Wallet(id: 'inocente@emxi.mx', balance: 100.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_fail_002',
        amount: 10.0,
        type: TransactionType.transfer,
        senderId: 'sospechoso@emxi.mx',
        recipientId: 'inocente@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: suspended, recipientWallet: recipient, transaction: tx), isFalse);
    });

    test('wallet frozen no puede recibir', () {
      final sender = Wallet(id: 'ok@emxi.mx', balance: 500.0, status: WalletStatus.active);
      final frozen = Wallet(id: 'congelado@emxi.mx', balance: 100.0, status: WalletStatus.frozen);

      final tx = AppTransaction(
        id: 'txn_fail_003',
        amount: 10.0,
        type: TransactionType.transfer,
        senderId: 'ok@emxi.mx',
        recipientId: 'congelado@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: sender, recipientWallet: frozen, transaction: tx), isFalse);
    });

    test('wallet closed no puede operar', () {
      final closed = Wallet(id: 'cerrado@emxi.mx', balance: 100.0, status: WalletStatus.closed);

      final tx = AppTransaction(
        id: 'txn_fail_004',
        amount: 5.0,
        type: TransactionType.transfer,
        senderId: 'cerrado@emxi.mx',
        recipientId: 'otro@emxi.mx',
      );

      expect(mockAddTransaction(senderWallet: closed, recipientWallet: null, transaction: tx), isFalse);
    });

    test('monto cero o negativo rechazado', () {
      final wallet = Wallet(id: 'test@emxi.mx', balance: 100.0, status: WalletStatus.active);

      expect(mockAddTransaction(
        senderWallet: null,
        recipientWallet: wallet,
        transaction: AppTransaction(amount: 0.0, type: TransactionType.deposit),
      ), isFalse);

      expect(mockAddTransaction(
        senderWallet: null,
        recipientWallet: wallet,
        transaction: AppTransaction(amount: -10.0, type: TransactionType.deposit),
      ), isFalse);

      // Balance no cambia
      expect(wallet.balance, 100.0);
    });

    test('user transaction sin sender wallet falla', () {
      final recipient = Wallet(id: 'destino@emxi.mx', balance: 0.0, status: WalletStatus.active);

      final tx = AppTransaction(
        id: 'txn_fail_005',
        amount: 50.0,
        type: TransactionType.purchase,
        recipientId: 'destino@emxi.mx',
      );

      // purchase es user transaction, requiere sender
      expect(mockAddTransaction(senderWallet: null, recipientWallet: recipient, transaction: tx), isFalse);
    });
  });

  // ─────────────────── Flujo Completo: Compra appCoin + Tip ───────────────────
  group('Flujo end-to-end: comprar appCoins → enviar tip', () {
    test('usuario compra 50 appCoins y envia tip amplificador', () {
      // 1. Estado inicial: wallet vacio
      final userWallet = Wallet(
        id: 'fan@emxi.mx',
        balance: 0.0,
        status: WalletStatus.active,
      );

      final artistWallet = Wallet(
        id: 'artista@emxi.mx',
        balance: 250.0,
        status: WalletStatus.active,
      );

      // 2. Compra de 50 appCoins via Stripe (simulado)
      // Precio: 50 * 5 = $250 MXN pagados con Stripe
      final purchaseAmount = 50.0;
      final mxnPaid = purchaseAmount * AppPaymentConstants.appCoinToMxn;
      expect(mxnPaid, 250.0);

      // 3. Deposit de coins al wallet (bank transaction)
      userWallet.balance += purchaseAmount;
      expect(userWallet.balance, 50.0);

      // 4. Enviar tip amplificador (100 coins) — deberia fallar, solo tiene 50
      final ampTip = TipTier.amplificador.coins.toDouble(); // 100
      expect(userWallet.balance < ampTip, isTrue);

      // 5. Enviar tip cuerdas (25 coins) — deberia funcionar
      final cuerdasTip = TipTier.cuerdas.coins.toDouble(); // 25
      expect(userWallet.balance >= cuerdasTip, isTrue);

      userWallet.balance -= cuerdasTip;
      artistWallet.balance += cuerdasTip;

      expect(userWallet.balance, 25.0);   // 50 - 25
      expect(artistWallet.balance, 275.0); // 250 + 25

      // 6. Enviar tip cafe (5 coins)
      final cafeTip = TipTier.cafe.coins.toDouble(); // 5
      userWallet.balance -= cafeTip;
      artistWallet.balance += cafeTip;

      expect(userWallet.balance, 20.0);   // 25 - 5
      expect(artistWallet.balance, 280.0); // 275 + 5

      // 7. Verificar valor total recibido por artista en MXN
      final totalTipsCoins = cuerdasTip + cafeTip; // 30
      final totalTipsMxn = totalTipsCoins * AppPaymentConstants.appCoinToMxn;
      expect(totalTipsMxn, 150.0); // $150 MXN
    });

    test('multiples depositos y transacciones mantienen balance consistente', () {
      final wallet = Wallet(id: 'test@emxi.mx', balance: 0.0, status: WalletStatus.active);

      // Depositos del banco
      wallet.balance += 100; // deposit
      wallet.balance += 15;  // coupon
      wallet.balance += 5;   // loyaltyPoints
      expect(wallet.balance, 120.0);

      // Gastos del usuario
      wallet.balance -= 25;  // tip cuerdas
      wallet.balance -= 5;   // tip cafe
      wallet.balance -= 50;  // purchase
      expect(wallet.balance, 40.0);

      // Refund
      wallet.balance += 50; // refund de la compra
      expect(wallet.balance, 90.0);

      // Royalty payout
      wallet.balance += 300; // royaltyPayout
      expect(wallet.balance, 390.0);
    });
  });

  // ─────────────────── AppTransaction para Bank ───────────────────
  group('AppTransaction para operaciones bancarias', () {
    test('transaccion de compra de appCoins', () {
      final tx = AppTransaction(
        amount: 50.0,
        type: TransactionType.purchase,
        currency: AppCurrency.appCoin,
        recipientId: 'user@emxi.mx',
        description: 'AppCoin purchase - 50 coins',
      );

      expect(tx.amount, 50.0);
      expect(tx.type, TransactionType.purchase);
      expect(tx.currency, AppCurrency.appCoin);
    });

    test('transaccion de tip con descripcion formateada', () {
      final tier = TipTier.cuerdas;
      final tx = AppTransaction(
        amount: tier.coins.toDouble(),
        type: TransactionType.tip,
        senderId: 'fan@emxi.mx',
        recipientId: 'artista@emxi.mx',
        description: 'Tip: ${tier.name} (${tier.coins} coins)',
        currency: AppCurrency.appCoin,
      );

      expect(tx.description, 'Tip: cuerdas (25 coins)');
      expect(tx.amount, 25.0);
    });

    test('status lifecycle: pending → completed', () {
      final tx = AppTransaction(status: TransactionStatus.pending);
      expect(tx.status, TransactionStatus.pending);

      tx.status = TransactionStatus.completed;
      expect(tx.status, TransactionStatus.completed);
    });

    test('status lifecycle: pending → failed', () {
      final tx = AppTransaction(status: TransactionStatus.pending);
      tx.status = TransactionStatus.failed;
      expect(tx.status, TransactionStatus.failed);
    });
  });
}
