#!/bin/bash

# Default Variables
RELEASE_URL="https://api.github.com/repos/chrislusf/seaweedfs/releases/latest"
INSTALL_DIR="$HOME/seaweedfs"
S3_FOLDER="$HOME/s3_bucket"
S3_PORT="8333"
PROFILE_FILE="$HOME/.bashrc"  # Change this to .zshrc if you are using Zsh

# Function to display usage information
usage() {
    echo "Usage: $0 [-i INSTALL_DIR] [-s S3_FOLDER] [-p S3_PORT] [-f PROFILE_FILE]"
    echo "  -i INSTALL_DIR    Directory to install SeaweedFS (default: $HOME/seaweedfs)"
    echo "  -s S3_FOLDER      S3 folder (default: $HOME/s3_bucket)"
    echo "  -p S3_PORT        S3 port (default: 8333)"
    echo "  -f PROFILE_FILE   Profile file to update PATH (default: $HOME/.bashrc)"
    exit 1
}

# Parse command-line options
while getopts "i:s:p:f:" opt; do
    case "${opt}" in
        i)
            INSTALL_DIR=${OPTARG}
            ;;
        s)
            S3_FOLDER=${OPTARG}
            ;;
        p)
            S3_PORT=${OPTARG}
            ;;
        f)
            PROFILE_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

# Get the download URLs for the latest linux_amd64.tar.gz binary and its md5 checksum
DL_TAR=$(curl -sL $RELEASE_URL | grep "browser_download_url" | grep "linux_amd64.tar.gz" | cut -d '"' -f 4)
DL_MD5=$(curl -sL $RELEASE_URL | grep "browser_download_url" | grep "linux_amd64.tar.gz.md5" | cut -d '"' -f 4)

if [ -z "$DL_TAR" ] || [ -z "$DL_MD5" ]; then
    echo "Failed to get the download URLs for the latest release."
    exit 1
fi

echo "Release URL: $RELEASE_URL"
echo "Download URL (tar.gz): $DL_TAR"
echo "Download URL (md5): $DL_MD5"

# Create installation directory
mkdir -p $INSTALL_DIR

# Download the files
curl -L $DL_TAR -o /tmp/seaweedfs.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download SeaweedFS."
    exit 1
fi

curl -L $DL_MD5 -o /tmp/seaweedfs.tar.gz.md5
if [ $? -ne 0 ]; then
    echo "Failed to download SeaweedFS md5 checksum."
    exit 1
fi

# Extract the MD5 checksum value from the .md5 file
EXPECTED_MD5=$(awk '{ print $1 }' /tmp/seaweedfs.tar.gz.md5)

# Calculate the MD5 checksum of the downloaded tar.gz file
ACTUAL_MD5=$(md5sum /tmp/seaweedfs.tar.gz | awk '{ print $1 }')

# Compare the checksums
if [ "$EXPECTED_MD5" == "$ACTUAL_MD5" ]; then
    echo "MD5 checksum is correct."
else
    echo "MD5 checksum does not match."
    rm /tmp/seaweedfs.tar.gz
    rm /tmp/seaweedfs.tar.gz.md5
    exit 1
fi

# Extract SeaweedFS
gunzip -f /tmp/seaweedfs.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to gunzip SeaweedFS."
    rm /tmp/seaweedfs.tar.gz
    rm /tmp/seaweedfs.tar.gz.md5
    exit 1
fi

tar -xf /tmp/seaweedfs.tar -C $INSTALL_DIR
if [ $? -ne 0 ]; then
    echo "Failed to extract SeaweedFS."
    rm /tmp/seaweedfs.tar.gz
    rm /tmp/seaweedfs.tar.gz.md5
    exit 1
fi

# Set executable permissions
chmod +x $INSTALL_DIR/weed

# Add the executable to the PATH
if ! grep -q "$INSTALL_DIR" "$PROFILE_FILE"; then
    echo "export PATH=\$PATH:$INSTALL_DIR" >> $PROFILE_FILE
    echo "Added $INSTALL_DIR to PATH in $PROFILE_FILE."
else
    echo "$INSTALL_DIR is already in the PATH."
fi

# Create the S3 folder if it doesn't exist
mkdir -p $S3_FOLDER

echo "SeaweedFS has been installed successfully to $INSTALL_DIR"
echo "Please restart your terminal or run 'source $PROFILE_FILE' to update your PATH."