import { assertEquals, assertNotEquals } from "https://deno.land/std@0.206.0/assert/mod.ts";

type Output = {
  exitCode: number;
  stdout: string;
  stderr: string;
};

export const runCommand = (command: Deno.Command): Output => {
  const output = command.outputSync();
  return {
    exitCode: output.code,
    stdout: new TextDecoder().decode(output.stdout),
    stderr: new TextDecoder().decode(output.stderr),
  };
};

const printOutput = (output: Output) => {
  console.error(`
    exitcode: ${output.exitCode}
    stdout:
    ${output.stdout}
    stderr:
    ${output.stderr}
  `);
};

export const assertSuccess = (output: Output): Output =>
  printOutputOnFailure(output, () => assertEquals(output.exitCode, 0));

export const assertFailure = (output: Output): Output =>
  printOutputOnFailure(output, () => assertNotEquals(output.exitCode, 0));

export const withStderr = <T>(output: Output, testCmd: (stderr: string, arg: T) => void, arg: T) =>
  printOutputOnFailure(output, () => testCmd(output.stderr, arg));

export const printOutputOnFailure = (
  output: Output,
  assertion: () => void,
): Output => {
  try {
    assertion();
  } catch (e) {
    printOutput(output);
    throw e;
  }
  return output;
};
