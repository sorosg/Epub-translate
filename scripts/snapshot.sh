#!/bin/bash
# EPUB Fordító – Pillanatkép (snapshot) készítése
# Használat: bash scripts/snapshot.sh ["leírás"]
# Ment minden módosítást és létrehoz egy visszatérési pontot

SNAPSHOT_NAME="${1:-$(date +%Y%m%d_%H%M%S)}"
echo "📸 Pillanatkép: $SNAPSHOT_NAME"

cd "$(dirname "$0")/.."

# Mentés minden változtatásról
git add -A
git commit -m "🔖 SNAPSHOT: $SNAPSHOT_NAME" || echo "⚠️ Nincs új változtatás"

# Tag létrehozása (könnyű visszatérés: git checkout tags/$SNAPSHOT_NAME)
git tag -a "snapshot-$SNAPSHOT_NAME" -m "Pillanatkép: $SNAPSHOT_NAME"

echo ""
echo "✅ Pillanatkép kész: snapshot-$SNAPSHOT_NAME"
echo ""
echo "📋 Visszatérés ehhez a ponthoz:"
echo "   git checkout tags/snapshot-$SNAPSHOT_NAME"
echo ""
echo "📋 Pillanatképek listája:"
echo "   git tag -l 'snapshot-*'"
echo ""
echo "📋 Visszatérés a legutóbbi commit-hoz (snapshot törlése):"
echo "   git checkout main"
echo "   git tag -d snapshot-$SNAPSHOT_NAME"