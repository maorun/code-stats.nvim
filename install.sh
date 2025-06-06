#!/bin/bash

# OS detection
CURRENT_OS="unknown"
if [[ "$(uname)" == "Linux" ]]; then
    CURRENT_OS="linux"
elif [[ "$(uname)" == "Darwin" ]]; then
    CURRENT_OS="macos"
elif [[ -n "${OS}" && "${OS}" == "Windows_NT" ]]; then # Check common env var for Windows
    CURRENT_OS="windows"
elif [[ -n "${OSTYPE}" && "${OSTYPE}" == "msys" ]]; then # Check for Git Bash
    CURRENT_OS="windows"
elif [[ -n "${OSTYPE}" && "${OSTYPE}" == "cygwin" ]]; then # Check for Cygwin
    CURRENT_OS="windows"
fi

if [[ "${CURRENT_OS}" == "windows" ]]; then
    echo "Automatic installation of Cargo and Luarocks is not supported on Windows. Please install them manually from https://rustup.rs/ and https://luarocks.org/wiki/rock/Installation"
    exit 0
fi

echo "Checking for Neovim..."
if command -v nvim &> /dev/null
then
    echo "Neovim is already installed."
    nvim --version
else
    echo "Neovim not found. Proceeding with installation attempts..."
    if [[ "${CURRENT_OS}" == "linux" ]]; then
       echo "Attempting to install Neovim for Linux..."
       # Try package managers first
       if command -v apt-get &> /dev/null; then
           echo "Attempting installation via apt-get..."
           sudo apt-get update && sudo apt-get install -y neovim
       elif command -v yum &> /dev/null; then
           echo "Attempting installation via yum..."
           sudo yum install -y neovim
       fi

       # Check if Neovim was installed by package manager
       if command -v nvim &> /dev/null; then
           echo "Neovim installed successfully via package manager."
           nvim --version
       else
           echo "ERROR: Neovim could not be installed via apt-get or yum." >&2
           echo "Please install Neovim manually and re-run this script." >&2
           exit 1
       fi
   elif [[ "${CURRENT_OS}" == "macos" ]]; then # This is the new block to add/fill
       echo "Attempting to install Neovim for macOS..."
       # Try Homebrew first
       if command -v brew &> /dev/null; then
           echo "Attempting installation via Homebrew..."
           brew install neovim
       else
           echo "Homebrew not found. Skipping Homebrew installation."
       fi

       # Check if Neovim was installed by Homebrew
       if command -v nvim &> /dev/null; then
           echo "Neovim installed successfully via Homebrew."
           nvim --version
       else
           echo "ERROR: Neovim could not be installed via Homebrew." >&2
           echo "Please ensure Homebrew is installed and working, then install Neovim manually (e.g., 'brew install neovim') and re-run this script." >&2
           exit 1
       fi
   else
       echo "ERROR: Automated Neovim installation is not configured for ${CURRENT_OS} in this script." >&2
       echo "Please install Neovim manually and re-run this script." >&2
       exit 1
   fi
fi

echo "Starting development environment setup..."

# Check for Luarocks
if ! command -v luarocks &> /dev/null
then
    if [[ "${CURRENT_OS}" == "linux" ]]; then
        echo "Luarocks not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y luarocks
        elif command -v yum &> /dev/null; then
            sudo yum install -y luarocks
            # Add a note about potential package name variations for yum
            if ! command -v luarocks &> /dev/null; then
                 echo "Luarocks installation with 'yum install luarocks' may have failed due to package name variations (e.g., lua-luarocks). Trying 'sudo yum install -y lua-luarocks'."
                 sudo yum install -y lua-luarocks
            fi
        else
            echo "Could not find apt-get or yum. Please install Luarocks manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        fi

        if ! command -v luarocks &> /dev/null; then
            echo "Luarocks installation failed. Please install manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        else
            echo "Luarocks installed successfully."
        fi
    elif [[ "${CURRENT_OS}" == "macos" ]]; then
        echo "Luarocks not found. Attempting to install via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install Homebrew first (see https://brew.sh/) and then install Luarocks manually or re-run this script."
            exit 1
        fi
        brew install luarocks
        if ! command -v luarocks &> /dev/null; then
            echo "Luarocks installation via Homebrew failed. Please install manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        else
            echo "Luarocks installed successfully."
        fi
    else
        # Fallback for other OSes (though Windows is handled earlier)
        echo "Luarocks not found. Please install Luarocks from https://luarocks.org/wiki/rock/Installation"
        exit 1
    fi
fi

echo "Installing stylua from GitHub release..."
# Ensure curl and unzip are installed for Linux package managers
if [[ "${CURRENT_OS}" == "linux" ]]; then
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl unzip
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl unzip
    else
        echo "apt-get or yum not found. Cannot automatically install curl and unzip. Please install them manually if stylua download fails."
    fi
elif [[ "${CURRENT_OS}" == "macos" ]]; then
    # On macOS, curl and unzip are generally pre-installed.
    # If Homebrew is used, it could also be a dependency of other packages.
    if ! command -v curl &> /dev/null || ! command -v unzip &> /dev/null; then
        echo "curl or unzip not found on macOS. Please install them (e.g., via Homebrew if available, or manually) if stylua download fails."
    fi
fi


STYLUA_VERSION="v2.1.0" # Using a fixed version from the original script
# Determine artifact name based on OS
STYLUA_ARTIFACT_NAME=""
if [[ "${CURRENT_OS}" == "linux" ]]; then
    STYLUA_ARTIFACT_NAME="stylua-linux-x86_64.zip"
elif [[ "${CURRENT_OS}" == "macos" ]]; then
    # Assuming x86_64 for macOS, adjust if Apple Silicon specific build is preferred/available
    STYLUA_ARTIFACT_NAME="stylua-macos-x86_64.zip"
else
    echo "Unsupported OS for stylua automatic download: ${CURRENT_OS}"
    # Optionally, exit or let it try to proceed if user installs manually
fi

if [[ -n "$STYLUA_ARTIFACT_NAME" ]]; then
    STYLUA_DOWNLOAD_URL="https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/${STYLUA_ARTIFACT_NAME}"
    # Try to use a more robust path for binaries, like ~/.local/bin or ensure ~/.luarocks/bin is in PATH
    # For consistency with luarocks, we'll keep ~/.luarocks/bin
    # However, ensure this directory is typically in PATH. Luarocks usually handles this.
    STYLUA_BIN_DIR="$HOME/.luarocks/bin"

    # Create the target bin directory if it doesn't exist
    mkdir -p "${STYLUA_BIN_DIR}"

    echo "Downloading stylua from ${STYLUA_DOWNLOAD_URL}..."
    if curl -L "${STYLUA_DOWNLOAD_URL}" -o "/tmp/${STYLUA_ARTIFACT_NAME}"; then
        echo "Unzipping stylua..."
        # Unzip and place directly into STYLUA_BIN_DIR, then chmod.
        # This avoids potential issues with mv across filesystems or if /tmp/stylua already exists.
        if unzip -o "/tmp/${STYLUA_ARTIFACT_NAME}" -d "${STYLUA_BIN_DIR}"; then
            # The binary inside the zip is just 'stylua'
            chmod +x "${STYLUA_BIN_DIR}/stylua"
            echo "stylua installed successfully to ${STYLUA_BIN_DIR}/stylua"
        else
            echo "Failed to unzip stylua to ${STYLUA_BIN_DIR}."
            # Attempt cleanup of downloaded file if unzip failed
            rm -f "/tmp/${STYLUA_ARTIFACT_NAME}"
        fi
    else
        echo "Failed to download stylua."
    fi
    # Clean up zip regardless of unzip success, if download was attempted
    if [[ -f "/tmp/${STYLUA_ARTIFACT_NAME}" ]]; then
        rm -f "/tmp/${STYLUA_ARTIFACT_NAME}"
    fi
else
    echo "Skipping stylua download due to unsupported OS or artifact name not set."
fi


echo "Verifying stylua installation..."
if command -v stylua &> /dev/null; then
    stylua --version
else
    echo "stylua command not found after installation attempt. Ensure ${STYLUA_BIN_DIR} is in your PATH."
    echo "You might need to source your shell profile (e.g., source ~/.bashrc, source ~/.zshrc) or open a new terminal."
fi

echo "Installing vusted for Lua 5.1..."
# Using --local to install into the user's directory, which is generally safer and doesn't require sudo.
# The CI environment handles its paths, for local setup --local is good.
if ! luarocks install --local vusted --lua-version=5.1; then
    echo "Failed to install vusted for Lua 5.1 with --local."
    echo "Attempting global install for vusted (may require sudo)..."
    if ! sudo luarocks install vusted --lua-version=5.1; then
        echo "Global installation of vusted also failed."
        echo "Please check Luarocks configuration and try manually."
    else
        echo "Vusted installed globally."
    fi
fi

echo "Installing inspect..."
if ! luarocks install --local inspect; then
    echo "Failed to install inspect with --local."
    echo "Attempting global install for inspect (may require sudo)..."
    if ! sudo luarocks install inspect; then
        echo "Global installation of inspect also failed."
        echo "Please check Luarocks configuration and try manually."
    else
        echo "Inspect installed globally."
    fi
fi

echo "Development environment setup complete!"
echo "Please ensure $HOME/.luarocks/bin is in your PATH to use stylua and other Lua binaries."
echo "You may need to add 'export PATH=\$HOME/.luarocks/bin:\$PATH' to your shell configuration file (e.g., .bashrc, .zshrc)."
