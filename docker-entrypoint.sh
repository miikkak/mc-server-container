#!/bin/bash
set -e

# Check EULA
if [ "$EULA" != "TRUE" ]; then
    echo "ERROR: You must accept the Minecraft EULA by setting EULA=TRUE"
    echo "See https://minecraft.net/terms for more information"
    exit 1
fi

# Accept EULA
echo "eula=true" > eula.txt

# Download server jar if it doesn't exist
if [ ! -f server.jar ]; then
    echo "Downloading Minecraft server..."
    
    if [ "$MINECRAFT_VERSION" = "latest" ]; then
        # Get latest version
        MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
        VERSION_URL=$(curl -s "$MANIFEST_URL" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
        SERVER_URL=$(curl -s "$VERSION_URL" | grep -o '"server":{"url":"[^"]*"' | cut -d'"' -f6)
    else
        # Use specific version (implement if needed)
        echo "Specific version download not implemented yet"
        exit 1
    fi
    
    curl -o server.jar -L "$SERVER_URL"
fi

# Generate server.properties if it doesn't exist
if [ ! -f server.properties ]; then
    cat > server.properties <<EOF
server-port=${SERVER_PORT}
max-players=${MAX_PLAYERS}
difficulty=${DIFFICULTY}
gamemode=${GAMEMODE}
enable-command-block=true
spawn-protection=16
max-tick-time=60000
view-distance=10
EOF
fi

# Start server
echo "Starting Minecraft server..."
exec java -Xmx2G -Xms1G -jar server.jar nogui
