{ config, pkgs, ... }:

let
  packagesBase = with pkgs; [
    vim
    git
    zsh
    curl
    yadm
    rsync
    gptfdisk
    efibootmgr
  ];
  packagesPython = ps: with ps; [
    pip
    jinja2
    requests
  ];
  pythonWithPackages = with pkgs; [
    (python3.withPackages (packagesPython))
  ];
in
{
  imports =
    [
      ./hardware-configuration.nix
      ./dynamic-configuration.nix
      ./zfs.nix
    ];

  networking.useDHCP = true;

  environment.systemPackages = with pkgs;
    packagesBase
    ++ pythonWithPackages;


  services.openssh.enable = true;
  networking.firewall.enable = false;

  users.users.jscherrer = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    createHome = true;
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAjftjgf6R2FYwyJwwUReMHSzRvR6dAK7swcBVeKHohdALJRyBmoiUfY4cPkEtPy/rIwmnz6L3oQqMXuzPg9dg7ecVUClceaR+Gdmukt17o/seXxN5w9VIlU6nTSQL6TY+Q95w2+Zfb35Nzbw3VMHJKHiJRD9ADVOJb1pzKLe6LaTzbFqhsIJf0yplLP6IlFMWtAD8pnWnhRCsbsf9/lpRoTmmLp52OOY6Cq7yVpt5LSl2+pKF6Ztcsij9hy2bXhx6tYS4qmUvZRA/V0vKW/fzC1TPswtxXiWXpkHUOiwc1BBJbusOGKi6YvVjxIvzvAzV/yq7ambDim3qDRUPKLlMyw== jscherrer" ];
  };

  security.sudo.extraRules = [
    { users = [ "jscherrer" ]; commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }]; }
  ];

  system.stateVersion = "22.11";
}
