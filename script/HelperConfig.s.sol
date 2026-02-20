// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";

// Chainlink VRF v2.5 mock (local testing)
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {LinkToken} from "test/mock/LinkToken.sol";


abstract contract CODE_CONSTANT {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
}

contract HelperConfig is CODE_CONSTANT, Script {

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    // chainId => config
    mapping(uint256 => NetworkConfig) private networkConfigs;

    // keep a cached Anvil config so we don't redeploy mocks repeatedly
    NetworkConfig private anvilConfig;

    error HelperConfig__InvalidChain();

     // --- Anvil mock params (commonly used defaults) ---
    uint96 private constant MOCK_BASE_FEE = 0.25 ether; // arbitrary mock fee
    uint96 private constant MOCK_GAS_PRICE_LINK = 1e9;  // arbitrary link gas price
    int256 private constant MOCK_WEI_PER_UNIT_LINK = 4e15; // 0.004 ETH per LINK (arbitrary)

    constructor() {
        // Sepolia (11155111)
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEth();

        // Mainnet (1) - placeholders
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEth();

        // Anvil (31337) - deploy mock + create subscription once
        if (block.chainid == ANVIL_LOCAL_CHAIN_ID) {
            networkConfigs[ANVIL_LOCAL_CHAIN_ID] = _getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRF v2.5 coordinator
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 13817975548147589086064026786122285340500494462068847926668188483378530170447,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x61B7376F875C43344A8d82fA55783CCA4d0e8CAf 

        });
    }
    function getMainnetEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 60,
            vrfCoordinator: address(0),
            keyHash: bytes32(0),
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA, // Mainnet LINK token
            account: 0x61B7376F875C43344A8d82fA55783CCA4d0e8CAf
        });
    }
    function getConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory config = networkConfigs[block.chainid];
        if (config.vrfCoordinator == address(0)) revert HelperConfig__InvalidChain();
        return config;
    }

    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        NetworkConfig memory config = networkConfigs[chainId];
        if (config.vrfCoordinator == address(0)) revert HelperConfig__InvalidChain();
        return config;
    }

    // Local Anvil setup
    function _getOrCreateAnvilConfig() private returns (NetworkConfig memory) {
        // If we've already created it, return cached config
        if (anvilConfig.vrfCoordinator != address(0)) {
            return anvilConfig;
        }

        // Broadcast so deployments happen as real txs during scripts
        vm.startBroadcast();

        // 1) Deploy VRF coordinator mock
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );

        LinkToken linkToken = new LinkToken();


        vm.stopBroadcast();

        // KeyHash is not meaningfully enforced on the mock; keep any constant value.
        anvilConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(coordinator),
            keyHash: bytes32(0),
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return anvilConfig;
    }
}