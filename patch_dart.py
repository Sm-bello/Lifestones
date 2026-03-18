import re

with open('lib/main.dart', 'r') as f:
    code = f.read()

# Swap the imports
code = code.replace("import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';", "import 'package:url_launcher/url_launcher.dart';")

# Find the Jitsi logic and replace it with the MLP web launcher
pattern = r"final jitsi = JitsiMeet\(\);[\s\S]*?await jitsi\.join\(JitsiMeetConferenceOptions\([\s\S]*?room:\s*([^,]+),[\s\S]*?\)\);"

def replacement(match):
    room_var = match.group(1).strip()
    return f"""final url = Uri.parse('https://meet.jit.si/${{{room_var}}}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {{
      print('Could not launch sanctuary');
    }}"""

new_code = re.sub(pattern, replacement, code)

with open('lib/main.dart', 'w') as f:
    f.write(new_code)
print("Dart code perfectly patched for MLP Fallback!")
