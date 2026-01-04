{
  description = "clawdbot plugin: bird";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    root.url = "path:../..";
  };

  outputs = { self, nixpkgs, root }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      bird = root.packages.${system}.bird;
    in {
      packages.${system}.bird = bird;

      clawdbotPlugin = {
        name = "bird";
        skills = [ ./skills/bird ];
        packages = [ bird ];
        needs = {
          stateDirs = [];
          requiredEnv = [];
        };
      };
    };
}
