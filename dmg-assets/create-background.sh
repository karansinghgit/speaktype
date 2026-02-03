#!/bin/bash

# Create a 660x400 white background with the arrow in the center
# Arrow should be positioned between the app icon (left) and Applications folder (right)

WIDTH=660
HEIGHT=400
ARROW_FILE="dmg-assets/arrow.png"
OUTPUT="dmg-assets/dmg-background.png"

# Check if ImageMagick is available
if command -v magick &> /dev/null; then
    echo "Creating DMG background with arrow..."
    
    # Create white background and overlay arrow in center
    magick -size ${WIDTH}x${HEIGHT} xc:white \
        \( "$ARROW_FILE" -resize 50x50 \) \
        -gravity center \
        -composite \
        "$OUTPUT"
    
    echo "✅ Created $OUTPUT"
    
elif command -v convert &> /dev/null; then
    echo "Creating DMG background with arrow (legacy ImageMagick)..."
    
    convert -size ${WIDTH}x${HEIGHT} xc:white \
        \( "$ARROW_FILE" -resize 50x50 \) \
        -gravity center \
        -composite \
        "$OUTPUT"
    
    echo "✅ Created $OUTPUT"
    
else
    echo "❌ ImageMagick not found. Install with: brew install imagemagick"
    exit 1
fi
