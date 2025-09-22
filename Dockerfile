FROM nixos/nix:latest

# Install bash into the root profile using flakes
RUN nix-shell -p bash
