const fs = require('fs');

function updateFile(path) {
  let content = fs.readFileSync(path, 'utf8');

  // Add _maxReachedIndex to state
  content = content.replace(`  int? _currentBusLocationStopId;`, `  int? _currentBusLocationStopId;\n  int _maxReachedIndex = -1;`);

  // Update _buildFullTimeline
  const oldFull = `    if (_currentBusLocationStopId != null) {
      currentStopIdx = stops.indexWhere((s) => s['id'] == _currentBusLocationStopId);
    }`;
    
  const newFull = `    if (_currentBusLocationStopId != null) {
      int incomingIdx = stops.indexWhere((s) => s['id'] == _currentBusLocationStopId);
      if (incomingIdx > _maxReachedIndex) {
        _maxReachedIndex = incomingIdx;
      }
      currentStopIdx = _maxReachedIndex;
    }`;

  content = content.replace(oldFull, newFull);
  
  fs.writeFileSync(path, content);
}

updateFile('c:/Users/admin/Desktop/Tripzo/TMS/lib/screens/student/student_bus_screen.dart');
updateFile('c:/Users/admin/Desktop/Tripzo/TMS/lib/screens/student/student_dashboard_screen.dart');
console.log('Done');
