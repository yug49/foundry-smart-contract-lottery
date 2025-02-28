//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Yug Agarwal
 * @notice This contract is for creating a sample Raffle Contract
 * @dev  Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        OPEN, // index 0
        CALCULATING //index 1
    }

    /* State Variables */
    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval; // duration of a lottery in seconds
    bytes32 private immutable i_keyHash; //gas willing to pay
    uint256 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit; //gaz limit
    uint32 private constant NUM_WORDS = 1; //number of random numbers willing to generate
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Evrents */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subsriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        //if parent has a constructor, always call it when calling the child's
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subsriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_lastTimeStamp = block.timestamp; //current block timestamp
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //require(msg.value >= i_enteranceFee, "Not enough ETH to enter the raffle");   //not gas efficient
        if (msg.value < i_enteranceFee) {
            revert Raffle__SendMoreToEnterRaffle(); //in 0.8.26 and above we can revert in require, although using if-revert is most gas efficient
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        // Events:
        // 1. Makes migration easier
        // 2. Makes front-end "indexing" easier
        emit RaffleEntered(msg.sender); //every time you update storage, you will want to emit an eventw
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see if the lottery is ready to have a winner picked.
     * The following should be true in order for upKeepNeed to be true:
     * 1. The time interval has passed between raffle runs
     * 2. the lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has ETH
     * @param - ignored
     * @return upKeepNeeded - true if it's time to restart the lottery
     * @return - ignoreed
     */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upKeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upKeepNeeded, "");
    }

    function performUpKeep(bytes calldata /* performData */) external {
        // 1. Get a random number
        // 2. Use Random number to pick a player
        // 3. Be automatically called
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;

        // Get our random number
        // 1. Request RNG
        // 2. Get RNG
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callBackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 reqestId = s_vrfCoordinator.requestRandomWords(request);

        //Is this redundant? -> yes coz vrf also emits an event for this
        emit RequestedRaffleWinner(reqestId);
    }

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        // Checks --> require, conditionals etc.

        // Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions */

    function getEnteranceFee() external view returns (uint256) {
        return i_enteranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
}
