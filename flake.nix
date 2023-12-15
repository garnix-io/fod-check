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
        version = "1";
        hashInput = testCommand: pkgs.runCommand "gen-hash-input" {} ''
          echo "${version}" > $out
          echo ${escapeShellArg testCommand} >> $out
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
