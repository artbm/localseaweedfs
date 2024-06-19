#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
release_url="https://api.github.com/repos/chrislusf/seaweedfs/releases/latest"
install_dir="${HOME}/seaweedfs"
s3_dir="${HOME}/s3_bucket"
startup_script="$(dirname "${s3_dir}")/start_seaweeds3.sh"
profile_file="${HOME}/.${SHELL##*/}rc" # e.g., ~/.bashrc, ~/.zshrc
tmp_dir="${install_dir}/tmp"
version_file="${install_dir}/seaweedfs_version"
startup_command="weed server -s3 -dir=${s3_dir}"
update_path="yes"
use_default="no"

# --- Functions ---

# Function to display usage information
usage() {
    echo "Usage: $0 [-i install_dir] [-s s3_dir] [-h] [-c] [-p update_path] [-d]"
    echo "  -i install_dir    Directory to install SeaweedFS (default: ${install_dir})"
    echo "  -s s3_dir         S3 directory to serve (default: ${s3_dir})"
    echo "  -c                Cleanup installation directory: ${install_dir}"
    echo "  -p update_path    Update PATH with the new binary (default: ${update_path})"
    echo "  -d                Proceed with the default configuration"
    echo "  -h                Display this help message"
    exit 1
}

# Function to handle errors
error_exit() {
    echo "Error: $1" >&2
    cleanup_tmp
    exit 1
}

# Function to cleanup temporary files and directories
cleanup_tmp() {
    if [ -d "${tmp_dir}" ]; then
        find "${tmp_dir}" -type f | xargs echo
        rm -rf "${tmp_dir}" "${startup_script}"
    fi
}

# Function to cleanup the installation directory
cleanup_install() {
    if [ -d "${install_dir}" ]; then
        rm -rf "${install_dir}"
        echo "Installation directory ${install_dir} has been removed."
    else
        echo "Installation directory ${install_dir} does not exist."
    fi
    exit 0
}

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: Command '$1' not found. Please install it." >&2
        exit 1
    }
}

# Function to download a file with progress
download_file() {
    local url="$1"
    local output_file="$2"
    curl -L -# "${url}" -o "${output_file}" || error_exit "Failed to download ${url}"
}

# Function to generate and display the startup command
generate_startup_command() {
    local startup_script="$(dirname "${s3_dir}")/start_seaweedfs.sh"
    echo "${startup_command}" >"${startup_script}"
    chmod +x "${startup_script}" || error_exit "Failed to create startup script."
    echo "To start SeaweedFS, run the following:"
    echo "${startup_script}"
}

# --- Main Script ---

# Check for required commands
check_command curl
check_command tar
check_command md5sum

# Parse command-line options
if [ "$#" -eq 0 ]; then
    usage
fi

while getopts "i:s:chdp:" opt; do
    case "${opt}" in
    i)
        install_dir="${OPTARG}"
        ;;
    s)
        s3_dir="${OPTARG}"
        generate_startup_command
        ;;
    c)
        cleanup_install
        ;;
    d)
        use_default="yes"
        ;;
    p)
        update_path="${OPTARG}"
        ;;
    h)
        usage
        ;;
    *)
        echo "Unknown argument ${opt}"
        usage
        ;;
    esac
done

# Ensure the creation of necessary directories even with the default configuration
if [ ! -d "${install_dir}" ]; then
    mkdir -p "${install_dir}" || error_exit "Failed to create installation directory."
fi

# Create temporary directory
mkdir -p "${tmp_dir}" || error_exit "Failed to create temporary directory."

# Create the S3 folder if it doesn't exist
if [ ! -d "${s3_dir}" ]; then
    mkdir -p "${s3_dir}" || error_exit "Failed to create S3 folder."
fi

# Get the latest release information
echo "Fetching latest release information..."
release_info=$(curl -sL "${release_url}")

# Extract information using string manipulation (less robust)
latest_version=$(echo "${release_info}" | grep -o '"tag_name": "[^"]*"' | cut -d '"' -f 4)
download_tar=$(echo "${release_info}" | grep -o '"browser_download_url": *"https.*linux_amd64.tar.gz"' | cut -d '"' -f 4)
download_md5=$(echo "${release_info}" | grep -o '"browser_download_url": *"https.*linux_amd64.tar.gz.md5"' | cut -d '"' -f 4)

if [ -z "${latest_version}" ] || [ -z "${download_tar}" ] || [ -z "${download_md5}" ]; then
    error_exit "Failed to get the necessary information from the latest release."
fi

# Check if the latest version is already installed
if [ -f "${version_file}" ] && [ "$(cat "${version_file}")" == "${latest_version}" ]; then
    echo "SeaweedFS is already up to date (version ${latest_version})."
    generate_startup_command
    cleanup_tmp
    exit 0
fi

echo "Latest version: ${latest_version}"

# Download the files
echo "Downloading SeaweedFS..."
download_file "${download_tar}" "${tmp_dir}/seaweedfs.tar.gz"
echo "Downloading MD5 checksum..."
download_file "${download_md5}" "${tmp_dir}/seaweedfs.tar.gz.md5"

# Verify checksum before extraction
expected_md5=$(awk '{ print $1 }' "${tmp_dir}/seaweedfs.tar.gz.md5")
actual_md5=$(md5sum "${tmp_dir}/seaweedfs.tar.gz" | awk '{ print $1 }')

if [ "${expected_md5}" != "${actual_md5}" ]; then
    error_exit "MD5 checksum does not match."
else
    echo "MD5 checksum verified."
fi

# Extract SeaweedFS
echo "Extracting SeaweedFS..."
tar -xzf "${tmp_dir}/seaweedfs.tar.gz" -C "${install_dir}" || error_exit "Failed to extract SeaweedFS."

# Clean up temporary directory
cleanup_tmp

# Set executable permissions
chmod +x "${install_dir}/weed" || error_exit "Failed to set executable permissions."

# Add the executable to the PATH if update_path is yes
if [ "${update_path}" == "yes" ]; then
    if ! grep -q "${install_dir}" "${profile_file}"; then
        echo "export PATH=\$PATH:${install_dir}" >>"${profile_file}"
        echo "Added ${install_dir} to PATH in ${profile_file}."
        source ${profile_file}
    else
        echo "${install_dir} is already in the PATH."
    fi
else
    echo "Skipped updating PATH."
fi

# Store the latest version in the version file
echo "${latest_version}" >"${version_file}"
echo "SeaweedFS has been installed successfully to ${install_dir}"
generate_startup_command # Display the startup command again at the end