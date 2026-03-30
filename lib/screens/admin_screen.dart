import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 IMPORT THIS
import '../widgets/app_drawer.dart';
import 'report_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _selectedFilter = "All";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  // 🔒 SECURITY STATE
  bool _isAdmin = false;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // 🕒 AGE CALCULATOR LOGIC
  String _getReportAge(Map<String, dynamic> data) {
    final dynamic startData =
        data['createdAt'] ?? data['timestamp'] ?? data['raisedAt'];
    if (startData == null) return "N/A";

    DateTime start = (startData is Timestamp)
        ? startData.toDate()
        : DateTime.parse(startData.toString());

    DateTime end = DateTime.now();
    String status = data['status'] ?? 'PENDING';

    if (status == 'RESOLVED') {
      final dynamic endData = data['closedAt'] ?? data['resolvedAt'];
      if (endData != null) {
        end = (endData is Timestamp)
            ? endData.toDate()
            : DateTime.parse(endData.toString());
      }
    }

    int days = end.difference(start).inDays;
    return days == 0 ? "Today" : "${days}d";
  }

  // 🔒 VERIFY ROLE
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        IdTokenResult tokenResult = await user.getIdTokenResult();
        bool isClaimAdmin = tokenResult.claims?['role'] == 'admin';

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        bool isDbAdmin = false;
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data['role'] == 'admin') isDbAdmin = true;
        }

        if (mounted) {
          setState(() {
            _isAdmin = isClaimAdmin || isDbAdmin;
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // 🛠️ LOGIC: CONTRACTOR ASSIGNMENT
  void _showContractorSelector(String docId, String department) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          "Assign $department Contractor",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'contractor')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Text(
                  "No contractors found for this department.",
                  style: TextStyle(color: Colors.grey),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var contractor = snapshot.data!.docs[index];
                  var cData = contractor.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(
                      Icons.engineering,
                      color: Colors.orange,
                    ),
                    title: Text(
                      cData['name'] ?? "No Name",
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      cData['email'] ?? "",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      _assignWork(
                        docId,
                        contractor.id,
                        cData['name'] ?? "Unknown",
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _assignWork(String docId, String contractorId, String contractorName) {
    FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': 'IN PROGRESS',
      'aiAnalysis.status': 'IN PROGRESS',
      'assignedContractorId': contractorId,
      'assignedContractorName': contractorName,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Assigned to $contractorName"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 🚀 UPDATED: Logic to handle Status Update + SMS
  void _updateStatus(
    String docId,
    String newStatus, [
    Map<String, dynamic>? data,
  ]) {
    FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': newStatus,
      'aiAnalysis.status': newStatus,
      if (newStatus == 'RESOLVED') 'closedAt': FieldValue.serverTimestamp(),
    });

    // 📨 Trigger SMS Logic
    if (newStatus == 'RESOLVED' && data != null) {
      _sendResolutionSMS(docId, data);
    }
  }

  // 📨 SEND SMS FUNCTION
  Future<void> _sendResolutionSMS(
    String docId,
    Map<String, dynamic> data,
  ) async {
    const String targetNumber = "+916369299829"; // 👈 YOUR TARGET NUMBER
    String description = data['description'] ?? "reported issue";

    // Construct the SMS Link
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: targetNumber,
      queryParameters: <String, String>{
        'body':
            "FixCity Update: The issue '$description' (ID: $docId) has been officially RESOLVED. Thank you!",
      },
    );

    // Launch the App
    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else {
        print("Could not launch SMS app");
      }
    } catch (e) {
      print("Error launching SMS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: _buildSearchBar(),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoadingRole
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: Text(
                        "Error loading data",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;

                  int total = docs.length;
                  int resolved = 0;
                  int pending = 0;
                  int inProgress = 0;
                  Map<String, int> deptStats = {};

                  for (var doc in docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    var analysis =
                        data['aiAnalysis'] as Map<String, dynamic>? ?? {};
                    String status = data['status'] ?? 'PENDING';
                    String dept = analysis['department'] ?? 'General';

                    if (status == 'RESOLVED')
                      resolved++;
                    else if (status == 'PENDING')
                      pending++;
                    else
                      inProgress++;

                    deptStats[dept] = (deptStats[dept] ?? 0) + 1;
                  }

                  var filteredDocs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? 'PENDING';
                    String description = (data['description'] ?? "")
                        .toString()
                        .toLowerCase();

                    if (_selectedFilter == "Unresolved" && status == "RESOLVED")
                      return false;
                    if (_selectedFilter == "Resolved" && status != "RESOLVED")
                      return false;
                    if (_searchQuery.isNotEmpty &&
                        !description.contains(_searchQuery.toLowerCase()))
                      return false;
                    return true;
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      _buildStatsDashboard(
                        total,
                        resolved,
                        pending,
                        inProgress,
                        deptStats,
                      ),
                      if (filteredDocs.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: _buildLiveMap(filteredDocs),
                          ),
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterChip("All", Icons.list),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              "Unresolved",
                              Icons.pending_actions,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              "Resolved",
                              Icons.check_circle_outline,
                              color: Colors.greenAccent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filteredDocs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              "No reports match.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...filteredDocs.map((doc) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: GestureDetector(
                              onTap: () {},
                              child: _buildAdminCard(
                                context,
                                doc.data() as Map<String, dynamic>,
                                doc['aiAnalysis'],
                                doc.id,
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // 🃏 THE ADMIN CARD
  Widget _buildAdminCard(
    BuildContext context,
    Map<String, dynamic> data,
    Map? analysisRaw,
    String docId,
  ) {
    var analysis = analysisRaw ?? {};
    String status = data['status'] ?? 'PENDING';
    String urgency = analysis['urgency'] ?? 'Normal';
    String dept = analysis['department'] ?? 'General';
    String? assignedName = data['assignedContractorName'];

    bool isAiVerified = data['afterImageVerified'] ?? false;
    String? aiReason = data['verificationReason'];

    Color statusColor = status == 'RESOLVED' ? Colors.green : Colors.orange;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(
              data: data,
              reportId: docId,
              userRole: 'Admin',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: const Color(0xFF1E1E1E),
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // 🛠️ FIX 1: Wrapped in Flexible
                        Flexible(child: _buildDeptBadge(dept)),
                        const SizedBox(width: 8),
                        _buildAgeBadge(data),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // Added gap
                  Text(
                    urgency,
                    style: TextStyle(
                      color: urgency == 'Immediate' ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                analysis['issueType'] ?? "Issue",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                data['description'] ?? "",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade400),
              ),
              if (isAiVerified)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "AI Verification: $aiReason",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (status == 'IN PROGRESS' && assignedName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Assigned to: $assignedName",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _isAdmin
                      ? _buildStatusDropdown(
                          docId,
                          status,
                          dept,
                          statusColor,
                          data,
                        )
                      : _buildStatusBadge(status, statusColor),
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmDelete(context, docId),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 👇 HERE IS THE MISSING DROPDOWN FUNCTION
  Widget _buildStatusDropdown(
    String docId,
    String status,
    String dept,
    Color color,
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ['PENDING', 'IN PROGRESS', 'RESOLVED'].contains(status)
              ? status
              : 'PENDING',
          dropdownColor: const Color(0xFF2C2C2C),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          items: ['PENDING', 'IN PROGRESS', 'RESOLVED']
              .map(
                (val) => DropdownMenuItem(
                  value: val,
                  child: Text(
                    val,
                    style: TextStyle(
                      color: val == 'RESOLVED' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == 'IN PROGRESS') {
              _showContractorSelector(docId, dept);
            } else if (val != null) {
              _updateStatus(docId, val, data); // 👈 PASSING DATA TO UPDATE
            }
          },
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildAgeBadge(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 10, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            _getReportAge(data),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptBadge(String dept) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        dept.toUpperCase(),
        // 🛠️ FIX 2: Added overflow handling
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(
    int total,
    int resolved,
    int pending,
    int inProgress,
    Map<String, int> deptStats,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem("Total", total.toString(), Colors.blue),
                const SizedBox(width: 20),
                _buildStatItem("Resolved", resolved.toString(), Colors.green),
                const SizedBox(width: 20),
                _buildStatItem("Pending", pending.toString(), Colors.orange),
                const SizedBox(width: 20),
                _buildStatItem("Active", inProgress.toString(), Colors.yellow),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: OutlinedButton(
              onPressed: () => _showDeptDetails(deptStats),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "View Department Breakdown ▼",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLiveMap(List<QueryDocumentSnapshot> docs) {
    List<Marker> markers = [];
    LatLng? centerPoint;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;

      LatLng? point;
      if (data['location'] != null) {
        if (data['location'] is GeoPoint) {
          GeoPoint gp = data['location'];
          point = LatLng(gp.latitude, gp.longitude);
        } else if (data['location'] is Map) {
          var loc = data['location'];
          if (loc['lat'] != null && loc['lng'] != null) {
            point = LatLng(loc['lat'], loc['lng']);
          }
        }
      }

      if (point != null) {
        centerPoint ??= point;
        markers.add(
          Marker(
            point: point,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {},
              child: const Icon(
                Icons.location_on,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: centerPoint ?? const LatLng(0, 0),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: "Search issues...",
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon, {
    Color color = const Color(0xFFFF6D00),
  }) {
    bool isSel = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSel && label != "All") {
            _selectedFilter = "All";
          } else {
            _selectedFilter = label;
          }
        });
      },
      child: Chip(
        avatar: Icon(icon, size: 16, color: isSel ? Colors.black : color),
        label: Text(
          label,
          style: TextStyle(color: isSel ? Colors.black : Colors.white),
        ),
        backgroundColor: isSel ? color : const Color(0xFF2C2C2C),
        side: BorderSide.none,
      ),
    );
  }

  void _showDeptDetails(Map<String, int> deptStats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Department Breakdown",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: deptStats.isEmpty
                    ? const Center(
                        child: Text(
                          "No data available.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: deptStats.length,
                        itemBuilder: (context, index) {
                          String key = deptStats.keys.elementAt(index);
                          int value = deptStats.values.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    key,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade800,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    value.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          "Delete Report?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This action cannot be undone.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('reports')
                  .doc(docId)
                  .delete();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
