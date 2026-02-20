// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
 
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CODE_CONSTANT} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CODE_CONSTANT {
    Raffle raffle;
    HelperConfig helperConfig;

    address public player = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether; // 1 ether = 10^18 wei
    bytes32 requestId; // requestId is a bytes32

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

    modifier raffleEntered() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1); // Move time forward to trigger upkeep
        vm.roll(block.number + 1); // Move block forward to trigger upkeep
        _; // Perform upkeep
    }

    function testRaffleDontAddPlayersWhenCalculating() public raffleEntered {
        // raffleEntered(); // Call the raffleEntered modifier to perform upkeep
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

    function testCheckUpkeepReturnsFalseWhenNoBalance() public {
        vm.warp(block.timestamp + raffle.getInterval() + 1); // Move time forward to trigger upkeep
        vm.roll(block.number + 1); // Move block forward to trigger upkee

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenNotOpen() public raffleEntered {
        // raffleEntered(); // Call the raffleEntered modifier to perform upkeep
        raffle.performUpkeep(""); // Perform upkeep

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
        // raffleEntered(); // Call the raffleEntered modifier to perform upkeep
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() public  {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState currentState = raffle.getRaffleState();

        vm.prank(player); // Set the player as the sender
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, currentState)
        );
        raffle.performUpkeep("");
    }

    modifier recordLogs() {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        requestId = entries[1].topics[1]; // Assuming the requestId is the second topic in the logs
        _; // Continue with the test after performing upkeep and recording logs
    }
    function testPerformUpkeepUpdatesStateAndEmitsRequestId() public raffleEntered recordLogs{
        // raffleEntered(); // Call the raffleEntered modifier to perform upkeep
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // recordLogs(); // Record logs to capture the requestId emitted during performUpkeep call

        assert(uint256(requestId) > 0); // requestId should be greater than 0
        assert(uint256(raffleState) == 1); // RaffleState.CALCULATING is the second value in the enum, which corresponds to 1
    }

    modifier skipFork() {
        if (block.chainid != ANVIL_LOCAL_CHAIN_ID) {
            return; // Skip the modifier if the chain is not the local chain
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 runTime) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(runTime, address(raffle));
    }

    
    function testFulfillRandomWordsPicksWinnerAndResetState() public raffleEntered skipFork {
        // Arrange
        uint256 otherPlayers = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < otherPlayers + startingIndex; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}(); // Enter the raffle with the new player
        }

        uint256 startingTimeStamp = raffle.getTimeStamp();
        uint256 winnerStartinBalance = expectedWinner.balance;

        // Acts
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        requestId = entries[1].topics[1]; // Assuming the requestId is the second topic in the logs
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState state = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getTimeStamp();
        uint256 prize = entranceFee * (otherPlayers + 1); // Total prize is the entrance fee multiplied by the number of players plus 1

        assert(recentWinner == expectedWinner);
        assert(state == Raffle.RaffleState(0)); // RaffleState.OPEN is the first value in the enum
        assert(winnerBalance == winnerStartinBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }


    // Challenge
    // testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed
    // testCheckUpkeepReturnsTrueIfParametersAreGood
}

