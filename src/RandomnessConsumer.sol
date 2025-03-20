// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {RandomnessReceiverBase} from "@randomness-solidity/src/RandomnessReceiverBase.sol";

/// @title Randomness Consumer contract
/// @author Randamu developers
/// @notice A mock RandomnessConsumer contract that makes use of the Randamu randomness-solidity
/// library to request verifiable randomness
/// The library is available at: https://github.com/randa-mu/randomness-solidity/tree/main
/// The library also contains logic for array shuffling using Feistel shuffle
/// and selecting n items randomly from an array
contract RandomnessConsumer is RandomnessReceiverBase {
    // RandomnessSender proxy address on Filecoin calibration testnet
    address public constant RANDOMNESS_SENDER = 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC;

    bytes32 public randomness;
    uint256 public requestId;

    constructor() RandomnessReceiverBase(RANDOMNESS_SENDER) {}

    /// @dev Requests randomness.
    /// This function calls the `requestRandomness` method to request a random value.
    /// The `requestId` is updated with the ID returned from the randomness request.
    function rollDice() external {
        requestId = requestRandomness();
    }

    /// @dev Callback function that is called when randomness is received.
    /// @param requestID The ID of the randomness request that was made.
    /// @param _randomness The random value received.
    /// This function verifies that the received `requestID` matches the one that
    /// was previously stored. If they match, it updates the `randomness` state variable
    /// with the newly received random value.
    /// Reverts if the `requestID` does not match the stored `requestId`, ensuring that
    /// the randomness is received in response to a valid request.
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
}
