import 'package:neom_core/ui/deferred_loader.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/wallet_history_page.dart' deferred as walletHistory;

class BankRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
      name: AppRouteConstants.wallet,
      page: () => DeferredLoader(walletHistory.loadLibrary, () => walletHistory.WalletHistoryPage()),
      transition: Transition.leftToRight,
    ),
  ];

}
