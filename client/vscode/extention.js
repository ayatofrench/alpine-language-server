// @ts-check
const { LanguageClient } = require("vscode-languageclient/node");
const tmpdir = require("os").tmpdir();

module.exports = {
  /** @param {import("vscode").ExtensionContext} context*/
  activate(context) {
    /** @type {import("vscode-languageclient/node").ServerOptions} */
    const serverOptions = {
      run: {
        command: "alpine-lsp",
      },
      debug: {
        command: "alpine-lsp",
        args: ["--file", `${tmpdir}/lsp.log`, "--level", "TRACE"],
      },
    };

    /** @type {import("vscode-languageclient/node").LanguageClientOptions} */
    const clientOptions = {
      documentSelector: [
        { scheme: "file", language: "html" },
        { scheme: "file", language: "astro" },
      ],
    };

    const client = new LanguageClient(
      "alpine-lsp",
      "Alpine Language Server",
      serverOptions,
      clientOptions
    );

    client.start();
  },
};
