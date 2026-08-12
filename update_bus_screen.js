const fs = require('fs');

const busScreenPath = 'c:/Users/admin/Desktop/Tripzo/TMS/lib/screens/student/student_bus_screen.dart';
let busScreen = fs.readFileSync(busScreenPath, 'utf8');

// Add import
const importToAdd = `import 'package:socket_io_client/socket_io_client.dart' as IO;`;
busScreen = busScreen.replace(`import 'package:google_fonts/google_fonts.dart';`, `import 'package:google_fonts/google_fonts.dart';\n${importToAdd}`);

// Add state variables
const stateVars = `  bool _isScrolledFarFromToday = false;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;
  IO.Socket? _socket;
  int? _currentBusLocationStopId;`;
busScreen = busScreen.replace(`  bool _isScrolledFarFromToday = false;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;`, stateVars);

// Add initSocket
const initSocket = `
  void _initSocket() {
    try {
      String baseUrl = ApiConstants.baseUrl;
      if (baseUrl.endsWith('/api/v1')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 7);
      }
      _socket = IO.io(baseUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/tms-socket/')
          .build());
      _socket?.connect();
      _socket?.onConnect((_) {
        debugPrint('WebSocket connected in student screen');
      });
      _socket?.on('bus_location_update', (data) {
        if (mounted) {
          setState(() {
            _currentBusLocationStopId = data['currentBusLocationStopId'];
          });
        }
      });
    } catch (e) {
      debugPrint('Error init websocket: $e');
    }
  }
`;

// Inject initSocket in initState
const initStateStart = `  void initState() {
    super.initState();
    _initSocket();`;
busScreen = busScreen.replace(`  void initState() {
    super.initState();`, initStateStart);

// Inject initSocket function
busScreen = busScreen.replace(`  void _scrollToDate(String dateStr) {`, `${initSocket}\n  void _scrollToDate(String dateStr) {`);

// Add dispose socket
const disposeAdd = `    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();`;
busScreen = busScreen.replace(`    super.dispose();`, disposeAdd);

// Modify timeline row to use dynamic stops
const oldTimelineRow = `  Widget _buildSimpleTimelineRow(
    int order,
    String name,
    bool isLast,
    Color blue,
    Color titleColor,
    Color sub,
    bool isPast,
    bool isCompleted,
  ) {
    final Color dotColor = isCompleted
        ? const Color(0xFF10B981)
        : (isPast ? blue : const Color(0xFF94A3B8));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : dotColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }`;

const newTimelineRow = `  Widget _buildSimpleTimelineRow(
    int order,
    String name,
    bool isLast,
    Color blue,
    Color titleColor,
    Color sub,
    bool isPast,
    bool isCompleted,
    bool isCurrentLocation,
  ) {
    final Color dotColor = isCompleted
        ? const Color(0xFF10B981)
        : (isPast ? blue : const Color(0xFF94A3B8));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              if (isCurrentLocation)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.directions_bus, size: 12, color: Colors.white),
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : dotColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }`;
busScreen = busScreen.replace(oldTimelineRow, newTimelineRow);

const oldSequence = `                      _buildSimpleTimelineRow(0, startLoc, false, const Color(0xFF6366F1), titleColor, subColor, true, status.toUpperCase() == 'COMPLETED'),
                      _buildSimpleTimelineRow(1, haltLoc, true, const Color(0xFF6366F1), titleColor, subColor, status.toUpperCase() == 'COMPLETED', status.toUpperCase() == 'COMPLETED'),`;

const newSequence = `                      ..._buildFullTimeline(run, titleColor, subColor, status),`;
busScreen = busScreen.replace(oldSequence, newSequence);

const fullTimelineFunc = `  List<Widget> _buildFullTimeline(Map<String, dynamic> run, Color titleColor, Color subColor, String status) {
    List<dynamic> stops = run['runStops'] ?? [];
    if (stops.isEmpty) return [];
    
    // For evening trips, reverse the stop order
    bool isEvening = run['shift_code'] == 'EVENING';
    if (isEvening) {
      stops = List.from(stops.reversed);
    }

    List<Widget> rows = [];
    int currentStopIdx = -1;
    
    if (_currentBusLocationStopId != null) {
      currentStopIdx = stops.indexWhere((s) => s['id'] == _currentBusLocationStopId);
    }
    
    // Fallback logic for status
    bool allCompleted = status.toUpperCase() == 'COMPLETED' || (isEvening && ['FN_COMPLETED'].contains(status.toUpperCase()));

    for (int i = 0; i < stops.length; i++) {
      var s = stops[i];
      bool isLast = i == stops.length - 1;
      
      bool isPast = allCompleted;
      bool isCompleted = allCompleted;
      bool isCurrentLocation = false;
      
      if (!allCompleted) {
        if (currentStopIdx != -1) {
          if (i < currentStopIdx) {
            isPast = true;
            isCompleted = true;
          } else if (i == currentStopIdx) {
            isCurrentLocation = true;
            isPast = true;
          }
        } else {
           if (i == 0 && (status == 'STARTED' || status == 'AN_STARTED')) {
              isPast = true;
           }
        }
      }

      rows.add(_buildSimpleTimelineRow(
        i,
        s['stop_name'] ?? 'Stop',
        isLast,
        const Color(0xFF6366F1),
        titleColor,
        subColor,
        isPast,
        isCompleted,
        isCurrentLocation
      ));
    }
    return rows;
  }
`;

busScreen = busScreen.replace(`  Future<void> _loadRunDetailsAndNavigate(Map<String, dynamic> run) async {`, `${fullTimelineFunc}\n  Future<void> _loadRunDetailsAndNavigate(Map<String, dynamic> run) async {`);

fs.writeFileSync(busScreenPath, busScreen);
console.log('student_bus_screen.dart updated');
