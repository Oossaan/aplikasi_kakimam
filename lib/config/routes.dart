import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../models/outlet_model.dart';
import '../views/splash/splash_page.dart';
import '../views/auth/login_page.dart';
import '../views/dashboard/dashboard_page.dart';
import '../views/inventory/inventory_page.dart';
import '../views/inventory/add_product_page.dart';
import '../views/inventory/stock_adjustment_page.dart';
import '../views/pos/pos_page.dart';
import '../views/pos/receipt_page.dart';
import '../views/reports/stock_report_page.dart';
import '../views/reports/receivables_page.dart';
import '../views/reports/profit_report_page.dart';
import '../views/reports/returns_page.dart';
import '../views/outlet/outlet_management_page.dart';
import '../views/outlet/outlet_stock_history_page.dart';
import '../views/supplier/supplier_management_page.dart';
import '../views/supplier/supplier_stock_history_page.dart';
import '../views/category/category_management_page.dart';
import '../views/invoice/invoice_list_page.dart';
import '../views/invoice/invoice_detail_page.dart';
import '../views/invoice/return_invoice_list_page.dart';
import '../views/settings/settings_page.dart';
import '../views/sales/sales_management_page.dart';
import '../views/sales/sales_history_page.dart';
import '../models/sales_model.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String inventory = '/inventory';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String stockAdjustment = '/stock-adjustment';
  static const String supplierReturn = '/supplier-return';
  static const String pos = '/pos';
  static const String receipt = '/receipt';
  static const String salesReport = '/sales-report';
  static const String stockReport = '/stock-report';
  static const String receivables = '/receivables';
  static const String profitReport = '/profit-report';
  static const String outletManagement = '/outlet-management';
  static const String supplierManagement = '/supplier-management';
  static const String supplierStockHistory = '/supplier-stock-history';
  static const String outletStockHistory = '/outlet-stock-history';
  static const String categoryManagement = '/category-management';
  static const String invoiceList = '/invoice-list';
  static const String invoiceDetail = '/invoice-detail';
static const String returnInvoiceList = '/return-invoice-list';
  static const String returns = '/returns';
  static const String settings = '/settings';
  static const String salesManagement = '/sales-management';
  static const String salesHistory = '/sales-history';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashPage(),
        login: (context) => const LoginPage(),
        dashboard: (context) => const DashboardPage(),
        inventory: (context) => const InventoryPage(),
        addProduct: (context) {
          final product = ModalRoute.of(context)?.settings.arguments as Product?;
          return AddProductPage(product: product);
        },
        editProduct: (context) {
          final product =
              ModalRoute.of(context)?.settings.arguments as Product?;
          return AddProductPage(product: product);
        },
        stockAdjustment: (context) => const StockAdjustmentPage(),
        supplierReturn: (context) => const StockAdjustmentPage(isSupplierReturn: true),
        pos: (context) => const POSPage(),
        receipt: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ReceiptPage(
            invoiceId: args?['invoiceId'] as int?,
            invoiceNumber: args?['invoiceNumber'] as String?,
            transaction: args?['transaction'],
            outletName: args?['outletName'] as String?,
          );
        },
        salesReport: (context) => const ProfitReportPage(),
        stockReport: (context) => const StockReportPage(),
        receivables: (context) => const ReceivablesPage(),
        profitReport: (context) => const ProfitReportPage(),
        outletManagement: (context) => const OutletManagementPage(),
        supplierManagement: (context) => const SupplierManagementPage(),
        supplierStockHistory: (context) {
          final supplier = ModalRoute.of(context)?.settings.arguments as Supplier?;
          return SupplierStockHistoryPage(supplier: supplier!);
        },
        outletStockHistory: (context) {
          final outlet = ModalRoute.of(context)?.settings.arguments as Outlet?;
          return OutletStockHistoryPage(outlet: outlet!);
        },
        categoryManagement: (context) => const CategoryManagementPage(),
        invoiceList: (context) => const InvoiceListPage(),
        invoiceDetail: (context) {
          final invoiceId = ModalRoute.of(context)?.settings.arguments as int?;
          return InvoiceDetailPage(invoiceId: invoiceId);
        },
returnInvoiceList: (context) => const ReturnInvoiceListPage(),
        returns: (context) => const ReturnsPage(),
        settings: (context) => const SettingsPage(),
        salesManagement: (context) => const SalesManagementPage(),
        salesHistory: (context) {
          final sales = ModalRoute.of(context)?.settings.arguments as Sales?;
          return SalesHistoryPage(sales: sales!);
        },
      };
}
