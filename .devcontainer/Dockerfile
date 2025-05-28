# Use the official Swift image based on Ubuntu
FROM swift:6.0-jammy

# Install additional packages needed for development
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
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user first
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install SwiftLint - pinned to specific version for reproducibility
RUN git clone https://github.com/realm/SwiftLint.git /tmp/SwiftLint \
    && cd /tmp/SwiftLint \
    && git checkout 0.57.0 \
    && swift build --configuration release \
    && cp .build/release/swiftlint /usr/local/bin/ \
    && rm -rf /tmp/SwiftLint

# Verify Swift and SwiftLint installation
RUN swift --version && swiftlint version

# Set up the workspace
WORKDIR /workspace

# Change ownership of the workspace to the vscode user
RUN chown -R $USERNAME:$USERNAME /workspace

# Switch to the non-root user
USER $USERNAME

# Set environment variables for Swift
ENV PATH="/usr/bin:$PATH"
ENV SWIFT_PATH="/usr/bin/swift"