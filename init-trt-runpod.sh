# --- Configuration ---
# Updated links for TensorRT-enabled KataGo and TensorRT library
KATAGO_LINK="https://github.com/lightvector/KataGo/releases/download/v1.16.4/katago-v1.16.4-trt10.9.0-cuda12.8-linux-x64.zip"
KATAGO_NETWORK_LINK="https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-b28c512nbt-adam-s11165M-d5387M.bin.gz"
TENSORRT_LINK="https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/10.9.0/tars/TensorRT-10.9.0.34.Linux.x86_64-gnu.cuda-12.8.tar.gz"

# Define paths for clarity and conditional checks
KATAGO_DIR="/workspace/katago-trt"
KATAGO_ZIP_PATH="/workspace/katago-trt.zip"
KATAGO_WEIGHT_PATH="$KATAGO_DIR/weight.bin.gz"
KATAGO_EXECUTABLE_PATH="$KATAGO_DIR/katago"
KATAGO_APPRUN_DIR="$KATAGO_DIR/squashfs-root"
KATAGO_CONFIG_PATH="$KATAGO_DIR/gtp.cfg"
TENSORRT_DIR="/workspace/tensorrt"
TENSORRT_ZIP_PATH="/workspace/tensorrt.tar.gz"

# --- 0. Download and Extract TensorRT ---
if [ -f "$TENSORRT_ZIP_PATH" ]; then
    echo "TensorRT zip already exists at $TENSORRT_ZIP_PATH. Skipping download."
else
    echo "Downloading TensorRT zip (quiet mode)..."
    # Note: TensorRT is large, using quiet mode
    wget -q -O "$TENSORRT_ZIP_PATH" "$TENSORRT_LINK"
fi

# Check for directory existence (-d) instead of file existence
if [ -d "$TENSORRT_DIR" ]; then
    echo "TensorRT directory already exists at $TENSORRT_DIR. Skipping extraction."
else
    echo "Extracting TensorRT into $TENSORRT_DIR..."
    mkdir -p "$TENSORRT_DIR"
    # Extract silently, but show initial message
    tar -xzf "$TENSORRT_ZIP_PATH" --strip-components=1 -C "$TENSORRT_DIR"
fi
export LD_LIBRARY_PATH=$TENSORRT_DIR/lib

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
    
    if [ ! -f "$KATAGO_EXECUTABLE_PATH" ]; then
        echo "WARNING: Executable not found at $KATAGO_EXECUTABLE_PATH after standard unzip. Please check zip contents."
    fi
fi

# --- 3. Set Permissions and AppImage Extraction ---
# This is required for AppRun to exist.
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
    # Note: TensorRT might still be required for genconfig if the AppRun binary links against it
    fi
fi

# --- Output Final Command ---
# CRITICAL: LD_LIBRARY_PATH must be set on the remote machine before the KataGo command
echo ""
echo "--- SETUP COMPLETE ---"
echo "LizzieYZY Engine Command (Use the -t flag to force a terminal):"
echo "ssh -t <YOURSSHID>@ssh.lightning.ai 'LD_LIBRARY_PATH=$TENSORRT_DIR/lib $KATAGO_APPRUN_DIR/AppRun gtp -model $KATAGO_WEIGHT_PATH -config $KATAGO_CONFIG_PATH'"
echo ""
