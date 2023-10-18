// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test{
    /** Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    /**State Variables */
    uint256 _entranceFee;
    uint256 _interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external{
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
        (
            _entranceFee,
            _interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig(); 
        vm.deal(PLAYER,STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
        //We are just checking if the current value of RaffleState is OPEN
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////
    /// enterRaffle ///
    //////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public{
        //Arrange
        hoax(PLAYER,STARTING_USER_BALANCE);
        //Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        //Assert
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        assertEq(raffle.getPlayer(0),PLAYER);
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false);
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value:_entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:_entranceFee}();
        //Now to test this condition we need to call the performUpkeep function and for that we need to check all conditions of checkUpKeep
        //This is test to go ahead in time
        vm.warp(block.timestamp + _interval + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
    }

    ////////////////////
    /// checkUpKeep ///
    ///////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public{
        //So here for testing this we need to make sure all the other parameters should pass

        //Arrange
        vm.warp(block.timestamp + _interval + 1);

        //As we know here in the checkUpKeep function will returns bool 
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //assert
        assertEq(upkeepNeeded,false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value : _entranceFee}();
        vm.warp(block.timestamp + _interval + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        
        //Assert 
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed()public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();

        //Act 
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        //Assert 
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + _interval + 1);

        //Act 
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        //Assert 
        assertEq(upKeepNeeded,true);
    }

    ////////////////////
    // performUpKeep //
    ///////////////////

    function testPerformUpKeepOnlyRunIfCheckUpKeepIsTrue() public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + _interval + 1);

        //Act 
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertIfCheckUpKeepIsFalse() public{
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        
        //Act 
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
                )
            );
        raffle.performUpkeep("");
    }

    modifier RaffleEnterAndTimePassed(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + _interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //What if we need to test using the output of an Event ? we need to remeber that events are not accessible by contracts
    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public RaffleEnterAndTimePassed{
        //Act 
        //It tells the VM to start recording all the emitted Events. To access them we use getRecordLogs
        vm.recordLogs();
        raffle.performUpkeep(""); //This will emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); //Vm.Log[] is special type that comes with foundry tests and getRecorded is going to get all the 

        //Now we can get the requestId from the logs that were emitted // All logs are in bytes32
        bytes32 requestId = entries[1].topics[1];

        //Here the 0th topic will be the entire event and the 1st topic will be the requestId

        //Now we will check that the requestid was actually generated
        assert(uint256(requestId) > 0);
    }

    ///////////////////////////
    // FullFillRandom Words //
    /////////////////////////

    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestid) public RaffleEnterAndTimePassed{
        //Arrange
        //This is where we will try and make the Mock call the fullfill random words
        vm.expectRevert();

        //We know that will fail for requestId when we set to 0 , so we need to check even other numbers to check requestId fails at different requestIds tooo
        //For this we are going to do a fuzz test , foundry will  create random numbers and run it multiple times
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestid,address(raffle));
    }

    function testFullFillRandomWordsPickAWinnerResetsAnsSendsMoney()public RaffleEnterAndTimePassed{
        /**Steps
         * We will enter the lottery a couple of times 
         * We will move the timeup so checkUpKeep returns true
         * We will performUpKeep and kick off a request to get a random number
         * We will pretend to be chainlink VRF to respond and call fullfillRandomWords
         */
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i < startingIndex+additionalEntrants;i++){
            address player = address(uint160(i));
            hoax(player,1 ether);
            raffle.enterRaffle{value: _entranceFee}();
        }

        
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entires = vm.getRecordedLogs();
        bytes32 requestId = entires[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimestamp();

        //Pretend to be chainlink Node and pickup the winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));

        //Assert 
        //Our raffleState should be open and back at 0
        assert(uint256(raffle.getRaffleState()) == 0);

        //Pick a Winner
        assert(raffle.getRecentWinner() != address(0));

        //Make sure the length of players is again 0
        assert(raffle.getLengthOfPlayers() == 0);

        //Update the timestamp
        assert(previousTimeStamp < raffle.getLastTimestamp());

        
    }
}