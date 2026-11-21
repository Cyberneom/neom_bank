import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_bank/data/translations/tip_de_translations.dart';
import 'package:neom_bank/data/translations/tip_en_translations.dart';
import 'package:neom_bank/data/translations/tip_es_translations.dart';
import 'package:neom_bank/data/translations/tip_fr_translations.dart';
import 'package:neom_bank/ui/wallet_controller.dart';
import 'package:neom_bank/ui/widgets/tip_sheet.dart';
import 'package:neom_bank/utils/constants/tip_translation_constants.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/product_type.dart';
import 'package:sint/sint.dart';

class _TestTipTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'es': TipEsTranslations.values,
        'en': TipEnTranslations.values,
        'fr': TipFrTranslations.values,
        'de': TipDeTranslations.values,
      };
}

void main() {
  group('GigCoins starter pack (10 GigCoins for \$50 MXN)', () {
    test('buildGigCoinPack defaults to 10 GigCoins for 50 MXN', () {
      final pack = WalletController.buildGigCoinPack();

      expect(pack.id, 'gigcoins_10');
      expect(pack.type, ProductType.appCoin);
      expect(pack.qty, 10);
      expect(pack.salePrice?.amount, 50.0);
      expect(pack.salePrice?.currency, AppCurrency.mxn);
      expect(pack.regularPrice?.amount, 50.0);
      expect(pack.regularPrice?.currency, AppCurrency.mxn);
    });

    test('defaultGigCoinPacks starts with 10 GigCoins for 50 MXN', () {
      final packs = WalletController.defaultGigCoinPacks();

      expect(packs, isNotEmpty);
      expect(packs.first.qty, 10);
      expect(packs.first.salePrice?.amount, 50.0);
      expect(packs.first.salePrice?.currency, AppCurrency.mxn);
      expect(packs.map((p) => p.qty).toList(), [10, 20, 50, 100]);
    });

    test('Tip translations maintain 100% key parity across es, en, fr, de', () {
      final esKeys = TipEsTranslations.values.keys.toSet();
      expect(TipEnTranslations.values.keys.toSet(), esKeys);
      expect(TipFrTranslations.values.keys.toSet(), esKeys);
      expect(TipDeTranslations.values.keys.toSet(), esKeys);
      expect(esKeys, contains(TipTranslationConstants.tipBuyStarterPack));
      expect(esKeys, contains(TipTranslationConstants.tipNoCoinsSubtitle));
      expect(esKeys, contains(TipTranslationConstants.tipOpenWallet));
    });
  });

  group('TipSheet insufficient GigCoins flow', () {
    tearDown(() {
      Sint.reset();
    });

    testWidgets(
      'when user has 0 GigCoins, displays active CTA to buy 10 GigCoins for \$50 MXN and invokes purchase callback',
      (tester) async {
        var purchaseTriggered = false;

        await tester.pumpWidget(
          SintMaterialApp(
            translations: _TestTipTranslations(),
            locale: const Locale('es'),
            home: Scaffold(
              body: TipSheet(
                recipientId: 'artist_1',
                recipientName: 'Serzen Montoya',
                initialBalanceOverride: 0,
                onBuyStarterPack: (_) async {
                  purchaseTriggered = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Comprar 10 GigCoins · \$50 MXN'), findsOneWidget);
        expect(find.textContaining('10 GigCoins por \$50 MXN'), findsOneWidget);
        expect(find.textContaining('Enviar Tip'), findsNothing);

        await tester.tap(find.text('Comprar 10 GigCoins · \$50 MXN'));
        await tester.pumpAndSettle();

        expect(purchaseTriggered, isTrue);
      },
    );

    testWidgets(
      'when user has enough GigCoins, shows Send Tip CTA instead of buy starter pack CTA',
      (tester) async {
        await tester.pumpWidget(
          SintMaterialApp(
            translations: _TestTipTranslations(),
            locale: const Locale('es'),
            home: const Scaffold(
              body: TipSheet(
                recipientId: 'artist_1',
                recipientName: 'Serzen Montoya',
                initialBalanceOverride: 10,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Enviar Tip'), findsOneWidget);
        expect(find.text('Comprar 10 GigCoins · \$50 MXN'), findsNothing);
      },
    );
  });
}
