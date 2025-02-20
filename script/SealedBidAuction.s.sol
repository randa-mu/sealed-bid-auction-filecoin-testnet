// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SealedBidAuction} from "../src/SealedBidAuction.sol";

contract SealedBidAuctionScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("CALIBRATION_TESTNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        
        uint biddingEndBlock = block.number + 200;
        address blocklockSenderContractAddress = 0xfF66908E1d7d23ff62791505b2eC120128918F44;
        
        SealedBidAuction auction = new SealedBidAuction(biddingEndBlock, blocklockSenderContractAddress);

        console.log("SealedBidAuction deployed at: ", address(auction));

        vm.stopBroadcast();
    }
}
