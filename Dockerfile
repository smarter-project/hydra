FROM debian:12

# Install required tools
RUN MACHINE_TYPE=$(uname -m | sed -e "s/arm64\|aarch64/arm/" -e "s/x86_64\|amd64/x86/");apt update -y;apt install -y qemu-system-${MACHINE_TYPE} mkisofs wget;apt clean

WORKDIR /root

USER root

# Copy the setup script
COPY start-vm.sh .

# Make the script executable
RUN chmod +x start-vm.sh

# Set the entrypoint
ENTRYPOINT ["./start-vm.sh"] 
