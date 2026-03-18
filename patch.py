import os

filepath = 'android/app/src/main/AndroidManifest.xml'
with open(filepath, 'r') as f:
    data = f.read()

# Add the tools dictionary if it's missing
if 'xmlns:tools' not in data:
    data = data.replace('xmlns:android="http://schemas.android.com/apk/res/android"', 'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"')

# Add the override command if it's missing
if 'tools:replace' not in data:
    data = data.replace('<application', '<application\n        tools:replace="android:label"')

with open(filepath, 'w') as f:
    f.write(data)
print("Manifest patched successfully!")
