import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/edit_vehicle_driver_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Fix Vehicle error
old_vehicle_logic = """        if (res.statusCode == 200) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            vSuccess = false;
            errorMsg = resData['message'];
          }
        } else {
          vSuccess = false;
          errorMsg = "Server error updating vehicle: ${res.statusCode}";
        }"""

new_vehicle_logic = """        if (res.statusCode == 200 || res.statusCode == 201) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            vSuccess = false;
            errorMsg = resData['message'];
          }
        } else {
          vSuccess = false;
          try {
            final decoded = json.decode(res.body);
            errorMsg = decoded['message'] ?? decoded['error'] ?? "Server error updating vehicle: ${res.statusCode}";
          } catch (_) {
            errorMsg = "Server error updating vehicle: ${res.statusCode}";
          }
        }"""

content = content.replace(old_vehicle_logic, new_vehicle_logic)

# Fix Driver error
old_driver_logic = """        if (res.statusCode == 200) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            dSuccess = false;
            if (errorMsg == null) {
              errorMsg = resData['message'];
            } else {
              errorMsg = "$errorMsg | ${resData['message']}";
            }
          }
        } else {
          dSuccess = false;
          final err = "Server error updating driver: ${res.statusCode}";
          errorMsg = errorMsg == null ? err : "$errorMsg | $err";
        }"""

new_driver_logic = """        if (res.statusCode == 200 || res.statusCode == 201) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            dSuccess = false;
            if (errorMsg == null) {
              errorMsg = resData['message'];
            } else {
              errorMsg = "$errorMsg | ${resData['message']}";
            }
          }
        } else {
          dSuccess = false;
          String err;
          try {
            final decoded = json.decode(res.body);
            err = decoded['message'] ?? decoded['error'] ?? "Server error updating driver: ${res.statusCode}";
          } catch (_) {
            err = "Server error updating driver: ${res.statusCode}";
          }
          errorMsg = errorMsg == null ? err : "$errorMsg | $err";
        }"""

content = content.replace(old_driver_logic, new_driver_logic)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
