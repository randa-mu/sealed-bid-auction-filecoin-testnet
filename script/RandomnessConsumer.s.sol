// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RandomnessConsumer} from "src/RandomnessConsumer.sol";

contract RandomnessConsumerScript is Script {
    function run() external {
        vm.broadcast();
        RandomnessConsumer randomnessConsumer = new RandomnessConsumer();

        console.log("RandomnessConsumer deployed at: ", address(randomnessConsumer));
    }
}
