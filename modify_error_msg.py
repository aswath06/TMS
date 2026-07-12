import re

file_path = 'lib/screens/admin/request/daily_bus_run_details_page.dart'
with open(file_path, 'r') as f:
    content = f.read()

def replace_error_handling(content, method_name):
    # Find the else block of the response status check
    pattern = r'(if\s*\(response\.statusCode\s*==\s*200\s*\|\|\s*response\.statusCode\s*==\s*201\)\s*\{[\s\S]*?\}\s*else\s*\{)\s*_showSnackBar\("([^"]+)",\s*Colors\.red\);\s*(\})'
    
    # We will parse the JSON to get the real error message
    replacement = r'''\1
        try {
          final decoded = json.decode(response.body);
          final msg = decoded['message'] ?? decoded['error'] ?? "\2";
          _showSnackBar(msg.toString(), Colors.red);
        } catch (_) {
          _showSnackBar("\2", Colors.red);
        }
      \3'''
    
    return re.sub(pattern, replacement, content)

content = replace_error_handling(content, '_startMorningRun')

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
