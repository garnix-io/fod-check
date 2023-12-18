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

        checks = {
          # networkInfo = runTest [ pkgs.nettools pkgs.iproute ] ''
          #   ip --brief address show
          #   exit 1
          # '';
          ifdTest =
            let
              waiter = pkgs.writeScript "waiter" ''
                fn main() {
                  for i in 0..100 {
                    println!("waiter: {i}");
                    // std::thread::sleep(std::time::Duration::from_secs(1));
                  }
                }
              '';
              ifd = pkgs.runCommand "fod-in-ifd-test"
                {
                  buildInputs = [ pkgs.cacert pkgs.iproute pkgs.rustc pkgs.gcc ];
                  outputHashMode = "recursive";
                  outputHashAlgo = "sha256";
                  outputHash = getHash "uihürtön87444";
                } ''
                rustc ${waiter} -o waiter
                ./waiter
                # ip --brief address show
                # ip --brief address show
                # echo 456 > $out
              '';
            in
            pkgs.runCommand "ifdTest" { } ''
              echo ${builtins.toString (import ifd)}
              touch $out
            '';
        };
      }
    );
}
