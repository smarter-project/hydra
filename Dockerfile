FROM debian:12

# Install required tools
RUN MACHINE_TYPE=$(uname -m | sed -e "s/arm64\|aarch64/arm/" -e "s/x86_64\|amd64/x86/");apt update -y;apt install -y qemu-system-${MACHINE_TYPE} mkisofs wget;apt clean

WORKDIR /root

# Copy the setup script
COPY initial_setup.sh .

# Make the script executable
RUN chmod +x initial_setup.sh

# Set the entrypoint
ENTRYPOINT ["./initial_setup.sh"] 
