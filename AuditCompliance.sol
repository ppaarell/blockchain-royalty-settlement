// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IAssetRegistryLite {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// ---------------------------------------------------------------------------
/// AuditCompliance (Algorithm-3: Audit & Compliance Layer)
/// ---------------------------------------------------------------------------
contract AuditCompliance is AccessControl {
    bytes32 public constant REPORTER_ROLE  = keccak256("REPORTER_ROLE");   // DSP / RoyaltyEngine
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");  // Auditor/Regulator
    bytes32 public constant ARBITER_ROLE   = keccak256("ARBITER_ROLE");    // Panel/Arbiter

    IAssetRegistryLite public immutable asset;

    constructor(address assetRegistry) {
        require(assetRegistry != address(0), "bad asset addr");
        asset = IAssetRegistryLite(assetRegistry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGULATOR_ROLE, msg.sender); // untuk demo
        _grantRole(ARBITER_ROLE, msg.sender);   // untuk demo
    }

    struct AuditBundle {
        uint256 tokenId;
        uint64  periodStart;   // unix (UTC)
        uint64  periodEnd;     // unix (UTC)
        bytes32 usageHash;     // hash file usage (CSV/JSON)
        bytes32 allocationHash;// hash file hasil alokasi
        bytes32 payoutHash;    // hash file batch payout
        address reporter;      // siapa yang unggah
        bool    compliant;     // ditandai regulator?
        bool    disputed;      // ada sengketa?
        bool    resolved;      // sengketa selesai?
        bool    decisionUpheld;// keputusan: true=upheld, false=overturned
    }

    // auto-increment id untuk setiap bundle
    uint256 public nextBundleId = 1;
    mapping(uint256 => AuditBundle) public bundles;

    event AuditRecorded(
        uint256 indexed bundleId,
        uint256 indexed tokenId,
        uint64 periodStart,
        uint64 periodEnd,
        bytes32 usageHash,
        bytes32 allocationHash,
        bytes32 payoutHash,
        address reporter
    );

    event ComplianceMarked(uint256 indexed bundleId, address indexed regulator, bool compliant, string note);
    event DisputeOpened(uint256 indexed bundleId, address indexed opener, bytes32 reasonHash);
    event DisputeResolved(uint256 indexed bundleId, address indexed arbiter, bool decisionUpheld, bytes32 noteHash);

    // --------- RECORD AUDIT BUNDLE ----------

    function recordAuditBundle(
        uint256 tokenId,
        uint64  periodStart,
        uint64  periodEnd,
        bytes32 usageHash,
        bytes32 allocationHash,
        bytes32 payoutHash
    ) external onlyRole(REPORTER_ROLE) returns (uint256 bundleId) {
        require(periodEnd > periodStart, "bad period");
        require(usageHash != bytes32(0) && allocationHash != bytes32(0) && payoutHash != bytes32(0), "empty hash");

        bundleId = nextBundleId++;
        bundles[bundleId] = AuditBundle({
            tokenId: tokenId,
            periodStart: periodStart,
            periodEnd: periodEnd,
            usageHash: usageHash,
            allocationHash: allocationHash,
            payoutHash: payoutHash,
            reporter: msg.sender,
            compliant: false,
            disputed: false,
            resolved: false,
            decisionUpheld: false
        });

        emit AuditRecorded(bundleId, tokenId, periodStart, periodEnd, usageHash, allocationHash, payoutHash, msg.sender);
    }

    // --------- REGULATOR: MARK COMPLIANCE ----------

    function markCompliant(uint256 bundleId, bool isCompliant, string calldata note)
        external
        onlyRole(REGULATOR_ROLE)
    {
        AuditBundle storage b = bundles[bundleId];
        require(b.tokenId != 0, "no bundle");
        b.compliant = isCompliant;
        emit ComplianceMarked(bundleId, msg.sender, isCompliant, note);
    }

    // --------- DISPUTE FLOW ----------

    function openDispute(uint256 bundleId, bytes32 reasonHash) external {
        AuditBundle storage b = bundles[bundleId];
        require(b.tokenId != 0, "no bundle");
        // pembuka sengketa: creator (pemilik token) atau reporter
        address owner = asset.ownerOf(b.tokenId);
        require(msg.sender == owner || msg.sender == b.reporter, "not allowed");
        require(!b.resolved, "already resolved");
        b.disputed = true;
        emit DisputeOpened(bundleId, msg.sender, reasonHash);
    }

    function resolveDispute(uint256 bundleId, bool decisionUpheld, bytes32 noteHash)
        external
        onlyRole(ARBITER_ROLE)
    {
        AuditBundle storage b = bundles[bundleId];
        require(b.tokenId != 0, "no bundle");
        require(b.disputed && !b.resolved, "no active dispute");
        b.resolved = true;
        b.decisionUpheld = decisionUpheld;
        emit DisputeResolved(bundleId, msg.sender, decisionUpheld, noteHash);
    }

    // --------- Views bantu ----------

    function getBundle(uint256 bundleId)
        external
        view
        returns (
            uint256 tokenId,
            uint64  periodStart,
            uint64  periodEnd,
            bytes32 usageHash,
            bytes32 allocationHash,
            bytes32 payoutHash,
            address reporter,
            bool compliant,
            bool disputed,
            bool resolved,
            bool decisionUpheld
        )
    {
        AuditBundle storage b = bundles[bundleId];
        tokenId         = b.tokenId;
        periodStart     = b.periodStart;
        periodEnd       = b.periodEnd;
        usageHash       = b.usageHash;
        allocationHash  = b.allocationHash;
        payoutHash      = b.payoutHash;
        reporter        = b.reporter;
        compliant       = b.compliant;
        disputed        = b.disputed;
        resolved        = b.resolved;
        decisionUpheld  = b.decisionUpheld;
    }

    // OZ v5 multiple inheritance support
    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
