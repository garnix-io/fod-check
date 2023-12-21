{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib.strings) escapeShellArg;

      version = "2023-12-18";
      hashAlgo = "sha256";

      hashInput = testCommand: builtins.toJSON {
        inherit version;
        inputHash = builtins.hashString hashAlgo testCommand;
      };

      getHash = testCommand:
        let
          hash = builtins.hashString hashAlgo (hashInput testCommand);
        in
        # nix >= 2.19 has builtins.convertHash
        if builtins ? convertHash
        then builtins.convertHash { inherit hash hashAlgo; toHashFormat = "sri"; }
        else hash;

      mkRunTest = pkgs: buildInputs: testCommand: pkgs.runCommand "fod-test"
        {
          buildInputs = [ pkgs.cacert ] ++ buildInputs;
          outputHashMode = "flat";
          outputHashAlgo = hashAlgo;
          outputHash = getHash testCommand;
        }
        ''
          echo ${escapeShellArg "running test: \n${testCommand}"}
          echo ---
          ${testCommand}
          echo -n ${escapeShellArg (hashInput testCommand)} > $out
        '';
    in
    (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      runFODTest = mkRunTest pkgs;
    in
    {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [ pkgs.deno ];
      };

      legacyPackages = { inherit runFODTest; };

      checks = {
        passTest = runFODTest [ ] "true";
        deno-tests = runFODTest [ pkgs.deno pkgs.nix ] ''
          export HOME=$(pwd)
          cd ${./.}
          deno test --allow-read --allow-write --allow-run -- ${system}
        '';
      };
    }))
    //
    {
      lib = { inherit version; };

      overlays.default = final: _: {
        runFODTest = mkRunTest final;
      };
    };
}
