//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


/**
 * @title A sample Raffle Contract
 * @author Yug Agarwal
 * @notice This contract is for creating a sample Raffle Contract
 * @dev Implements Chainlink VRFv2.5
 */


contract Raffle {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();


    uint256 private immutable i_enteranceFee;
    address payable[] private s_players;


    constructor(uint256 enteranceFee){
        i_enteranceFee = enteranceFee;
    }


    function enterRaffle() public payable{
        //require(msg.value >= i_enteranceFee, "Not enough ETH to enter the raffle");   //not gas efficient
        if(msg.value < i_enteranceFee){
            revert Raffle__SendMoreToEnterRaffle(); //in 0.8.26 and above we can revert in require, although using if-revert is most gas efficient
        }
        s_players.push(payable(msg.sender));

        // 1. Makes migration easier
        // 2. Makes front-end "indexing" easier
    }

    function pickWinner() public {
        
    }


    /* Getter Functions */

    function getEnteranceFee() external view returns(uint256){
        return i_enteranceFee;
    }
}