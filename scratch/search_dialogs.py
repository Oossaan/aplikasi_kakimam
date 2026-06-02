import os
import re

views_dir = r"c:\Users\MadaoTaizo\Documents\code\flutter\aplikasi_kak_imam\lib\views"
pattern = re.compile(r"(showDialog|showModalBottomSheet)")

for root, dirs, files in os.walk(views_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                for idx, line in enumerate(lines):
                    if pattern.search(line):
                        print(f"{os.path.relpath(filepath, views_dir)} (L{idx+1}): {line.strip()}")
            except Exception as e:
                pass
