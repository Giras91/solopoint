import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../analytics_repository.dart';
import '../services/pdf_report_service.dart';
import '../../settings/data/printer_service.dart';

/// Screen for exporting reports in various formats
class ReportExportScreen extends ConsumerStatefulWidget {
  const ReportExportScreen({super.key});

  @override
  ConsumerState<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends ConsumerState<ReportExportScreen> {
  ReportType _selectedReportType = ReportType.daily;
  ExportFormat _selectedFormat = ExportFormat.pdf;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Reports'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report type selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Type',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...ReportType.values.map((type) => RadioListTile<ReportType>(
                          title: Text(type.displayName),
                          subtitle: Text(type.description),
                          value: type,
                          groupValue: _selectedReportType,
                          onChanged: (value) {
                            setState(() {
                              _selectedReportType = value!;
                              _updateDateRangeForReportType();
                            });
                          },
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date range selector
            if (_selectedReportType != ReportType.xReport &&
                _selectedReportType != ReportType.zReport)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date Range',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateSelector(
                              'Start Date',
                              _startDate,
                              (date) => setState(() => _startDate = date),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateSelector(
                              'End Date',
                              _endDate,
                              (date) => setState(() => _endDate = date),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Z-Report date selector
            if (_selectedReportType == ReportType.zReport)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Date',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDateSelector(
                        'Date',
                        _startDate,
                        (date) => setState(() => _startDate = date),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Export format selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Format',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ExportFormat.values.map((format) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(format.icon, size: 18),
                                  const SizedBox(width: 8),
                                  Text(format.displayName),
                                ],
                              ),
                              selected: _selectedFormat == format,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedFormat = format);
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateReport,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_selectedFormat.icon),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, Function(DateTime) onDateSelected) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }

  void _updateDateRangeForReportType() {
    final now = DateTime.now();
    switch (_selectedReportType) {
      case ReportType.daily:
        _startDate = now;
        _endDate = now;
        break;
      case ReportType.weekly:
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case ReportType.monthly:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case ReportType.profit:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case ReportType.xReport:
      case ReportType.zReport:
        _startDate = now;
        _endDate = now;
        break;
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final repository = ref.read(analyticsRepositoryProvider);
      final pdfService = PdfReportService();

      switch (_selectedReportType) {
        case ReportType.daily:
          await _generateDailyReport(repository, pdfService);
          break;
        case ReportType.weekly:
          await _generateWeeklyReport(repository, pdfService);
          break;
        case ReportType.monthly:
          await _generateMonthlyReport(repository, pdfService);
          break;
        case ReportType.profit:
          await _generateProfitReport(repository, pdfService);
          break;
        case ReportType.xReport:
          await _generateXReport(repository, pdfService);
          break;
        case ReportType.zReport:
          await _generateZReport(repository, pdfService);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateDailyReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    final summary = await repository.getSalesSummary(_startDate, _endDate);
    final paymentBreakdown = await repository.getPaymentMethodBreakdown(_startDate, _endDate);
    final categoryBreakdown = await repository.getCategorySales(_startDate, _endDate);

    if (_selectedFormat == ExportFormat.pdf) {
      await pdfService.generateDailySalesReport(
        _startDate,
        summary,
        paymentBreakdown,
        categoryBreakdown,
      );
    }
    // Thermal printing disabled - use ThermalPrinterService in settings instead
  }

  Future<void> _generateWeeklyReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    final summary = await repository.getSalesSummary(_startDate, _endDate);
    final dailyBreakdown = await repository.getDailySales(_startDate, _endDate);
    final paymentBreakdown = await repository.getPaymentMethodBreakdown(_startDate, _endDate);
    final categoryBreakdown = await repository.getCategorySales(_startDate, _endDate);

    await pdfService.generateWeeklySalesReport(
      _startDate,
      _endDate,
      summary,
      dailyBreakdown,
      paymentBreakdown,
      categoryBreakdown,
    );
  }

  Future<void> _generateMonthlyReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    final summary = await repository.getSalesSummary(_startDate, _endDate);
    final dailyBreakdown = await repository.getDailySales(_startDate, _endDate);
    final paymentBreakdown = await repository.getPaymentMethodBreakdown(_startDate, _endDate);
    final categoryBreakdown = await repository.getCategorySales(_startDate, _endDate);
    final topProducts = await repository.getTopSellingProducts(_startDate, _endDate);

    await pdfService.generateMonthlySalesReport(
      _startDate,
      summary,
      dailyBreakdown,
      paymentBreakdown,
      categoryBreakdown,
      topProducts,
    );
  }

  Future<void> _generateProfitReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    if (_selectedFormat == ExportFormat.thermal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profit report is only available in PDF format.')),
        );
      }
      return;
    }

    final summary = await repository.getProfitSummary(_startDate, _endDate);
    final categoryProfit = await repository.getProfitByCategory(_startDate, _endDate);
    final topProducts = await repository.getTopProfitProducts(_startDate, _endDate, limit: 10);

    await pdfService.generateProfitReport(
      _startDate,
      _endDate,
      summary,
      categoryProfit,
      topProducts,
    );
  }

  Future<void> _generateXReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    final xReportData = await repository.getXReport();

    if (_selectedFormat == ExportFormat.pdf) {
      await pdfService.generateXReport(xReportData);
    }
    // Thermal printing disabled - use ThermalPrinterService in settings instead
  }

  Future<void> _generateZReport(
    AnalyticsRepository repository,
    PdfReportService pdfService,
  ) async {
    final zReportData = await repository.getZReport(_startDate);

    if (_selectedFormat == ExportFormat.pdf) {
      await pdfService.generateZReport(zReportData);
    }
    // Thermal printing disabled - use ThermalPrinterService in settings instead
  }
}

// ============== ENUMS ==============

enum ReportType {
  daily,
  weekly,
  monthly,
  profit,
  xReport,
  zReport;

  String get displayName {
    switch (this) {
      case ReportType.daily:
        return 'Daily Sales Report';
      case ReportType.weekly:
        return 'Weekly Sales Report';
      case ReportType.monthly:
        return 'Monthly Sales Report';
      case ReportType.profit:
        return 'Profit Report';
      case ReportType.xReport:
        return 'X-Report (Current Shift)';
      case ReportType.zReport:
        return 'Z-Report (End of Day)';
    }
  }

  String get description {
    switch (this) {
      case ReportType.daily:
        return 'Sales summary for a single day';
      case ReportType.weekly:
        return 'Sales summary for a week with daily breakdown';
      case ReportType.monthly:
        return 'Sales summary for a month with top products';
      case ReportType.profit:
        return 'Revenue, cost, and profit by category';
      case ReportType.xReport:
        return 'Current shift sales without closing register';
      case ReportType.zReport:
        return 'End of day sales with register closure';
    }
  }
}

enum ExportFormat {
  pdf,
  thermal;

  String get displayName {
    switch (this) {
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.thermal:
        return 'Thermal';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.pdf:
        return Icons.picture_as_pdf;
      case ExportFormat.thermal:
        return Icons.print;
    }
  }
}
