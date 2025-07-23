// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SealedBidAuction} from "src/SealedBidAuction.sol";

contract SealedBidAuctionScript is Script {
    function run() external {
        console.log("Current chain height: ", block.number);

        address blocklockSenderContractAddress = vm.envAddress("BLOCKLOCK_SENDER_CONTRACT_ADDRESS");

        vm.broadcast();
        SealedBidAuction auction = new SealedBidAuction(blocklockSenderContractAddress);

        console.log("SealedBidAuction deployed at: ", address(auction));
        
        // Start the auction
        uint256 biddingEndBlock = block.number + 100;
        console.log("Starting auction with bid closing at chain height: ", biddingEndBlock);
        
        vm.broadcast();
        auction.startAuction(biddingEndBlock);
    }
}
