// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CODE_CONSTANT} from "../script/HelperConfig.s.sol";
import {LinkToken} from "test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


contract CreateSubsciptions is Script {

    function createSubscriptionConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        
        return (subId, vrfCoordinator);

    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on chain ID ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinator);
        uint256 subId = coordinator.createSubscription();
        coordinator.fundSubscription(subId, 10 ether);
        vm.stopBroadcast();
        console.log("Your subId is ", subId);
        console.log("Your vrfCoordinator is ", vrfCoordinator);

        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionConfig();
    }
}


contract FundSubscription is Script, CODE_CONSTANT {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Link token is ", linkToken);
        console.log("Funding subscription ", subscriptionId);
        console.log("Using vrfCoordinator ", vrfCoordinator);
        console.log("Funding subscription on chain ID ", block.chainid);

        if (block.chainid == ANVIL_LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinator);
            coordinator.fundSubscription(subscriptionId, FUND_AMOUNT * 100); // 100x to account for mock's lower LINK price
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();

        }

        
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address contract2VRF) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(contract2VRF, vrfCoordinator, subscriptionId, account);
    }

    function addConsumer(address contract2VRF, address vrfCoordinator, uint256 subscriptionId, address account) public {
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("Adding consumer on chain ID", block.chainid);
        console.log("Consumer:", contract2VRF);
        console.log("SubId:", subscriptionId);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinator);
        coordinator.addConsumer(subscriptionId, contract2VRF);
        vm.stopBroadcast();


    }

    function run() public {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployment);
    }
}