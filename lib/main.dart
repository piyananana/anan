import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sa/screens/home_screen.dart';
import 'sa/screens/login_screen.dart';

import 'sa/services/auth_service.dart';
import 'sa/services/language_provider.dart';
import 'sa/services/backup_service.dart';
import 'sa/services/company_service.dart';
import 'sa/services/group_menu_service.dart';
import 'sa/services/group_service.dart';
import 'sa/services/group_user_service.dart';
import 'sa/services/menu_service.dart';
import 'sa/services/module_document_service.dart';
import 'sa/services/password_policy_service.dart';
import 'sa/services/user_document_service.dart';
import 'sa/services/user_menu_service.dart';
import 'sa/services/user_service.dart';

import 'cd/services/branch_service.dart';
import 'cd/services/business_type_service.dart';
import 'cd/services/business_unit_service.dart';
import 'cd/services/currency_service.dart';
import 'cd/services/project_service.dart';
import 'cd/services/zipcode_service.dart';
import 'cd/services/vat_rate_service.dart';
import 'cd/services/bank_service.dart';
import 'cd/services/bank_branch_service.dart';

import 'gl/services/account_service.dart';
import 'gl/services/gl_entry_service.dart';
import 'gl/services/financial_report_service.dart';
import 'gl/services/general_ledger_report_service.dart';
import 'gl/services/period_service.dart';
import 'gl/services/trial_balance_report_service.dart';

import 'ar/services/ar_customer_service.dart';
import 'ar/services/ar_customer_group_service.dart';
import 'ar/services/ar_customer_running_service.dart';
import 'ar/services/ar_collector_service.dart';

import 'cd/services/sales_territory_service.dart';
import 'cd/services/salesperson_service.dart';
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
        Provider<BusinessUnitService>(create: (_) => BusinessUnitService()),
        Provider<CurrencyService>(create: (_) => CurrencyService()),
        Provider<ProjectService>(create: (_) => ProjectService()),
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
