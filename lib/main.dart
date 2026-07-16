import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sa/screens/sa_home_screen.dart';
import 'sa/screens/sa_login_screen.dart';

import 'sa/services/sa_auth_service.dart';
import 'sa/services/sa_language_provider.dart';
import 'sa/services/sa_backup_service.dart';
import 'sa/services/sa_company_service.dart';
import 'sa/services/sa_group_menu_service.dart';
import 'sa/services/sa_group_service.dart';
import 'sa/services/sa_group_user_service.dart';
import 'sa/services/sa_menu_service.dart';
import 'sa/services/sa_module_document_service.dart';
import 'sa/services/sa_password_policy_service.dart';
import 'sa/services/sa_user_document_service.dart';
import 'sa/services/sa_user_menu_service.dart';
import 'sa/services/sa_user_service.dart';

import 'cd/services/cd_branch_service.dart';
import 'cd/services/cd_business_type_service.dart';
import 'cd/services/cd_currency_service.dart';
import 'cd/services/cd_zipcode_service.dart';
import 'cd/services/cd_vat_rate_service.dart';
import 'cd/services/cd_bank_service.dart';
import 'cd/services/cd_bank_branch_service.dart';

import 'gl/services/gl_account_service.dart';
import 'gl/services/gl_entry_service.dart';
import 'gl/services/gl_financial_report_service.dart';
import 'gl/services/gl_general_ledger_report_service.dart';
import 'gl/services/gl_period_service.dart';
import 'gl/services/gl_trial_balance_report_service.dart';

import 'ar/services/ar_customer_service.dart';
import 'ar/services/ar_customer_group_service.dart';
import 'ar/services/ar_customer_running_service.dart';
import 'ar/services/ar_collector_service.dart';

import 'cd/services/cd_sales_territory_service.dart';
import 'cd/services/cd_salesperson_service.dart';
import 'cd/services/cd_wht_type_service.dart';

import 'cm/services/cm_bank_account_service.dart';
import 'cm/services/cm_payment_method_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // ถ้าใช้ provider
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
        Provider<BackupService>(create: (_) => BackupService()),
        Provider<CompanyService>(create: (_) => CompanyService()),
        Provider<GroupMenuService>(create: (_) => GroupMenuService()),
        Provider<GroupService>(create: (_) => GroupService()),
        Provider<GroupUserService>(create: (_) => GroupUserService()),
        Provider<MenuService>(create: (_) => MenuService()),
        Provider<ModuleDocumentService>(create: (_) => ModuleDocumentService()),
        Provider<PasswordPolicyService>(create: (_) => PasswordPolicyService()),
        Provider<UserDocumentService>(create: (_) => UserDocumentService()),
        Provider<UserMenuService>(create: (_) => UserMenuService()),
        Provider<UserService>(create: (_) => UserService()),

        Provider<BranchService>(create: (_) => BranchService()),
        Provider<BusinessTypeService>(create: (_) => BusinessTypeService()),
        Provider<CurrencyService>(create: (_) => CurrencyService()),
        Provider<ZipcodeService>(create: (_) => ZipcodeService()),
        Provider<VatRateService>(create: (_) => VatRateService()),

        Provider<AccountService>(create: (_) => AccountService()),
        Provider<GlEntryService>(create: (_) => GlEntryService()),
        Provider<FinancialReportService>(create: (_) => FinancialReportService()),
        Provider<GeneralLedgerReportService>(create: (_) => GeneralLedgerReportService()),
        Provider<PeriodService>(create: (_) => PeriodService()),
        Provider<TrialBalanceReportService>(create: (_) => TrialBalanceReportService()),

        Provider<ArCustomerService>(create: (_) => ArCustomerService()),
        Provider<ArCustomerGroupService>(create: (_) => ArCustomerGroupService()),
        Provider<ArCustomerRunningService>(create: (_) => ArCustomerRunningService()),
        Provider<BankService>(create: (_) => BankService()),
        Provider<BankBranchService>(create: (_) => BankBranchService()),
        Provider<SalesTerritoryService>(create: (_) => SalesTerritoryService()),
        Provider<SalespersonService>(create: (_) => SalespersonService()),
        Provider<ArCollectorService>(create: (_) => ArCollectorService()),
        Provider<CdWhtTypeService>(create: (_) => CdWhtTypeService()),

        Provider<CmBankAccountService>(create: (_) => CmBankAccountService()),
        Provider<CmPaymentMethodService>(create: (_) => CmPaymentMethodService()),
        // Add other providers if needed
      ],
      child: MaterialApp(
        title: 'ANAN System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'tahoma',
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            // return FutureBuilder<String>(
            return FutureBuilder<bool>(
              future:
                  Provider.of<AuthService>(context, listen: false).isLoggedIn(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasData && snapshot.data == true) {
                  // มี Token อยู่แล้ว, แสดง HomeScreen
                  return const HomeScreen();
                } else {
                  // ไม่มี Token, แสดง LoginScreen
                  return const LoginScreen();
                }
              },
            );
          },
        ),
      ),
    );
  }
}
