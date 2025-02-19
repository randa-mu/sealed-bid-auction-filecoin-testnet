import { JsonRpcProvider, ethers, AbiCoder, getBytes, AddressLike } from "ethers";
import 'dotenv/config'
import {
    DecryptionSender__factory,
    BlocklockSender__factory,
    MockBlocklockReceiver__factory,
} from "../../typechain-types";
import { encrypt_towards_identity_g1, Ciphertext } from "../crypto"
import { TypesLib as BlocklockTypes } from "../../typechain-types/src/blocklock/BlocklockSender"
import { IbeOpts } from "../crypto";
import { keccak_256 } from "@noble/hashes/sha3";

// Usage:
// yarn ts-node scripts/mocks/create-timelock-request.ts 

const RPC_URL = process.env.CALIBRATIONNET_RPC_URL;
const blocklockSenderAddr = "0xfF66908E1d7d23ff62791505b2eC120128918F44"
const decryptionSenderAddr = "0x9297Bb1d423ef7386C8b2e6B7BdE377977FBedd3";
const mockBlocklockReceiverAddr = "0x6f637EcB3Eaf8bEd0fc597Dc54F477a33BBCA72B";

async function getWalletBalance(rpcUrl: string, walletAddress: string): Promise<void> {
    try {
        // Connect to the Ethereum network using the RPC URL
        const provider = new ethers.JsonRpcProvider(rpcUrl);

        // Get the wallet balance
        const balance = await provider.getBalance(walletAddress);

        // Convert the balance from Wei to Ether and print it
        console.log(`Balance of ${walletAddress}: ${ethers.formatEther(balance)} ETH`);
    } catch (error) {
        console.error("Error fetching wallet balance:", error);
    }
}

async function latestBlockNumber(provider: JsonRpcProvider) {
    // Fetch the latest block number
    const latestBlockNumber = await provider.getBlockNumber();
    console.log(`Latest Block Number: ${latestBlockNumber}`);
}

async function replacePendingTransaction() {
    let txData = {
        to: "0x5d84b82b750B996BFC1FA7985D90Ae8Fbe773364",
        value: "0", 
        chainId: 314159,
        nonce: 1420,
        gasLimit: 10000000000,
        gasPrice: 2000000000
    }
    // let estimate = await provider.estimateGas(tx)
    // tx.gasLimit = estimate;
    // tx.gasPrice = ethers.parseUnits("0.14085197", "gwei");
    let tx = await signer.sendTransaction(txData)
    let receipt = await tx.wait(1)
    console.log(receipt)
}

async function getTransactionCount(walletAddr: AddressLike) {
    return await provider.getTransactionCount(walletAddr)
}

async function main() {
    const walletAddr = await signer.getAddress()

    try {
        // Get latest block number
        await latestBlockNumber(provider);

        // Get wallet ETH balance
        await getWalletBalance(RPC_URL!, walletAddr);

        await createTimelockRequest();
    } catch (error) {
        console.error("Error fetching latest block number:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });