// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IAssetRegistry {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract LicenseTerms is AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    IAssetRegistry public immutable asset;
    uint256 public immutable requiredQuorum;

    struct Terms {
        uint256 version;
        uint256 ratePerUnit;
        bytes32 metadataHash;
        bool active;
        uint256 approvals;
    }

    mapping(uint256 => Terms) private _terms;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private _approvedByVersion;
    mapping(uint256 => uint256) private _versionCounter;

    event ValidatorAdded(address indexed validator);
    event TermsProposed(uint256 indexed tokenId, uint256 version, uint256 ratePerUnit, bytes32 metadataHash);
    event TermsApproved(uint256 indexed tokenId, uint256 version, address indexed validator, uint256 approvals);
    event TermsPublished(uint256 indexed tokenId, uint256 version, uint256 ratePerUnit);

    constructor(address assetRegistry, uint256 quorum) {
        require(assetRegistry != address(0), "bad asset");
        require(quorum > 0, "quorum=0");
        asset = IAssetRegistry(assetRegistry);
        requiredQuorum = quorum;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addValidator(address v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(VALIDATOR_ROLE, v);
        emit ValidatorAdded(v);
    }

    function proposeTerms(uint256 tokenId, uint256 ratePerUnit, bytes32 metadataHash) external {
        require(asset.ownerOf(tokenId) == msg.sender, "not token owner");
        require(ratePerUnit > 0, "rate=0");

        uint256 nextVer = _versionCounter[tokenId] + 1;
        _versionCounter[tokenId] = nextVer;

        Terms storage t = _terms[tokenId];
        t.version = nextVer;
        t.ratePerUnit = ratePerUnit;
        t.metadataHash = metadataHash;
        t.active = false;
        t.approvals = 0;

        emit TermsProposed(tokenId, nextVer, ratePerUnit, metadataHash);
    }

    function approveTerms(uint256 tokenId) external onlyRole(VALIDATOR_ROLE) {
        Terms storage t = _terms[tokenId];
        require(t.version > 0, "no proposal");
        require(!_approvedByVersion[tokenId][t.version][msg.sender], "already approved");

        _approvedByVersion[tokenId][t.version][msg.sender] = true;
        t.approvals += 1;
        emit TermsApproved(tokenId, t.version, msg.sender, t.approvals);
    }

    function publishTerms(uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Terms storage t = _terms[tokenId];
        require(t.version > 0, "no proposal");
        require(t.approvals >= requiredQuorum, "quorum not met");
        t.active = true;
        emit TermsPublished(tokenId, t.version, t.ratePerUnit);
    }

    function isActive(uint256 tokenId) external view returns (bool) {
        return _terms[tokenId].active;
    }

    function currentVersion(uint256 tokenId) external view returns (uint256) {
        return _terms[tokenId].version;
    }

    function rateOf(uint256 tokenId) external view returns (uint256) {
        return _terms[tokenId].ratePerUnit;
    }

    function hasApproved(uint256 tokenId, uint256 version, address validator) external view returns (bool) {
        return _approvedByVersion[tokenId][version][validator];
    }

    function getTerms(uint256 tokenId)
        external
        view
        returns (uint256 version, uint256 ratePerUnit, bytes32 metadataHash, bool active, uint256 approvals)
    {
        Terms storage t = _terms[tokenId];
        version = t.version;
        ratePerUnit = t.ratePerUnit;
        metadataHash = t.metadataHash;
        active = t.active;
        approvals = t.approvals;
    }
}
