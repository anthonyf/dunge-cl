#!/usr/bin/env bash
# VPS setup script for dunge-cl development
# Run as root on a fresh Ubuntu 24.04 Hetzner server:
#   ssh root@178.156.239.236 'bash -s' < setup-vps.sh

set -euo pipefail

echo "=== Dunge VPS Setup ==="

# Suppress needrestart interactive prompts
export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

# 1. System packages
echo "--- Installing system packages ---"
apt-get update
apt-get install -y \
    build-essential \
    git \
    tmux \
    mosh \
    curl \
    wget \
    sbcl \
    rlwrap \
    emacs-nox \
    unzip \
    zlib1g-dev \
    acl

# 2. Add GitHub host keys (for both root and dev user)
echo "--- Adding GitHub SSH host keys ---"
mkdir -p /root/.ssh
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null

# 3. Create a dev user (don't develop as root)
echo "--- Creating dev user ---"
if ! id -u dev &>/dev/null; then
    useradd -m -s /bin/bash dev
    mkdir -p /home/dev/.ssh
    cp /root/.ssh/authorized_keys /home/dev/.ssh/authorized_keys
    chown -R dev:dev /home/dev/.ssh
    chmod 700 /home/dev/.ssh
    chmod 600 /home/dev/.ssh/authorized_keys
    # Allow dev to sudo without password (for installing packages later)
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
fi

# Copy GitHub host keys to dev user
cat /root/.ssh/known_hosts >> /home/dev/.ssh/known_hosts
chown dev:dev /home/dev/.ssh/known_hosts

# Allow dev user to access the forwarded SSH agent
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
    setfacl -m u:dev:rwx "$(dirname "$SSH_AUTH_SOCK")"
    setfacl -m u:dev:rw "$SSH_AUTH_SOCK"
fi

# Clone private repos as root (where SSH agent is available), then move them
echo "--- Cloning Emacs config ---"
if [ ! -d /home/dev/.emacs.d/.git ]; then
    git clone git@github.com:anthonyf/.emacs.d.git /home/dev/.emacs.d
    chown -R dev:dev /home/dev/.emacs.d
fi

echo "--- Cloning dunge-cl ---"
if [ ! -d /home/dev/git/dunge-cl ]; then
    mkdir -p /home/dev/git
    git clone git@github.com:anthonyf/dunge-cl.git /home/dev/git/dunge-cl
    chown -R dev:dev /home/dev/git
fi

echo "--- Switching to dev user for remaining setup ---"
sudo -u dev --preserve-env=SSH_AUTH_SOCK bash << 'DEVSETUP'
set -euo pipefail

# 4. Quicklisp
echo "--- Installing Quicklisp ---"
if [ ! -d ~/quicklisp ]; then
    curl -o /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp
    sbcl --non-interactive \
         --load /tmp/quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql:add-to-init-file)'
    rm /tmp/quicklisp.lisp
fi

# 5. Qlot
echo "--- Installing Qlot ---"
if ! command -v qlot &>/dev/null; then
    curl -L https://qlot.tech/installer | bash
    echo 'export PATH="$HOME/.qlot/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.qlot/bin:$PATH"
fi

# 6. Install project dependencies
echo "--- Installing dunge-cl dependencies ---"
if [ -d ~/git/dunge-cl ] && [ ! -d ~/git/dunge-cl/.qlot ]; then
    cd ~/git/dunge-cl
    export PATH="$HOME/.qlot/bin:$PATH"
    qlot install
fi

# 7. tmux config
echo "--- Writing tmux config ---"
cat > ~/.tmux.conf << 'TMUX'
# Enable mouse support
set -g mouse on
# Increase scrollback
set -g history-limit 50000
# Better colors
set -g default-terminal "screen-256color"
# Start windows and panes at 1
set -g base-index 1
setw -g pane-base-index 1
TMUX

echo "--- Dev user setup complete ---"
DEVSETUP

# 8. Node.js (required for Claude Code)
echo "--- Installing Node.js ---"
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi

# 9. Claude Code (install as dev user)
echo "--- Installing Claude Code ---"
if ! sudo -u dev bash -c 'command -v claude' &>/dev/null; then
    sudo -u dev bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. SSH in as dev:  ssh dev@178.156.239.236"
echo "  2. Start tmux:     tmux new -s dev"
echo "  3. Run Emacs:      emacs ~/git/dunge-cl/"
echo "  4. Run Claude:     cd ~/git/dunge-cl && claude"
echo "  5. Auth Claude:    claude will prompt you to authenticate on first run"
echo ""
echo "To reconnect later:  ssh dev@178.156.239.236 -t 'tmux attach -t dev'"
