//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
* @title: A sample Raffle Contract
* @author: Jund
* @notice: This contract is for creating a sample raffle
* @dev: Implements a Chainlink VRFv2
*/


import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {

    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);


    /* Type Declarations */
    enum RaffleState {
        OPEN,    //0
        CALCULATING  //1
    }


    //**State Variables*/

    uint16  private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)
        VRFConsumerBaseV2(vrfCoordinator)
        {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;

    }

    function enterRaffle() external payable{
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    //When is the winner supposed to be picked?
    //**
    //*@dev This is function that the Chainlink Automation nodes call to see if it's time to perform an upkeep
    //* The following should be true if it to return true:
    //1. The time interval has passed between raffle runs
    //2. The raffle is in the OPEN state
    //3. The contract has ETH (aka, players)
    //4. (Implicit) The subscription is funded with LINK



    function checkUpkeep(
       bytes memory /*checkData*/
        ) public view returns (bool upkeepNeeded, bytes memory /*performdata*/)  {
         bool timeHasPassed =  ((block.timestamp - s_lastTimeStamp) >= i_interval);
         bool isOpen = RaffleState.OPEN == s_raffleState;
         bool hasBalance = address(this).balance > 0;
         bool hasPlayers = s_players.length > 0;
         upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
         return (upkeepNeeded, "0x0");
             }

    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(
                    address(this).balance,
                    s_players.length,
                    uint256(s_raffleState)
                    );

        }

       //Check to see if enough time has passed
       s_raffleState = RaffleState.CALCULATING;
          uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId); 
       }


    function fulfillRandomWords(
            uint256 /*requestId */,
            uint256[] memory randomWords
    ) internal override {
        // Checks
        // Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];

      s_recentWinner = winner;

      s_raffleState = RaffleState.OPEN;

      s_players = new address payable[](0);

      s_lastTimeStamp = block.timestamp;

      emit PickedWinner(winner);

      //Interactions (without contracts)
      (bool success,) = winner.call{value: address(this).balance}("");
      if (!success) {
          revert Raffle__TransferFailed();
      }
    }

    /**Getter Functions   */


    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
}
    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }
    function getPlayer(uint256 indexOfPlayer) external view returns (address){
      return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns(address) {
      return s_recentWinner; 
    }

    function getLengthOfPlayers() external view returns(uint256) {
      return s_players.length; 
    }
    function getLastTimeStamp() external view returns(uint256) {
      return s_lastTimeStamp; 

    }
}


