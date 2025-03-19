// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Import the Types library for managing ciphertexts.
import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";
// Import the AbstractBlocklockReceiver for handling timelock decryption callbacks.
import {AbstractBlocklockReceiver} from "@blocklock-solidity/src/AbstractBlocklockReceiver.sol";
// Import ReentrancyGuard which is an Openzeppelin solidity library that helps prevent reentrant calls to a function.
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ISealedBidAuction {
    function placeSealedBid(TypesLib.Ciphertext calldata sealedBid) external payable returns (uint256);
    function withdrawRefund() external;
    function fulfillHighestBid() external payable;
    function finalizeAuction() external;
}

contract SealedBidAuction is ISealedBidAuction, AbstractBlocklockReceiver, ReentrancyGuard {
    struct Bid {
        uint256 bidID; // Unique identifier for the bid
        address bidder; // Bidders wallet address
        TypesLib.Ciphertext sealedBid; // Encrypted / sealed bid amount
        bytes decryptionKey; // The timelock decryption key used to unseal the sealed bid
        uint256 unsealedBid; // Decrypted/unsealed bid amount, revealed after auction end
        bool revealed; // Status of whether the bid has been revealed
    }

    uint256 public constant RESERVE_PRICE = 0.01 ether; // the reserve price to pay when placing a bid
    address public immutable seller; // the seller address
    uint256 public immutable biddingEndBlock; // bidding end block number
    bool public auctionEnded; // bool indicating end of the auction or not
    bool public highestBidPaid; // bool indicating if auction winner has fulfilled their bid
    uint256 public totalBids; // Total number of bids placed
    uint256 public revealedBidsCount; // Count of revealed bids after auction end
    bool public allBidsUnsealed; // bool indicating if all the sealed bids have been decrypted
    address public highestBidder; // address of the current highest bidder
    uint256 public highestBid; // highest bid amount in plaintext
    mapping(address => Bid) bids; // Mapping of bidders to bids
    mapping(uint256 => Bid) public bidsById; // Mapping of bid IDs to bid details
    mapping(address => uint256) public bidderToBidID; // Mapping of bidders to their bid IDs
    mapping(address => uint256) public pendingReturns; // mapping of bidders to their pending reservePrice refunds

    event NewBid(uint256 indexed bidID, address indexed bidder);
    event AuctionEnded(address winner, uint256 highestBid);
    event BidUnsealed(uint256 indexed bidID, address indexed bidder, uint256 unsealedBid);
    event HighestBidFulfilled(address indexed bidder, uint256 amount);
    event ReservePriceClaimed(uint256 indexed bidID, address indexed claimant, uint256 amount);

    modifier onlyBefore(uint256 _block) {
        require(block.number < _block, "Block has passed.");
        _;
    }

    modifier onlyAfter(uint256 _block) {
        require(block.number > _block, "Not yet allowed.");
        _;
    }

    modifier validateReservePrice() {
        require(msg.value == RESERVE_PRICE, "Bid must be accompanied by a deposit equal to the reserve price.");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this.");
        _;
    }

    modifier onlyAfterBidsUnsealed() {
        require(revealedBidsCount == totalBids, "Not all bids have been revealed.");
        _;
    }

    constructor(uint256 _biddingEndBlock, address blocklockContract) AbstractBlocklockReceiver(blocklockContract) {
        require(_biddingEndBlock > block.number, "Bidding must end after a future block.");
        biddingEndBlock = _biddingEndBlock;
        seller = msg.sender;
    }

    // BID PHASES
    /**
     * Phase 1. Bidding Phase
     */
    // Submit a sealed bid
    function placeSealedBid(TypesLib.Ciphertext calldata sealedBid)
        external
        payable
        onlyBefore(biddingEndBlock)
        validateReservePrice
        returns (uint256)
    {
        uint256 bidID = bidderToBidID[msg.sender];
        require(bidID == 0, "Only one bid allowed per bidder.");
        bidID = blocklock.requestBlocklock(biddingEndBlock, sealedBid);
        Bid memory newBid = Bid({
            bidID: bidID,
            bidder: msg.sender,
            sealedBid: sealedBid,
            decryptionKey: hex"",
            unsealedBid: 0,
            revealed: false
        });
        bids[msg.sender] = newBid;
        bidsById[bidID] = newBid;
        bidderToBidID[msg.sender] = bidID;

        pendingReturns[msg.sender] = RESERVE_PRICE;
        totalBids += 1;

        emit NewBid(bidID, msg.sender);
        return bidID;
    }

    /**
     * Phase 2. Reveal Phase
     */
    // Unseal sealed bid
    function receiveBlocklock(uint256 requestID, bytes calldata decryptionKey)
        external
        override
        onlyAfter(biddingEndBlock)
    {
        require(bidsById[requestID].bidID != 0, "Bid ID does not exist.");
        require(
            bidsById[requestID].decryptionKey.length == 0, "Bid decryption key already received from timelock contract."
        );

        // update the stored bid data
        Bid storage bid = bidsById[requestID];
        bid.decryptionKey = decryptionKey;
        bid.revealed = true;

        // decrypt bid amount
        uint256 decryptedSealedBid = abi.decode(blocklock.decrypt(bid.sealedBid, bid.decryptionKey), (uint256));
        bid.unsealedBid = decryptedSealedBid;

        // update highest bid
        updateHighestBid(requestID, decryptedSealedBid);

        emit BidUnsealed(bid.bidID, bid.bidder, bid.unsealedBid);
    }

    function updateHighestBid(uint256 bidID, uint256 unsealedBid) internal {
        Bid storage bid = bidsById[bidID];

        bid.unsealedBid = unsealedBid;
        bid.revealed = true;
        revealedBidsCount += 1;

        if (unsealedBid > highestBid && unsealedBid > RESERVE_PRICE) {
            highestBid = unsealedBid;
            highestBidder = bid.bidder;
        }

        emit BidUnsealed(bidID, bid.bidder, unsealedBid);
    }

    /**
     * Phase 3. Auction Finalization
     */
    // Withdraw refundable reserve amounts paid during bidding
    function withdrawRefund() external onlyAfter(biddingEndBlock) onlyAfterBidsUnsealed nonReentrant {
        require(msg.sender != highestBidder, "Highest bidder cannot withdraw refund.");
        Bid memory bid = bids[msg.sender];
        uint256 amount = pendingReturns[bid.bidder];
        require(amount > 0, "Nothing to withdraw.");
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit ReservePriceClaimed(bid.bidID, msg.sender, amount);
    }

    // Fulfil highest bid
    function fulfillHighestBid() external payable onlyAfter(biddingEndBlock) onlyAfterBidsUnsealed {
        require(highestBid > 0, "Highest bid is zero.");
        require(msg.sender == highestBidder, "Only the highest bidder can fulfil.");
        require(!highestBidPaid, "Payment has already been completed.");
        require(
            msg.value == highestBid - RESERVE_PRICE, "Payment must be equal to highest bid minus the reserve amount."
        );
        highestBidPaid = true;
        pendingReturns[highestBidder] = 0;
        payable(seller).transfer(msg.value + RESERVE_PRICE);
        emit HighestBidFulfilled(msg.sender, msg.value + RESERVE_PRICE);
    }

    // Finalize auction
    function finalizeAuction() external onlyAfterBidsUnsealed {
        require(!auctionEnded, "Auction already finalised.");
        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    /**
     * Getters
     */
    function getBidWithBidID(uint256 bidID)
        external
        view
        returns (
            TypesLib.Ciphertext memory sealedBid,
            bytes memory decryptionKey,
            uint256 unsealedBid,
            address bidder,
            bool revealed
        )
    {
        sealedBid = bidsById[bidID].sealedBid;
        decryptionKey = bidsById[bidID].decryptionKey;
        unsealedBid = bidsById[bidID].unsealedBid;
        bidder = bidsById[bidID].bidder;
        revealed = bidsById[bidID].revealed;
    }

    function getBidWithBidder(address bidder)
        external
        view
        returns (
            TypesLib.Ciphertext memory sealedBid,
            bytes memory decryptionKey,
            uint256 unsealedBid,
            address _bidder,
            bool revealed
        )
    {
        sealedBid = bidsById[bidderToBidID[bidder]].sealedBid;
        decryptionKey = bidsById[bidderToBidID[bidder]].decryptionKey;
        unsealedBid = bidsById[bidderToBidID[bidder]].unsealedBid;
        _bidder = bidsById[bidderToBidID[bidder]].bidder;
        revealed = bidsById[bidderToBidID[bidder]].revealed;
    }

    function getHighestBid() external view returns (uint256 highestBidAmount, address highestBidderAddress) {
        highestBidAmount = highestBid;
        highestBidderAddress = highestBidder;
    }
}
