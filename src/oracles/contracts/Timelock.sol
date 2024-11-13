// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @notice inspired by OpenZeppelin's Timelock.sol
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/mocks/compound/CompTimelock.sol

contract Timelock is Ownable2Step {
    /// @notice Delay must exceed minimum delay."
    error DelayMustExceedMinimumDelay();
    /// @notice Delay must exceed maximum delay."
    error DelayMustExceedMaximumDelay();
    /// @notice Call must come from Timelock.
    error CallMustComeFromTimelock();
    /// @notice Estimated execution block must satisfy delay.
    error EstimatedExecutionBlockMustSatisfyDelay();
    /// @notice Transaction hasn't been queued.
    error TransactionHasNotBeenQueued();
    /// @notice Transaction hasn't surpassed time lock
    error TransactionHasNotSurpassedTimeLock();
    /// @notice Transaction is stale
    error TransactionIsStale();
    /// @notice Transaction execution reverted.
    error TransactionExecutionReverted();

    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(address admin_, uint256 delay_) Ownable(admin_) {
        _setDelay(delay_);
    }

    function _setDelay(uint256 delay_) internal {
        require(delay_ >= MINIMUM_DELAY, DelayMustExceedMinimumDelay());
        require(delay_ <= MAXIMUM_DELAY, DelayMustExceedMaximumDelay());

        delay = delay_;
        emit NewDelay(delay);
    }

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), CallMustComeFromTimelock());

        _setDelay(delay_);
    }

    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyOwner returns (bytes32) {
        require(getBlockTimestamp() + delay < eta, EstimatedExecutionBlockMustSatisfyDelay());

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        public
        payable
        onlyOwner
        returns (bytes memory)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], TransactionHasNotBeenQueued());
        require(getBlockTimestamp() >= eta, TransactionHasNotSurpassedTimeLock());
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, TransactionIsStale());

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // Execute the call
        (bool success, bytes memory returnData) = target.call{ value: value }(callData);
        require(success, TransactionExecutionReverted());

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}
