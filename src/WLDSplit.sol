// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { mathUtils } from './libraries/MathUtils.sol';
import { SafeTransferLib } from 'solmate/utils/SafeTransferLib.sol';
import { ByteHasher } from 'worldcoin/world-id/libraries/ByteHasher.sol';
import { ISemaphore } from 'worldcoin/world-id/interfaces/ISemaphore.sol';
import { ThirdwebContract } from 'thirdweb-dev/ThirdwebContract.sol';

contract WLDSplit is ThirdwebContract {
    using ByteHasher for bytes;

    error Unauthorized();
    error AlreadyClaimed();
    error InvalidReceiver();
    error InvalidNullifier();

    event ReceiverRegistered(address receiver);
    event ClaimedShare(address indexed receiver, ERC20 indexed token, uint256 amount);

    uint256 public receiverCount;
    uint256 internal immutable groupId;
    ISemaphore internal immutable semaphore;

    mapping(address => bool) public isRegistered;
    mapping(uint256 => bool) internal nullifierHashes;
    mapping(address => mapping(address => uint256)) public splitClaimAmount;

    constructor(ISemaphore _semaphore, uint256 _groupId) payable {
        semaphore = _semaphore;
        groupId = _groupId;
    }

    function register(
        address receiver,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public payable {
        if (isRegistered[receiver]) revert InvalidReceiver();
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();

        semaphore.verifyProof(
            root,
            groupId,
            abi.encodePacked(receiver).hashToField(),
            nullifierHash,
            abi.encodePacked(address(this)).hashToField(),
            proof
        );

        nullifierHashes[nullifierHash] = true;

        ++receiverCount;
        isRegistered[receiver] = true;

        emit ReceiverRegistered(receiver);
    }

    function claim(address receiver, ERC20 token) public payable {
        if (!isRegistered[receiver]) revert Unauthorized();

        uint256 outstandingAmount = getOutstandingFor(receiver, token);

        emit ClaimedShare(receiver, token, outstandingAmount);
        splitClaimAmount[receiver][address(token)] += outstandingAmount;

        token.transfer(receiver, outstandingAmount);
    }

    function getOutstandingFor(address receiver, ERC20 token)
        public
        view
        returns (uint256 outstanding)
    {
        return
            mathUtils.cappedSub(
                mathUtils.uncheckedDiv(token.balanceOf(address(this)), receiverCount),
                splitClaimAmount[receiver][address(token)]
            );
    }
}
