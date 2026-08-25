import os

# Get the backend root directory automatically
directory = os.path.dirname(os.path.abspath(__file__))
count = 0

print(f"Scanning directory: {directory}...")

for root, _, files in os.walk(directory):
    # Skip virtual environments
    if "venv" in root or ".git" in root or "__pycache__" in root:
        continue
        
    for file in files:
        if file.endswith(".py"):
            filepath = os.path.join(root, file)
            # Skip this script itself
            if filepath == __file__:
                continue
                
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                
                if "gemini-3.6-flash" in content:
                    content = content.replace("gemini-3.6-flash", "gemini-3.7-flash")
                    with open(filepath, "w", encoding="utf-8") as f:
                        f.write(content)
                    count += 1
                    print(f"  [UPDATED] {os.path.relpath(filepath, directory)}")
            except Exception as e:
                print(f"  [ERROR] {os.path.relpath(filepath, directory)}: {e}")

print()
print(f"Done! Replaced 'gemini-3.6-flash' -> 'gemini-3.7-flash' in {count} files.")
