// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UtilsPullTest is ActionTestHelpers {
    uint256 mainnetFork;

    PullToken pullToken;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17814506);

        pullToken = new PullToken();
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_CanPullTokenAfterApprove() public {
        vm.selectFork(mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(pullToken));
        uint256 tokenId = mintNFT(user);

        bytes[] memory callData = new bytes[](1);
        PullToken.Params memory params = PullToken.Params(MAINNET_WETH, user, 10e18);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        (bool success, bytes memory data) =
            address(petalexProxy).call(abi.encodeWithSignature(GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE, tokenId));
        assertEq(success, true);

        vm.prank(user);
        address proxyAddress = abi.decode(data, (address));
        IERC20(MAINNET_WETH).approve(proxyAddress, 10e18);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(uint256(10e18)));
        assertEq(IERC20(MAINNET_WETH).balanceOf(proxyAddress), 10e18);
        assertEq(IERC20(MAINNET_WETH).balanceOf(user), 1000000e18 - 10e18);
    }
}
