import os, re

lib_dir = "/Users/aswath/Documents/Tripzo/TMS/lib"
pattern = re.compile(r"\"([^\"]*)\$\{?response\.statusCode\}?([^\"]*)\"")
import_pattern = re.compile(r"import\s+.(?:package:tripzo/)?utils/api_error_parser.dart.;")

count = 0
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r") as f:
                content = f.read()
            
            if "response.statusCode" in content and pattern.search(content):
                def replacer(match):
                    g1 = match.group(1)
                    fallback = re.sub(r"[\(\:\s]+(?:Error)?\s*$", "", g1).strip()
                    if not fallback:
                        fallback = "Operation failed"
                    return f"ApiErrorParser.parse(response, fallback: \"{fallback}\")"
                
                new_content = pattern.sub(replacer, content)
                
                if "ApiErrorParser" in new_content and not import_pattern.search(new_content):
                    imports = list(re.finditer(r"^import\s+.*;", new_content, flags=re.MULTILINE))
                    if imports:
                        last_import = imports[-1]
                        insert_pos = last_import.end()
                        new_content = new_content[:insert_pos] + "\nimport \'package:tripzo/utils/api_error_parser.dart\';" + new_content[insert_pos:]
                    else:
                        new_content = "import \'package:tripzo/utils/api_error_parser.dart\';\n" + new_content
                        
                if content != new_content:
                    with open(path, "w") as f:
                        f.write(new_content)
                    print(f"Updated {path}")
                    count += 1

print(f"Total files updated: {count}")
