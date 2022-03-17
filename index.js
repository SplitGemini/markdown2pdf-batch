// node.js
const path = require("path");
const fs = require("fs");
const mume = require("@shd101wyy/mume");
const os = require("os");
const { program } = require("commander");
const { dirname } = require("path");
const configPath = path.resolve(os.tmpdir(), ".mume");

const config = {
    configPath,
    previewTheme: "github-light.css",
    // revealjsTheme: "white.css"
    codeBlockTheme: "github.css",
    printBackground: true,
    chromePath: path.resolve(
        __dirname,
        "./node_modules/puppeteer/.local-chromium/linux-970485/chrome-linux/chrome"
    ),
    enableScriptExecution: true,
    puppeteerWaitForTimeout: 0,
    usePuppeteerCore: true,
    puppeteerArgs: ["--no-sandbox"],
    plantumlServer: "",
};

function copyPdf(pdfPath, targetDirPath) {
    fs.mkdirSync(targetDirPath, { recursive: true });
    fs.writeFileSync(
        path.resolve(targetDirPath, path.basename(pdfPath)),
        fs.readFileSync(pdfPath)
    );
}

async function convert(docsPath, filePath, targetDirPath) {
    const engine = new mume.MarkdownEngine({
        filePath,
        projectDirectoryPath: path.dirname(filePath),
        config,
    });

    pdf = path.resolve(
        targetDirPath,
        filePath.replace(new RegExp(`^${docsPath}/`), "")
    );
    console.log(`convert ${filePath} to ${pdf.replace(/\.md$/, ".pdf")}`);
    // chrome (puppeteer) export
    await engine.chromeExport({ fileType: "pdf", runAllCodeChunks: true });
    console.log("finish");
    copyPdf(filePath.replace(/\.md$/, ".pdf"), dirname(pdf));
}

function copyFileSync(source, target) {
    var targetFile = target;

    // If target is a directory, a new file with the same name will be created
    if (fs.existsSync(target)) {
        if (fs.lstatSync(target).isDirectory()) {
            targetFile = path.join(target, path.basename(source));
        }
    }

    fs.writeFileSync(targetFile, fs.readFileSync(source));
}

function copyFolderRecursiveSync(source, target) {
    var files = [];

    // Check if folder needs to be created or integrated
    var targetFolder = path.join(target, path.basename(source));
    if (!fs.existsSync(targetFolder)) {
        fs.mkdirSync(targetFolder);
    }

    // Copy
    if (fs.lstatSync(source).isDirectory()) {
        files = fs.readdirSync(source);
        files.forEach(function (file) {
            var curSource = path.join(source, file);
            if (fs.lstatSync(curSource).isDirectory()) {
                copyFolderRecursiveSync(curSource, targetFolder);
            } else {
                copyFileSync(curSource, targetFolder);
            }
        });
    }
}

async function main() {
    // if no configPath is specified, the default is "~/.config/mume"
    // but only if the old location (~/.mume) does not exist
    await mume.init(configPath);
    program
        .requiredOption("-d, --docs <dir>", "output extra debugging")
        .option("-o, --output <dir>", "small pizza size");

    program.parse(process.argv);
    const docsPath = path.resolve(program.opts().docs);

    let mktemp = require("mktemp");
    let docsTmpDir = mktemp.createDirSync(os.tmpdir() + "/XXXXXXXXXX");

    // copy dir
    copyFolderRecursiveSync(docsPath, docsTmpDir);
    docsTmpDir = path.resolve(docsTmpDir, path.basename(docsPath));
    const FileHound = require("filehound");
    const files = await FileHound.create().paths(docsTmpDir).ext("md").find();

    for (const filePath of files) {
        await convert(
            docsTmpDir,
            filePath,
            program.opts().output || docsPath + "-pdf"
        );
    }
    process.exit(0);
}

main();
