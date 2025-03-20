// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SealedBidAuction} from "src/SealedBidAuction.sol";

contract SealedBidAuctionScript is Script {
    function run() external {
        console.log("Current chain height: ", block.number);

        uint256 biddingDurationInBlocks = block.number + 10;
        address blocklockSenderContractAddress = 0xfF66908E1d7d23ff62791505b2eC120128918F44;

        console.log("Bid closes at chain height: ", biddingDurationInBlocks);

        vm.broadcast();
        SealedBidAuction auction = new SealedBidAuction(biddingDurationInBlocks, blocklockSenderContractAddress);

        console.log("SealedBidAuction deployed at: ", address(auction));
    }
}
