import 'package:flutter/material.dart';

class ResizableSplitter extends StatefulWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double? initialSplitRatio; // 0.0 to 1.0

  const ResizableSplitter({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.initialSplitRatio, // เริ่มต้น 30% สำหรับซ้าย
  });

  @override
  ResizableSplitterState createState() => ResizableSplitterState();
}

class ResizableSplitterState extends State<ResizableSplitter> {
  late double _splitRatio;
  double _initialSplitRatio = 0.0;
  double _initialDragX = 0.0;

  @override
  void initState() {
    super.initState();
    _splitRatio = widget.initialSplitRatio ?? 0.3; // กำหนดค่าเริ่มต้นเป็น 30% ถ้าไม่ระบุ
  }

  void _onPanStart(DragStartDetails details) {
    _initialDragX = details.globalPosition.dx;
    _initialSplitRatio = _splitRatio;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      final double deltaX = details.globalPosition.dx - _initialDragX;
      final double newSplitRatio =
          _initialSplitRatio + (deltaX / context.size!.width);
      // _splitRatio = newSplitRatio.clamp(0.1, 0.9); // Clamp ระหว่าง 10% ถึง 90%
      _splitRatio = newSplitRatio.clamp(0.06, 0.8); // Clamp ระหว่าง 7% ถึง 80%
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double splitterWidth = 10.0; // ความกว้างของเส้นแบ่ง
        final double leftWidth = constraints.maxWidth * _splitRatio;
        final double rightWidth =
            constraints.maxWidth - leftWidth - splitterWidth;

        return Row(
          children: <Widget>[
            Container(
              color: Colors.blueGrey[100], // สีพื้นหลังของส่วนซ้าย
              alignment: Alignment.center,
              child: SizedBox(
                width: leftWidth,
                child: widget.leftChild,
              ),
            ),
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: splitterWidth,
                  color: Colors.blueGrey[200], // สีเส้นแบ่ง
                  alignment: Alignment.center,
                  child: Center(child:
                  Icon(
                    // Icons.drag_indicator,
                    Icons.drag_indicator_sharp,
                    size: 11.0,
                    // color: Colors.grey[600],
                    color: Colors.blue[900],
                  ),
                  )
                ),
              ),
            ),
            Container(
              color: Colors.blueGrey[50], // สีพื้นหลังของส่วนซ้าย
              alignment: Alignment.center,
              child: SizedBox(
                width: rightWidth,
                child: widget.rightChild,
              ),
            ),
          ],
        );
      },
    );
  }
}
