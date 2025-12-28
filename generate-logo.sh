INPUT=build/logo.png
  IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
  MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset

  while read -r size file; do
    sips -z "$size" "$size" "$INPUT" --out "$IOS/$file" >/dev/null
  done <<'EOF'
  20 Icon-App-20x20@1x.png
  40 Icon-App-20x20@2x.png
  60 Icon-App-20x20@3x.png
  29 Icon-App-29x29@1x.png
  58 Icon-App-29x29@2x.png
  87 Icon-App-29x29@3x.png
  40 Icon-App-40x40@1x.png
  80 Icon-App-40x40@2x.png
  120 Icon-App-40x40@3x.png
  76 Icon-App-76x76@1x.png
  152 Icon-App-76x76@2x.png
  167 Icon-App-83.5x83.5@2x.png
  120 Icon-App-60x60@2x.png
  180 Icon-App-60x60@3x.png
  1024 Icon-App-1024x1024@1x.png
  EOF

  while read -r size file; do
    sips -z "$size" "$size" "$INPUT" --out "$MAC/$file" >/dev/null
  done <<'EOF'
  16 app_icon_16.png
  32 app_icon_32.png
  64 app_icon_64.png
  128 app_icon_128.png
  256 app_icon_256.png
  512 app_icon_512.png
  1024 app_icon_1024.png
  EOF
