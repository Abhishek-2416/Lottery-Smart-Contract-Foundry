// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title  A sample Raffle Contract
 * @author Abhishek Alimchandani
 * @notice This contract is creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 currentBalance,uint256 numPlayers,uint256 raffState);

    /**Type Declaration */
    enum RaffleState{OPEN,CALCULATING}

    /**State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; //constant variable always be in uppercase
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //Duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(uint256 _entranceFee,uint256 _interval,address vrfCoordinator,bytes32 gasLane,uint64 subscriptionId,uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        s_raffleState = RaffleState.OPEN;
    }

    //The EnterRaffle function is to make people enter into the raffle and also this function is external as we wont have anything other function to call it and external is more gas efficient
    function enterRaffle() external payable{
        //This method is much better than using require as it saves gas
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        //AS A RULE OF THUMB WHENVER WE MAKE A STORAGE UPDATE WE SHOULD EMIT AN EVENT
        //We do this because 1. They make migrating easier 2. Makes front end "indexing" easier
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function of chainlink automation nodes call to see if it is time to perform upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in OPEN state
     * 3. The contract has ETH(aka players)
     * 4. The subcription is funded with LINK
     */
    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */){
        //To check if enough time has been passed
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded,"0x0");
    }

    function performUpkeep(bytes calldata) external{
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;

        //Now pick a random winner, pretty much with this we have a way to actually to make a request with the chainlink contract
        i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    //Now this is function which the chainlink node is going to call in order for us to get our random number back
    //We are taking this function from VRFConsumerBaseV2
    //We should follow the CEI model which is Checks Effects and Interactions
    function fulfillRandomWords(uint256 /* requestId */,uint256[] memory randomWords) internal override{
        //Checks (require,ifelse)
        //Effects (on own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);

        //Interactions (other contract)
        (bool s,) = winner.call{value: address(this).balance}("");
        if(!s){
            revert Raffle__TransferFailed();
        }

    }

    /** Getter Functions */
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }

    function getIntervalTime() external view returns(uint256){
        return i_interval;
    }
}