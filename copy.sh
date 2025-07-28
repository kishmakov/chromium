SOURCE_DIR="$(pwd)/out/$1"

if [ -d "/home/kishmakov/Repos/vscode" ]; then
	DEST_DIR="/home/kishmakov/Repos/vscode/.build/electron"
else
	DEST_DIR="/home/kishmakov/Repos/vs/vscode/.build/electron"
fi

echo "cp \"$SOURCE_DIR/electron\" \"$DEST_DIR/code-oss\""
cp "$SOURCE_DIR/electron" "$DEST_DIR/code-oss"

FILES=(
	"snapshot_blob.bin"
	"v8_context_snapshot.bin"
	"icudtl.dat"
	"libEGL.so"
	"libGLESv2.so"
	"libvk_swiftshader.so"
	"libvulkan.so.1"
	"libffmpeg.so"
)

for file in "${FILES[@]}"; do
	echo "cp \"$SOURCE_DIR/$file\" \"$DEST_DIR/\""
	cp "$SOURCE_DIR/$file" "$DEST_DIR/"
done
