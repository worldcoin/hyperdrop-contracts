// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { mathUtils } from './libraries/MathUtils.sol';
import { SafeTransferLib } from 'solmate/utils/SafeTransferLib.sol';
import { ByteHasher } from 'worldcoin/world-id/libraries/ByteHasher.sol';
import { ISemaphore } from 'worldcoin/world-id/interfaces/ISemaphore.sol';

/// @title Universal Split
/// @author Miguel Piedrafita
/// @notice A contract that splits any token it receives between all humans
contract WLDSplit {
    using ByteHasher for bytes;

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  ERRORS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when trying to claim shares with a wallet that hasn't been verified
    error Unauthorized();

    /// @notice Thrown when trying to verify an address someone else has already verified
    error InvalidReceiver();

    /// @notice Thrown when trying to reuse a zero-knowledge proof
    error InvalidNullifier();

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  EVENTS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when verifying a new receiver address
    /// @param receiver The address that has now been verified
    event ReceiverRegistered(address receiver);

    /// @notice Emitted when a registered wallet claims their proportional share of a token
    /// @param receiver The address claiming the tokens
    /// @param token The ERC-20 token getting claimed
    /// @param amount The amount of the token that the address will receive
    event ClaimedShare(address indexed receiver, ERC20 indexed token, uint256 amount);

    ///////////////////////////////////////////////////////////////////////////////
    ///                              CONFIG STORAGE                            ///
    //////////////////////////////////////////////////////////////////////////////

    /// @dev The Semaphore group ID whose participants can claim this airdrop
    uint256 internal immutable groupId;

    /// @dev The Semaphore instance that will be used for managing groups and verifying proofs
    ISemaphore internal immutable semaphore;

    /// @notice The amount of wallets currently registered as claimers in this contract
    uint256 public receiverCount;

    /// @notice Whether a particular wallet has been verified
    mapping(address => bool) public isRegistered;

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(uint256 => bool) internal nullifierHashes;

    /// @notice The amount of an ERC-20 token that a certain address has already claimed
    mapping(address => mapping(address => uint256)) public splitClaimAmount;

    ///////////////////////////////////////////////////////////////////////////////
    ///                               CONSTRUCTOR                              ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Deploys a WLDSplit instance
    /// @param _semaphore The Semaphore instance that will verify the zero-knowledge proofs
    /// @param _groupId The ID of the Semaphore group that will be eligible to register their wallets
    constructor(ISemaphore _semaphore, uint256 _groupId) payable {
        semaphore = _semaphore;
        groupId = _groupId;
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///                               SPLIT LOGIC                              ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Register an address as a receiver
    /// @param receiver The address that will get verified
    /// @param root The of the Merkle tree
    /// @param nullifierHash The nullifier for this proof, preventing double signaling
    /// @param proof The zero knowledge proof that demostrates the claimer is part of the Semaphore group
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

    /// @notice Claim a proportional share for a certain ERC-20 token
    /// @param receiver The registered address that will receive the tokens
    /// @param token The ERC-20 token you'll receive
    function claim(address receiver, ERC20 token) public payable {
        if (!isRegistered[receiver]) revert Unauthorized();

        uint256 outstandingAmount = getOutstandingFor(receiver, token);

        emit ClaimedShare(receiver, token, outstandingAmount);
        splitClaimAmount[receiver][address(token)] += outstandingAmount;

        token.transfer(receiver, outstandingAmount);
    }

    /// @notice Get the proportional share of an ERC-20 token available for claim
    /// @param receiver The registered address that has available tokens
    /// @param token The ERC-20 token you want to check for
    /// @return outstanding The amount of ERC-20 tokens left to claim by this address
    function getOutstandingFor(address receiver, ERC20 token) public view returns (uint256) {
        return
            mathUtils.cappedSub(
                mathUtils.uncheckedDiv(token.balanceOf(address(this)), receiverCount),
                splitClaimAmount[receiver][address(token)]
            );
    }
}
