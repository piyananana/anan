import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// แทนตัวแปรที่ engine คืนมาใน reportData['variables'] เช่น $periodEndDate, $amountUnit, $branchName
/// (ชื่อยาวก่อน เพื่อไม่ให้ $period ไปแทนส่วนหน้าของ $periodEndDate)
String finReportApplyVariables(String text, Map<String, dynamic>? reportData) {
  final vars = reportData?['variables'];
  if (vars is! Map || !text.contains(r'$')) return text;
  final keys = vars.keys.map((k) => k.toString()).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    text = text.replaceAll('\$$k', vars[k]?.toString() ?? '');
  }
  return text;
}

/// ตัวแปรที่ใช้ในข้อความของงบได้ (ชื่อบรรทัด, หัวคอลัมน์, ข้อความในบรรทัดหัว/ท้ายงบ)
List<(String, String, String)> finReportVariableHelp() => const [
      (r'$companyName', 'ชื่อบริษัท', 'Company name'),
      (r'$reportName', 'ชื่องบ', 'Report name'),
      (r'$periodName', 'ชื่องวดที่เลือก', 'Selected period name'),
      (r'$fiscalYear', 'ปีบัญชี', 'Fiscal year'),
      (r'$periodStartDate', 'วันเริ่มงวด', 'Period start date'),
      (r'$periodEndDate', 'วันสิ้นงวด เช่น 31 ธันวาคม 2569', 'Period end date, e.g. 31 December 2026'),
      (r'$yearStartDate', 'วันเริ่มปีบัญชี', 'Fiscal year start date'),
      (r'$amountUnit', 'หน่วยจำนวนเงิน (บาท/พันบาท/ล้านบาท)', 'Amount unit (Baht/Thousand/Million)'),
      (r'$branchName', 'สาขาที่กรอง (หรือ "ทุกสาขา")', 'Filtered branch (or "All branches")'),
      (r'$userName', 'ผู้พิมพ์', 'Printed by'),
      (r'$printDate', 'วันเวลาที่พิมพ์', 'Print date/time'),
      (r'$pageNumber / $pageCount', 'เลขหน้า / จำนวนหน้า (PDF)', 'Page number / count (PDF)'),
      (r'$colPeriodName', 'หัวคอลัมน์: ชื่องวดของคอลัมน์', 'Column header: column period name'),
      (r'$colPeriodEndDate', 'หัวคอลัมน์: วันสิ้นงวดของคอลัมน์', 'Column header: column period end date'),
      (r'$colPeriodStartDate', 'หัวคอลัมน์: วันเริ่มช่วงของคอลัมน์', 'Column header: column range start date'),
      (r'$colFiscalYear', 'หัวคอลัมน์: ปีบัญชีของคอลัมน์', 'Column header: column fiscal year'),
    ];

/// แสดงผลงบการเงินจาก engine (/gl_financial_report_engine) เป็นตาราง
/// ใช้ร่วมกันระหว่างหน้าดูงบ (gl_financial_report_screen) และตัวอย่างในหน้าออกแบบ
class FinReportTableView extends StatelessWidget {
  final Map<String, dynamic> reportData;

  /// แทนตัวแปรในช่องข้อความ เช่น $companyName, $periodName
  final String Function(String text) resolveText;
  final EdgeInsetsGeometry padding;
  final double fontScale;

  /// คลิกช่องตัวเลขที่แตกยอดได้ (cell['drill'] == true) — null = ไม่เปิดให้คลิก
  final void Function(Map<String, dynamic> row, Map<String, dynamic> cell)? onDrill;
  final String drillTooltip;
  /// ข้อความบนเส้นแบ่งหน้า (บรรทัดที่ตั้งขึ้นหน้าใหม่ก่อนพิมพ์)
  final String pageBreakLabel;

  const FinReportTableView({
    super.key,
    required this.reportData,
    required this.resolveText,
    this.padding = const EdgeInsets.all(16.0),
    this.fontScale = 1.0,
    this.onDrill,
    this.drillTooltip = '',
    this.pageBreakLabel = 'ขึ้นหน้าใหม่',
  });

  /// รูปแบบตัวเลขตามจำนวนทศนิยมของงบ (decimal_places) — ใช้ร่วมกับ PDF/Excel ของหน้าดูงบ
  static NumberFormat numberFormat(Map<String, dynamic>? reportData) {
    final int decimals = (reportData?['decimal_places'] as num?)?.toInt() ?? 2;
    return NumberFormat(decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0', 'en_US');
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> rows = reportData['data'] ?? [];
    // ยอดถูกหารหน่วย (พันบาท/ล้านบาท) มาจาก engine แล้ว ที่นี่จัดรูปแบบทศนิยมอย่างเดียว
    final NumberFormat currencyFormat = numberFormat(reportData);
    final String zeroText = currencyFormat.format(0);

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
          final rowWidget = Padding(
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
                  final String absText = currencyFormat.format(val.abs());
                  if (absText == zeroText) {
                    // ศูนย์ หรือปัดตามทศนิยมแล้วเป็นศูนย์ (เช่น 0.3 พันบาท แสดง 0 ตำแหน่ง)
                    displayVal = '-';
                  } else if (val < 0 && useParenthesis) {
                    // ครอบวงเล็บสำหรับค่าติดลบ
                    displayVal = '($absText)';
                  } else {
                    displayVal = val < 0 ? '-$absText' : absText;
                  }
                }

                TextAlign align = TextAlign.left;
                if (style['textAlign'] == 'CENTER') align = TextAlign.center;
                if (style['textAlign'] == 'RIGHT') align = TextAlign.right;

                // บรรทัดหัวงบ/ท้ายงบใช้ตัวหนาตามที่ตั้งในบรรทัด (engine ส่งมาใน style) เหมือน PDF
                final FontWeight weight = style['fontWeight'] == 'BOLD' ? FontWeight.bold : FontWeight.normal;

                final bool canDrill = onDrill != null && col['drill'] == true && col['error'] == null;
                Widget text = Text(
                  displayVal,
                  textAlign: align,
                  style: TextStyle(
                    fontSize: (style['fontSize'] ?? 11).toDouble() * fontScale,
                    fontWeight: weight,
                    color: col['error'] != null ? Colors.red : (canDrill ? Colors.blue.shade900 : null),
                  ),
                );
                if (canDrill) {
                  text = Tooltip(
                    message: drillTooltip,
                    waitDuration: const Duration(milliseconds: 600),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onDrill!(Map<String, dynamic>.from(row), Map<String, dynamic>.from(col)),
                        child: text,
                      ),
                    ),
                  );
                }

                return Expanded(
                  flex: flex,
                  child: Padding(
                    padding: EdgeInsets.only(left: indent * 20.0 * fontScale),
                    child: text,
                  ),
                );
              }).toList().cast<Widget>(),
            ),
          );
          // บรรทัดที่ขึ้นหน้าใหม่ใน PDF (page_break_before) — แสดงเส้นแบ่งหน้าให้เห็นในตาราง
          if (index == 0 || row['page_break_before'] != true) return rowWidget;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade400, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(pageBreakLabel, style: TextStyle(fontSize: 10 * fontScale, color: Colors.grey.shade600)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade400, height: 1)),
              ]),
            ),
            rowWidget,
          ]);
        },
      ),
    );
  }
}
