// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";



/**
 * @title 
 * @author 
 * @notice 
 */

contract Raffle is VRFConsumerBaseV2Plus {

    // Error handling 
    error Raffle__NotEnougETH();
    address payable[] private s_players;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    
    event PlayerEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp; // block.timestamp is a global variable that returns the current block timestamp
        vrfCoordinator.requestRandomWords();
    }

    function enterRaffle() external payable {
        // require(msg.value =< _entranceFee, NotEnougETH());
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnougETH();
        }

        s_players.push(payable(msg.sender));
        emit PlayerEntered(msg.sender); // Emit an event when we update a dynamic array or mapping

        VRFV2PlusClient.RandomWordsRequest requestWord = VRFV2PlusClient.RandomWordsRequest({
            keyHash: s_keyHash,
            subId: s_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 s_requestId = s_vrfCoordinator.requestRandomWords(requestWord);
    }


    function selectWinner() external {
        uint256 currentTime = block.timestamp - s_lastTimeStamp;
        if (currentTime > i_interval) {
            revert();
        }

    }


    // Getter functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
    

    function getPlayers() external view returns (address[] memory) {
        // return s_players;
    }




}