import re
import os

# Patch Project-level
proj = 'android/build.gradle.kts'
if os.path.exists(proj):
    with open(proj, 'r') as f: data = f.read()
    if 'com.google.gms:google-services' not in data:
        buildscript = "buildscript {\n    repositories {\n        google()\n        mavenCentral()\n    }\n    dependencies {\n        classpath(\"com.google.gms:google-services:4.4.1\")\n    }\n}\n"
        with open(proj, 'w') as f: f.write(buildscript + data)

# Patch App-level
app = 'android/app/build.gradle.kts'
if os.path.exists(app):
    with open(app, 'r') as f: data = f.read()
    if 'com.google.gms.google-services' not in data:
        data = data.replace('plugins {', 'plugins {\n    id("com.google.gms.google-services")')
        data = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', data)
        data = data.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled = true')
        with open(app, 'w') as f: f.write(data)

print("Kotlin Anatomy fully restored and fortified!")
