import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../analytics_repository.dart';

class ProfitAnalyticsScreen extends ConsumerStatefulWidget {
  const ProfitAnalyticsScreen({super.key});

  @override
  ConsumerState<ProfitAnalyticsScreen> createState() => _ProfitAnalyticsScreenState();
}

class _ProfitAnalyticsScreenState extends ConsumerState<ProfitAnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final currencyFormat = NumberFormat.currency(symbol: 'RM', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDateRangePicker,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeCard(),
            const SizedBox(height: 16),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildProfitTrendChart(),
            const SizedBox(height: 24),
            _buildCategoryProfitChart(),
            const SizedBox(height: 24),
            _buildTopProfitProducts(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeCard() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.date_range, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Change'),
              onPressed: _showDateRangePicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<ProfitSummary>(
      future: ref.read(analyticsRepositoryProvider).getProfitSummary(_startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final summary = snapshot.data!;

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Revenue',
                currencyFormat.format(summary.totalRevenue),
                Icons.trending_up,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Cost',
                currencyFormat.format(summary.totalCost),
                Icons.shopping_cart,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Profit',
                currencyFormat.format(summary.totalProfit),
                Icons.attach_money,
                summary.totalProfit >= 0 ? Colors.green : Colors.red,
                subtitle: '${summary.marginPercent.toStringAsFixed(1)}% margin',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfitTrendChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ProfitTrend>>(
              future: ref.read(analyticsRepositoryProvider).getProfitTrend(_startDate, _endDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: Text('No data available')),
                  );
                }

                final trend = snapshot.data!;
                return SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                currencyFormat.format(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= trend.length) return const Text('');
                              final date = trend[value.toInt()].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MM/dd').format(date),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.profit))
                              .toList(),
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryProfitChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<CategoryProfit>>(
              future: ref.read(analyticsRepositoryProvider).getProfitByCategory(_startDate, _endDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: Text('No data available')),
                  );
                }

                final categories = snapshot.data!;
                final maxProfit = categories.first.profit;

                return SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxProfit * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${categories[groupIndex].categoryName}\n${currencyFormat.format(rod.toY)}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                currencyFormat.format(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= categories.length) return const Text('');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  categories[value.toInt()].categoryName,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      barGroups: categories
                          .asMap()
                          .entries
                          .map((e) => BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.profit,
                                    color: e.value.profit >= 0 ? Colors.green : Colors.red,
                                    width: 20,
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProfitProducts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products by Profit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ProductProfit>>(
              future: ref.read(analyticsRepositoryProvider).getTopProfitProducts(_startDate, _endDate, limit: 10),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Text('No data available')),
                  );
                }

                final products = snapshot.data!;

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      dense: true,
                      title: Text(product.productName),
                      subtitle: Text('Revenue: ${currencyFormat.format(product.revenue)}  •  Cost: ${currencyFormat.format(product.cost)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(product.profit),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: product.profit >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          Text(
                            '${product.marginPercent.toStringAsFixed(1)}% margin',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}
