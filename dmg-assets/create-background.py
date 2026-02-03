#!/usr/bin/env python3

from PIL import Image

# Create 660x400 white background
width, height = 660, 400
background = Image.new('RGB', (width, height), 'white')

# Open and resize arrow
arrow = Image.open('arrow.png')

# Resize arrow to fit nicely (smaller)
arrow = arrow.resize((50, 50), Image.Resampling.LANCZOS)

# Calculate center position
arrow_x = (width - 50) // 2
arrow_y = (height - 50) // 2

# Paste arrow (if it has transparency, use it as mask)
if arrow.mode == 'RGBA':
    background.paste(arrow, (arrow_x, arrow_y), arrow)
else:
    background.paste(arrow, (arrow_x, arrow_y))

# Save
background.save('dmg-background.png')
print('✅ Created dmg-background.png')
