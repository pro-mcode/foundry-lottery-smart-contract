// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
 
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployRaffle is Script { 
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory chainConfig = helperConfig.getConfig();

        vm.startBroadcast();
        // Deploy the contract (replace constructor args to match your Raffle constructor)
        Raffle raffle = new Raffle(
            chainConfig.entranceFee,
            chainConfig.interval,
            chainConfig.vrfCoordinator,
            chainConfig.keyHash,
            chainConfig.subscriptionId,
            chainConfig.callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

}
