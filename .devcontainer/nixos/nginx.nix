# nginx.nix
{ lib, pkgs, ... }:

{
  services.nginx.enable = true;
  services.nginx.virtualHosts."127.0.0.1" = {
    root = "/web";
  };

  environment.systemPackages = [
    pkgs.bash
  ];



  networking = {
    useHostResolvConf = lib.mkForce false;
  };
}
