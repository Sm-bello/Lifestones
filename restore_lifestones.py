import re

# --- 1. FIX THE ERASER BUG (firebase_service.dart) ---
with open('lib/firebase_service.dart', 'r') as f:
    fs = f.read()

if 'SetOptions(merge: true)' not in fs:
    fs = fs.replace(
        "}).catchError", 
        "}, SetOptions(merge: true)).catchError"
    )
    with open('lib/firebase_service.dart', 'w') as f:
        f.write(fs)
    print("✅ Eraser Bug Squashed: Roles will now 'stick'!")

# --- 2. FIX THE BIBLE & ROLE LOGIC (main.dart) ---
with open('lib/main.dart', 'r') as f:
    dart = f.read()

# Fix the Bible Loader to provide the LIST the UI wants
old_bible_logic = """            setState(() {
               _passageText = verses.join('\\\\n');
               _errorText = '';
            });"""

new_bible_logic = """            setState(() {
               _verses = List.generate(verses.length, (index) => {
                 'verse': index + 1,
                 'text': verses[index].toString(),
               });
               _errorText = '';
            });"""

dart = dart.replace(old_bible_logic, new_bible_logic)

# Fix the PIN logic to ensure immediate local update
dart = dart.replace(
    "'role': role,",
    "'role': role, 'chatApproved': true,"
)

with open('lib/main.dart', 'w') as f:
    f.write(dart)

print("✅ Bible & Role logic restored to the correct format!")
