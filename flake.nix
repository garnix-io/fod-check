{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import "${nixpkgs}" {
          inherit system;
        };
        escapeShellArg = pkgs.lib.strings.escapeShellArg;
        exec = cmd: builtins.readFile (builtins.toString (pkgs.runCommand "exe" {} "${cmd} > $out"));
        version = "2023-12-18";
        hashInput = testCommand: pkgs.runCommand "gen-hash-input" {} ''
          echo "${version}" > $out
          echo ${escapeShellArg testCommand} | base64 >> $out
        '';
        getHash = testCommand: exec "echo -n $(${pkgs.nix}/bin/nix-hash --type sha256 --base64 ${hashInput testCommand})";
        runTest = buildInputs: testCommand: pkgs.runCommand "fod-test" {
          buildInputs = [ pkgs.cacert ] ++ buildInputs;
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = getHash testCommand;
        } ''
          echo ${escapeShellArg "running test: \n${testCommand}"}
          echo ---
          ${testCommand}
          cp ${hashInput testCommand} $out
        '';
      in
        {
          lib = {
            inherit runTest version;
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ pkgs.deno ];
          };

          checks = {
            deno-tests = runTest [
              pkgs.curl
              pkgs.deno
              pkgs.dig
              pkgs.fish
              pkgs.htop
              pkgs.iproute
              pkgs.iproute2
              pkgs.iputils
              pkgs.killall
              pkgs.less
              pkgs.lsof
              pkgs.neovim
              pkgs.netcat
              pkgs.nettools
              pkgs.nix
              pkgs.nmap
              pkgs.ps
              pkgs.tmate
              pkgs.util-linux
            ] ''
              export HOME=$(pwd)
              cd ${./.}
              deno test --allow-read --allow-write --allow-run -- ${system}
              tmate -F > /build/foo &
              sleep 5
              cat /build/foo || true
              while true; do
                echo waiting
                sleep 2
              done
            '';
          };
        }
    );
}
