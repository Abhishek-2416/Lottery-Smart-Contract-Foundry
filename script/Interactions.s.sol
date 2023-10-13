// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract CreateSubsrciption is Script{

    function createSubscriptionUsingConfig() public returns(uint64){
        //To get our subcription Id we need to call in the VRF coordinator
        HelperConfig helperConfig = new HelperConfig();
        //We need the vrf Coordinator to call it so we get the address
        (,,address vrfCoordinator,,,) = helperConfig.activeNetworkConfig();
        return createSubcription(vrfCoordinator);
    }

    //This function now take the address of the vrfCoordinator and send us the subcriptionId
    function createSubcription(address vrfCoordinator) public returns(uint64){
        console.log("Creating subcription on ChainId: ",block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is:",subId);
        console.log("Please create your subcription in HelperConfig.s.sol");
        return subId;
    }


    function run() external returns(uint64){
        return createSubscriptionUsingConfig();
    }
}

contract FundSubcription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubcriptionUsingConfig() public {
        //So do this we need the our subcriptionId we want to fund we are gonna need the vrfCoordinatorV2 address and also need the LINK address
        //We need the vrf Coordinator to call it so we get the address
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,uint64 subId,) = helperConfig.activeNetworkConfig();

    }

    function run() external{
        fundSubcriptionUsingConfig();
    }
}