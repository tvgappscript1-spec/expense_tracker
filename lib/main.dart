import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'views/budget_setting_screen.dart';
import 'views/main_screen.dart';
import 'views/add_transaction_screen.dart';
import 'providers/category_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/theme_provider.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => CategoryProvider()..load(),
        ),
        ChangeNotifierProvider<ExpenseProvider>(
          create: (_) => ExpenseProvider()..init(),
        ),
        ChangeNotifierProvider<DebtProvider>(
          create: (_) => DebtProvider()..load(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..load(),
        ),
      ],
      // Chi rebuild MaterialApp khi doi che do giao dien, khong an theo
      // moi lan danh sach giao dich thay doi.
      child: Consumer<ThemeProvider>(
        builder: (BuildContext context, ThemeProvider theme, Widget? _) =>
            MaterialApp(
        title: 'Quản lý chi tiêu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Nguoi dung tu chon: theo he thong / luon sang / luon toi.
        themeMode: theme.themeMode,
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
        initialRoute: MainScreen.routeName,
        routes: <String, WidgetBuilder>{
          MainScreen.routeName: (_) => const MainScreen(),
          AddTransactionScreen.routeName: (_) => const AddTransactionScreen(),
          BudgetSettingScreen.routeName: (_) => const BudgetSettingScreen(),
        },
        ),
      ),
    );
  }
}
