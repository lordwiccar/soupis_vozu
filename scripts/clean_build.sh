#!/bin/bash
echo "🧹 Vyčišťuji build složky..."
rm -rf build
rm -rf .dart_tool
echo "✅ Vyčištěno!"
echo "📦 Instaluji dependencies..."
flutter pub get
echo "🚀 Spouštím aplikaci..."
flutter run -d ZY22GJ3VKB
