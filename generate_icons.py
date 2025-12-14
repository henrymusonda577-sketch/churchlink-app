from PIL import Image
import os

# Create build/web/icons directory if it doesn't exist
os.makedirs('build/web/icons', exist_ok=True)

# Load the Church-Link logo
img = Image.open("assets/Enhanced app icon fo.png").convert("RGBA")

# Resize to 192x192
icon_192 = img.resize((192, 192), Image.Resampling.LANCZOS)
icon_192.save('build/web/icons/Icon-192.png')

# Resize to 512x512
icon_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
icon_512.save('build/web/icons/Icon-512.png')

# For maskable, use the same resized images (simplified)
icon_192.save('build/web/icons/Icon-maskable-192.png')
icon_512.save('build/web/icons/Icon-maskable-512.png')

print("Church-Link icons generated successfully!")