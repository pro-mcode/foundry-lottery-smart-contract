(() => {
  const DEFAULTS = {
    chainId: 11155111,
    entry: "0.01",
    addresses: {
      "11155111": "0x5A68cfD069aE080760Fe9d806fe3c3Cd45f5bE15"
    }
  };

  const NETWORKS = {
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

  const ABI = [
    "function enterRaffle() payable",
    "function getRaffleState() view returns (uint8)",
    "function getRecentWinner() view returns (address)",
    "function getInterval() view returns (uint256)",
    "function getTimeStamp() view returns (uint256)",
    "event PlayerEntered(address indexed player)",
    "event WinnerPicked(address indexed winner)"
  ];

  const STORAGE_KEY = "foundry-raffle-ui";

  const $ = (id) => document.getElementById(id);

  const elements = {
    connectBtn: $("connectBtn"),
    enterHeroBtn: $("enterHeroBtn"),
    enterBtn: $("enterBtn"),
    viewContract: $("viewContract"),
    networkName: $("networkName"),
    contractShort: $("contractShort"),
    copyAddress: $("copyAddress"),
    raffleState: $("raffleState"),
    potValue: $("potValue"),
    progressBar: $("progressBar"),
    nextDraw: $("nextDraw"),
    entryAmount: $("entryAmount"),
    statusMessage: $("statusMessage"),
    recentWinner: $("recentWinner"),
    lastDraw: $("lastDraw"),
    intervalValue: $("intervalValue"),
    statPool: $("statPool"),
    statState: $("statState"),
    statNext: $("statNext"),
    statWinner: $("statWinner"),
    contractAddress: $("contractAddress"),
    networkSelect: $("networkSelect"),
    defaultEntry: $("defaultEntry"),
    refreshBtn: $("refreshBtn"),
    switchNetworkBtn: $("switchNetworkBtn")
  };

  let provider = null;
  let signer = null;
  let refreshTimer = null;
  let countdownTimer = null;

  const loadConfig = () => {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    const config = {
      chainId: stored.chainId || DEFAULTS.chainId,
      entry: stored.entry || DEFAULTS.entry,
      addresses: stored.addresses || { ...DEFAULTS.addresses }
    };

    if (!config.addresses[String(config.chainId)]) {
      config.addresses[String(config.chainId)] = DEFAULTS.addresses[String(config.chainId)] || "";
    }

    return config;
  };

  const saveConfig = (config) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
  };

  const config = loadConfig();

  const normalizeAddress = (value) => {
    if (!value) return "";
    try {
      return window.ethers.getAddress(value.trim());
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
    const formatted = window.ethers.formatEther(value);
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

  const setStatus = (message, tone = "") => {
    elements.statusMessage.textContent = message;
    if (tone) {
      elements.statusMessage.dataset.tone = tone;
    } else {
      delete elements.statusMessage.dataset.tone;
    }
  };

  if (!window.ethers) {
    setStatus("Ethers library failed to load.", "error");
    return;
  }

  const setNetworkDisplay = (chainId) => {
    const network = NETWORKS[chainId];
    elements.networkName.textContent = network ? network.name : `Chain ${chainId}`;
  };

  const updateContractDisplay = (address) => {
    elements.contractShort.textContent = address ? shortAddress(address) : "Not set";
    elements.copyAddress.disabled = !address;

    const selectedNetwork = NETWORKS[Number(elements.networkSelect.value)];
    if (selectedNetwork && selectedNetwork.explorer && address) {
      elements.viewContract.href = `${selectedNetwork.explorer}${address}`;
      elements.viewContract.removeAttribute("aria-disabled");
    } else {
      elements.viewContract.href = "#";
      elements.viewContract.setAttribute("aria-disabled", "true");
    }
  };

  const updateCountdown = (lastTime, interval) => {
    if (!lastTime || !interval) return;

    const update = () => {
      const now = Math.floor(Date.now() / 1000);
      const next = Number(lastTime) + Number(interval);
      const remaining = next - now;
      const progress = Math.min(Math.max(1 - remaining / interval, 0), 1);

      elements.progressBar.style.width = `${Math.floor(progress * 100)}%`;
      const label = remaining <= 0 ? "Any moment" : formatDuration(remaining);
      elements.nextDraw.textContent = label;
      elements.statNext.textContent = label;
    };

    update();
    if (countdownTimer) clearInterval(countdownTimer);
    countdownTimer = setInterval(update, 1000);
  };

  const getProviderChainId = async () => {
    if (!provider) return null;
    const network = await provider.getNetwork();
    return Number(network.chainId);
  };

  const initProvider = () => {
    if (!window.ethereum) {
      return false;
    }

    if (!provider) {
      provider = new window.ethers.BrowserProvider(window.ethereum);
    }
    return true;
  };

  const ensureProvider = () => {
    if (!initProvider()) {
      setStatus("Wallet not detected. Install a web3 wallet to continue.", "error");
      return false;
    }
    return true;
  };

  const updateWalletDisplay = async () => {
    if (!provider) return;
    const accounts = await provider.send("eth_accounts", []);
    if (accounts && accounts.length) {
      elements.connectBtn.textContent = `Connected: ${shortAddress(accounts[0])}`;
      signer = await provider.getSigner();
    } else {
      elements.connectBtn.textContent = "Connect wallet";
      signer = null;
    }
  };

  const connectWallet = async () => {
    const ok = ensureProvider();
    if (!ok) return;

    try {
      await provider.send("eth_requestAccounts", []);
      await updateWalletDisplay();
      setStatus("Wallet connected. Loading live data.", "success");
      await refreshData();
    } catch (error) {
      setStatus("Wallet connection cancelled.", "error");
    }
  };

  const refreshData = async (options = {}) => {
    const silent = options.silent === true;
    if (!initProvider()) {
      if (!silent) {
        setStatus("Connect a wallet to load live data.");
      }
      return;
    }
    await updateWalletDisplay();

    const selectedAddress = normalizeAddress(elements.contractAddress.value);
    if (!selectedAddress) {
      setStatus("Enter a valid contract address.", "error");
      updateContractDisplay("");
      return;
    }

    updateContractDisplay(selectedAddress);

    try {
      const chainId = await getProviderChainId();
      setNetworkDisplay(chainId || Number(elements.networkSelect.value));

      if (chainId && chainId !== Number(elements.networkSelect.value) && !silent) {
        setStatus("Connected to the wrong network. Use the switch button.", "error");
      }

      const contract = new window.ethers.Contract(selectedAddress, ABI, provider);

      const [state, winner, interval, lastTime, balance] = await Promise.all([
        contract.getRaffleState(),
        contract.getRecentWinner(),
        contract.getInterval(),
        contract.getTimeStamp(),
        provider.getBalance(selectedAddress)
      ]);

      const stateLabel = Number(state) === 0 ? "OPEN" : "CALCULATING";
      const stateStyle = Number(state) === 0 ? "open" : "calculating";

      elements.raffleState.textContent = stateLabel;
      elements.raffleState.dataset.state = stateStyle;
      elements.statState.textContent = stateLabel;

      const pot = `${formatEth(balance)} ETH`;
      elements.potValue.textContent = pot;
      elements.statPool.textContent = pot;

      const winnerAddress = winner && winner !== window.ethers.ZeroAddress ? winner : "";
      elements.recentWinner.textContent = winnerAddress ? shortAddress(winnerAddress) : "Not set";
      elements.statWinner.textContent = elements.recentWinner.textContent;

      const intervalValue = Number(interval);
      elements.intervalValue.textContent = intervalValue ? `${intervalValue} sec` : "--";

      if (lastTime) {
        const date = new Date(Number(lastTime) * 1000);
        elements.lastDraw.textContent = `Last draw: ${date.toLocaleString()}`;
      }

      updateCountdown(Number(lastTime), intervalValue);
      if (!silent) {
        setStatus("Live data updated.", "success");
      }
    } catch (error) {
      console.error(error);
      setStatus("Failed to load contract data. Check the address and network.", "error");
    }
  };

  const enterRaffle = async () => {
    if (!provider || !window.ethereum) {
      setStatus("Connect a wallet to enter.", "error");
      return;
    }

    const selectedAddress = normalizeAddress(elements.contractAddress.value);
    if (!selectedAddress) {
      setStatus("Enter a valid contract address.", "error");
      return;
    }

    const amount = elements.entryAmount.value || elements.defaultEntry.value;
    if (!amount || Number(amount) <= 0) {
      setStatus("Enter a valid ETH amount.", "error");
      return;
    }

    try {
      const chainId = await getProviderChainId();
      if (chainId && chainId !== Number(elements.networkSelect.value)) {
        setStatus("Switch to the selected network before entering.", "error");
        return;
      }

      const writable = new window.ethers.Contract(selectedAddress, ABI, signer);
      const value = window.ethers.parseEther(amount);
      const tx = await writable.enterRaffle({ value });
      setStatus(`Entry sent. Tx: ${shortAddress(tx.hash)}`, "success");
      await tx.wait();
      setStatus("Entry confirmed. Good luck.", "success");
      await refreshData();
    } catch (error) {
      console.error(error);
      setStatus("Transaction failed or rejected.", "error");
    }
  };

  const switchNetwork = async () => {
    if (!window.ethereum) {
      setStatus("Wallet not detected.", "error");
      return;
    }

    const chainId = Number(elements.networkSelect.value);
    const network = NETWORKS[chainId];
    if (!network || !network.chainHex) {
      setStatus("Unknown network selection.", "error");
      return;
    }

    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: network.chainHex }]
      });
      await refreshData();
    } catch (error) {
      setStatus("Network switch failed. Try manually in your wallet.", "error");
    }
  };

  const applyConfigToUI = () => {
    elements.networkSelect.value = String(config.chainId);
    elements.contractAddress.value = config.addresses[String(config.chainId)] || "";
    elements.defaultEntry.value = config.entry;
    elements.entryAmount.value = config.entry;
    updateContractDisplay(normalizeAddress(elements.contractAddress.value));
    setNetworkDisplay(config.chainId);
  };

  const persistConfigFromUI = () => {
    config.chainId = Number(elements.networkSelect.value);
    config.entry = elements.defaultEntry.value || DEFAULTS.entry;
    const current = normalizeAddress(elements.contractAddress.value);
    if (current) {
      config.addresses[String(config.chainId)] = current;
    }
    saveConfig(config);
  };

  const bindEvents = () => {
    elements.connectBtn.addEventListener("click", connectWallet);
    elements.enterBtn.addEventListener("click", enterRaffle);
    elements.enterHeroBtn.addEventListener("click", () => {
      elements.entryAmount.scrollIntoView({ behavior: "smooth", block: "center" });
      elements.entryAmount.focus();
    });
    elements.refreshBtn.addEventListener("click", refreshData);
    elements.switchNetworkBtn.addEventListener("click", switchNetwork);

    elements.networkSelect.addEventListener("change", () => {
      persistConfigFromUI();
      const nextAddress = config.addresses[String(config.chainId)] || "";
      elements.contractAddress.value = nextAddress;
      updateContractDisplay(normalizeAddress(nextAddress));
      setNetworkDisplay(config.chainId);
    });

    elements.contractAddress.addEventListener("change", () => {
      persistConfigFromUI();
      updateContractDisplay(normalizeAddress(elements.contractAddress.value));
    });

    elements.defaultEntry.addEventListener("change", () => {
      persistConfigFromUI();
      elements.entryAmount.value = elements.defaultEntry.value;
    });

    elements.copyAddress.addEventListener("click", async () => {
      const address = normalizeAddress(elements.contractAddress.value);
      if (!address || !navigator.clipboard) {
        setStatus("Unable to copy address.", "error");
        return;
      }
      await navigator.clipboard.writeText(address);
      setStatus("Contract address copied.", "success");
    });
  };

  const setupObservers = () => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15 }
    );

    document.querySelectorAll("[data-animate]").forEach((node) => observer.observe(node));
  };

  const attachWalletListeners = () => {
    if (!window.ethereum) return;

    window.ethereum.on("accountsChanged", () => {
      updateWalletDisplay();
      refreshData();
    });

    window.ethereum.on("chainChanged", () => {
      refreshData();
    });
  };

  const scheduleRefresh = () => {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(() => {
      if (provider) refreshData({ silent: true });
    }, 20000);
  };

  if (initProvider()) {
    updateWalletDisplay();
    refreshData({ silent: true });
  }
  applyConfigToUI();
  bindEvents();
  setupObservers();
  attachWalletListeners();
  scheduleRefresh();
})();
