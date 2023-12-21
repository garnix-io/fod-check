import {
  beforeEach,
  describe,
  it,
} from "https://deno.land/std@0.190.0/testing/bdd.ts";
import {
  assertFailure,
  assertSuccess,
  runCommand,
  withStderr,
} from "./test-helpers.ts";
import outdent from "https://deno.land/x/outdent@v0.8.0/mod.ts";
import {
  assertMatch,
  assertNotMatch,
  assertStringIncludes,
} from "https://deno.land/std@0.206.0/assert/mod.ts";

let bustCache = "";

const currentSystem = Deno.args[0];
if (!currentSystem) {
  throw Error("deno tests must be passed the current nix system");
}

describe("runTest", () => {
  beforeEach(() => {
    bustCache = Date.now().toString();
  });

  it("passes when given passing tests", () => {
    assertSuccess(runTest("true"));
  });

  it("fails when given failing tests", () => {
    assertFailure(runTest("false"));
  });

  it("has access to the internet", () => {
    assertSuccess(runTest("curl https://garnix.io", ["pkgs.curl"]));
  });

  it("caches the test results when not changing test script", () => {
    withStderr(runTest("echo foo"), assertMatch, /foo/);
    withStderr(runTest("echo foo"), assertNotMatch, /foo/);
  });

  it("caches the test results with a runtime-dependency", () => {
    withStderr(runTest("# ${pkgs.hello}\necho foo"), assertMatch, /foo/);
    withStderr(runTest("# ${pkgs.hello}\necho foo"), assertNotMatch, /foo/);
  });

  it("does not cache test results when changing test script", () => {
    withStderr(
      runTest("echo foo"),
      assertStringIncludes,
      outdent`
      fod-test> echo foo
      fod-test> ---
      fod-test> foo
    `,
    );
    withStderr(
      runTest("echo bar"),
      assertStringIncludes,
      outdent`
      fod-test> echo bar
      fod-test> ---
      fod-test> bar
    `,
    );
  });
});

function runTest(test: string, buildInputs: Array<string> = []) {
  const tmp = Deno.makeTempDirSync({ prefix: "fod-test" });
  const testScript = `# ${bustCache}\n${test}`;
  Deno.writeTextFileSync(
    `${tmp}/flake.nix`,
    `{
      inputs.fod = {
        url = "${Deno.cwd()}";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      outputs = { self, nixpkgs, fod }:
        let
          pkgs = import "\${nixpkgs}" {
            system = "${currentSystem}";
          };
        in {
          checks.${currentSystem}.sample-check =
            fod.lib.${currentSystem}.runTest
            [${buildInputs.join(" ")}]
            "${testScript}";
        };
      }`,
  );
  return runCommand(
    new Deno.Command("nix", {
      args: [
        "--extra-experimental-features",
        "nix-command flakes",
        "build",
        "-L",
        ".#checks.x86_64-linux.sample-check",
      ],
      cwd: tmp,
    }),
  );
}

// change
