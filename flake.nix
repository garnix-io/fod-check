{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import "${nixpkgs}" {
          inherit system;
        };
        waiter = pkgs.writeText "waiter" ''
          fn main() {
            for i in 0..1000 {
              println!("waiter: {i} 6");
              std::thread::sleep(std::time::Duration::from_secs(1));
            }
          }
        '';
        ifd = pkgs.runCommand "fod-in-ifd-test"
          {
            nativeBuildInputs = [ pkgs.rustc pkgs.gcc ];
            # outputHashMode = "recursive";
            # outputHashAlgo = "sha256";
            # outputHash = "sha256-iFSPu804N4Qh4x11uFnieiEUQKPmjGp3jArABb9E3Pc=";
          } ''
          rustc ${waiter} -o waiter2
          ./waiter2
          echo 'pkgs : { packages.default = pkgs.hello; }' > $out
        '';
      in
      (import ifd) pkgs
    );
}
