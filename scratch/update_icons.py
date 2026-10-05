from PIL import Image
import os

src_path = r"d:\music-app\assets\icon\app_icon.png"
img = Image.open(src_path)

targets = [
    (r"d:\music-app\web\favicon.png", (64, 64)),
    (r"d:\music-app\web\icons\Icon-192.png", (192, 192)),
    (r"d:\music-app\web\icons\Icon-512.png", (512, 512)),
    (r"d:\music-app\web\icons\Icon-maskable-192.png", (192, 192)),
    (r"d:\music-app\web\icons\Icon-maskable-512.png", (512, 512)),
    (r"d:\music-app\android\app\src\main\res\mipmap-mdpi\ic_launcher.png", (48, 48)),
    (r"d:\music-app\android\app\src\main\res\mipmap-hdpi\ic_launcher.png", (72, 72)),
    (r"d:\music-app\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png", (96, 96)),
    (r"d:\music-app\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png", (144, 144)),
    (r"d:\music-app\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png", (192, 192)),
]

for dest_path, size in targets:
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(dest_path, "PNG")
    print(f"Updated {dest_path} -> {size}")

print("All app icons updated successfully!")
