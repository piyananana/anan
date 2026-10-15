import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// แสดงผลงบการเงินจาก engine (/gl_financial_report_engine) เป็นตาราง
/// ใช้ร่วมกันระหว่างหน้าดูงบ (gl_financial_report_screen) และตัวอย่างในหน้าออกแบบ
class FinReportTableView extends StatelessWidget {
  final Map<String, dynamic> reportData;

  /// แทนตัวแปรในช่องข้อความ เช่น $companyName, $periodName
  final String Function(String text) resolveText;
  final EdgeInsetsGeometry padding;
  final double fontScale;

  FinReportTableView({
    super.key,
    required this.reportData,
    required this.resolveText,
    this.padding = const EdgeInsets.all(16.0),
    this.fontScale = 1.0,
  });

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final List<dynamic> rows = reportData['data'] ?? [];

    // ดึงค่าตั้งค่าการแสดงผลวงเล็บ
    final bool useParenthesis = reportData['parenthesis_for_minus'] ?? true;

    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: padding,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final List<dynamic> cols = row['columns'] ?? [];
          final bool isHeaderOrFooter = row['row_type'] == 'HEADER' || row['row_type'] == 'FOOTER';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cols.map((col) {
                final int flex = col['flex'] ?? 1;
                final String type = col['type'] ?? 'TEXT';
                final String dataType = col['data_type']?.toString() ?? '-';
                final style = col['style'] ?? {};
                final dynamic rawValue = col['value'];

                final int indent = int.tryParse(col['indent_level']?.toString() ?? '0') ?? 0;

                if (type == 'DIVIDER') {
                  return Expanded(
                    flex: flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: dataType == '='
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(thickness: 0.5, color: Colors.black87, height: 0.5),
                              SizedBox(height: 0.5),
                              Divider(thickness: 2, color: Colors.black87, height: 2),
                            ],
                          )
                        : const Divider(thickness: 1, color: Colors.black87, height: 2),
                    ),
                  );
                }

                String displayVal = "";
                if (type == 'TEXT') {
                  displayVal = resolveText(rawValue?.toString() ?? "");
                } else if (col['error'] != null) {
                  displayVal = '#ERR';
                } else {
                  // จัดการตัวเลขและการแสดงผลค่าติดลบ
                  double val = double.tryParse(rawValue?.toString() ?? '0') ?? 0;
                  if (val == 0) {
                    displayVal = '-';
                  } else if (val < 0 && useParenthesis) {
                    // ครอบวงเล็บสำหรับค่าติดลบ
                    displayVal = '(${_currencyFormat.format(val.abs())})';
                  } else {
                    displayVal = _currencyFormat.format(val);
                  }
                }

                TextAlign align = TextAlign.left;
                if (style['textAlign'] == 'CENTER') align = TextAlign.center;
                if (style['textAlign'] == 'RIGHT') align = TextAlign.right;

                FontWeight weight = (style['fontWeight'] == 'BOLD' || isHeaderOrFooter)
                    ? FontWeight.bold
                    : FontWeight.normal;

                return Expanded(
                  flex: flex,
                  child: Padding(
                    padding: EdgeInsets.only(left: indent * 20.0 * fontScale),
                    child: Text(
                      displayVal,
                      textAlign: align,
                      style: TextStyle(
                        fontSize: (style['fontSize'] ?? 11).toDouble() * fontScale,
                        fontWeight: weight,
                        color: col['error'] != null ? Colors.red : null,
                      ),
                    ),
                  ),
                );
              }).toList().cast<Widget>(),
            ),
          );
        },
      ),
    );
  }
}
