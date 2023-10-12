// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract CreateSubscription is Script{
    function createSubcriptionUsingConfig() public returns(uint64){
        HelperConfig helperConfig = new HelperConfig();
    }

    function run() external returns(uint64){
        return createSubcriptionUsingConfig();
    }
}