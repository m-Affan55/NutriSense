import os

directory = r"d:\mobileAppDev\BanoQabilHackathon\NutriSense\backend"
count = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith(".py"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            if "gemini-3.6-flash" in content:
                content = content.replace("gemini-3.6-flash", "gemini-3.6-flash")
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                count += 1
                print(f"Updated {filepath}")

print(f"Done! Replaced in {count} files.")
