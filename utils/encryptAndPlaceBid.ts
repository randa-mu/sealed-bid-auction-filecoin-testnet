import { ethers, getBytes } from "ethers";
import { Blocklock, encodeCiphertextToSolidity, encodeCondition,encodeParams } from "blocklock-js";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

async function encryptAndPlaceBid(
    privateKey: string,
    contractAddress: string,
    bidAmount: string
) {
    try {
        // Initialize provider
        const provider = new ethers.JsonRpcProvider(process.env.TESTNET_RPC_URL);

        // User wallet
        const wallet = new ethers.Wallet(privateKey, provider);

        // Connect to the contract
        const sealedBidContract = new ethers.Contract(contractAddress, require("../out/SealedBidAuction.sol/SealedBidAuction.json").abi, wallet);
        // const blocklockjs = new Blocklock(wallet, await sealedBidContract.blocklock());
        const blocklockjs = Blocklock.createBaseSepolia(wallet)

        // Get block height for bidding deadline
        const biddingEndBlockHight = await sealedBidContract.biddingEndBlock();
        console.log(`Bidding end block: ${biddingEndBlockHight}`);

        // Encode message for encryption
        const msg = ethers.parseEther(bidAmount);
        const msgBytes = encodeParams(["uint256"], [msg]);
        const encodedMessage = getBytes(msgBytes);
        console.log(`Biding Amount is : ${msg}`);

        // Encrypt the encoded message
        const ciphertext = blocklockjs.encrypt(encodedMessage, BigInt(biddingEndBlockHight));

        // Send sealed bid transaction
        const reservePrice = await sealedBidContract.RESERVE_PRICE();
        const callbackGasLimit = 1_000_000n;
        const [requestCallBackPrice] = await blocklockjs.calculateRequestPriceNative(callbackGasLimit);

        const tx = await sealedBidContract.placeSealedBid(
            callbackGasLimit, 
            encodeCiphertextToSolidity(ciphertext), 
            { value: (requestCallBackPrice+reservePrice) });
        const receipt = await tx.wait(2);

        if (!receipt) {
            throw new Error("Transaction has not been mined");
        }

        // Fetch bid id and bidder address
        const bidder = await wallet.getAddress();
        const bidID = await sealedBidContract.bidderToBidID(bidder);

        // Log transaction receipt
        console.log(`Sealed bid placed successfully! Transaction hash: ${receipt.hash}`);
        console.log(`Bid ID: ${bidID}`);
        console.log(`Bidder: ${bidder}`);
    } catch (error) {
        console.error("Error:", (error as Error).message || error);
    }
}

// Main function to execute the script
async function main() {
    // Change these values as needed
    const PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY;
    const contractAddress = process.env.BID_CONTRACT_ADDRESS; // Change this as needed
    if (!contractAddress) {
      throw new Error("BID_CONTRACT_ADDRESS environment variable is not set");
    }
    const BID_AMOUNT = "3.162"; // Bid amount in ETH

    // Ensure required values are provided
    if (!PRIVATE_KEY) {
        console.error("PRIVATE_KEY is missing in .env file!");
        process.exit(1);
    }

    // Execute the function
    await encryptAndPlaceBid(PRIVATE_KEY, contractAddress, BID_AMOUNT);
}

// Run the script
main().catch((error) => {
    console.error("Error:", (error as Error).message || error);
});
