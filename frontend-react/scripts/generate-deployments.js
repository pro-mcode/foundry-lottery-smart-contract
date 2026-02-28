import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const repoRoot = path.resolve(__dirname, "..", "..");
const broadcastRoot = path.join(repoRoot, "broadcast", "DeployRaffle.s.sol");
const outputPath = path.join(__dirname, "..", "src", "deployments.json");

const readJson = (filePath) => {
  const raw = fs.readFileSync(filePath, "utf8");
  return JSON.parse(raw);
};

const getAddressFromRun = (data) => {
  if (data?.returns?.["0"]?.value) {
    return data.returns["0"].value;
  }

  if (Array.isArray(data?.transactions)) {
    const deployTx = data.transactions.find((tx) => tx.contractAddress);
    if (deployTx?.contractAddress) {
      return deployTx.contractAddress;
    }
  }

  return "";
};

const getTimestampMs = (data, fallbackPath) => {
  const raw = data?.timestamp;
  if (raw) {
    return raw > 1e12 ? raw : raw * 1000;
  }

  const stats = fs.statSync(fallbackPath);
  return stats.mtimeMs;
};

const pickRunFile = (chainDir) => {
  const latest = path.join(chainDir, "run-latest.json");
  if (fs.existsSync(latest)) {
    return latest;
  }

  const candidates = fs
    .readdirSync(chainDir)
    .filter((file) => file.startsWith("run-") && file.endsWith(".json"))
    .map((file) => path.join(chainDir, file));

  if (!candidates.length) return "";

  candidates.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return candidates[0];
};

const output = {};

if (fs.existsSync(broadcastRoot)) {
  const chainDirs = fs
    .readdirSync(broadcastRoot)
    .map((name) => path.join(broadcastRoot, name))
    .filter((dir) => fs.statSync(dir).isDirectory());

  for (const dir of chainDirs) {
    const chainId = path.basename(dir);
    const runFile = pickRunFile(dir);
    if (!runFile) continue;

    try {
      const data = readJson(runFile);
      const address = getAddressFromRun(data);
      if (!address) continue;

      const timestampMs = getTimestampMs(data, runFile);
      output[chainId] = {
        address,
        updatedAt: new Date(timestampMs).toISOString(),
        source: path.relative(repoRoot, runFile)
      };
    } catch (error) {
      console.warn(`Failed to parse ${runFile}:`, error.message);
    }
  }
}

fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`);
console.log(`Wrote deployments to ${path.relative(repoRoot, outputPath)}`);
