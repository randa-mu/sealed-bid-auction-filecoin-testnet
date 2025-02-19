// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SealedBidAuctionModule = buildModule("SealedBidAuctionModule", (m) => {
  const biddingEndBlock = 45n;
  const blocklockContractAddr = "0xfF66908E1d7d23ff62791505b2eC120128918F44"; 
  const sealedBidAuction = m.contract("SealedBidAuction", [biddingEndBlock, blocklockContractAddr], {});

  return { sealedBidAuction };
});

export default SealedBidAuctionModule;
