filepath = 'android/app/src/main/AndroidManifest.xml'
with open(filepath, 'r') as f:
    data = f.read()

# Add permissions right above the application tag
if 'android.permission.INTERNET' not in data:
    permissions = """<uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    
    <application"""
    data = data.replace('<application', permissions)

with open(filepath, 'w') as f:
    f.write(data)
print("Internet permissions successfully injected!")
