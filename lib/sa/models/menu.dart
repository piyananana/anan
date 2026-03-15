import 'package:flutter/material.dart';

import '../screens/backup_screen.dart';
import '../screens/company_profile_screen.dart';
import '../screens/group_management_screen.dart';
import '../screens/group_menu_management_screen.dart';
import '../screens/group_user_management_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/module_document_screen.dart';
import '../screens/password_policy_screen.dart';
import '../screens/user_document_screen.dart';
import '../screens/user_menu_screen.dart';
import '../screens/user_screen.dart';

import '../../cd/screens/branch_screen.dart';
import '../../cd/screens/business_unit_screen.dart';
import '../../cd/screens/currency_screen.dart';
import '../../cd/screens/project_screen.dart';
import '../../cd/screens/zipcode_screen.dart';
import '../../cd/screens/vat_rate_screen.dart';

import '../../gl/screens/account_screen.dart';
import '../../gl/screens/financial_report_builder_screen.dart';
import '../../gl/screens/gl_entry_screen.dart';
import '../../gl/screens/financial_report_screen.dart';
import '../../gl/screens/general_ledger_report_screen.dart';
import '../../gl/screens/period_screen.dart';
import '../../gl/screens/trial_balance_report_screen.dart';
import '../../gl/screens/balance_sheet_report_screen.dart';
import '../../gl/screens/income_statement_report_screen.dart';
import '../../gl/screens/daily_transaction_report_screen.dart';
import '../../gl/screens/year_end_closing_screen.dart';
import '../../gl/screens/year_end_closing_config_screen.dart';

import '../../ar/screens/ar_customer_screen.dart';

class Menu {
  final int id;
  final int? parentId;
  final String menuName;
  final String menuType; // 'folder', 'link', 'widget'
  final String?
      targetPath; // e.g., 'HomePage', 'ProductListScreen', '/products'
  final int sortOrder;
  final Widget Function(BuildContext context)
      builder; // ฟังก์ชันสำหรับสร้าง Widget ของหน้านั้นๆ

  List<Menu> children = [];
  static final Map<String, Widget Function(BuildContext context)>
      _staticWidgetBuilders = {
    // 'HomePage': (context) => const Text('This is the Home Page content!'),
    // 'ProductListScreen': (context) => const Text('List of Products!'),
    // 'UserProfileView': (context) => const Text('User Profile Details!'),
    'BackupScreen': (context) => const BackupScreen(),
    'CompanyProfileScreen': (context) => const CompanyProfileScreen(),
    'GroupManagementScreen': (context) => const GroupManagementScreen(),
    'GroupMenuManagementScreen': (context) => const GroupMenuManagementScreen(),
    'GroupUserManagementScreen': (context) => const GroupUserManagementScreen(),
    'MenuScreen': (context) => MenuScreen(
          onMenusChanged: () {},
        ),
    'ModuleDocumentScreen': (context) => ModuleDocumentScreen(
          onFieldsChanged: () {},
        ),
    'PasswordPolicyScreen': (context) => const PasswordPolicyScreen(),
    'UserDocumentScreen': (context) => const UserDocumentScreen(),
    'UserMenuScreen': (context) => const UserMenuScreen(),
    'UserScreen': (context) => const UserScreen(),

    'BranchScreen': (context) => BranchScreen(
          onFieldsChanged: () {},
        ),
    'BusinessUnitScreen': (context) => BusinessUnitScreen(
          onFieldsChanged: () {},
        ),
    'CurrencyScreen': (context) => CurrencyScreen(
          onFieldsChanged: () {},
        ),
    'ProjectScreen': (context) => ProjectScreen(
          onFieldsChanged: () {},
        ),
    'ZipcodeScreen': (context) => ZipcodeScreen(
          onFieldsChanged: () {},
        ),
    'VatRateScreen': (context) => VatRateScreen(
          onFieldsChanged: () {},
        ),

    'AccountScreen': (context) => AccountScreen(
          onFieldsChanged: () {},
        ),
    'GlEntryScreen': (context) => const GlEntryScreen(),
    'FinancialReportScreen': (context) => const FinancialReportScreen(),
    'GeneralLedgerReportScreen': (context) => const GeneralLedgerReportScreen(),
    'PeriodScreen': (context) => PeriodScreen(
          onFieldsChanged: () {},
        ),
    'TrialBalanceReportScreen': (context) => const TrialBalanceReportScreen(),
    'DailyTransactionReportScreen': (context) => const DailyTransactionReportScreen(),
    'BalanceSheetReportScreen': (context) => const BalanceSheetReportScreen(),
    'IncomeStatementReportScreen': (context) => const IncomeStatementReportScreen(),
    'FinancialReportBuilderScreen': (context) => const FinancialReportBuilderScreen(),
    'YearEndClosingScreen': (context) => const YearEndClosingScreen(),
    'YearEndClosingConfigScreen': (context) => const YearEndClosingConfigScreen(),

    'ArCustomerScreen': (context) => ArCustomerScreen(
          onFieldsChanged: () {},
        ),
    // 'PeriodScreen': (context) => const PeriodScreen(),
    // Add all your custom widgets here
    // 'YourCustomWidget1': (context) => const YourCustomWidget1(),
    // 'YourCustomWidget2': (context) => const YourCustomWidget2(),
  };

  Menu({
    required this.id,
    this.parentId,
    required this.menuName,
    required this.menuType,
    this.targetPath,
    required this.sortOrder,
    this.children = const [], // <-- กำหนดค่าเริ่มต้น
    required this.builder,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    String? path = json['target_path'];
    Widget Function(BuildContext context) screenBuilder =
        _staticWidgetBuilders[path] ??
            ((context) => Center(child: Text('Widget for "$path" not found!')));

    return Menu(
        id: json['id'],
        parentId: json['parent_id'],
        menuName: json['menu_name'],
        menuType: json['menu_type'],
        targetPath: json['target_path'] ?? '',
        sortOrder: json['sort_order'],
        children: [], // จะถูกเติมในภายหลังเมื่อสร้าง tree
        builder: screenBuilder);
  }
}

class MenuContent {
  final String menuName;
  final String menuType;
  final String? targetPath;
  final String? contentType;
  final String? contentData;

  MenuContent({
    required this.menuName,
    required this.menuType,
    this.targetPath,
    this.contentType,
    this.contentData,
  });

  factory MenuContent.fromJson(Map<String, dynamic> json) {
    return MenuContent(
      menuName: json['menu_name'],
      menuType: json['menu_type'],
      targetPath: json['target_path'],
      contentType: json['content_type'],
      contentData: json['content_data'],
    );
  }
}
