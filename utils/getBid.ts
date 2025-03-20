import { ethers } from "ethers";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Define Types
interface PointG2 {
  x: [bigint, bigint];
  y: [bigint, bigint];
}

interface Ciphertext {
  u: PointG2;
  v: string;
  w: string;
}

interface BidResponse {
  sealedBid: Ciphertext;
  decryptionKey: string;
  unsealedBid: bigint;
  bidder: string;
  revealed: boolean;
}

// Function to fetch bid details
async function getBidDetails(bidID: bigint, contractAddress: string) {
  try {
    // Set up provider
    const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);

    // Read ABI from file
    const contractABI = require("../out/SealedBidAuction.sol/SealedBidAuction.json").abi;

    // Connect to the contract
    const contract = new ethers.Contract(contractAddress, contractABI, provider);
    
    // Call the getBidWithBidID function
    const bidDetails: BidResponse = await contract.getBidWithBidID(bidID);

    // Convert the `bytes` fields to raw bytes if needed
    const decryptionKeyBytes = ethers.hexlify(bidDetails.decryptionKey);

    // Log the current bid data
    console.log("Sealed Bid:", {
      U: { x: bidDetails.sealedBid.u.x, y: bidDetails.sealedBid.u.y },
      V: bidDetails.sealedBid.v,
      W: bidDetails.sealedBid.w,
    });
    console.log("Decryption Key:", decryptionKeyBytes);
    console.log("Unsealed Amount:", bidDetails.unsealedBid.toString());
    console.log("Bidder Address:", bidDetails.bidder);
    console.log("Revealed:", bidDetails.revealed);
  } catch (error) {
    console.error("Error fetching bid details:", error);
  }
}

// Main function to handle script execution
async function main() {
  // Define bid ID and contract address
  const bidId: string = "135"; // Change this as needed
  const contractAddress: string = "0xF9FB4cA00fd8249Ad1Db13433D94d990eD9F6F36"; // Change this as needed

  // Convert bid ID to BigInt
  const bidID = BigInt(bidId);

  // Fetch bid details
  await getBidDetails(bidID, contractAddress);
}

// Run the main function
main().catch((error) => console.error("Unhandled error:", error));
