// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/linkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubsrciption is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        //To get our subcription Id we need to call in the VRF coordinator
        HelperConfig helperConfig = new HelperConfig();
        //We need the vrf Coordinator to call it so we get the address
        (,, address vrfCoordinator,,,, address link) = helperConfig.activeNetworkConfig();
        return createSubcription(vrfCoordinator);
    }

    //This function now take the address of the vrfCoordinator and send us the subcriptionId
    function createSubcription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating subcription on ChainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is:", subId);
        console.log("Please create your subcription in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubcription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubcriptionUsingConfig() public {
        //So do this we need the our subcriptionId we want to fund we are gonna need the vrfCoordinatorV2 address and also need the LINK address
        //We need the vrf Coordinator to call it so we get the address
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,, address link) = helperConfig.activeNetworkConfig();
        fundSubcription(vrfCoordinator, subId, link);
    }

    function fundSubcription(address vrfCoordinator, uint64 subId, address link) public {
        console.log("Funding Subscription", subId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainId", block.chainid);
        if (block.chainid == 31337) {
            //This is for MOCK
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubcriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId) public {
        console.log("Adding Consumer contract", raffle);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainId", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,,) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("My Contracts", block.chainid);
        addConsumerUsingConfig(raffle);
    }
}
