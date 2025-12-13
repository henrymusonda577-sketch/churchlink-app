from PIL import Image, ImageDraw
import os

def create_church_icon(size, foreground_only=False):
    # Create image
    if foreground_only:
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))  # Transparent background
        color = (30, 58, 138, 255)  # Church blue
        bg_color = (255, 255, 255, 255)  # White for cutouts
    else:
        img = Image.new('RGBA', (size, size), (30, 58, 138, 255))  # Church blue background
        color = (255, 255, 255, 255)  # White church
        bg_color = (30, 58, 138, 255)  # Blue for cutouts
    
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    building_width = int(size * 0.6)
    building_height = int(size * 0.4)
    building_left = center - building_width // 2
    building_top = center + int(size * 0.1)
    
    # Main church building
    draw.rectangle([building_left, building_top, building_left + building_width, building_top + building_height], fill=color)
    
    # Church roof (triangle)
    roof_points = [
        (building_left - int(size * 0.05), building_top),
        (center, building_top - int(size * 0.15)),
        (building_left + building_width + int(size * 0.05), building_top)
    ]
    draw.polygon(roof_points, fill=color)
    
    # Cross on top
    cross_size = int(size * 0.08)
    cross_top = building_top - int(size * 0.25)
    
    # Vertical part of cross
    draw.rectangle([
        center - int(cross_size * 0.15), cross_top,
        center + int(cross_size * 0.15), cross_top + int(cross_size * 1.2)
    ], fill=color)
    
    # Horizontal part of cross
    draw.rectangle([
        center - int(cross_size * 0.4), cross_top + int(cross_size * 0.2),
        center + int(cross_size * 0.4), cross_top + int(cross_size * 0.5)
    ], fill=color)
    
    # Church door
    door_width = int(size * 0.12)
    door_height = int(size * 0.2)
    door_left = center - door_width // 2
    door_top = building_top + building_height - door_height
    
    draw.rectangle([door_left, door_top, door_left + door_width, door_top + door_height], fill=bg_color)
    
    # Church windows
    window_size = int(size * 0.06)
    window_y = building_top + int(size * 0.08)
    
    # Left window
    draw.rectangle([
        building_left + int(size * 0.08), window_y,
        building_left + int(size * 0.08) + window_size, window_y + window_size
    ], fill=bg_color)
    
    # Right window
    draw.rectangle([
        building_left + building_width - int(size * 0.08) - window_size, window_y,
        building_left + building_width - int(size * 0.08), window_y + window_size
    ], fill=bg_color)
    
    return img

# Create assets directory if it doesn't exist
os.makedirs('assets', exist_ok=True)

# Create main church icon (1024x1024)
main_icon = create_church_icon(1024)
main_icon.save('assets/church_icon.png')

# Create foreground icon for adaptive (1024x1024)
foreground_icon = create_church_icon(1024, foreground_only=True)
foreground_icon.save('assets/church_icon_foreground.png')

print("Church icons created successfully!")