{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import "${nixpkgs}" {
          inherit system;
        };
        file = pkgs.writeText "waiter" ''
          // 9
          fn main() {
            let arg = std::env::args().nth(1).unwrap();
            let to = 100;
            for i in 0..to {
              println!("arg: {arg}, i: {i}/{to}");
              std::thread::sleep(std::time::Duration::from_secs(1));
            }
          }
        '';
        waiter = n:
          pkgs.runCommand "fod-in-ifd-test"
            {
              nativeBuildInputs = [ pkgs.rustc pkgs.gcc ];
            } ''
            rustc ${file} -o waiter
            ./waiter ${builtins.toString n}
            touch $out
          '';
        lists = pkgs.lib.lists;
      in
      {
        packages.default = pkgs.linkFarm "def" (
          lists.map
            (n:
              {
                name = "waiter-${builtins.toString n}";
                path = waiter n;
              })
            (lists.range 0 50));
      }
    );
}
