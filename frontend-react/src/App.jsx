import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  BrowserProvider,
  Contract,
  ZeroAddress,
  formatEther,
  getAddress,
  parseEther
} from "ethers";
import deployments from "./deployments.json";

const STORAGE_KEY = "foundry-raffle-ui-react";
const DEFAULT_ENTRY = "0.01";
const DEFAULT_CHAIN = 11155111;

const ABI = [
  "function enterRaffle() payable",
  "function getRaffleState() view returns (uint8)",
  "function getRecentWinner() view returns (address)",
  "function getInterval() view returns (uint256)",
  "function getTimeStamp() view returns (uint256)",
  "event PlayerEntered(address indexed player)",
  "event WinnerPicked(address indexed winner)"
];

const NETWORKS = {
  1: {
    name: "Mainnet",
    explorer: "https://etherscan.io/address/",
    chainHex: "0x1"
  },
  11155111: {
    name: "Sepolia",
    explorer: "https://sepolia.etherscan.io/address/",
    chainHex: "0xaa36a7"
  },
  31337: {
    name: "Localhost",
    explorer: "",
    chainHex: "0x7a69"
  }
};

const normalizeAddress = (value) => {
  if (!value) return "";
  try {
    return getAddress(value.trim());
  } catch (error) {
    return "";
  }
};

const shortAddress = (value) => {
  if (!value) return "--";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
};

const formatEth = (value) => {
  if (!value) return "0.00";
  const formatted = formatEther(value);
  const [whole, decimal = ""] = formatted.split(".");
  return `${whole}.${decimal.padEnd(2, "0").slice(0, 2)}`;
};

const formatDuration = (seconds) => {
  const safe = Math.max(seconds, 0);
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  const secs = safe % 60;
  const parts = [];
  if (hours) parts.push(`${hours}h`);
  if (hours || minutes) parts.push(`${minutes}m`);
  parts.push(`${String(secs).padStart(2, "0")}s`);
  return parts.join(" ");
};

const getDeploymentAddress = (chainId) => {
  return deployments?.[String(chainId)]?.address || "";
};

const getDeploymentNote = (chainId) => {
  const info = deployments?.[String(chainId)];
  if (!info?.updatedAt) return "No broadcast deployment found for this network.";
  const timestamp = new Date(info.updatedAt);
  return `Latest deployment: ${timestamp.toLocaleString()}`;
};

const loadStoredConfig = () => {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    return {
      chainId: stored.chainId || DEFAULT_CHAIN,
      entry: stored.entry || DEFAULT_ENTRY,
      manual: stored.manual || {}
    };
  } catch (error) {
    return { chainId: DEFAULT_CHAIN, entry: DEFAULT_ENTRY, manual: {} };
  }
};

export default function App() {
  const providerRef = useRef(null);
  const signerRef = useRef(null);

  const [selectedChainId, setSelectedChainId] = useState(DEFAULT_CHAIN);
  const [manualAddresses, setManualAddresses] = useState({});
  const [defaultEntry, setDefaultEntry] = useState(DEFAULT_ENTRY);
  const [contractAddress, setContractAddress] = useState("");
  const [entryAmount, setEntryAmount] = useState(DEFAULT_ENTRY);
  const [walletAddress, setWalletAddress] = useState("");
  const [providerChainId, setProviderChainId] = useState(null);
  const [status, setStatus] = useState({
    message: "Connect a wallet to load live data.",
    tone: ""
  });
  const [raffleState, setRaffleState] = useState({ label: "Unknown", state: "" });
  const [potValue, setPotValue] = useState("0.00 ETH");
  const [recentWinner, setRecentWinner] = useState("--");
  const [lastDrawLabel, setLastDrawLabel] = useState("--");
  const [intervalSeconds, setIntervalSeconds] = useState(0);
  const [lastTime, setLastTime] = useState(0);
  const [nextDrawLabel, setNextDrawLabel] = useState("--");
  const [progressValue, setProgressValue] = useState(0);

  const updateStatus = useCallback((message, tone = "") => {
    setStatus({ message, tone });
  }, []);

  const initProvider = useCallback(() => {
    if (!window.ethereum) {
      return false;
    }

    if (!providerRef.current) {
      providerRef.current = new BrowserProvider(window.ethereum);
    }

    return true;
  }, []);

  const updateWalletDisplay = useCallback(async () => {
    if (!providerRef.current) return;
    const accounts = await providerRef.current.send("eth_accounts", []);
    if (accounts && accounts.length) {
      setWalletAddress(accounts[0]);
      signerRef.current = await providerRef.current.getSigner();
    } else {
      setWalletAddress("");
      signerRef.current = null;
    }
  }, []);

  const refreshData = useCallback(
    async ({ silent = false } = {}) => {
      if (!initProvider()) {
        if (!silent) {
          updateStatus("Connect a wallet to load live data.");
        }
        return;
      }

      await updateWalletDisplay();

      const normalized = normalizeAddress(contractAddress);
      if (!normalized) {
        if (!silent) {
          updateStatus("Enter a valid contract address.", "error");
        }
        return;
      }

      try {
        const network = await providerRef.current.getNetwork();
        const chainId = Number(network.chainId);
        setProviderChainId(chainId);

        if (chainId && chainId !== Number(selectedChainId) && !silent) {
          updateStatus("Connected to the wrong network. Use the switch button.", "error");
        }

        const contract = new Contract(normalized, ABI, providerRef.current);
        const [state, winner, interval, lastTimeStamp, balance] = await Promise.all([
          contract.getRaffleState(),
          contract.getRecentWinner(),
          contract.getInterval(),
          contract.getTimeStamp(),
          providerRef.current.getBalance(normalized)
        ]);

        const stateLabel = Number(state) === 0 ? "OPEN" : "CALCULATING";
        const stateStyle = Number(state) === 0 ? "open" : "calculating";
        setRaffleState({ label: stateLabel, state: stateStyle });

        const pot = `${formatEth(balance)} ETH`;
        setPotValue(pot);

        const winnerAddress = winner && winner !== ZeroAddress ? winner : "";
        setRecentWinner(winnerAddress ? shortAddress(winnerAddress) : "Not set");

        const intervalValue = Number(interval);
        setIntervalSeconds(intervalValue);
        const lastTimeValue = Number(lastTimeStamp);
        setLastTime(lastTimeValue);
        if (lastTimeValue) {
          const date = new Date(lastTimeValue * 1000);
          setLastDrawLabel(`Last draw: ${date.toLocaleString()}`);
        }

        if (!silent) {
          updateStatus("Live data updated.", "success");
        }
      } catch (error) {
        console.error(error);
        updateStatus("Failed to load contract data. Check the address and network.", "error");
      }
    },
    [contractAddress, initProvider, selectedChainId, updateStatus, updateWalletDisplay]
  );

  const connectWallet = useCallback(async () => {
    if (!initProvider()) {
      updateStatus("Wallet not detected. Install a web3 wallet to continue.", "error");
      return;
    }

    try {
      await providerRef.current.send("eth_requestAccounts", []);
      await updateWalletDisplay();
      updateStatus("Wallet connected. Loading live data.", "success");
      await refreshData();
    } catch (error) {
      updateStatus("Wallet connection cancelled.", "error");
    }
  }, [initProvider, refreshData, updateStatus, updateWalletDisplay]);

  const enterRaffle = useCallback(async () => {
    if (!initProvider()) {
      updateStatus("Wallet not detected.", "error");
      return;
    }

    const normalized = normalizeAddress(contractAddress);
    if (!normalized) {
      updateStatus("Enter a valid contract address.", "error");
      return;
    }

    if (!signerRef.current) {
      updateStatus("Connect a wallet to enter.", "error");
      return;
    }

    const amount = entryAmount || defaultEntry;
    if (!amount || Number(amount) <= 0) {
      updateStatus("Enter a valid ETH amount.", "error");
      return;
    }

    try {
      const network = await providerRef.current.getNetwork();
      if (network.chainId && Number(network.chainId) !== Number(selectedChainId)) {
        updateStatus("Switch to the selected network before entering.", "error");
        return;
      }

      const contract = new Contract(normalized, ABI, signerRef.current);
      const tx = await contract.enterRaffle({ value: parseEther(amount) });
      updateStatus(`Entry sent. Tx: ${shortAddress(tx.hash)}`, "success");
      await tx.wait();
      updateStatus("Entry confirmed. Good luck.", "success");
      await refreshData();
    } catch (error) {
      console.error(error);
      updateStatus("Transaction failed or rejected.", "error");
    }
  }, [contractAddress, defaultEntry, entryAmount, initProvider, refreshData, selectedChainId, updateStatus]);

  const switchNetwork = useCallback(async () => {
    if (!window.ethereum) {
      updateStatus("Wallet not detected.", "error");
      return;
    }

    const network = NETWORKS[selectedChainId];
    if (!network?.chainHex) {
      updateStatus("Unknown network selection.", "error");
      return;
    }

    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: network.chainHex }]
      });
      await refreshData();
    } catch (error) {
      updateStatus("Network switch failed. Try manually in your wallet.", "error");
    }
  }, [refreshData, selectedChainId, updateStatus]);

  const copyAddress = useCallback(async () => {
    const normalized = normalizeAddress(contractAddress);
    if (!normalized || !navigator.clipboard) {
      updateStatus("Unable to copy address.", "error");
      return;
    }

    await navigator.clipboard.writeText(normalized);
    updateStatus("Contract address copied.", "success");
  }, [contractAddress, updateStatus]);

  const derivedNetwork = useMemo(() => {
    const chainId = providerChainId || selectedChainId;
    return NETWORKS[chainId] || { name: `Chain ${chainId}`, explorer: "" };
  }, [providerChainId, selectedChainId]);

  const viewContractHref = useMemo(() => {
    const normalized = normalizeAddress(contractAddress);
    if (!normalized || !derivedNetwork.explorer) return "#";
    return `${derivedNetwork.explorer}${normalized}`;
  }, [contractAddress, derivedNetwork.explorer]);

  useEffect(() => {
    const stored = loadStoredConfig();
    setSelectedChainId(stored.chainId);
    setManualAddresses(stored.manual);
    setDefaultEntry(stored.entry);
    setEntryAmount(stored.entry);

    const manual = stored.manual?.[String(stored.chainId)] || "";
    const deployment = getDeploymentAddress(stored.chainId);
    setContractAddress(manual || deployment || "");
  }, []);

  useEffect(() => {
    const manual = manualAddresses[String(selectedChainId)] || "";
    const deployment = getDeploymentAddress(selectedChainId);
    setContractAddress(manual || deployment || "");
  }, [manualAddresses, selectedChainId]);

  useEffect(() => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        chainId: selectedChainId,
        entry: defaultEntry,
        manual: manualAddresses
      })
    );
  }, [defaultEntry, manualAddresses, selectedChainId]);

  useEffect(() => {
    if (!initProvider()) return;
    updateWalletDisplay();
    refreshData({ silent: true });

    const intervalId = setInterval(() => {
      if (providerRef.current) {
        refreshData({ silent: true });
      }
    }, 20000);

    return () => clearInterval(intervalId);
  }, [initProvider, refreshData, updateWalletDisplay]);

  useEffect(() => {
    if (!window.ethereum) return undefined;

    const handleAccountsChanged = () => {
      updateWalletDisplay();
      refreshData();
    };
    const handleChainChanged = () => {
      refreshData();
    };

    window.ethereum.on("accountsChanged", handleAccountsChanged);
    window.ethereum.on("chainChanged", handleChainChanged);

    return () => {
      window.ethereum.removeListener("accountsChanged", handleAccountsChanged);
      window.ethereum.removeListener("chainChanged", handleChainChanged);
    };
  }, [refreshData, updateWalletDisplay]);

  useEffect(() => {
    if (!lastTime || !intervalSeconds) return undefined;

    const updateCountdown = () => {
      const now = Math.floor(Date.now() / 1000);
      const next = Number(lastTime) + Number(intervalSeconds);
      const remaining = next - now;
      const progress = Math.min(Math.max(1 - remaining / intervalSeconds, 0), 1);

      setProgressValue(Math.floor(progress * 100));
      setNextDrawLabel(remaining <= 0 ? "Any moment" : formatDuration(remaining));
    };

    updateCountdown();
    const timerId = setInterval(updateCountdown, 1000);
    return () => clearInterval(timerId);
  }, [intervalSeconds, lastTime]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
          }
        });
      },
      { threshold: 0.15 }
    );

    document.querySelectorAll("[data-animate]").forEach((node) => observer.observe(node));

    return () => observer.disconnect();
  }, []);

  const handleChainChange = (event) => {
    setSelectedChainId(Number(event.target.value));
  };

  const handleDefaultEntryChange = (event) => {
    setDefaultEntry(event.target.value || DEFAULT_ENTRY);
    setEntryAmount(event.target.value || DEFAULT_ENTRY);
  };

  const handleAddressBlur = () => {
    const normalized = normalizeAddress(contractAddress);
    if (!contractAddress.trim()) {
      setManualAddresses((prev) => {
        const next = { ...prev };
        delete next[String(selectedChainId)];
        return next;
      });
      return;
    }

    if (!normalized) {
      updateStatus("Invalid contract address.", "error");
      return;
    }

    setContractAddress(normalized);
    setManualAddresses((prev) => ({ ...prev, [String(selectedChainId)]: normalized }));
  };

  return (
    <div>
      <div className="bg-grid" />
      <div className="glow glow-1" />
      <div className="glow glow-2" />
      <div className="glow glow-3" />

      <header className="site-header">
        <div className="brand">
          <div className="logo" aria-hidden="true">
            <svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M24 4L40 12V28L24 44L8 28V12L24 4Z" stroke="currentColor" strokeWidth="2" />
              <path d="M24 12L32 16V24L24 32L16 24V16L24 12Z" stroke="currentColor" strokeWidth="2" />
            </svg>
          </div>
          <div className="brand-text">
            <span className="brand-title">Foundry Raffle</span>
            <span className="brand-subtitle">Verifiable premium lottery</span>
          </div>
        </div>
        <nav className="site-nav">
          <a href="#stats">Stats</a>
          <a href="#how">How it works</a>
          <a href="#protocol">Protocol</a>
          <a href="#config">Config</a>
        </nav>
        <div className="header-actions">
          <button className="btn btn-ghost" onClick={connectWallet} type="button">
            {walletAddress ? `Connected: ${shortAddress(walletAddress)}` : "Connect wallet"}
          </button>
        </div>
      </header>

      <main>
        <section className="hero" id="top">
          <div className="hero-copy" data-animate>
            <p className="eyebrow">Chainlink VRF v2.5 + Automation</p>
            <h1>Premium randomness. On-chain rewards. Zero compromises.</h1>
            <p className="lead">
              Enter the raffle with ETH. Chainlink VRF selects a winner. Payouts execute
              automatically on-chain. Clean UX, clear trust.
            </p>
            <div className="cta-row">
              <button className="btn btn-primary" onClick={enterRaffle} type="button">
                Enter raffle
              </button>
              <a
                className="btn btn-ghost"
                href={viewContractHref}
                target="_blank"
                rel="noreferrer"
                aria-disabled={!normalizeAddress(contractAddress) || !derivedNetwork.explorer}
              >
                View contract
              </a>
            </div>
            <div className="meta-row">
              <div className="meta-card">
                <span className="meta-label">Network</span>
                <span className="meta-value">{derivedNetwork.name}</span>
              </div>
              <div className="meta-card">
                <span className="meta-label">Contract</span>
                <div className="meta-value meta-contract">
                  <span>{normalizeAddress(contractAddress) ? shortAddress(normalizeAddress(contractAddress)) : "Not set"}</span>
                  <button className="chip" onClick={copyAddress} type="button">
                    Copy
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div className="hero-panel" data-animate>
            <div className="card hero-card">
              <div className="card-header">
                <div>
                  <p className="card-title">Live round</p>
                  <p className="card-subtitle">Provably fair and non-custodial</p>
                </div>
                <span className="pill" data-state={raffleState.state || undefined}>
                  {raffleState.label}
                </span>
              </div>
              <div className="pot">
                <span className="pot-label">Current pot</span>
                <span className="pot-value">{potValue}</span>
              </div>
              <div className="progress">
                <div className="progress-bar" style={{ width: `${progressValue}%` }} />
              </div>
              <div className="progress-meta">
                <span>Next draw</span>
                <span>{nextDrawLabel}</span>
              </div>
              <div className="entry-form">
                <label htmlFor="entryAmount">Entry amount (ETH)</label>
                <div className="entry-row">
                  <input
                    id="entryAmount"
                    type="number"
                    min="0"
                    step="0.001"
                    inputMode="decimal"
                    value={entryAmount}
                    onChange={(event) => setEntryAmount(event.target.value)}
                  />
                  <button className="btn btn-primary" onClick={enterRaffle} type="button">
                    Enter
                  </button>
                </div>
              </div>
              <div className="status" data-tone={status.tone || undefined} role="status" aria-live="polite">
                {status.message}
              </div>
            </div>

            <div className="mini-grid">
              <div className="card mini-card">
                <p className="mini-label">Last winner</p>
                <p className="mini-value">{recentWinner}</p>
                <p className="mini-sub">{lastDrawLabel}</p>
              </div>
              <div className="card mini-card">
                <p className="mini-label">Interval</p>
                <p className="mini-value">{intervalSeconds ? `${intervalSeconds} sec` : "--"}</p>
                <p className="mini-sub">Seconds between draws</p>
              </div>
            </div>
          </div>
        </section>

        <section className="stats" id="stats">
          <div className="section-header" data-animate>
            <h2>Live protocol stats</h2>
            <p>Real time state from the deployed contract.</p>
          </div>
          <div className="stats-grid">
            <div className="card stat-card" data-animate>
              <p className="stat-label">Pool balance</p>
              <p className="stat-value">{potValue}</p>
              <p className="stat-sub">Contract balance</p>
            </div>
            <div className="card stat-card" data-animate>
              <p className="stat-label">Raffle state</p>
              <p className="stat-value">{raffleState.label}</p>
              <p className="stat-sub">Open or calculating</p>
            </div>
            <div className="card stat-card" data-animate>
              <p className="stat-label">Next draw</p>
              <p className="stat-value">{nextDrawLabel}</p>
              <p className="stat-sub">Countdown to draw</p>
            </div>
            <div className="card stat-card" data-animate>
              <p className="stat-label">Last winner</p>
              <p className="stat-value">{recentWinner}</p>
              <p className="stat-sub">Most recent payout</p>
            </div>
          </div>
        </section>

        <section className="how" id="how">
          <div className="section-header" data-animate>
            <h2>How it works</h2>
            <p>Three steps. Fully on-chain. Fully verifiable.</p>
          </div>
          <div className="how-grid">
            <div className="card how-card" data-animate>
              <span className="step">01</span>
              <h3>Enter with ETH</h3>
              <p>Send your entry amount to the raffle contract. Funds pool together instantly.</p>
            </div>
            <div className="card how-card" data-animate>
              <span className="step">02</span>
              <h3>Automation triggers draw</h3>
              <p>Chainlink Automation checks timing and conditions, then requests randomness.</p>
            </div>
            <div className="card how-card" data-animate>
              <span className="step">03</span>
              <h3>VRF selects winner</h3>
              <p>Chainlink VRF delivers verifiable randomness and the payout executes automatically.</p>
            </div>
          </div>
        </section>

        <section className="protocol" id="protocol">
          <div className="section-header" data-animate>
            <h2>Protocol guarantees</h2>
            <p>Built for transparency, trust, and premium UX.</p>
          </div>
          <div className="protocol-grid">
            <div className="card protocol-card" data-animate>
              <h3>Verifiable randomness</h3>
              <p>Chainlink VRF v2.5 ensures the winner is unbiased and provable.</p>
            </div>
            <div className="card protocol-card" data-animate>
              <h3>Non-custodial funds</h3>
              <p>Entries live in the contract. No third party custody. No hidden controls.</p>
            </div>
            <div className="card protocol-card" data-animate>
              <h3>Predictable cadence</h3>
              <p>Intervals are enforced on-chain. The system draws at consistent cycles.</p>
            </div>
            <div className="card protocol-card" data-animate>
              <h3>Premium interface</h3>
              <p>Focused layout, quick actions, and elegant clarity for every participant.</p>
            </div>
          </div>
        </section>

        <section className="config" id="config">
          <div className="section-header" data-animate>
            <h2>Connection config</h2>
            <p>Point the UI at any deployed raffle contract.</p>
          </div>
          <div className="card config-card" data-animate>
            <div className="config-grid">
              <div className="field">
                <label htmlFor="contractAddress">Contract address</label>
                <input
                  id="contractAddress"
                  type="text"
                  spellCheck="false"
                  value={contractAddress}
                  onChange={(event) => setContractAddress(event.target.value)}
                  onBlur={handleAddressBlur}
                />
              </div>
              <div className="field">
                <label htmlFor="networkSelect">Network</label>
                <select id="networkSelect" value={selectedChainId} onChange={handleChainChange}>
                  <option value={1}>Mainnet (1)</option>
                  <option value={11155111}>Sepolia (11155111)</option>
                  <option value={31337}>Localhost (31337)</option>
                </select>
              </div>
              <div className="field">
                <label htmlFor="defaultEntry">Default entry (ETH)</label>
                <input
                  id="defaultEntry"
                  type="number"
                  min="0"
                  step="0.001"
                  inputMode="decimal"
                  value={defaultEntry}
                  onChange={handleDefaultEntryChange}
                />
              </div>
            </div>
            <div className="config-actions">
              <button className="btn btn-secondary" onClick={() => refreshData()} type="button">
                Refresh data
              </button>
              <button className="btn btn-ghost" onClick={switchNetwork} type="button">
                Switch network
              </button>
            </div>
            <p className="config-note">{getDeploymentNote(selectedChainId)}</p>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div>
          <p className="footer-title">Foundry Raffle</p>
          <p className="footer-sub">Premium frontend for the on-chain raffle contract.</p>
        </div>
        <p className="footer-note">
          Powered by Chainlink VRF and Automation. Always verify contract addresses.
        </p>
      </footer>
    </div>
  );
}
