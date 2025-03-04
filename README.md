# 🏦 Sealed Bid Auction Smart Contract Tutorial

This repository provides a step-by-step guide to implementing a timelock encryption-based **sealed-bid auction** using Solidity. In a sealed bid auction, bidders submit their bids privately (encrypted bids are submitted on-chain), and only after the bidding phase ends is the winner revealed (encrypted bids are automatically decrypted on-chain at the end of the bidding phase).

## 📌 Features
- ✅ Private bidding using encrypted bids
- ✅ Bidding phase and reveal phase
- ✅ Automatic winner determination
- ✅ Secure and transparent auction process

## 📂 Repository Structure
```
📦 sealed-bid-auction
├── src/   # Solidity smart contracts
├── scripts/     # Deployment scripts
├── test/        # Unit tests for the contract
├── utils/     # Smart contract interaction scripts
└── README.md    # Project guide
```


## 📜 How It Works
1. **Bidding Phase:** Users submit encrypted bids along with a deposit (non-refundable for highest bidder at the end of the bidding period).  
2. **Reveal Phase:** Bids are automatically decrypted at the end of the bidding period.  
3. **Winner Selection:** The highest valid bidder wins.

## 🔒 Security Considerations
- Ensures bidders cannot manipulate their bids after submission.
- Prevents frontrunning attacks by placing encrypted bids only decrypted at the end of the bidding period.

## 📖 Tutorial & Documentation
Check out the detailed tutorial on [our blog](#) (link to tutorial).


## Licensing

This source code is licensed under the MIT License which can be accessed [here](LICENSE).