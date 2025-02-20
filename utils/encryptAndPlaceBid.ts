import { ethers, getBytes, parseEther, Result, EventFragment, Interface, TransactionReceipt } from "ethers";
// @ts-ignore
import { Blocklock, SolidityEncoder, encodeCiphertextToSolidity } from "blocklock-js";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

const BLOCKLOCK_DEFAULT_PUBLIC_KEY = {
    x: {
        c0: BigInt("0x2691d39ecc380bfa873911a0b848c77556ee948fb8ab649137d3d3e78153f6ca"),
        c1: BigInt("0x2863e20a5125b098108a5061b31f405e16a069e9ebff60022f57f4c4fd0237bf"),
    },
    y: {
        c0: BigInt("0x193513dbe180d700b189c529754f650b7b7882122c8a1e242a938d23ea9f765c"),
        c1: BigInt("0x11c939ea560caf31f552c9c4879b15865d38ba1dfb0f7a7d2ac46a4f0cae25ba"),
    },
};

async function encryptAndPlaceBid(
    privateKey: string,
    contractAddress: string,
    bidAmount: string
) {
    try {
        // Initialize provider
        const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);

        // User wallet
        const wallet = new ethers.Wallet(privateKey, provider);

        // Connect to the contract
        const sealedBidContract = new ethers.Contract(contractAddress, require("../out/SealedBidAuction.sol/SealedBidAuction.json").abi, wallet);
        const blocklockjs = new Blocklock(wallet, await sealedBidContract.blocklock());

        // Get block height for bidding deadline
        const blockHeight = await sealedBidContract.biddingEndBlock();

        const msg = ethers.parseEther(bidAmount);
        const encoder = new SolidityEncoder()
        const msgBytes = encoder.encodeUint256(msg);
        const encodedMessage = getBytes(msgBytes);

        // Encrypt the encoded message
        const ciphertext = blocklockjs.encrypt(encodedMessage, blockHeight, BLOCKLOCK_DEFAULT_PUBLIC_KEY);

        // Send sealed bid transaction
        const reservePrice = await sealedBidContract.reservePrice();
        const tx = await sealedBidContract.placeSealedBid(encodeCiphertextToSolidity(ciphertext), { value: reservePrice });
        const receipt = await tx.wait(1);

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
    const PRIVATE_KEY = process.env.CALIBRATION_TESTNET_PRIVATE_KEY;
    const CONTRACT_ADDRESS = "0x033B6302e593eb39813dCC521cde0d660189eDc3";
    const BID_AMOUNT = "4"; // Bid amount in ETH

    // Ensure required values are provided
    if (!PRIVATE_KEY) {
        console.error("PRIVATE_KEY is missing in .env file!");
        process.exit(1);
    }

    // Execute the function
    await encryptAndPlaceBid(PRIVATE_KEY, CONTRACT_ADDRESS, BID_AMOUNT);
}

// Run the script
main().catch((error) => {
    console.error("Error:", (error as Error).message || error);
});
