// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test{
    /** Events */
    event EnteredRaffle(address indexed player);


    Raffle raffle;
    HelperConfig helperConfig;

    uint256 _entranceFee;
    uint256 _interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

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
            callbackGasLimit
        ) = helperConfig.activeNetworkConfig(); 
        vm.deal(PLAYER,STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
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

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value:_entranceFee}();
        //Assert
        assertEq(raffle.getPlayer(0),PLAYER);
    }

    function testEmitsEventOnEntrance() public{
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false);
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value:_entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:_entranceFee}();
        vm.warp(block.timestamp + _interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:_entranceFee}();
    }


}