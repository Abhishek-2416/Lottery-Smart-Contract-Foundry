// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubsrciption, FundSubcription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //Here we are deconstructing the Network Config into thesse parameters
        (
            uint256 _entranceFee,
            uint256 _interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            //In this case we need to create an subscription id
            CreateSubsrciption createSubsrciption = new CreateSubsrciption();
            subscriptionId = createSubsrciption.createSubcription(vrfCoordinator);

            //Now we will fund our subcription thing
            FundSubcription fundSubscription = new FundSubcription();
            fundSubscription.fundSubcription(vrfCoordinator, subscriptionId, link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            _entranceFee,
            _interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId);
        return (raffle, helperConfig);
    }
}
