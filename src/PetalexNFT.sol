// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC1155Upgradeable} from "oz-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "oz-upgradeable/access/OwnableUpgradeable.sol";
import {IERC2981, IERC165} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165Upgradeable} from "oz-upgradeable/interfaces/IERC165Upgradeable.sol";
import {DSProxyFactory} from "./DS/DSProxyFactory.sol";
import {DSProxy} from "./DS/DSProxy.sol";
import {IPetalexNFT} from "./interfaces/IPetalexNFT.sol";
import {PetalexActions} from "./PetalexActions.sol";

contract PetalexNFT is PetalexActions, ERC1155Upgradeable, UUPSUpgradeable, OwnableUpgradeable, IERC2981, IPetalexNFT {
    DSProxyFactory private _proxyFactory;    
    mapping(uint256 => address) private _proxyAddresses;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => bool) private _tokenExists;

    address private _royaltyReceiver;
    uint8 private _royaltyFee; // base 1000, highest is 25.5

    // UPGRADABLE

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address proxyFactory) public initializer {
        __ERC1155_init("");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        _proxyFactory = DSProxyFactory(proxyFactory);
        _royaltyFee = 255;
        _royaltyReceiver = owner();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, IERC165Upgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // END UPGRADABLE

    function mintBatch(address to, uint256[] calldata ids, bytes calldata data) public payable {
        require(_actionExecutor != address(0), "Action executor not set");
        require(to != address(0), "Zero address");
        require(ids.length > 0, "Too little");
        require(ids.length <= 10, "Too many");

        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            require(_tokenExists[ids[i]] == false, "Token already exists");
            amounts[i] = 1;
        }
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            DSProxy proxy = _proxyFactory.build(address(this));
            _proxyAddresses[ids[i]] = address(proxy);
            _tokenExists[ids[i]] = true;
            _ownedTokens[to].push(ids[i]);
        }        
    }

    function getProxyAddressForToken(uint256 tokenId) public view returns (address) {
        return _proxyAddresses[tokenId];
    }

    function getActionExecutor() public view returns (address) {
        return _actionExecutor;
    }

    function getOwnedTokens(address owner) public view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }

    function isTokenIdAvailable(uint256 tokenId) public view returns (bool) {
        return _tokenExists[tokenId] == false;
    }

    function setActionExecutor(address actionExecutor) public onlyOwner {
        _actionExecutor = actionExecutor;
    }

    function royaltyInfo(uint256, /*_tokenId*/ uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 amount = (_salePrice * _royaltyFee) / 1000;
        return (_royaltyReceiver, amount);
    }

    function withdraw(address to) public onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}
