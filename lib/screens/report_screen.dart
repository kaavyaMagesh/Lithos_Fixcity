import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/translator.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String reportId;
  final String userRole;

  const ReportDetailScreen({
    super.key,
    required this.data,
    required this.reportId,
    required this.userRole,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.data['aiAnalysis']?['status'] ?? 'PENDING';
  }

  // 🕒 AGE CALCULATOR LOGIC
  String _calculateReportAge() {
    final dynamic startData = widget.data['createdAt'];
    if (startData == null) return "N/A";

    DateTime start = (startData is Timestamp)
        ? startData.toDate()
        : DateTime.parse(startData.toString());
    DateTime end = DateTime.now();

    if (_status == 'RESOLVED') {
      final dynamic endData = widget.data['closedAt'];
      if (endData != null) {
        end = (endData is Timestamp)
            ? endData.toDate()
            : DateTime.parse(endData.toString());
      }
    }

    int days = end.difference(start).inDays;
    return days == 0 ? "Raised Today" : "$days Days";
  }

  // 🖨️ PDF GENERATOR
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final analysis = widget.data['aiAnalysis'] ?? {};
    final loc = widget.data['location'] ?? {};

    String cost = analysis['estimatedCost'] ?? "Assessment Pending";
    String manpower = analysis['manpower'] ?? "Assessment Pending";

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "OFFICIAL WORK ORDER - FIXCITY",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Report ID: ${widget.reportId}"),
              pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}"),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                "AI ASSESSMENT",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Bullet(text: "Issue: ${analysis['issueType'] ?? 'N/A'}"),
              pw.Bullet(text: "Department: ${analysis['department'] ?? 'N/A'}"),
              pw.Bullet(text: "Urgency: ${analysis['urgency'] ?? 'N/A'}"),
              pw.Bullet(text: "Severity: ${analysis['severity'] ?? 'N/A'}"),
              pw.SizedBox(height: 10),
              pw.Text(
                "RESOURCE ESTIMATION",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Bullet(text: "Budget: $cost"),
              pw.Bullet(text: "Manpower: $manpower"),
              pw.SizedBox(height: 20),
              pw.Text(
                "LOCATION DATA",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Lat: ${loc['lat'] ?? 0.0}, Lng: ${loc['lng'] ?? 0.0}"),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text("____________________"),
                      pw.Text("Supervisor Signature"),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text("____________________"),
                      pw.Text("Contractor Signature"),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // 🔄 STATUS UPDATER
  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.reportId)
        .update({'aiAnalysis.status': newStatus});
    setState(() => _status = newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${Translator.t('status_updated')}: $newStatus"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.data['aiAnalysis'] ?? {};
    final loc = widget.data['location'] ?? {'lat': 0.0, 'lng': 0.0};

    // ✅ REAL SECURITY CHECK: Only show admin tools if role is 'Admin'
    final bool isAdmin = widget.userRole == 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(Translator.t('report_issue')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              Share.share(
                "🚨 FixCity Report: ${analysis['issueType']} #SmartCity",
              );
            },
          ),
        ],
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGE HEADER
              SizedBox(
                height: 250,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (widget.data['imageUrl'] ?? '').toString().isNotEmpty
                        ? Image.network(
                            widget.data['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey.shade900,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                ),
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _status == 'RESOLVED'
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. BASIC INFO
                    Text(
                      analysis['issueType']?.toString().toUpperCase() ??
                          "ISSUE",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.data['description'] ?? "",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. AI ANALYSIS DETAILS
                    _buildAnalysisDetails(analysis),
                    const SizedBox(height: 20),

                    // 4. BUDGET CARD (Admins Only)
                    if (isAdmin) _buildBudgetCard(analysis),

                    // 5. MAP PREVIEW
                    Text(
                      Translator.t('location_context'),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              loc['lat']?.toDouble() ?? 0.0,
                              loc['lng']?.toDouble() ?? 0.0,
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.codealchemists.fixcity',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    loc['lat']?.toDouble() ?? 0.0,
                                    loc['lng']?.toDouble() ?? 0.0,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 6. ADMIN ACTIONS
                    if (isAdmin) ...[
                      const SizedBox(height: 30),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                      Text(
                        Translator.t('admin_actions'),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Status Update Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade700),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2C2C2C),
                            style: const TextStyle(color: Colors.white),
                            items: ['PENDING', 'IN PROGRESS', 'RESOLVED']
                                .map(
                                  (val) => DropdownMenuItem(
                                    value: val,
                                    child: Text(val),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) => _updateStatus(val!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Print Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: Text(Translator.t('print_pdf')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: _generatePdf,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📋 AI DETAILS WIDGET
  Widget _buildAnalysisDetails(Map<String, dynamic> analysis) {
    // Safe parsing for confidence
    double confidence = 0.0;
    if (analysis['confidence'] != null) {
      confidence = double.tryParse(analysis['confidence'].toString()) ?? 0.0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(
                Translator.t('ai_assessment'),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          _detailRow("Urgency", analysis['urgency'], Colors.redAccent),
          _detailRow("Severity", analysis['severity'], Colors.orangeAccent),
          _detailRow("Department", analysis['department'], Colors.white),
          _detailRow(
            "Confidence",
            "${(confidence * 100).toStringAsFixed(0)}%",
            Colors.greenAccent,
          ),
          const SizedBox(height: 10),
          Text(
            analysis['summary'] ?? "No summary available.",
            style: const TextStyle(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value?.toString().toUpperCase() ?? "N/A",
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 💰 BUDGET WIDGET
  Widget _buildBudgetCard(Map<String, dynamic> analysis) {
    String cost = analysis['estimatedCost'] ?? "Calculating...";
    String manpower = analysis['manpower'] ?? "Pending...";
    List<dynamic> materials = analysis['materialsRequired'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.4),
            const Color(0xFF1E1E1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text(
                Translator.t('cost_estimation'),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.greenAccent, height: 20),
          _detailRow(Translator.t('est_budget'), cost, Colors.white),
          _detailRow(Translator.t('labor_req'), manpower, Colors.white),
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              Translator.t('materials'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: materials
                  .map<Widget>(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        item.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
