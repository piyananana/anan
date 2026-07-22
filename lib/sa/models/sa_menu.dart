import 'package:flutter/material.dart';

import '../screens/sa_backup_screen.dart';
import '../screens/sa_company_profile_screen.dart';
import '../screens/sa_group_management_screen.dart';
import '../screens/sa_group_menu_management_screen.dart';
import '../screens/sa_group_user_management_screen.dart';
import '../screens/sa_menu_screen.dart';
import '../screens/sa_module_document_screen.dart';
import '../screens/sa_password_policy_screen.dart';
import '../screens/sa_doc_number_branch_setup_screen.dart';
import '../screens/sa_doc_number_reset_screen.dart';
import '../screens/sa_module_approver_screen.dart';
import '../screens/sa_user_document_screen.dart';
import '../screens/sa_user_menu_screen.dart';
import '../screens/sa_user_screen.dart';

import '../../cd/screens/cd_branch_screen.dart';
import '../../cd/screens/cd_business_type_screen.dart';
import '../../cd/screens/cd_currency_screen.dart';
import '../../cd/screens/cd_zipcode_screen.dart';
import '../../cd/screens/cd_vat_rate_screen.dart';
import '../../cd/screens/cd_bank_screen.dart';
import '../../cd/screens/cd_sales_territory_screen.dart';
import '../../cd/screens/cd_salesperson_screen.dart';
import '../../cd/screens/cd_wht_type_screen.dart';

import '../../gl/screens/gl_account_screen.dart';
import '../../gl/screens/gl_account_import_screen.dart';
import '../../gl/screens/gl_opening_balance_import_screen.dart';
import '../../gl/screens/gl_chart_of_accounts_report_screen.dart';
import '../../gl/screens/gl_financial_report_builder_screen.dart';
import '../../gl/screens/gl_entry_screen.dart';
import '../../gl/screens/gl_financial_report_screen.dart';
import '../../gl/screens/gl_general_ledger_report_screen.dart';
import '../../gl/screens/gl_period_screen.dart';
import '../../gl/screens/gl_trial_balance_report_screen.dart';
import '../../gl/screens/gl_balance_sheet_report_screen.dart';
import '../../gl/screens/gl_income_statement_report_screen.dart';
import '../../gl/screens/gl_daily_transaction_report_screen.dart';
import '../../gl/screens/gl_year_end_closing_screen.dart';
import '../../gl/screens/gl_year_end_closing_config_screen.dart';
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
import '../../vt/screens/vt_vat_report_screen.dart';
import '../../ar/screens/ar_collector_screen.dart';
import '../../ar/screens/ar_gl_account_setup_screen.dart';
import '../../ar/screens/ar_reset_screen.dart';
import '../../ar/screens/ar_year_end_setup_screen.dart';
import '../../ar/screens/ar_pre_close_check_screen.dart';
import '../../ar/screens/ar_fx_revaluation_screen.dart';
import '../../ar/screens/ar_allowance_run_screen.dart';

import '../../cm/screens/cm_bank_account_screen.dart';
import '../../cm/screens/cm_payment_method_screen.dart';
import '../../cm/screens/cm_checkbook_screen.dart';
import '../../cm/screens/cm_receipt_screen.dart';
import '../../cm/screens/cm_payment_screen.dart';
import '../../cm/screens/cm_petty_cash_screen.dart';
import '../../cm/screens/cm_bank_statement_screen.dart';
import '../../cm/screens/cm_bank_reconcile_screen.dart';
import '../../cm/screens/cm_bank_fx_revaluation_screen.dart';
import '../../cm/screens/cm_cash_position_screen.dart';
import '../../cm/screens/cm_bank_transaction_report_screen.dart';
import '../../cm/screens/cm_check_register_screen.dart';
import '../../cm/screens/cm_inter_bank_transfer_screen.dart';
import '../../cm/screens/cm_gl_account_setup_screen.dart';
import '../../cm/screens/cm_pre_close_check_screen.dart';
import '../../cm/screens/cm_reset_screen.dart';
import '../../cm/screens/cm_bank_gl_reconcile_report_screen.dart';
import '../../cm/screens/cm_dashboard_screen.dart';
import '../../cm/screens/cm_year_end_screen.dart';
import '../../cm/screens/cm_check_print_screen.dart';
import '../../cm/screens/cm_check_print_config_screen.dart';
import '../../cm/screens/cm_bank_opening_balance_screen.dart';
import '../../cm/screens/cm_fx_gain_loss_report_screen.dart';
import '../../cm/screens/cm_cash_flow_statement_screen.dart';
import '../../cm/screens/cm_petty_cash_replenishment_screen.dart';
import '../../cm/screens/cm_bank_file_export_screen.dart';
import '../../cm/screens/cm_doc_number_screen.dart';
import '../../cm/screens/cm_bank_statement_import_screen.dart';
import '../../cm/screens/cm_post_dated_check_screen.dart';
import '../../cm/screens/cm_bank_charge_screen.dart';

import '../../ap/screens/ap_vendor_screen.dart';
import '../../ap/screens/ap_vendor_group_screen.dart';
import '../../ap/screens/ap_vendor_import_screen.dart';
import '../../ap/screens/ap_vendor_balance_import_screen.dart';
import '../../ap/screens/ap_vendor_running_screen.dart';
import '../../ap/screens/ap_reset_screen.dart';
import '../../ap/screens/ap_vendor_report_screen.dart';
import '../../ap/screens/ap_wht_report_screen.dart';
import '../../ap/screens/ap_transaction_screen.dart';
import '../../ap/screens/ap_gl_account_setup_screen.dart';
import '../../ap/screens/ap_payment_run_screen.dart';
import '../../ap/screens/ap_aging_report_screen.dart';
import '../../ap/screens/ap_due_report_screen.dart';
import '../../ap/screens/ap_fx_gain_loss_report_screen.dart';
import '../../ap/screens/ap_movement_report_screen.dart';
import '../../ap/screens/ap_payment_report_screen.dart';
import '../../ap/screens/ap_transaction_report_screen.dart';
import '../../ap/screens/ap_credit_limit_report_screen.dart';
import '../../ap/screens/ap_year_end_setup_screen.dart';
import '../../ap/screens/ap_pre_close_check_screen.dart';
import '../../ap/screens/ap_fx_revaluation_screen.dart';
import '../../ap/screens/ap_remittance_advice_screen.dart';
import '../../ap/screens/ap_bulk_payment_screen.dart';
import '../../cm/screens/cm_bank_file_format_screen.dart';
import '../screens/sa_smtp_config_screen.dart';
import '../screens/sa_user_audit_log_screen.dart';
import '../screens/sa_audit_log_reset_screen.dart';

class Menu {
  final int id;
  final int? parentId;
  final String menuName;
  final String menuNameEn;
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
    'CurrencyScreen': (context) => CurrencyScreen(
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

    'CmBankScreen': (context) => BankScreen(onFieldsChanged: () {}),
    'CmBankAccountScreen': (context) => CmBankAccountScreen(onFieldsChanged: () {}),
    'CmPaymentMethodScreen': (context) => CmPaymentMethodScreen(onFieldsChanged: () {}),
    'CmCheckbookScreen': (context) => const CmCheckbookScreen(),
    'CmReceiptScreen':    (context) => const CmReceiptScreen(),
    'CmPaymentScreen':    (context) => const CmPaymentScreen(),
    'CmPettyCashScreen':       (context) => const CmPettyCashScreen(),
    'CmBankStatementScreen':         (context) => const CmBankStatementScreen(),
    'CmBankReconcileScreen':         (context) => const CmBankReconcileScreen(),
    'CmBankFxRevaluationScreen':     (context) => const CmBankFxRevaluationScreen(),
    'CmCashPositionScreen':          (context) => const CmCashPositionScreen(),
    'CmBankTransactionReportScreen': (context) => const CmBankTransactionReportScreen(),
    'CmCheckRegisterScreen':         (context) => const CmCheckRegisterScreen(),
    'CmInterBankTransferScreen':         (context) => const CmInterBankTransferScreen(),
    'CmGlAccountSetupScreen':            (context) => const CmGlAccountSetupScreen(),
    'CmPreCloseCheckScreen':             (context) => const CmPreCloseCheckScreen(),
    'CmResetScreen':                     (context) => const CmResetScreen(),
    'CmBankGlReconcileReportScreen':     (context) => const CmBankGlReconcileReportScreen(),
    'CmDashboardScreen':                 (context) => const CmDashboardScreen(),
    'CmYearEndScreen':                   (context) => const CmYearEndScreen(),
    'CmCheckPrintScreen':                (context) => const CmCheckPrintScreen(),
    'CmCheckPrintConfigScreen':          (context) => const CmCheckPrintConfigScreen(),
    'CmBankOpeningBalanceScreen':        (context) => const CmBankOpeningBalanceScreen(),
    'CmFxGainLossReportScreen':          (context) => const CmFxGainLossReportScreen(),
    'CmCashFlowStatementScreen':         (context) => const CmCashFlowStatementScreen(),
    'CmPettyCashReplenishmentScreen':    (context) => const CmPettyCashReplenishmentScreen(),
    'CmBankFileExportScreen':            (context) => const CmBankFileExportScreen(),
    'CmDocNumberScreen':                 (context) => const CmDocNumberScreen(),
    'CmBankStatementImportScreen':       (context) => const CmBankStatementImportScreen(),
    'CmPostDatedCheckScreen':            (context) => const CmPostDatedCheckScreen(),
    'CmBankChargeScreen':                (context) => const CmBankChargeScreen(),

    'ApVendorScreen': (context) => ApVendorScreen(onFieldsChanged: () {}),
    'ApVendorGroupScreen': (context) => const ApVendorGroupScreen(),
    'ApVendorImportScreen': (context) => ApVendorImportScreen(onFieldsChanged: () {}),
    'ApVendorBalanceImportScreen': (context) => ApVendorBalanceImportScreen(onFieldsChanged: () {}),
    'ApResetScreen': (context) => const ApResetScreen(),
    'ApVendorRunningScreen': (context) => const ApVendorRunningScreen(),
    'ApVendorReportScreen': (context) => const ApVendorReportScreen(),
    'ApWhtReportScreen':   (context) => const ApWhtReportScreen(),
    'ApTransactionScreen': (context) => const ApTransactionScreen(),
    'ApGlAccountSetupScreen': (context) => const ApGlAccountSetupScreen(),
    'ApPaymentRunScreen': (context) => const ApPaymentRunScreen(),
    'ApAgingReportScreen':       (context) => const ApAgingReportScreen(),
    'ApDueReportScreen':         (context) => const ApDueReportScreen(),
    'ApFxGainLossReportScreen':  (context) => const ApFxGainLossReportScreen(),
    'ApMovementReportScreen':    (context) => const ApMovementReportScreen(),
    'ApPaymentReportScreen':     (context) => const ApPaymentReportScreen(),
    'ApTransactionReportScreen':  (context) => const ApTransactionReportScreen(),
    'ApCreditLimitReportScreen': (context) => const ApCreditLimitReportScreen(),
    'ApYearEndSetupScreen':     (context) => const ApYearEndSetupScreen(),
    'ApPreCloseCheckScreen':    (context) => const ApPreCloseCheckScreen(),
    'ApFxRevaluationScreen':    (context) => const ApFxRevaluationScreen(),
    'ApRemittanceAdviceScreen': (context) => const ApRemittanceAdviceScreen(),
    'ApBulkPaymentScreen':      (context) => const ApBulkPaymentScreen(),
    'CmBankFileFormatScreen': (context) => const CmBankFileFormatScreen(),
    'SaSmtpConfigScreen':        (context) => const SaSmtpConfigScreen(),
    'SaUserAuditLogScreen':      (context) => const SaUserAuditLogScreen(),
    'SaAuditLogResetScreen':     (context) => const SaAuditLogResetScreen(),
    // 'PeriodScreen': (context) => const PeriodScreen(),
    // Add all your custom widgets here
    // 'YourCustomWidget1': (context) => const YourCustomWidget1(),
    // 'YourCustomWidget2': (context) => const YourCustomWidget2(),
  };

  String localName(bool isEnglish) =>
      isEnglish && menuNameEn.isNotEmpty ? menuNameEn : menuName;

  Menu({
    required this.id,
    this.parentId,
    required this.menuName,
    this.menuNameEn = '',
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
        menuName: json['menu_name'] ?? '',
        menuNameEn: json['menu_name_en'] ?? '',
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
