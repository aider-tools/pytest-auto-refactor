# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04
LABEL version="1.0"
LABEL description="Ansible environment with Python 3.12"
LABEL "com.github.actions.name"="Pytest Github Action for aider development"
LABEL "com.github.actions.description"="A Github action of image for fixing pytest and pylint failures for a github repo."
LABEL "com.github.actions.icon"="box"
LABEL "com.github.actions.color"="green"

LABEL "repository"="https://github.com/aider-tools/pytest-auto-refactor.git"
LABEL "homepage"="https://github.com/aider-tools/pytest-auto-refactor"
LABEL "maintainer"="Tosin Akinosho <tosin.akinosho@gmail.com>"


# Set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive

# Install software-properties-common to get add-apt-repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common \
    gnupg \
    ca-certificates

# Add deadsnakes PPA for Python 3.12
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update

# Install Python 3.12 and other dependencies
RUN apt-get install -y --no-install-recommends \
    apt-utils \
    build-essential \
    locales \
    libffi-dev \
    libssl-dev \
    libyaml-dev \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3-setuptools \
    python3-pip \
    python3-apt \
    python3-yaml \
    git \
    curl \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libglib2.0-0 \
    sudo \
    iproute2 && \
    rm -Rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man && \
    apt-get clean

# Set python3 to point to Python 3.12
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Fix potential UTF-8 errors
RUN locale-gen en_US.UTF-8

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install Python packages
RUN python3 -m venv /opt/qauser-venv \
    && /opt/qauser-venv/bin/pip install --upgrade pip \
    && /opt/qauser-venv/bin/pip install --no-cache-dir \
        pylint \
        pytest \
        pytest-html \
        aider-chat \
        aider \
        playwright \
        pytest-playwright \
    && /opt/qauser-venv/bin/python -m playwright install --with-deps chromium

# Add virtual environment to PATH
ENV PATH="/opt/qauser-venv/bin:$PATH"

# Create `qauser` user with sudo permissions
RUN set -xe \
    && useradd -m  qauser \
    && echo "qauser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/qauser \
    && chmod 0440 /etc/sudoers.d/qauser \
    && mkdir -p /workspace \
    && chown -R qauser:qauser  /workspace \
    && chown -R qauser:qauser /opt/qauser-venv \
    &&  chmod -R u+w /opt/qauser-venv

    

# Set working directory
WORKDIR /qauser

# Switch to 'qauser' user
USER qauser

# Switch to the `qauser` user
USER qauser

COPY entrypoint.sh /opt/qauser-venv/bin
COPY create-tests.sh /opt/qauser-venv/
COPY fix-pylint-issues.sh /opt/qauser-venv/bin
# COPY versions.sh /opt/qauser-venv/bin

ENTRYPOINT ["entrypoint.sh"]