// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDSProxy} from "./DS/IDSProxy.sol";
import {DSAuthority} from "./DS/DSAuthority.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ActionBase} from "./actions/ActionBase.sol";
import {IPetalexNFT} from "./interfaces/IPetalexNFT.sol";
import {ActionRegistry} from "./actions/ActionRegistry.sol";

/// @title Action Executor for DSProxy to enable chaining of actions for Petalex NFT owners
/// @dev No state storage should be use in this contract as it is delegatecalled by other contracts
contract ActionExecutor is Ownable {
    struct ActionList {
        bytes[] callData;
        uint8[] actionIds;
        uint256 tokenId;
    }

    IPetalexNFT private immutable _nftProxy;
    DSAuthority private immutable _authority;
    ActionRegistry private immutable _actionRegistry;

    constructor(address nftProxy, address authority, address actionRegistry, address owner) Ownable(owner) {
        _nftProxy = IPetalexNFT(nftProxy);
        _authority = DSAuthority(authority);
        _actionRegistry = ActionRegistry(actionRegistry);
    }

    function setActionIdToAddress(uint8 actionId, address actionAddress) public onlyOwner {
        _actionRegistry.setActionIdToAddress(actionId, actionAddress);
    }

    function executeActionList(ActionList calldata actionList) public payable returns (bytes32[] memory) {
        require(_nftProxy.balanceOf(msg.sender, actionList.tokenId) == 1, "Not owner of token");
        require(actionList.actionIds.length == actionList.callData.length, "Length mismatch");

        address proxy = _nftProxy.getProxyAddressForToken(actionList.tokenId);
        if (msg.value > 0) {
            (bool sent, ) = proxy.call{value: msg.value}("");
            require(sent, "ActionExecutor: Failed to send");
        }
        bytes32[] memory response = new bytes32[](actionList.callData.length);

        // if flashloan then do that one first and call the rest after from the callback
        if (_firstActionIsFlashloan(actionList)) {
            response[0] = _executeFlashloanAction(actionList);
            return response;
        }
        
        uint32 actionRolls = 0;
        for (uint8 i = 0; i < actionList.callData.length; i++) {
            address actionAddr = _checkActionSet(actionList.actionIds[i]);            
            response[i] = _executeAction(actionList, i, actionAddr, proxy);
            actionRolls += ActionBase(actionAddr).actionRollWeight();
        }
        return response;
    }

    /// @notice Execute all actions after a flash loan action
    /// @dev We can avoid checks here as authority is only given to the flashloan action after it is checked
    function executeActionsFromFL(ActionList calldata actionList) public payable returns (bytes32[] memory) {
        require(msg.sender == _actionRegistry.getActionAddress(actionList.actionIds[0]), "Not authorized");
        require(actionList.actionIds.length == actionList.callData.length, "Length mismatch");

        address proxy = _nftProxy.getProxyAddressForToken(actionList.tokenId);
        bytes32[] memory response = new bytes32[](actionList.callData.length - 1);

        // skip first action since it was already executed
        uint32 actionRolls = 0; // flash loans don't have action rolls
        for (uint8 i = 1; i < actionList.callData.length; i++) {
            address actionAddr = _checkActionSet(actionList.actionIds[i]);
            response[i - 1] = _executeAction(actionList, i, actionAddr, proxy);
            actionRolls += ActionBase(actionAddr).actionRollWeight();
        }
        return response;
    }

    function _checkActionSet(uint8 actionId) internal view returns (address actionAddr) {
        actionAddr = _actionRegistry.getActionAddress(actionId);
        require(actionAddr != address(0), "Action not set");
    }

    function _firstActionIsFlashloan(ActionList calldata actionList) internal view returns (bool) {
        address actionAddr = _checkActionSet(actionList.actionIds[0]);
        return ActionBase(actionAddr).actionType() == ActionBase.ActionType.FLASHLOAN;
    }

    function _executeFlashloanAction(ActionList calldata actionList) internal returns (bytes32) {
        address actionAddr = _checkActionSet(actionList.actionIds[0]);
        // FL action needs temporary Authority to callback ActionExecutor
        _authority.giveAuthority(actionAddr);
        bytes32 response = ActionBase(actionAddr).executeAction(abi.encode(actionList));
        _authority.removeAuthority(actionAddr);

        return response;
    }

    function _executeAction(ActionList calldata actionList, uint8 index, address actionAddr, address proxy) internal returns (bytes32) {
        return IDSProxy(proxy).execute(
            actionAddr, abi.encodeWithSignature("executeAction(bytes)", actionList.callData[index])
        );
    }
}
