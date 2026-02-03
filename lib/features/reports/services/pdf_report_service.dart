import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../analytics_repository.dart';

/// Service for generating PDF reports
class PdfReportService {
  final currencyFormat = NumberFormat.currency(symbol: 'RM', decimalDigits: 2);
  final dateFormat = DateFormat('MMM dd, yyyy');
  final dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

  // ============== SALES REPORTS ==============

  /// Generate daily sales report PDF
  Future<void> generateDailySalesReport(
    DateTime date,
    SalesSummary summary,
    List<PaymentMethodStat> paymentBreakdown,
    List<CategorySales> categoryBreakdown,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('Daily Sales Report', date),
          pw.SizedBox(height: 20),
          _buildSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildPaymentBreakdownSection(paymentBreakdown),
          pw.SizedBox(height: 20),
          _buildCategoryBreakdownSection(categoryBreakdown),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Generate weekly sales report PDF
  Future<void> generateWeeklySalesReport(
    DateTime startDate,
    DateTime endDate,
    SalesSummary summary,
    List<DailySales> dailyBreakdown,
    List<PaymentMethodStat> paymentBreakdown,
    List<CategorySales> categoryBreakdown,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('Weekly Sales Report', startDate, endDate: endDate),
          pw.SizedBox(height: 20),
          _buildSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildDailyBreakdownSection(dailyBreakdown),
          pw.SizedBox(height: 20),
          _buildPaymentBreakdownSection(paymentBreakdown),
          pw.SizedBox(height: 20),
          _buildCategoryBreakdownSection(categoryBreakdown),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Generate monthly sales report PDF
  Future<void> generateMonthlySalesReport(
    DateTime month,
    SalesSummary summary,
    List<DailySales> dailyBreakdown,
    List<PaymentMethodStat> paymentBreakdown,
    List<CategorySales> categoryBreakdown,
    List<ProductSales> topProducts,
  ) async {
    final pdf = pw.Document();
    final monthFormat = DateFormat('MMMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Monthly Sales Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(monthFormat.format(month), style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          _buildSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildDailyBreakdownSection(dailyBreakdown),
          pw.SizedBox(height: 20),
          _buildPaymentBreakdownSection(paymentBreakdown),
          pw.SizedBox(height: 20),
          _buildCategoryBreakdownSection(categoryBreakdown),
          pw.SizedBox(height: 20),
          _buildTopProductsSection(topProducts),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Generate profit report PDF
  Future<void> generateProfitReport(
    DateTime startDate,
    DateTime endDate,
    ProfitSummary summary,
    List<CategoryProfit> categoryProfit,
    List<ProductProfit> topProducts,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('Profit Report', startDate, endDate: endDate),
          pw.SizedBox(height: 20),
          _buildProfitSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildProfitByCategorySection(categoryProfit),
          pw.SizedBox(height: 20),
          _buildTopProfitProductsSection(topProducts),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ============== X/Z REPORTS ==============

  /// Generate X-Report (current shift without reset)
  Future<void> generateXReport(XReportData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'X-REPORT (Current Shift)',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generated: ${dateTimeFormat.format(data.reportDate)}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            _buildSummarySection(data.summary),
            pw.SizedBox(height: 20),
            _buildPaymentBreakdownSection(data.paymentBreakdown),
            pw.SizedBox(height: 20),
            _buildCategoryBreakdownSection(data.categoryBreakdown),
            pw.SizedBox(height: 20),
            pw.Text(
              'Note: This is a current shift report. Register remains open.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            _buildFooter(),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Generate Z-Report (end of day with reset)
  Future<void> generateZReport(ZReportData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Z-REPORT (End of Day)',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Date: ${dateFormat.format(data.reportDate)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Generated: ${dateTimeFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 20),
          _buildSummarySection(data.summary),
          pw.SizedBox(height: 20),
          _buildPaymentBreakdownSection(data.paymentBreakdown),
          pw.SizedBox(height: 20),
          _buildCategoryBreakdownSection(data.categoryBreakdown),
          pw.SizedBox(height: 20),
          _buildTopProductsSection(data.topProducts),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red, width: 2),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              'This is an end-of-day report. Register closed for reconciliation.',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ============== COMPONENT BUILDERS ==============

  pw.Widget _buildHeader(String title, DateTime date, {DateTime? endDate}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          endDate != null
              ? '${dateFormat.format(date)} - ${dateFormat.format(endDate)}'
              : dateFormat.format(date),
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildSummarySection(SalesSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sales Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Metric', 'Value'],
            ['Total Sales', currencyFormat.format(summary.totalSales)],
            ['Total Orders', summary.totalOrders.toString()],
            ['Average Order Value', currencyFormat.format(summary.averageOrderValue)],
            ['Subtotal', currencyFormat.format(summary.subtotal)],
            ['Total Discount', currencyFormat.format(summary.totalDiscount)],
            ['Total Tax', currencyFormat.format(summary.totalTax)],
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPaymentBreakdownSection(List<PaymentMethodStat> paymentBreakdown) {
    if (paymentBreakdown.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment Method Breakdown',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Payment Method', 'Transactions', 'Amount'],
            ...paymentBreakdown.map((stat) => [
                  stat.method,
                  stat.count.toString(),
                  currencyFormat.format(stat.amount),
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCategoryBreakdownSection(List<CategorySales> categoryBreakdown) {
    if (categoryBreakdown.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Breakdown',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Category', 'Items Sold', 'Total Sales'],
            ...categoryBreakdown.map((cat) => [
                  cat.categoryName,
                  cat.itemCount.toString(),
                  currencyFormat.format(cat.totalSales),
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDailyBreakdownSection(List<DailySales> dailyBreakdown) {
    if (dailyBreakdown.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daily Breakdown',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Date', 'Orders', 'Sales'],
            ...dailyBreakdown.map((day) => [
                  dateFormat.format(day.date),
                  day.orderCount.toString(),
                  currencyFormat.format(day.sales),
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTopProductsSection(List<ProductSales> topProducts) {
    if (topProducts.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Selling Products',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Product', 'Quantity', 'Sales'],
            ...topProducts.map((product) => [
                  product.productName,
                  product.quantitySold.toStringAsFixed(1),
                  currencyFormat.format(product.totalSales),
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildProfitSummarySection(ProfitSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Profit Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Metric', 'Value'],
            ['Total Revenue', currencyFormat.format(summary.totalRevenue)],
            ['Total Cost', currencyFormat.format(summary.totalCost)],
            ['Total Profit', currencyFormat.format(summary.totalProfit)],
            ['Profit Margin', '${summary.marginPercent.toStringAsFixed(2)}%'],
          ],
        ),
      ],
    );
  }

  pw.Widget _buildProfitByCategorySection(List<CategoryProfit> categoryProfit) {
    if (categoryProfit.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Profit by Category',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Category', 'Revenue', 'Cost', 'Profit', 'Margin'],
            ...categoryProfit.map((cat) => [
                  cat.categoryName,
                  currencyFormat.format(cat.revenue),
                  currencyFormat.format(cat.cost),
                  currencyFormat.format(cat.profit),
                  '${cat.marginPercent.toStringAsFixed(2)}%',
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTopProfitProductsSection(List<ProductProfit> topProducts) {
    if (topProducts.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Products by Profit',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 30,
          data: [
            ['Product', 'Revenue', 'Cost', 'Profit', 'Margin'],
            ...topProducts.map((product) => [
                  product.productName,
                  currencyFormat.format(product.revenue),
                  currencyFormat.format(product.cost),
                  currencyFormat.format(product.profit),
                  '${product.marginPercent.toStringAsFixed(2)}%',
                ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.Text(
          'Generated by SoloPoint POS System',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          'Report generated on ${dateTimeFormat.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
