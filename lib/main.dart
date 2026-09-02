import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'views/budget_setting_screen.dart';
import 'views/root_screen.dart';
import 'views/add_transaction_screen.dart';
import 'providers/expense_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nap du lieu locale cho DateFormat('...', 'vi_VN'). Bat buoc, neu thieu se
  // nem LocaleDataException khi format ngay.
  await initializeDateFormatting('vi_VN', null);

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenseProvider>(
      create: (_) => ExpenseProvider()..init(),
      child: MaterialApp(
        title: 'Quản lý chi tiêu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Tu dong doi Sang/Toi theo cai dat he thong.
        themeMode: ThemeMode.system,
        locale: const Locale('vi', 'VN'),
        supportedLocales: const <Locale>[
          Locale('vi', 'VN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: RootScreen.routeName,
        routes: <String, WidgetBuilder>{
          RootScreen.routeName: (_) => const RootScreen(),
          AddTransactionScreen.routeName: (_) => const AddTransactionScreen(),
          BudgetSettingScreen.routeName: (_) => const BudgetSettingScreen(),
        },
      ),
    );
  }
}
