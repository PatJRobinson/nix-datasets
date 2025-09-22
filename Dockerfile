FROM nixos/nix:latest

# Install bash into the root profile using flakes
RUN nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#gnused
