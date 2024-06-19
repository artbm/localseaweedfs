# SeaweedFS Installation Script

This repository contains a bash script to install and configure [SeaweedFS](https://github.com/chrislusf/seaweedfs), a distributed storage system. The script automates the process of downloading the latest release of SeaweedFS, verifying its integrity, and setting up the necessary directories and environment variables.

## Features

- Downloads the latest release of SeaweedFS.
- Verifies the integrity of the downloaded files using MD5 checksums.
- Sets up installation and S3 directory.
- Optionally updates the system's PATH to include the SeaweedFS binary.
- Generates a startup script for easy execution of the SeaweedFS server.

## Usage

### Prerequisites

Ensure that the following commands are available on your system:
- `curl`
- `tar`
- `md5sum`

### Running the Script

You can run the script with various options to customize the installation. Below are the available options:

- `-i install_dir`: Directory to install SeaweedFS (default: `${HOME}/seaweedfs`).
- `-s s3_dir`: S3 directory to serve (default: `${HOME}/s3_bucket`).
- `-c`: Cleanup installation directory.
- `-p update_path`: Update PATH with the new binary (default: `yes`).
- `-d`: Proceed with the default configuration.
- `-h`: Display help message.

#### Example Commands

1. Proceed with the default configuration:
    ```sh
    sh setup.sh -d
    ```

2. Install SeaweedFS to a custom directory and specify an S3 directory:
    ```sh
    sh setup.sh -i /custom/path/seaweedfs -s /custom/path/s3_bucket
    ```

3. Cleanup the installation directory:
    ```sh
    sh setup.sh -c
    ```

### Generated Files

- **Startup Script**: A script named `start_seaweeds3.sh` will be generated in the parent directory of the specified S3 directory. This script can be used to start the SeaweedFS S3 server with the configured options.
- **Version File**: A file named `seaweedfs_version` will be created in the installation directory to keep track of the installed SeaweedFS version.
