# Use the official Swift image based on Ubuntu
FROM swift:6.0-jammy

# Create a non-root user first
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# Install additional packages and create user in single layer
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    build-essential \
    pkg-config \
    libedit-dev \
    libxml2-dev \
    libsqlite3-dev \
    libncurses5-dev \
    zlib1g-dev \
    sudo \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Verify Swift installation
RUN swift --version

# Set up the workspace to match VS Code dev container path
WORKDIR /workspaces/FeLangKit

# Change ownership of the workspace to the vscode user
RUN chown -R $USERNAME:$USERNAME /workspaces/FeLangKit

# Switch to the non-root user
USER $USERNAME

# Set environment variables for Swift
ENV PATH="/usr/bin:$PATH"
ENV SWIFT_PATH="/usr/bin/swift"