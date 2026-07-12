# --- Configuration ---
KATAGO_LINK="https://github.com/lightvector/KataGo/releases/download/v1.16.4/katago-v1.16.4-cuda12.8-cudnn9.8.0-linux-x64.zip"
KATAGO_NETWORK_LINK="https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-b28c512nbt-adam-s11165M-d5387M.bin.gz"

# Define paths for clarity and conditional checks
KATAGO_DIR="/workspace/katago"
KATAGO_ZIP_PATH="/workspace/katago.zip"
KATAGO_WEIGHT_PATH="$KATAGO_DIR/weight.bin.gz"
KATAGO_EXECUTABLE_PATH="$KATAGO_DIR/katago"
KATAGO_APPRUN_DIR="$KATAGO_DIR/squashfs-root"
KATAGO_CONFIG_PATH="$KATAGO_DIR/gtp.cfg"

# --- 1. Download KataGo Zip ---
if [ -f "$KATAGO_ZIP_PATH" ]; then
    echo "KataGo zip already exists at $KATAGO_ZIP_PATH. Skipping download."
else
    echo "Downloading KataGo executable zip (quiet mode)..."
    wget -q -O "$KATAGO_ZIP_PATH" "$KATAGO_LINK"
fi

# --- 2. Unzip and Extract KataGo ---
# Check if the primary executable file is present before attempting unzip
if [ -f "$KATAGO_EXECUTABLE_PATH" ]; then
    echo "KataGo executable found. Skipping unzip."
else
    echo "Extracting KataGo into $KATAGO_DIR..."
    mkdir -p "$KATAGO_DIR" # Ensure target directory exists
    unzip -o "$KATAGO_ZIP_PATH" -d "$KATAGO_DIR"
    # The AppImage is often extracted into a subdirectory, so we move it up for the script's sake.
    # Note: Depending on the specific zip structure, you might need to adjust the path here. 
    # Assuming 'katago' is the binary file inside the zip.
    if [ ! -f "$KATAGO_EXECUTABLE_PATH" ]; then
        echo "WARNING: Executable not found at $KATAGO_EXECUTABLE_PATH after standard unzip. Please check zip contents."
    fi
fi

# --- 3. Set Permissions and AppImage Extraction (FIXED WITH CD) ---
# This is required for AppRun to exist. We use a subshell to change directory 
# to ensure 'squashfs-root' is created inside the KataGo folder.
if [ ! -d "$KATAGO_APPRUN_DIR" ]; then
    if [ -f "$KATAGO_EXECUTABLE_PATH" ]; then
        echo "Setting executable permissions and extracting AppImage components..."
        
        # Use a subshell to safely change directory, execute commands, and return.
        (
            cd "$KATAGO_DIR" || { echo "ERROR: Cannot change directory to $KATAGO_DIR"; exit 1; }
            echo "Working directory temporarily changed to $(pwd)"
            
            # Now we use relative paths for the binary inside the subshell
            chmod +x ./katago
            ./katago --appimage-extract > /dev/null 2>&1
        )
    else
        echo "ERROR: KataGo executable not found for AppImage extraction."
    fi
else
    echo "AppImage components (squashfs-root) already extracted. Skipping extraction."
fi

# --- 4. Download KataGo Network (Weight File) ---
if [ -f "$KATAGO_WEIGHT_PATH" ]; then
    echo "KataGo weight file already exists. Skipping download."
else
    echo "Downloading KataGo network (weight file) (quiet mode)..."
    wget -q -O "$KATAGO_WEIGHT_PATH" "$KATAGO_NETWORK_LINK"
fi

# --- 5. Generate GTP Config ---
if [ -f "$KATAGO_CONFIG_PATH" ]; then
    echo "GTP config file $KATAGO_CONFIG_PATH already exists. Skipping generation."
else
    echo "Generating GTP config file..."
    if [ -f "$KATAGO_APPRUN_DIR/AppRun" ]; then
        "$KATAGO_APPRUN_DIR/AppRun" genconfig -model "$KATAGO_WEIGHT_PATH" -output "$KATAGO_CONFIG_PATH"
        echo "Config generated successfully."
    else
        echo "ERROR: AppRun executable not found. Cannot generate config."
    fi
fi

# --- Output Final Command ---
echo ""
echo "--- SETUP COMPLETE ---"
echo "LizzieYZY Engine Command (Use the -t flag to force a terminal):"
echo "ssh -t <YOURSSHID>@ssh.lightning.ai '$KATAGO_APPRUN_DIR/AppRun gtp -model $KATAGO_WEIGHT_PATH -config $KATAGO_CONFIG_PATH'"
echo ""
