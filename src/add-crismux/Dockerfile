FROM debian:12

# Install required tools
RUN MACHINE_TYPE=$(uname -m | sed -e "s/arm64\|aarch64/arm/" -e "s/x86_64\|amd64/x86/");apt update -y;apt clean -y 

WORKDIR /root

USER root

# Copy the setup script
COPY install_crismux.sh .

# Make the script executable
RUN chmod +x install_crismux.sh

# Set the entrypoint
ENTRYPOINT ["./install_crismux.sh"] 
