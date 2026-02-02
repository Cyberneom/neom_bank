import 'package:sint/sint.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'ui/wallet_history_page.dart';

class BankRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
      name: AppRouteConstants.wallet,
      page: () => const WalletHistoryPage(),
      transition: Transition.leftToRight,
    ),
  ];

}
