// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
 
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubsciptions, AddConsumer, FundSubscription} from "../script/Interactions.s.sol";

contract DeployRaffle is Script { 
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory chainConfig = helperConfig.getConfig();

        if (chainConfig.subscriptionId == 0) {
            CreateSubsciptions createSubscription = new CreateSubsciptions();
            (chainConfig.subscriptionId, chainConfig.vrfCoordinator) = createSubscription.createSubscription(chainConfig.vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(chainConfig.vrfCoordinator, chainConfig.subscriptionId, chainConfig.link);
        } 




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


        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), chainConfig.vrfCoordinator, chainConfig.subscriptionId);

        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

}
