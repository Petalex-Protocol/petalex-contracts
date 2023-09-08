// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {Wrap} from "src/actions/utils/Wrap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UtilsWrapTest is ActionTestHelpers {
    uint256 mainnetFork;

    Wrap wrap;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17814506);

        wrap = new Wrap(MAINNET_WETH);
        deal(user, 1000000e18);
    }

    function test_Wrap() public {
        vm.selectFork(mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(wrap));
        uint256 tokenId = mintNFT(user);

        bytes[] memory callData = new bytes[](1);
        Wrap.Params memory params = Wrap.Params(10e18);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        (bool success, bytes memory data) =
            address(petalexProxy).call(abi.encodeWithSignature(GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE, tokenId));
        assertEq(success, true);
        address proxyAddress = abi.decode(data, (address));

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList{ value: 10e18 }(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(uint256(10e18)));
        assertEq(IERC20(MAINNET_WETH).balanceOf(proxyAddress), 10e18);
        assertEq(user.balance, 1000000e18 - 10e18);
    }
}
