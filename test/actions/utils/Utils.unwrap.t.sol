// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {Unwrap} from "src/actions/utils/Unwrap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UtilsUnwrapTest is ActionTestHelpers {
    uint256 mainnetFork;

    Unwrap unwrap;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17814506);

        unwrap = new Unwrap(MAINNET_WETH);
    }

    function test_Unwrap() public {
        vm.selectFork(mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(unwrap));
        uint256 tokenId = mintNFT(user);

        bytes[] memory callData = new bytes[](1);
        Unwrap.Params memory params = Unwrap.Params(10e18);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        (bool success, bytes memory data) =
            address(petalexProxy).call(abi.encodeWithSignature(GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE, tokenId));
        assertEq(success, true);
        address proxyAddress = abi.decode(data, (address));

        deal(MAINNET_WETH, proxyAddress, 10e18);
        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(uint256(10e18)));
        assertEq(IERC20(MAINNET_WETH).balanceOf(proxyAddress), 0);
        assertEq(proxyAddress.balance, 10e18);
    }
}
