// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TestToken } from './mock/TestToken.sol';
import { WLDSplit, ERC20 } from '../WLDSplit.sol';
import { Semaphore } from 'worldcoin/world-id/Semaphore.sol';
import { Test, stdStorage, StdStorage } from 'forge-std/Test.sol';
import { TypeConverter } from 'worldcoin/world-id/test/utils/TypeConverter.sol';

contract User {}

contract WLDSplitTest is Test {
    using TypeConverter for address;
    using stdStorage for StdStorage;

    event ReceiverRegistered(address receiver);
    event ClaimedShare(address indexed receiver, ERC20 indexed token, uint256 amount);

    User user;
    WLDSplit split;
    TestToken token;
    Semaphore semaphore;

    function setUp() public {
        user = new User();
        token = new TestToken();
        semaphore = new Semaphore();
        split = new WLDSplit(semaphore, 1);

        vm.label(address(user), 'User');
        vm.label(address(this), 'Sender');
        vm.label(address(token), 'Token');
        vm.label(address(split), 'WLDSplit');
        vm.label(address(semaphore), 'Semaphore');

        semaphore.createGroup(1, 20, 0);
        token.issue(address(this), 10 ether);
    }

    function testCanReceiveTokens() public {
        assertEq(token.balanceOf(address(split)), 0);

        token.transfer(address(split), 1 ether);

        assertEq(token.balanceOf(address(split)), 1 ether);
    }

    function testCanRegister() public {
        assertTrue(!split.isRegistered(address(user)));

        semaphore.addMember(1, _genIdentityCommitment());

        uint256 root = semaphore.getRoot(1);
        (uint256 nullifierHash, uint256[8] memory proof) = _genProof(address(user));

        vm.expectEmit(false, false, false, true);
        emit ReceiverRegistered(address(user));
        split.register(address(user), root, nullifierHash, proof);

        assertTrue(split.isRegistered(address(user)));
    }

    function testCannotDoubleRegister() public {
        assertTrue(!split.isRegistered(address(user)));
        assertTrue(!split.isRegistered(address(this)));

        semaphore.addMember(1, _genIdentityCommitment());

        (uint256 nullifierHash, uint256[8] memory proof) = _genProof(address(user));
        split.register(address(user), semaphore.getRoot(1), nullifierHash, proof);

        assertTrue(split.isRegistered(address(user)));

        uint256 root = semaphore.getRoot(1);
        (uint256 nullifierHash2, uint256[8] memory proof2) = _genProof(address(this));
        vm.expectRevert(WLDSplit.InvalidNullifier.selector);
        split.register(address(this), root, nullifierHash2, proof2);

        assertTrue(!split.isRegistered(address(this)));
    }

    function testCannotRegisterIfNotMember() public {
        assertTrue(!split.isRegistered(address(user)));

        semaphore.addMember(1, 1);

        uint256 root = semaphore.getRoot(1);
        (uint256 nullifierHash, uint256[8] memory proof) = _genProof(address(user));

        vm.expectRevert(abi.encodeWithSignature('InvalidProof()'));
        split.register(address(user), root, nullifierHash, proof);

        assertTrue(!split.isRegistered(address(user)));
    }

    function testCannotRegisterWithInvalidSignal() public {
        assertTrue(!split.isRegistered(address(user)));

        semaphore.addMember(1, _genIdentityCommitment());

        (uint256 nullifierHash, uint256[8] memory proof) = _genProof(address(this));

        uint256 root = semaphore.getRoot(1);
        vm.expectRevert(abi.encodeWithSignature('InvalidProof()'));
        split.register(address(user), root, nullifierHash, proof);

        assertTrue(!split.isRegistered(address(user)));
    }

    function testCannotRegisterWithInvalidProof() public {
        assertTrue(!split.isRegistered(address(user)));

        semaphore.addMember(1, _genIdentityCommitment());

        (uint256 nullifierHash, uint256[8] memory proof) = _genProof(address(user));
        proof[0] ^= 42;

        uint256 root = semaphore.getRoot(1);
        vm.expectRevert(abi.encodeWithSignature('InvalidProof()'));
        split.register(address(user), root, nullifierHash, proof);

        assertTrue(!split.isRegistered(address(user)));
    }

    function testCanClaim() public {
        assertEq(token.balanceOf(address(user)), 0);

        _setReceiverCount(2);
        _registerReceiver(address(user));

        token.transfer(address(split), 2 ether);

        vm.expectEmit(true, true, false, true);
        emit ClaimedShare(address(user), token, 1 ether);
        split.claim(address(user), token);

        assertEq(token.balanceOf(address(user)), 1 ether);
    }

    function testCannotClaimIfNotReceiver() public {
        assertEq(token.balanceOf(address(user)), 0);

        _setReceiverCount(2);

        token.transfer(address(split), 2 ether);

        vm.expectRevert(WLDSplit.Unauthorized.selector);
        split.claim(address(user), token);

        assertEq(token.balanceOf(address(user)), 0);
    }

    function testCanClaimMoreIfMoreSent() public {
        assertEq(token.balanceOf(address(user)), 0);

        _setReceiverCount(2);
        _registerReceiver(address(user));

        token.transfer(address(split), 2 ether);
        split.claim(address(user), token);

        assertEq(token.balanceOf(address(user)), 1 ether);

        split.claim(address(user), token);
        assertEq(token.balanceOf(address(user)), 1 ether);

        token.transfer(address(split), 2 ether);

        split.claim(address(user), token);
        assertEq(token.balanceOf(address(user)), 1.5 ether);
    }

    function _genIdentityCommitment() internal returns (uint256) {
        string[] memory ffiArgs = new string[](2);
        ffiArgs[0] = 'node';
        ffiArgs[1] = 'src/test/scripts/generate-commitment.js';

        bytes memory returnData = vm.ffi(ffiArgs);
        return abi.decode(returnData, (uint256));
    }

    function _genProof(address receiver) internal returns (uint256, uint256[8] memory proof) {
        string[] memory ffiArgs = new string[](5);
        ffiArgs[0] = 'node';
        ffiArgs[1] = '--no-warnings';
        ffiArgs[2] = 'src/test/scripts/generate-proof.js';
        ffiArgs[3] = address(split).toString();
        ffiArgs[4] = address(receiver).toString();

        bytes memory returnData = vm.ffi(ffiArgs);

        return abi.decode(returnData, (uint256, uint256[8]));
    }

    function _registerReceiver(address receiver) internal {
        stdstore
            .target(address(split))
            .sig(split.isRegistered.selector)
            .with_key(receiver)
            .checked_write(true);
    }

    function _setReceiverCount(uint256 count) internal {
        stdstore.target(address(split)).sig(split.receiverCount.selector).checked_write(count);
    }
}
