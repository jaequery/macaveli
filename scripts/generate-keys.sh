#!/bin/zsh
# find Sparkle's bin folder
generate_keys=$(find ~/Library/Developer/Xcode/DerivedData/InitialX* -type f -name "*generate_keys")

# generate appcast
echo "Generating keys..."
$generate_keys

