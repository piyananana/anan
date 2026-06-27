import 'package:flutter/material.dart';

import '../screens/backup_screen.dart';
import '../screens/company_profile_screen.dart';
import '../screens/group_management_screen.dart';
import '../screens/group_menu_management_screen.dart';
import '../screens/group_user_management_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/module_document_screen.dart';
import '../screens/password_policy_screen.dart';
import '../screens/doc_number_branch_setup_screen.dart';
import '../screens/doc_number_reset_screen.dart';
import '../screens/sa_module_approver_screen.dart';
import '../screens/user_document_screen.dart';
import '../screens/user_menu_screen.dart';
import '../screens/user_screen.dart';

import '../../cd/screens/branch_screen.dart';
import '../../cd/screens/business_type_screen.dart';
import '../../cd/screens/business_unit_screen.dart';
import '../../cd/screens/currency_screen.dart';
import '../../cd/screens/project_screen.dart';
import '../../cd/screens/zipcode_screen.dart';
import '../../cd/screens/vat_rate_screen.dart';
import '../../cd/screens/bank_screen.dart';
import '../../cd/screens/sales_territory_screen.dart';
import '../../cd/screens/salesperson_screen.dart';
import '../../cd/screens/cd_wht_type_screen.dart';

import '../../gl/screens/account_screen.dart';
import '../../gl/screens/account_import_screen.dart';
import '../../gl/screens/gl_opening_balance_import_screen.dart';
import '../../gl/screens/chart_of_accounts_report_screen.dart';
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
import '../../gl/screens/gl_dimension_type_screen.dart';
import '../../gl/screens/gl_dimension_value_screen.dart';
import '../../gl/screens/gl_reset_screen.dart';

import '../../ar/screens/ar_customer_screen.dart';
import '../../ar/screens/ar_customer_group_screen.dart';
import '../../ar/screens/ar_customer_import_screen.dart';
import '../../ar/screens/ar_customer_balance_import_screen.dart';
import '../../ar/screens/ar_customer_running_screen.dart';
import '../../ar/screens/ar_transaction_screen.dart';
import '../../ar/screens/ar_aging_report_screen.dart';
import '../../ar/screens/ar_due_report_screen.dart';
import '../../ar/screens/ar_movement_report_screen.dart';
import '../../ar/screens/ar_billing_plan_report_screen.dart';
import '../../ar/screens/ar_bulk_billing_screen.dart';
import '../../ar/screens/ar_transaction_report_screen.dart';
import '../../ar/screens/ar_billing_status_report_screen.dart';
import '../../ar/screens/ar_receipt_payment_report_screen.dart';
import '../../ar/screens/ar_credit_limit_report_screen.dart';
import '../../ar/screens/ar_customer_report_screen.dart';
import '../../ar/screens/ar_fx_gain_loss_report_screen.dart';
import '../../vt/screens/vat_report_screen.dart';
import '../../ar/screens/ar_collector_screen.dart';
import '../../ar/screens/ar_gl_account_setup_screen.dart';
import '../../ar/screens/ar_reset_screen.dart';
import '../../ar/screens/ar_year_end_setup_screen.dart';
import '../../ar/screens/ar_pre_close_check_screen.dart';
import '../../ar/screens/ar_fx_revaluation_screen.dart';
import '../../ar/screens/ar_allowance_run_screen.dart';

import '../../cm/screens/cm_bank_screen.dart';
import '../../cm/screens/cm_bank_account_screen.dart';
import '../../cm/screens/cm_payment_method_screen.dart';

import '../../ap/screens/ap_vendor_screen.dart';
import '../../ap/screens/ap_vendor_group_screen.dart';
import '../../ap/screens/ap_vendor_import_screen.dart';
import '../../ap/screens/ap_vendor_running_screen.dart';
import '../../ap/screens/ap_vendor_report_screen.dart';
import '../../ap/screens/ap_transaction_screen.dart';
import '../../ap/screens/ap_gl_account_setup_screen.dart';
import '../../ap/screens/ap_payment_run_screen.dart';
import '../../cm/screens/cm_bank_file_format_screen.dart';
import '../screens/sa_smtp_config_screen.dart';

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
  final bool isSystem;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canApprove;
  final bool canPrint;
  final bool canExport;

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
    'DocNumberBranchSetupScreen': (context) => const DocNumberBranchSetupScreen(),
    'DocNumberResetScreen': (context) => const DocNumberResetScreen(),
    'SaModuleApproverScreen': (context) => const SaModuleApproverScreen(),
    'UserDocumentScreen': (context) => const UserDocumentScreen(),
    'UserMenuScreen': (context) => const UserMenuScreen(),
    'UserScreen': (context) => const UserScreen(),

    'BranchScreen': (context) => BranchScreen(
          onFieldsChanged: () {},
        ),
    'BusinessTypeScreen': (context) => BusinessTypeScreen(
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
    'SalesTerritoryScreen': (context) => SalesTerritoryScreen(
          onFieldsChanged: () {},
        ),
    'SalespersonScreen': (context) => SalespersonScreen(
          onFieldsChanged: () {},
        ),

    'AccountScreen': (context) => AccountScreen(
          onFieldsChanged: () {},
        ),
    'AccountImportScreen': (context) => AccountImportScreen(onFieldsChanged: () {}),
    'GlOpeningBalanceImportScreen': (context) => GlOpeningBalanceImportScreen(onFieldsChanged: () {}),
    'GlEntryScreen': (context) => const GlEntryScreen(),
    'GlDimensionTypeScreen': (context) => const GlDimensionTypeScreen(),
    'GlDimensionValueScreen': (context) => const GlDimensionValueScreen(),
    'FinancialReportScreen': (context) => const FinancialReportScreen(),
    'GeneralLedgerReportScreen': (context) => const GeneralLedgerReportScreen(),
    'PeriodScreen': (context) => PeriodScreen(
          onFieldsChanged: () {},
        ),
    'ChartOfAccountsReportScreen': (context) => const ChartOfAccountsReportScreen(),
    'TrialBalanceReportScreen': (context) => const TrialBalanceReportScreen(),
    'DailyTransactionReportScreen': (context) => const DailyTransactionReportScreen(),
    'BalanceSheetReportScreen': (context) => const BalanceSheetReportScreen(),
    'IncomeStatementReportScreen': (context) => const IncomeStatementReportScreen(),
    'FinancialReportBuilderScreen': (context) => const FinancialReportBuilderScreen(),
    'YearEndClosingScreen': (context) => const YearEndClosingScreen(),
    'YearEndClosingConfigScreen': (context) => const YearEndClosingConfigScreen(),
    'GlResetScreen': (context) => const GlResetScreen(),

    'ArCustomerScreen': (context) => ArCustomerScreen(
          onFieldsChanged: () {},
        ),
    'ArCustomerGroupScreen': (context) => ArCustomerGroupScreen(
          onFieldsChanged: () {},
        ),
    'ArCustomerImportScreen': (context) => ArCustomerImportScreen(onFieldsChanged: () {}),
    'ArCustomerBalanceImportScreen': (context) => ArCustomerBalanceImportScreen(onFieldsChanged: () {}),
    'ArCustomerRunningScreen': (context) => const ArCustomerRunningScreen(),
    'ArTransactionScreen': (context) => const ArTransactionScreen(),
    'ArAgingReportScreen': (context) => const ArAgingReportScreen(),
    'ArDueReportScreen':      (context) => const ArDueReportScreen(),
    'ArMovementReportScreen':      (context) => const ArMovementReportScreen(),
    'ArBillingPlanReportScreen':   (context) => const ArBillingPlanReportScreen(),
    'ArBulkBillingScreen':         (context) => const ArBulkBillingScreen(),
    'ArTransactionReportScreen':    (context) => const ArTransactionReportScreen(),
    'ArBillingStatusReportScreen':      (context) => const ArBillingStatusReportScreen(),
    'ArReceiptPaymentReportScreen':    (context) => const ArReceiptPaymentReportScreen(),
    'ArCreditLimitReportScreen':      (context) => const ArCreditLimitReportScreen(),
    'ArCustomerReportScreen':         (context) => const ArCustomerReportScreen(),
    'ArFxGainLossReportScreen':       (context) => const ArFxGainLossReportScreen(),
    'VatReportScreen':        (context) => const VatReportScreen(),
    'ArCollectorScreen': (context) => ArCollectorScreen(onFieldsChanged: () {}),
    'BankScreen': (context) => BankScreen(onFieldsChanged: () {}),
    'CdWhtTypeScreen': (context) => CdWhtTypeScreen(onFieldsChanged: () {}),
    'ArGlAccountSetupScreen': (context) => const ArGlAccountSetupScreen(),
    'ArResetScreen': (context) => const ArResetScreen(),
    'ArYearEndSetupScreen':   (context) => const ArYearEndSetupScreen(),
    'ArPreCloseCheckScreen':  (context) => const ArPreCloseCheckScreen(),
    'ArFxRevaluationScreen':  (context) => const ArFxRevaluationScreen(),
    'ArAllowanceRunScreen':   (context) => const ArAllowanceRunScreen(),

    'CmBankScreen': (context) => CmBankScreen(onFieldsChanged: () {}),
    'CmBankAccountScreen': (context) => CmBankAccountScreen(onFieldsChanged: () {}),
    'CmPaymentMethodScreen': (context) => CmPaymentMethodScreen(onFieldsChanged: () {}),

    'ApVendorScreen': (context) => ApVendorScreen(onFieldsChanged: () {}),
    'ApVendorGroupScreen': (context) => const ApVendorGroupScreen(),
    'ApVendorImportScreen': (context) => ApVendorImportScreen(onFieldsChanged: () {}),
    'ApVendorRunningScreen': (context) => const ApVendorRunningScreen(),
    'ApVendorReportScreen': (context) => const ApVendorReportScreen(),
    'ApTransactionScreen': (context) => const ApTransactionScreen(),
    'ApGlAccountSetupScreen': (context) => const ApGlAccountSetupScreen(),
    'ApPaymentRunScreen': (context) => const ApPaymentRunScreen(),
    'CmBankFileFormatScreen': (context) => const CmBankFileFormatScreen(),
    'SaSmtpConfigScreen':     (context) => const SaSmtpConfigScreen(),
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
    this.children = const [],
    required this.builder,
    this.isSystem = false,
    this.canView = true,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canApprove = false,
    this.canPrint = false,
    this.canExport = false,
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
        children: [],
        builder: screenBuilder,
        isSystem: json['is_system'] ?? false,
        canView: json['can_view'] ?? true,
        canCreate: json['can_create'] ?? false,
        canEdit: json['can_edit'] ?? false,
        canDelete: json['can_delete'] ?? false,
        canApprove: json['can_approve'] ?? false,
        canPrint: json['can_print'] ?? false,
        canExport: json['can_export'] ?? false);
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
