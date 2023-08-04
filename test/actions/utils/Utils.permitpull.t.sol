// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {PermitPullToken} from "src/actions/utils/PermitPullToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

contract UtilsPermitPullTest is ActionTestHelpers {
    uint256 mainnetFork;
    PermitPullToken pullToken;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17814506);

        pullToken = new PermitPullToken(MAINNET_PERMIT2);
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_CanPullTokenAfterApprove() public {
        vm.selectFork(mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(pullToken));
        uint256 tokenId = mintNFT(user);
        uint256 amount = 10e18;

        (bool success, bytes memory data) =
            address(petalexProxy).call(abi.encodeWithSignature(GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE, tokenId));
        assertEq(success, true);

        vm.prank(user);
        address proxyAddress = abi.decode(data, (address));
        IERC20(MAINNET_WETH).approve(MAINNET_PERMIT2, amount);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: MAINNET_WETH, amount: amount}),
            nonce: 1,
            deadline: block.timestamp + 1000
        });
        bytes memory sig = _signPermit(permit, address(proxyAddress), userKey);

        bytes[] memory callData = new bytes[](1);
        PermitPullToken.Params memory params =
            PermitPullToken.Params(MAINNET_WETH, user, amount, permit.deadline, permit.nonce, sig);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(uint256(amount)));
        assertEq(IERC20(MAINNET_WETH).balanceOf(proxyAddress), amount);
        assertEq(IERC20(MAINNET_WETH).balanceOf(user), 1000000e18 - amount);
    }
}
