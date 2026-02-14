// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// // Importing Chainlink VRF interfaces for randomness
// import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// /**
//  * @title Raffle
//  * @dev A contract to manage a raffle (lottery) using Chainlink VRF for verifiable randomness.
//  */
// contract NewRaffle is VRFConsumerBaseV2 {
//     /* Errors */
//     error Raffle__NotEnoughEthSent();       // Custom error if entrance fee is too low
//     error Raffle__TransferFailed();         // Custom error if prize payout fails
//     error Raffle__RaffleNotOpen();          // Custom error if raffle is not currently open
//     error Raffle__UpkeepNotNeeded(          // Custom error with parameters for debugging
//         uint256 currentBalance,
//         uint256 numPlayers,
//         uint256 raffleState
//     );

//     /* Type Declarations */
//     enum RaffleState {
//         OPEN,    // Raffle is accepting players
//         CALCULATING // Winner is being calculated (VRF request in flight)
//     }

//     /* State Variables */
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private constant NUM_WORDS = 1;

//     // Chainlink VRF Variables
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
//     bytes32 private immutable i_gasLane;
//     uint64 private immutable i_subscriptionId;
//     uint32 private constant CALLBACK_GAS_LIMIT = 100000;

//     // Raffle Variables
//     uint256 private immutable i_entranceFee;
//     address payable[] private s_players;
//     uint256 private s_lastTimeStamp;
//     address private s_recentWinner;
//     RaffleState private s_raffleState;

//     /* Events */
//     event RaffleEnter(address indexed player);
//     event RequestedRaffleWinner(uint256 indexed requestId);
//     event WinnerPicked(address indexed winner);

//     /**
//      * @dev Constructor initializes the raffle with Chainlink VRF parameters.
//      * @param vrfCoordinatorV2 Address of the Chainlink VRF Coordinator.
//      * @param entranceFee The cost to enter the raffle.
//      * @param gasLane The gas lane key for Chainlink VRF (max gas price).
//      * @param subscriptionId The Chainlink VRF subscription ID.
//      */
//     constructor(
//         address vrfCoordinatorV2,
//         uint256 entranceFee,
//         bytes32 gasLane,
//         uint64 subscriptionId
//     ) VRFConsumerBaseV2(vrfCoordinatorV2) {
//         i_entranceFee = entranceFee;
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane;
//         i_subscriptionId = subscriptionId;

//         s_raffleState = RaffleState.OPEN;
//         s_lastTimeStamp = block.timestamp;
//     }

//     /**
//      * @dev Allows a user to enter the raffle by paying the entrance fee.
//      */
//     function enterRaffle() public payable {
//         // Check if enough ETH was sent
//         if (msg.value < i_entranceFee) {
//             revert Raffle__NotEnoughEthSent();
//         }
//         // Check if raffle is open
//         if (s_raffleState != RaffleState.OPEN) {
//             revert Raffle__RaffleNotOpen();
//         }

//         // Add player to the array
//         s_players.push(payable(msg.sender));

//         // Emit event for logging
//         emit RaffleEnter(msg.sender);
//     }

//     /**
//      * @dev This is the function that the Chainlink Automation nodes call
//      * to see if it's time to pick a winner.
//      * 
//      * Conditions for upkeep:
//      * 1. The time interval has passed.
//      * 2. The raffle is in the OPEN state.
//      * 3. The contract has ETH (players).
//      * 4. (Implicit) The subscription is funded.
//      */
//     function checkUpkeep(
//         bytes memory /* checkData */
//     )
//         public
//         view
//         returns (
//             bool upkeepNeeded,
//             bytes memory /* performData */
//         )
//     {
//         bool isOpen = (RaffleState.OPEN == s_raffleState);
//         bool timePassed = ((block.timestamp - s_lastTimeStamp) > 30 seconds); // Example interval: 30s
//         bool hasPlayers = (s_players.length > 0);
//         bool hasBalance = (address(this).balance > 0);

//         upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
//         return (upkeepNeeded, "0x0");
//     }

//     /**
//      * @dev Called by Chainlink Automation if checkUpkeep returns true.
//      * Requests a random number from Chainlink VRF.
//      */
//     function performUpkeep(bytes calldata /* performData */) external {
//         // Revert if upkeep is not needed (security check)
//         (bool upkeepNeeded, ) = checkUpkeep("");
//         if (!upkeepNeeded) {
//             revert Raffle__UpkeepNotNeeded(
//                 address(this).balance,
//                 s_players.length,
//                 uint256(s_raffleState)
//             );
//         }

//         // Update state to CALCULATING to prevent re-entrancy or double entries
//         s_raffleState = RaffleState.CALCULATING;

//         // Request randomness from Chainlink VRF
//         VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
//             keyHash: i_gasLane,
//             subId: i_subscriptionId,
//             requestConfirmations: REQUEST_CONFIRMATIONS,
//             callbackGasLimit: i_callbackGasLimit,
//             numWords: NUM_WORDS,
//             extraArgs: VRFV2PlusClient._argsToBytes(
//                 VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
//             )
//         });

//         uint256 s_requestId =  s_vrfCoordinator.requestRandomWords(req);



//         // Emit event for tracking
//         emit RequestedRaffleWinner(requestId);
//     }

//     /**
//      * @dev Callback function used by VRF Coordinator to return the random winner.
//      * @param requestId The ID of the request (can be used to verify).
//      * @param randomWords The array of random numbers returned.
//      */
//     function fulfillRandomWords(
//         uint256 /* requestId */,
//         uint256[] memory randomWords
//     ) internal override {
//         // Use modulo to pick a winner index based on the random number
//         uint256 indexOfWinner = randomWords[0] % s_players.length;
//         address payable recentWinner = s_players[indexOfWinner];
//         s_recentWinner = recentWinner;

//         // Reset the raffle state
//         s_raffleState = RaffleState.OPEN;
        
//         // Reset players array and timestamp
//         s_players = new address payable[](0);
//         s_lastTimeStamp = block.timestamp;
        
//         // Emit event
//         emit WinnerPicked(recentWinner);

//         // Send the prize money to the winner
//         (bool success, ) = recentWinner.call{value: address(this).balance}("");
//         if (!success) {
//             revert Raffle__TransferFailed();
//         }
//     }

//     /* Getter Functions (View/Pure) */

//     function getEntranceFee() public view returns (uint256) {
//         return i_entranceFee;
//     }

//     function getPlayer(uint256 index) public view returns (address) {
//         return s_players[index];
//     }

//     function getRaffleState() public view returns (RaffleState) {
//         return s_raffleState;
//     }

//     // Get the raw array of players (less gas efficient for large arrays)
//     function getPlayers() public view returns (address payable[] memory) {
//         return s_players;
//     }

//     function getLastTimeStamp() public view returns (uint256) {
//         return s_lastTimeStamp;
//     }

//     function getRecentWinner() public view returns (address) {
//         return s_recentWinner;
//     }
// }
