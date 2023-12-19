{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import "${nixpkgs}" {
          inherit system;
        };
        escapeShellArg = pkgs.lib.strings.escapeShellArg;
        exec = cmd: builtins.readFile (builtins.toString (pkgs.runCommand "exe" { } "${cmd} > $out"));
        version = "2023-12-18";
        hashInput = testCommand: pkgs.runCommand "gen-hash-input" { } ''
          echo "${version}" > $out
          echo ${escapeShellArg testCommand} | base64 >> $out
        '';
        getHash = testCommand: exec "echo -n $(${pkgs.nix}/bin/nix-hash --type sha256 --base64 ${hashInput testCommand})";
        runTest = buildInputs: testCommand: pkgs.runCommand "fod-test"
          {
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

        packages = {
          # networkInfo = runTest [ pkgs.nettools pkgs.iproute ] ''
          #   ip --brief address show
          #   exit 1
          # '';
          ifdTest =
            let
              waiter = pkgs.writeText "waiter" ''
                fn main() {
                  for i in 0..1000 {
                    println!("waiter: {i} 2");
                    std::thread::sleep(std::time::Duration::from_secs(1));
                  }
                }
              '';
              ifd = pkgs.runCommand "fod-in-ifd-test"
                {
                  buildInputs = [ pkgs.rustc pkgs.gcc ];
                  # outputHashMode = "recursive";
                  # outputHashAlgo = "sha256";
                  # outputHash = "sha256-iFSPu804N4Qh4x11uFnieiEUQKPmjGp3jArABb9E3Pc=";
                } ''
                rustc ${waiter} -o waiter
                ./waiter
                echo '{}' > $out
              '';
            in
            pkgs.runCommand "ifdTest" (import ifd) ''
              echo ${builtins.toJSON (import ifd)}
              echo ifdTest > $out
            '';
        };
      }
    );
}
