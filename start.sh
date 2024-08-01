#!/bin/bash
# Legendary Paper Minecraft Java Server Docker + Geyser/Floodgate server startup script
# Author: James A. Chambers - https://jamesachambers.com/minecraft-java-bedrock-server-together-geyser-floodgate/
# GitHub Repository: https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate

echo "Paper Minecraft Java Server Docker + Geyser/Floodgate script by James A. Chambers"
echo "Latest version always at https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate"
echo "Don't forget to set up port forwarding on your router!  The default port is 25565 and the Bedrock port is 19132"

if [ ! -d '/minecraft' ]; then
    echo "ERROR:  A named volume was not specified for the minecraft server data.  Please create one with: docker volume create yourvolumename"
    echo "Please pass the new volume to docker like this:  docker run -it -v yourvolumename:/minecraft"
    exit 1
fi

# Randomizer for user agent
RandNum=$(echo $((1 + $RANDOM % 5000)))

if [ -z "$Port" ]; then
    Port="25565"
fi
echo "Port used: $Port"

if [ -z "$BedrockPort" ]; then
    Port="19132"
fi
echo "Bedrock port used: $BedrockPort"

# Change directory to server directory
cd /minecraft

# Create backups/downloads folder if it doesn't exist
if [ ! -d "/minecraft/downloads" ]; then
    mkdir -p /minecraft/downloads
fi
if [ ! -d "/minecraft/config" ]; then
    mkdir -p /minecraft/config
fi
if [ ! -d "/minecraft/backups" ]; then
    mkdir -p /minecraft/backups
fi

# Check if network interfaces are up
NetworkChecks=0
if [ -e '/sbin/route' ]; then
    DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
else
    DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
fi
while [ -z "$DefaultRoute" ]; do
    echo "Network interface not up, will try again in 1 second"
    sleep 1
    if [ -e '/sbin/route' ]; then
        DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
    else
        DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
    fi
    NetworkChecks=$((NetworkChecks + 1))
    if [ $NetworkChecks -gt 20 ]; then
        echo "Waiting for network interface to come up timed out - starting server without network connection ..."
        break
    fi
done

# Take ownership of server files and set correct permissions
if [ -z "$NoPermCheck" ]; then
    echo "Taking ownership of all server files/folders in /minecraft..."
    sudo -n chown -R $(whoami) /minecraft >/dev/null 2>&1
    echo "Complete"
else
    echo "Skipping permissions check due to NoPermCheck flag"
fi

# Back up server
if [ -d "world" ]; then
    if [ -n "$(which pigz)" ]; then
        echo "Backing up server (all cores) to cd minecraft/backups folder"
        tarArgs=(-I pigz --exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./fabric.jar')
        IFS=','
        read -ra ADDR <<< "$NoBackup"
        for i in "${ADDR[@]}"; do
            tarArgs+=(--exclude="./$i")
        done
        tarArgs+=(-pvcf backups/$(date +%Y.%m.%d.%H.%M.%S).tar.gz ./*)
        tar "${tarArgs[@]}"
    else
        echo "Backing up server (single core, pigz not found) to cd minecraft/backups folder"
        tarArgs=(--exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./fabric.jar')
        IFS=','
        read -ra ADDR <<< "$NoBackup"
        for i in "${ADDR[@]}"; do
            tarArgs+=(--exclude="./$i")
        done
        tarArgs+=(-pvcf backups/$(date +%Y.%m.%d.%H.%M.%S).tar.gz ./*)
        tar "${tarArgs[@]}"
    fi
fi

# Rotate backups
if [ -d /minecraft/backups ]; then
    Rotate=$(
        pushd /minecraft/backups
        ls -1tr | head -n -$BackupCount | xargs -d '\n' rm -f --
        popd
    )
fi

# Copy config files if this is a brand new server
if [ ! -e "/minecraft/bukkit.yml" ]; then
    cp /scripts/bukkit.yml /minecraft/bukkit.yml
fi
if [ ! -e "/minecraft/config/paper-global.yml" ]; then
    cp /scripts/paper-global.yml /minecraft/config/paper-global.yml
fi
if [ ! -e "/minecraft/server.properties" ]; then
    cp /scripts/server.properties /minecraft/server.properties
fi
if [ ! -e "/minecraft/config/Geyser-Fabric/config.yml" ]; then
    cp /scripts/config.yml /minecraft/config/Geyser-Fabric/config.yml
fi

# Test internet connectivity first
# Update paperclip.jar
echo "Updating to most recent fabric version ..."

# Test internet connectivity first
if [ -z "$QuietCurl" ]; then
    curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -s https://fabricmc.net -o /dev/null
else
    curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -s https://fabricmc.net -o /dev/null
fi

if [ "$?" != 0 ]; then
    echo "Unable to connect to update website (internet connection may be down).  Skipping update ..."
else
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/fabric.jar "https://meta.fabricmc.net/v2/versions/loader/1.21/0.15.11/1.0.1/server/jar"
    fi

    # Update Floodgate
    echo "Updating Floodgate..."
    if [ -z "$QuietCurl" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Floodgate-Fabric.jar "https://cdn.modrinth.com/data/bWrNNfkb/versions/yL5NRQ1i/Floodgate-Fabric-2.2.3-SNAPSHOT%2Bbuild.30.jar"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Floodgate-Fabric.jar "https://cdn.modrinth.com/data/bWrNNfkb/versions/yL5NRQ1i/Floodgate-Fabric-2.2.3-SNAPSHOT%2Bbuild.30.jar"
    fi

    # Update Fabric API
    echo "Updating Fabric API..."
    if [ -z "$QuietCurl" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Fabric-API.jar "https://www.curseforge.com/minecraft/mc-mods/fabric-api/files/5577526"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Fabric-API.jar "https://www.curseforge.com/minecraft/mc-mods/fabric-api/files/5577526"
    fi

    # Update Geyser
    echo "Updating Geyser..."
    if [ -z "$QuietCurl" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Geyser-Fabric.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/fabric"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/mods/Geyser-Fabric.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/fabric"
    fi

    if [ -z "$NoViaVersion" ]; then
        # Update ViaVersion if new version is available
        ViaVersionVersion=$(curl --no-progress-meter -k -L -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/ | grep 'href="ViaVersion' | cut -d'"' -f2)
        if [ -n "$ViaVersionVersion" ]; then
            ViaVersionMD5=$(curl --no-progress-meter -k -L -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion/*fingerprint*/" | grep breadcrumbs | cut -d'_' -f24- | cut -d'<' -f2 | cut -d'>' -f2)
            if [ -n "$ViaVersionMD5" ]; then
                LocalMD5=$(md5sum plugins/ViaVersion.jar | cut -d' ' -f1)
                if [ -e /minecraft/plugins/ViaVersion.jar ] && [ "$LocalMD5" = "$ViaVersionMD5" ]; then
                    echo "ViaVersion is up to date"
                else
                    echo "Updating ViaVersion..."
                    if [ -z "$QuietCurl" ]; then
                        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion"
                    else
                        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion"
                    fi
                fi
            else
                echo "Unable to check for updates to ViaVersion!"
            fi
        fi
    else
        echo "ViaVersion is disabled -- skipping"
    fi

# Accept EULA
AcceptEULA=$(echo eula=true >eula.txt)

# Change ports in server.properties
sed -i "/server-port=/c\server-port=$Port" /minecraft/server.properties
sed -i "/query\.port=/c\query\.port=$Port" /minecraft/server.properties
# Change Bedrock port in Geyser config
if [ -e /minecraft/config/Geyser-Fabric/config.yml ]; then
    sed -i -z "s/  port: [0-9]*/  port: $BedrockPort/" /minecraft/config/Geyser-Fabric/config.yml
fi

# Start server
echo "Starting Minecraft server..."

if [[ -z "$MaxMemory" ]] || [[ "$MaxMemory" -le 0 ]]; then
    exec java -XX:+UnlockDiagnosticVMOptions -XX:-UseAESCTRIntrinsics -DPaper.IgnoreJavaVersion=true -Xms400M -jar /minecraft/fabric.jar
else
    exec java -XX:+UnlockDiagnosticVMOptions -XX:-UseAESCTRIntrinsics -DPaper.IgnoreJavaVersion=true -Xms400M -Xmx${MaxMemory}M -jar /minecraft/fabric.jar
fi

# Exit container
exit 0
