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
    uint256 subscriptionId;
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

        vm.deal(player, STARTING_BALANCE); // Give the player some ether to work with
    }

    function testRaffleInitialState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // getRaffleState() returns a RaffleState enum
    }

    function testRaffleWhenPlayersPayLessThanEntranceFee() public {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__NotEnoughETH.selector); // Expect the custom error to be reverted
        raffle.enterRaffle(); // Pay less than the entrance fee
    }

    function testRaffleAddsPlayerToPlayersArray() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers(0) == player);
    }

    function testRaffleDontAddPlayersWhenCalculating() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1); // Move time forward to trigger upkeep
        vm.roll(block.number + 1); // Move block forward to trigger upkeep
        raffle.performUpkeep(""); // Perform upkeep


        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.PlayerEntered(player);
        raffle.enterRaffle{value: entranceFee}();
    }
}




//       <style>
//         .libutton {
//           display: flex;
//           flex-direction: column;
//           justify-content: center;
//           padding: 7px;
//           text-align: center;
//           outline: none;
//           text-decoration: none !important;
//           color: #ffffff !important;
//           width: 200px;
//           height: 32px;
//           border-radius: 16px;
//           background-color: #0A66C2;
//           font-family: "SF Pro Text", Helvetica, sans-serif;
//         }
//       </style>
// <a class="libutton" href="https://www.linkedin.com/comm/mynetwork/discovery-see-all?usecase=PEOPLE_FOLLOWS&followMember=pro-mcode" target="_blank">Follow on LinkedIn</a>