// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {TestHelpers} from "./TestHelpers.t.sol";
import {PetalexNFT} from "src/PetalexNFT.sol";

contract PetalexNFTMintTest is TestHelpers {
    function setUp() public {}

    function test_RevertWhenMintingActionExecutorNotSet() public {
        _deployProxyContracts();

        vm.prank(user);
        uint256[] memory ids = new uint256[](0);
        bytes memory data = abi.encodePacked("0x");
        (bool success, bytes memory revertBytes) =
            address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, false);
        assertEq(_getRevertMsg(revertBytes), "Action executor not set");
    }

    function test_RevertWhenMintingNoTokens() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](0);
        bytes memory data = abi.encodePacked("0x");
        (bool success, bytes memory revertBytes) =
            address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, false);
        assertEq(_getRevertMsg(revertBytes), "Too little");
    }

    function test_RevertWhenMintingToNullAddress() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        (bool success, bytes memory revertBytes) =
            address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, address(0), ids, data));
        assertEq(success, false);
        assertEq(_getRevertMsg(revertBytes), "Zero address");
    }

    function test_RevertWhenMintingTooManyTokens() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](20);
        for (uint256 i = 0; i < 20; i++) {
            ids[i] = i + 1;
        }
        bytes memory data = abi.encodePacked("0x");
        (bool success, bytes memory revertBytes) =
            address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, false);
        assertEq(_getRevertMsg(revertBytes), "Too many");
    }

    function test_RevertWhenMintingSameTokens() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            ids[i] = i + 1;
        }
        bytes memory data = abi.encodePacked("0x");
        (bool success,) = address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, true);

        (bool successAgain, bytes memory revertBytes) =
            address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(successAgain, false);
        assertEq(_getRevertMsg(revertBytes), "Token already exists");
    }

    function test_MintTokenAndProxy(uint8 amount) public {
        vm.assume(amount > 0 && amount <= 10);
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            ids[i] = i + 1;
        }
        bytes memory data = abi.encodePacked("0x");
        (bool success,) = address(petalexProxy).call(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, true);

        (bool balanceSuccess, bytes memory result) =
            address(petalexProxy).call(abi.encodeWithSignature(BALANCE_OF_SIGNATURE, user, 1));
        assertEq(balanceSuccess, true);
        assertEq(abi.decode(result, (uint256)), 1);

        (bool finalBalanceSuccess, bytes memory finalResult) =
            address(petalexProxy).call(abi.encodeWithSignature(BALANCE_OF_SIGNATURE, user, amount));
        assertEq(finalBalanceSuccess, true);
        assertEq(abi.decode(finalResult, (uint256)), 1);

        (bool ownedTokenSuccess, bytes memory ownedTokensResult) =
            address(petalexProxy).call(abi.encodeWithSignature(OWNED_TOKENS_SIGNATURE, user));
        assertEq(ownedTokenSuccess, true);
        assertEq(abi.decode(ownedTokensResult, (uint256[])), ids);
    }

    function test_Donation() public {
        _deployProxyContracts();
        _deployActions();

        vm.deal(user, 1 ether);
        vm.prank(user);        
        uint256[] memory ids = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            ids[i] = i + 1;
        }
        bytes memory data = abi.encodePacked("0x");
        (bool success,) = address(petalexProxy).call{ value: 1 ether }(abi.encodeWithSignature(MINT_BATCH_SIGNATURE, user, ids, data));
        assertEq(success, true);

        (bool ownedTokenSuccess, bytes memory ownedTokensResult) =
            address(petalexProxy).call(abi.encodeWithSignature(OWNED_TOKENS_SIGNATURE, user));
        assertEq(ownedTokenSuccess, true);
        assertEq(abi.decode(ownedTokensResult, (uint256[])), ids);
    }

    function test_RevertWithdrawWhenNotOwner() public {
        _deployProxyContracts();
        _deployActions();

        vm.deal(address(petalexProxy), 1 ether);
        vm.prank(user);        
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user));
        (bool success, ) = address(petalexProxy).call(abi.encodeWithSignature('withdraw(address)', user));
        assertEq(success, true);
    }

    function test_Withdraw() public {
        _deployProxyContracts();
        _deployActions();

        vm.deal(address(petalexProxy), 1 ether);
        (bool success, ) = address(petalexProxy).call(abi.encodeWithSignature('withdraw(address)', user));
        assertEq(success, true);
        assertEq(address(petalexProxy).balance, 0);
        assertEq(address(user).balance, 1 ether);
    }
}
