// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {SignatureSchemeAddressProvider} from
    "@blocklock-solidity/src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "@blocklock-solidity/src/signature-requests/SignatureSender.sol";
import {BlocklockSender} from "@blocklock-solidity/src/blocklock/BlocklockSender.sol";
import {BlocklockSignatureScheme} from "@blocklock-solidity/src/blocklock/BlocklockSignatureScheme.sol";
import {DecryptionSender} from "@blocklock-solidity/src/decryption-requests/DecryptionSender.sol";
import {BLS} from "@blocklock-solidity/src/libraries/BLS.sol";
import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";
import {UUPSProxy} from "@blocklock-solidity/src/proxy/UUPSProxy.sol";

import {SealedBidAuction} from "../src/SealedBidAuction.sol";

contract SealedBidAuctionTest is Test {
    UUPSProxy decryptionSenderProxy;
    UUPSProxy blocklockSenderProxy;

    DecryptionSender decryptionSender;
    BlocklockSender blocklock;
    SealedBidAuction auction;

    string constant SCHEME_ID = "BN254-BLS-BLOCKLOCK";
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address owner;
    address bidder;
    uint256 biddingEndBlock = 13;

    uint256 bidAmount = 3 ether;

    TypesLib.Ciphertext sealedBid = TypesLib.Ciphertext({
        u: BLS.PointG2({
            x: [
                14142380308423906610328325205633754694002301558654408701934220147059967542660,
                4795984740938726483924720262587026838890051381570343702421443260575124596446
            ],
            y: [
                13301122453285478420056122708237526083484415709254283392885579853639158169617,
                11125759247493978573666410429063118092803139083876927879642973106997490249635
            ]
        }),
        v: hex"63f745f4240f4708db37b0fa0e40309a37ab1a65f9b1be4ac716a347d4fe57fe",
        w: hex"e8aadd66a9a67c00f134b1127b7ef85046308c340f2bb7cee431bd7bfe950bd4"
    });
    bytes signature =
        hex"02b3b2fa2c402d59e22a2f141e32a092603862a06a695cbfb574c440372a72cd0636ba8092f304e7701ae9abe910cb474edf0408d9dd78ea7f6f97b7f2464711";
    bytes decryptionKey = hex"7ec49d8f06b34d8d6b2e060ea41652f25b1325fafb041bba9cf24f094fbca259";

    function setUp() public {
        owner = vm.addr(1);
        bidder = vm.addr(2);

        BLS.PointG2 memory pk = BLS.PointG2({
            x: [
                17445541620214498517833872661220947475697073327136585274784354247720096233162,
                18268991875563357240413244408004758684187086817233527689475815128036446189503
            ],
            y: [
                11401601170172090472795479479864222172123705188644469125048759621824127399516,
                8044854403167346152897273335539146380878155193886184396711544300199836788154
            ]
        });

        vm.startPrank(owner);

        SignatureSchemeAddressProvider signatureSchemeAddressProvider = new SignatureSchemeAddressProvider(owner);
        BlocklockSignatureScheme blocklockScheme = new BlocklockSignatureScheme();
        signatureSchemeAddressProvider.updateSignatureScheme(SCHEME_ID, address(blocklockScheme));

        // deploy implementation contracts for decryption and blocklock senders
        DecryptionSender decryptionSenderImplementation = new DecryptionSender();
        BlocklockSender blocklockSenderImplementation = new BlocklockSender();

        // deploy proxy contracts and point them to their implementation contracts
        decryptionSenderProxy = new UUPSProxy(address(decryptionSenderImplementation), "");
        console.log("Decryption Sender proxy contract deployed at: ", address(decryptionSenderProxy));

        blocklockSenderProxy = new UUPSProxy(address(blocklockSenderImplementation), "");
        console.log("Blocklock Sender proxy contract deployed at: ", address(blocklockSenderProxy));

        // wrap proxy address in implementation ABI to support delegate calls
        decryptionSender = DecryptionSender(address(decryptionSenderProxy));
        blocklock = BlocklockSender(address(blocklockSenderProxy));

        // initialize the contracts
        decryptionSender.initialize(pk.x, pk.y, owner, address(signatureSchemeAddressProvider));
        blocklock.initialize(owner, address(decryptionSender));

        auction = new SealedBidAuction(biddingEndBlock, address(blocklockSenderProxy));

        vm.stopPrank();
    }

    function test_DeploymentConfigurations() public view {
        assertEq(auction.seller(), owner);
        assertGt(auction.biddingEndBlock(), block.number);
        assertEq(auction.biddingEndBlock(), biddingEndBlock);
        assertTrue(decryptionSender.hasRole(ADMIN_ROLE, owner));
    }

    function test_BidPlacement() public {
        vm.deal(bidder, 1 ether); // Give bidder 1 ether for reserve price payment requirement
        vm.startPrank(bidder);
        auction.placeSealedBid{value: auction.RESERVE_PRICE()}(sealedBid); // Place a sealed bid of 3 ether in wei
        assertEq(auction.totalBids(), 1, "Bid count should be 1");
        vm.stopPrank();
    }

    function test_RevealBid() public {
        // First, place a bid
        vm.deal(bidder, 1 ether);
        vm.startPrank(bidder);
        uint256 bidID = auction.placeSealedBid{value: auction.RESERVE_PRICE()}(sealedBid);
        vm.stopPrank();

        // Move to the auction end block to end the auction
        vm.roll(auction.biddingEndBlock() + 1);

        // Receive the decryption key for the bid id from the timelock contract
        // This should also decrypt the sealed bid
        vm.startPrank(owner);

        decryptionSender.fulfilDecryptionRequest(bidID, decryptionKey, signature);

        vm.stopPrank();

        (,, uint256 unsealedAmount, address bidderAddressWithBidID,) = auction.getBidWithBidID(bidID);
        (,,, address bidderAddressWithBidder,) = auction.getBidWithBidder(bidder);
        (uint256 highestBidAmount, address highestBidder) = auction.getHighestBid();

        assertEq(auction.highestBidder(), bidder, "Highest bidder should be bidder");
        assertEq(highestBidder, bidder, "Highest bidder should be bidder");
        assertEq(bidderAddressWithBidID, bidder, "Bidder for bid ID 1 should be bidder");
        assertEq(bidderAddressWithBidder, bidder, "Bidder for bid ID 1 should be bidder 1");
        assertEq(auction.highestBid(), bidAmount, "Highest bid should be bid amount");
        assertEq(highestBidAmount, bidAmount, "Highest bid should be bid amount");
        assertEq(unsealedAmount, bidAmount, "Unsealed amount should be bid amount");
    }

    function test_FulfillHighestBid() public {
        // Bidder places a bid
        vm.deal(bidder, 5 ether);
        vm.startPrank(bidder);
        uint256 bidID1 = auction.placeSealedBid{value: auction.RESERVE_PRICE()}(sealedBid);
        vm.stopPrank();

        // Move to the auction end block to end the auction
        vm.roll(auction.biddingEndBlock() + 1);

        // Receive the decryption key for the bid id from the timelock contract
        vm.startPrank(owner);

        decryptionSender.fulfilDecryptionRequest(bidID1, decryptionKey, signature);

        vm.stopPrank();

        // Bidder fulfills the highest bid
        vm.startPrank(bidder); // Set bidder as the sender
        auction.fulfillHighestBid{value: bidAmount - auction.RESERVE_PRICE()}();
        vm.stopPrank();

        assert(auction.highestBidPaid());
    }

    function test_WithdrawRefund() public {
        // Bidder places a bid
        vm.deal(bidder, 5 ether);
        vm.startPrank(bidder);
        uint256 bidID1 = auction.placeSealedBid{value: auction.RESERVE_PRICE()}(sealedBid);
        vm.stopPrank();

        // Move to the auction end block to end the auction
        vm.roll(auction.biddingEndBlock() + 1);

        // Receive the decryption key for the bid id from the timelock contract
        vm.startPrank(owner);

        decryptionSender.fulfilDecryptionRequest(bidID1, decryptionKey, signature);

        vm.stopPrank();

        // Bidder fulfills the highest bid
        vm.startPrank(bidder); // Set bidder as the sender
        auction.fulfillHighestBid{value: bidAmount - auction.RESERVE_PRICE()}();
        vm.stopPrank();

        assert(auction.highestBidPaid());

        // Highest bidder cannot withdraw their deposit
        vm.startPrank(bidder); // Set bidder as the sender
        vm.expectRevert("Highest bidder cannot withdraw refund.");
        auction.withdrawRefund();
        vm.stopPrank();
    }

    function test_FinalizeAuction() public {
        // Bidder places a bid
        vm.deal(bidder, 5 ether);
        vm.startPrank(bidder);
        uint256 bidID1 = auction.placeSealedBid{value: auction.RESERVE_PRICE()}(sealedBid);
        vm.stopPrank();

        // Move to the auction end block to end the auction
        vm.roll(auction.biddingEndBlock() + 1);

        // Receive the decryption key for the bid id from the timelock contract
        vm.startPrank(owner);

        decryptionSender.fulfilDecryptionRequest(bidID1, decryptionKey, signature);

        vm.stopPrank();

        // Bidder fulfills the highest bid
        vm.startPrank(bidder); // Set bidder as the sender
        auction.fulfillHighestBid{value: bidAmount - auction.RESERVE_PRICE()}();
        vm.stopPrank();

        assert(auction.highestBidPaid());

        // Highest bidder cannot withdraw their deposit
        vm.startPrank(bidder); // Set bidder as the sender
        vm.expectRevert("Highest bidder cannot withdraw refund.");
        auction.withdrawRefund();
        vm.stopPrank();

        vm.startPrank(owner);
        assert(!auction.auctionEnded());
        auction.finalizeAuction();
        assert(auction.auctionEnded());
    }
}
