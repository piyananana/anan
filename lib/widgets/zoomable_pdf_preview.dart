// lib/widgets/zoomable_pdf_preview.dart — wraps package:printing's PdfPreview with a zoom slider and
// click-drag panning. Plain Transform (not InteractiveViewer) so mouse-wheel scroll passes through
// untouched to PdfPreview's own page list instead of being hijacked as a zoom gesture.
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ZoomablePdfPreview extends StatefulWidget {
  const ZoomablePdfPreview({
    super.key,
    required this.documentVersion,
    required this.build,
    this.initialPageFormat,
    this.canChangeOrientation = false,
    this.canDebug = false,
    this.allowPrinting = true,
    this.allowSharing = true,
    this.pdfFileName,
  });

  /// Bump this (e.g. a counter incremented each time a new report is generated) so the
  /// widget knows to reset the pan offset for the new document. Also used as the inner
  /// PdfPreview's key.
  final Object documentVersion;
  final LayoutCallback build;
  final PdfPageFormat? initialPageFormat;
  final bool canChangeOrientation;
  final bool canDebug;
  final bool allowPrinting;
  final bool allowSharing;
  final String? pdfFileName;

  @override
  State<ZoomablePdfPreview> createState() => _ZoomablePdfPreviewState();
}

class _ZoomablePdfPreviewState extends State<ZoomablePdfPreview> {
  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;

  @override
  void didUpdateWidget(covariant ZoomablePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentVersion != widget.documentVersion) {
      _panOffset = Offset.zero;
    }
  }

  void _setZoom(double z) {
    setState(() {
      _zoom = z;
      if (z <= 1.0) _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(Icons.zoom_out, size: 18, color: Colors.grey[700]),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: SizedBox(
                height: 24,
                child: Slider(
                  value: _zoom,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  label: '${(_zoom * 100).round()}%',
                  onChanged: _setZoom,
                ),
              ),
            ),
          ),
          Icon(Icons.zoom_in, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          SizedBox(
              width: 48,
              child: Text('${(_zoom * 100).round()}%',
                  style: const TextStyle(fontSize: 12))),
        ]),
      ),
      Expanded(
        child: ClipRect(
          child: GestureDetector(
            onPanUpdate: _zoom > 1.0
                ? (details) => setState(() => _panOffset += details.delta)
                : null,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..translate(_panOffset.dx, _panOffset.dy)
                ..scale(_zoom),
              child: PdfPreview(
                key: ValueKey(widget.documentVersion),
                build: widget.build,
                initialPageFormat: widget.initialPageFormat,
                canChangeOrientation: widget.canChangeOrientation,
                canDebug: widget.canDebug,
                allowPrinting: widget.allowPrinting,
                allowSharing: widget.allowSharing,
                pdfFileName: widget.pdfFileName,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
