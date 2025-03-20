# Sealed Bid Auction Smart Contract Tutorial

This repository provides the source code for a Sealed Bid Auction Smart Contract Tutorial which is a step-by-step Solidity guide for implementing a timelock encryption-based **sealed-bid auction** on the Filecoin Calibration Testnet. In a sealed bid auction, bidders submit their bids privately (encrypted bids are submitted on-chain), and only after the bidding phase ends is the winner revealed (encrypted bids are automatically decrypted on-chain at the end of the bidding phase).

## Features
- **Private Bidding:** Utilizes timelock encryption to keep bids confidential until the reveal phase.
- **Phased Auction Process:** Structured into encryption, bidding, revealing, and settlement phases.
- **On-Chain Decryption:** Employs smart contracts to automatically decrypt and reveal bids at the designated block.
- **Fair Competition:** Prevents last-minute bid sniping and promotes genuine valuation-based bidding.


## Repository Structure
```
sealed-bid-auction
├── src/   # Solidity smart contracts
├── scripts/     # Deployment scripts
├── test/        # Unit tests for the contract
├── utils/       # Smart contract interaction scripts
└── README.md    # Project guide
```

## Getting Started

### Prerequisites

- **Node.js** and **Yarn** installed. Verify installations with:

```sh
  node --version
  yarn --version
```

### Install Dependencies

```sh
yarn install
```

### Compile the Contract

```sh
forge build
```

### Run Tests

```sh
forge test
```

### Deploying the Contract to the Filecoin Calibration Testnet

To deploy and interact with the contract, copy over the required variables (i.e., calibration testnet rpc url and private key linked to a wallet with test FIL tokens) declared in the `.env.example` file into a `.env` file and populate them. 


```sh
source .env

forge script script/SealedBidAuction.s.sol --rpc-url $CALIBRATION_TESTNET_RPC_URL --private-key $CALIBRATION_TESTNET_PRIVATE_KEY --broadcast
```

For common deployment issues (e.g., setting the gas estimate multiplier -g, --gas-estimate-multiplier) with the Filecoin calibration testnet, please refer to the  [FEVM (Ethereum Virtual Machine on Filecoin) Foundry toolkit](https://github.com/filecoin-project/fevm-foundry-kit).


## How It Works
1. Encrypting Your Bid (Off-Chain): Bidders encrypt their bid amounts off-chain, generating ciphertexts for submission.
2. Submitting Your Bid (On-Chain): Encrypted bids are submitted to the smart contract along with a reserve price deposit.
3. Revealing the Bids (On-Chain): At a predefined block number, an off-chain oracle provides decryption keys to the contract, which then decrypts each bid on-chain.
4. Picking the Winner & Settling Payments (On-Chain): The contract identifies the highest bid. The winner pays the difference between their bid and the reserve price, while other bidders receive refunds.


## Security Considerations
- Ensures bidders cannot manipulate their bids after submission.
- Prevents frontrunning attacks by placing encrypted bids only decrypted at the end of the bidding period.

## Tutorial & Documentation
Check out the detailed tutorial on [our blog](https://drand.love/blog/2025/03/04/onchain-sealed-bid-auction/).


## Licensing
This source code is licensed under the MIT License which can be accessed [here](LICENSE).
