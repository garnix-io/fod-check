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
          requiredSystemFeatures = ["recursive-nix"];
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
            tmatefodtest = runTest [
              pkgs.dig
              pkgs.fish
              pkgs.htop
              pkgs.iproute
              pkgs.killall
              pkgs.less
              pkgs.netcat
              pkgs.nettools
              pkgs.nix
              pkgs.nmap
              pkgs.ps
              pkgs.tmate
              pkgs.util-linux
            ] "touch tmate.out\nscript --return --quiet --command tmate tmate.out &\ntail -f tmate.out";
            passTest = runTest [] "true";
            deno-tests = runTest [pkgs.deno pkgs.nix] ''
              export HOME=$(pwd)
              cd ${./.}
              deno test --allow-read --allow-write --allow-run -- ${system}
            '';
          };
        }
    );
}
