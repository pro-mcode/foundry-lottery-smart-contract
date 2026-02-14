// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
 
import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    address public player = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether; // 1ether = 10^18 wei

    uint256 entranceFee;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    
    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory chainConfig = helperConfig.getConfig(); // chainConfig is a struct
        entranceFee = chainConfig.entranceFee; // entranceFee is a uint256
        vrfCoordinator = chainConfig.vrfCoordinator; // vrfCoordinator is an address
        keyHash = chainConfig.keyHash; // keyHash is a bytes32
        subscriptionId = chainConfig.subscriptionId; // subscriptionId is a uint64
        callbackGasLimit = chainConfig.callbackGasLimit;
    }

    function testRaffleInitialState() public {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // getRaffleState() returns a RaffleState enum
    }
}