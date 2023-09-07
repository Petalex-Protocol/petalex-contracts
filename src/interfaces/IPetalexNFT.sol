// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC1155Upgradeable} from "oz-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

interface IPetalexNFT is IERC1155Upgradeable {
    function getProxyAddressForToken(uint256 tokenId) external view returns (address);
    function getActionExecutor() external view returns (address);
    function getOwnedTokens(address owner) external view returns (uint256[] memory);
    function isTokenIdAvailable(uint256 tokenId) external view returns (bool);
    function setActionExecutor(address actionExecutor) external;
    function mintBatch(address to, uint256[] calldata ids, bytes calldata data) external payable;
    function withdraw(address to) external;
}
