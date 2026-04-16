// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// ---------------------------------------------------------------------------
/// AssetRegistry: Implements Algorithm 1 (Onboarding & Asset Registration)
/// ---------------------------------------------------------------------------
contract AssetRegistry is ERC721, AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    uint256 private _nextId = 1;

    
    mapping(bytes32 => uint256) public hashToTokenId;

   
    mapping(uint256 => string) private _tokenURIs;

    event AssetMinted(
        uint256 indexed tokenId,
        address indexed creator,
        bytes32 contentHash,
        string uri
    );

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
    }

    
    function mintAsset(string calldata assetURI, bytes32 contentHash)
        external
        onlyRole(CREATOR_ROLE)
        returns (uint256 tokenId)
    {
        require(hashToTokenId[contentHash] == 0, "Asset already registered");

        tokenId = _nextId++;
        _safeMint(msg.sender, tokenId);

        _tokenURIs[tokenId] = assetURI;
        hashToTokenId[contentHash] = tokenId;

        emit AssetMinted(tokenId, msg.sender, contentHash, assetURI);
    }

    
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId); 
        return _tokenURIs[tokenId];
    }

    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
