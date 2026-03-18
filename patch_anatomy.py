import re

# Patch the Project-level Veins
proj_gradle = 'android/build.gradle'
with open(proj_gradle, 'r') as f: data = f.read()
if 'com.google.gms:google-services' not in data:
    data = re.sub(r'(dependencies\s*\{)', r"\1\n        classpath 'com.google.gms:google-services:4.4.1'", data, count=1)
with open(proj_gradle, 'w') as f: f.write(data)

# Patch the App-level Spine
app_gradle = 'android/app/build.gradle'
with open(app_gradle, 'r') as f: data = f.read()
if 'com.google.gms.google-services' not in data:
    data += "\napply plugin: 'com.google.gms.google-services'\n"

# Fortify the Spine: Upgrade to SDK 23 and enable MultiDex
data = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', data)
data = re.sub(r'minSdkVersion\s+21', 'minSdkVersion 23', data)
if 'multiDexEnabled' not in data:
    data = re.sub(r'(defaultConfig\s*\{)', r'\1\n        multiDexEnabled true', data)

with open(app_gradle, 'w') as f: f.write(data)
print("Anatomy fully restored and fortified!")
