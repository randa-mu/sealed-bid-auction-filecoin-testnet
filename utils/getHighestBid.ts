import { ethers } from "ethers";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Define Types
interface PointG2 {
  x: [bigint, bigint];
  y: [bigint, bigint];
}

interface BidResult {
  highestBidAmount: bigint;
  highestBidderAddress: string;
}

// Function to fetch bid details
async function getHighestBid(contractAddress: string) {
  try {
    // Set up provider
    const provider = new ethers.JsonRpcProvider(process.env.TESTNET_RPC_URL);

    // Read ABI from file
    const contractABI = require("../out/SealedBidAuction.sol/SealedBidAuction.json").abi;

    // Connect to the contract
    const contract = new ethers.Contract(contractAddress, contractABI, provider);

    console.log(`Current Block Height: ${await provider.getBlockNumber()}`);

    const blockLockHight = await contract.biddingEndBlock();
    console.log(`Bidding end block: ${blockLockHight}`);

    // Call the getBidWithBidID function
    const result: BidResult = await contract.getHighestBid();

    // Log the current bid data
    console.log(`Highest Bid Amount: ${ethers.formatEther(result.highestBidAmount)} ETH`);
    console.log(`Highest Bidder: ${result.highestBidderAddress}`);
  } catch (error) {
    console.error("Error fetching bid details:", error);
  }
}

// Main function to handle script execution
async function main() {
  const contractAddress = process.env.BID_CONTRACT_ADDRESS; // Change this as needed
  if (!contractAddress) {
    throw new Error("BID_CONTRACT_ADDRESS environment variable is not set");
  }

  // Fetch bid details
  await getHighestBid(contractAddress);
}

// Run the main function
main().catch((error) => console.error("Unhandled error:", error));
