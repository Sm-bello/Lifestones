import sys

with open('android/app/build.gradle.kts', 'r') as f:
    c = f.read()

if 'pickFirsts' not in c:
    patch = '''    packaging {
        jniLibs {
            pickFirsts += setOf(
                "lib/arm64-v8a/libjingle_peerconnection_so.so",
                "lib/armeabi-v7a/libjingle_peerconnection_so.so",
                "lib/x86_64/libjingle_peerconnection_so.so",
                "lib/x86/libjingle_peerconnection_so.so"
            )
        }
    }
    buildTypes {'''
    c = c.replace('    buildTypes {', patch, 1)
    with open('android/app/build.gradle.kts', 'w') as f:
        f.write(c)
    print('WebRTC pickFirsts patched!')
else:
    print('Already patched')
