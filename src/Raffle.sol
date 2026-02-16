// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__NotEnoughETH();
    error Raffle__NotOpen();
    error Raffle__TransferFailed();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 players, uint256 state);

    enum RaffleState { OPEN, CALCULATING }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;

    bytes32 private immutable i_gasLane;
    uint256  private immutable i_subscriptionId;
    uint32  private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;
    address private s_recentWinner;

    event PlayerEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughETH();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__NotOpen();

        s_players.push(payable(msg.sender));
        emit PlayerEntered(msg.sender);
    }

    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;

        upkeepNeeded = timePassed && hasPlayers && hasBalance && isOpen;
        return (upkeepNeeded, bytes(""));
    }

    function performUpkeep(bytes calldata) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        /* uint256 s_requestId = */ s_vrfCoordinator.requestRandomWords(req);

        // NOTE: In V2 Plus, you request via the coordinator wrapper exposed by the base.
        // The exact call name depends on the version you imported.
        // e.g. _requestRandomWords(req) or s_vrfCoordinator.requestRandomWords(req)
        // (you need to match the actual base contract API)
    }

    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool ok,) = winner.call{value: address(this).balance}("");
        if (!ok) revert Raffle__TransferFailed();

        emit WinnerPicked(winner);
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayers) external view returns (address) {
        return s_players[indexOfPlayers];
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }
}
