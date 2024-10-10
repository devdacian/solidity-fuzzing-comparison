// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// using regular and old Ownable for simplicity, any findings
// related to using newer Ownable or 2-step are invalid
import "@openzeppelin/contracts/access/Ownable.sol";

//
// This contract is a simplified version of a real contract which
// was audited by Cyfrin in a private audit and contained the same bug.
//
// Your mission, should you choose to accept it, is to find that bug!
//
// This is an nft contract that allows users to have nfts which
// have voting power in a DAO. These nfts can lose power over time if
// the required collateral is not deposited. The power of these nfts
// can never increase, only decrease or remain the same. 
//
// This contract has been intentionally simplified to remove much of
// the extra complexity in order to help you find the particular bug without
// other distractions. Please read the comments carefully as they note
// specific findings that are excluded as the implementation has been
// purposefully kept simple to help you focus on finding the harder
// to find and more interesting bug.
//
// This contract should only contain 1 intentional High finding, but
// if you find others they were not intentional :-) This contract should
// not be used in any live/production environment; it is purely an
// educational bug-hunting exercise based on a real-world example.
//
contract VotingNft is ERC721, Ownable {

    // useful constants
    uint256 private constant PERCENTAGE_100 = 10 ** 27;

    // required collateral in eth to be deposited per NFT in order to
    // prevent voting power from decreasing
    uint256 private s_requiredCollateral;

    // time when power calculation begins
    uint256 private s_powerCalcTimestamp;

    // max power an nft can have. Power can only decrease or stay the same
    uint256 private s_maxNftPower;

    // % by which nft power decreases if required collateral not deposited
    uint256 private s_nftPowerReductionPercent;

    // current total power; will increase before power calculation starts
    // as nfts are created. once power calculation starts can only decrease
    // if nfts don't have the required collateral deposited
    uint256 private s_totalPower;

    // current total collateral which has been deposited for nfts
    uint256 private s_totalCollateral;

    struct NftInfo {
        uint256 lastUpdate;
        uint256 currentPower;
        uint256 currentCollateral;
    }
    // keeps track of contract-specific nft info
    mapping(uint256 tokenId => NftInfo) s_nftInfo;


    // create the contract
    constructor(
        uint256 requiredCollateral,
        uint256 powerCalcTimestamp,
        uint256 maxNftPower,
        uint256 nftPowerReductionPercent) 
        ERC721("VNFT", "VNFT")
        Ownable(msg.sender) {

        // input sanity checks
        require(requiredCollateral > 0, "VNFT: required collateral must be > 0");
        require(powerCalcTimestamp > block.timestamp, "VNFT: power calc timestamp must be in the future");
        require(maxNftPower > 0, "VNFT: max nft power must be > 0");
        require(nftPowerReductionPercent > 0, "VNFT: nft power reduction must be > 0");
        require(nftPowerReductionPercent < PERCENTAGE_100, "VNFT: nft power reduction too big");

        s_requiredCollateral = requiredCollateral;
        s_powerCalcTimestamp = powerCalcTimestamp;
        s_maxNftPower        = maxNftPower;
        s_nftPowerReductionPercent = nftPowerReductionPercent;
    }


    // some operations can only be performed before
    // power calculation has started 
    modifier onlyBeforePowerCalc() {
        _onlyBeforePowerCalc();
        _;
    }
    function _onlyBeforePowerCalc() private view {
        require(
            block.timestamp < s_powerCalcTimestamp,
            "VNFT: power calculation has already started"
        );
    }
    
    // allows contract owner to mint nfts to an address
    // can only be called before power calculation starts
    // all new nfts start at max power
    function safeMint(address to, uint256 tokenId) external onlyOwner onlyBeforePowerCalc {
        _safeMint(to, tokenId, "");

        s_totalPower += s_maxNftPower;
    }

    // allows nft holders to deposit collateral for their nft
    // nfts which have their required collateral deposited
    // don't lose power
    function addCollateral(uint256 tokenId) external payable {
        // sanity checks
        require(ownerOf(tokenId) == msg.sender, "VNFT: only nft owner can deposit collateral");

        uint256 amount = msg.value;
        require(amount > 0, "VNFT: collateral deposit amount must be > 0");

        require(s_nftInfo[tokenId].currentCollateral + amount <= s_requiredCollateral,
        "VNFT: collateral deposit must not exceeed required collateral");

        // recalculation intentionally takes place before storage update
        recalculateNftPower(tokenId);

        // update storage
        s_nftInfo[tokenId].currentCollateral += amount;
        s_totalCollateral += amount;
    }

    // allows nft holders to withdraw collateral which had been
    // deposited for their nfts. This will cause those nfts
    // to subsequently lose power
    function removeCollateral(uint256 tokenId) external payable {
        // sanity checks
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == msg.sender, "VNFT: only nft owner can remove collateral");

        uint256 amount = msg.value;
        require(amount > 0, "VNFT: collateral remove amount must be > 0");

        // recalculation intentionally takes place before storage update
        recalculateNftPower(tokenId);

        // update storage
        s_nftInfo[tokenId].currentCollateral -= amount;
        s_totalCollateral -= amount;

        // send withdrawn collateral to token owner
        _sendEth(tokenOwner, amount);
    }

    // recalculated nft power. Used internally and also called externally by
    // other operations within the DAO
    function recalculateNftPower(uint256 tokenId) public returns (uint256 newPower) {
        // nfts have no power until power calculation starts
        if (block.timestamp < s_powerCalcTimestamp) {
            return 0;
        }

        newPower = getNftPower(tokenId);

        NftInfo storage nftInfo = s_nftInfo[tokenId];

        s_totalPower -= nftInfo.lastUpdate != 0 ? nftInfo.currentPower : s_maxNftPower;
        s_totalPower += newPower;

        nftInfo.lastUpdate   = block.timestamp;
        nftInfo.currentPower = newPower;
    }

    // make sure to recalculate nft power if these nfts are transferred
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        // if users have collateral deposited for their nfts when they transfer
        // them to another user, the other users effectively becomes the owner
        // of the collateral. The nfts are mostly worthless without the collateral since
        // their voting power drops without it, so by design the deposited
        // collateral moves with the nfts
        recalculateNftPower(tokenId);

        return super._update(to, tokenId, auth);
    }

    // bunch of getter functions
    function getRequiredCollateral() public view returns (uint256) {
        return s_requiredCollateral;
    }

    function getPowerCalcTimestamp() public view returns (uint256) {
        return s_powerCalcTimestamp;
    }

    function getMaxNftPower() public view returns (uint256) {
        return s_maxNftPower;
    }

    function getNftPowerReductionPercent() public view returns (uint256) {
        return s_nftPowerReductionPercent;
    }

    function getTotalPower() public view returns (uint256) {
        return s_totalPower;
    }

    function getTotalCollateral() public view returns (uint256) {
        return s_totalCollateral;
    }

    function getDepositedCollateral(uint256 tokenId) public view returns (uint256) {
        _requireOwned(tokenId);

        return s_nftInfo[tokenId].currentCollateral;
    }

    function getNftPower(uint256 tokenId) public view returns (uint256) {
        // ensure token has already been minted
        _requireOwned(tokenId);

        if (block.timestamp <= s_powerCalcTimestamp) {
            return 0;
        }

        uint256 collateral   = s_nftInfo[tokenId].currentCollateral;

        // Calculate the minimum possible power based on the collateral of the nft
        uint256 maxNftPower  = s_maxNftPower;
        uint256 minNftPower  = maxNftPower * collateral / s_requiredCollateral;
        minNftPower          = Math.min(maxNftPower, minNftPower);

        // Get last update and current power. Or set them to default if it is first iteration
        uint256 lastUpdate   = s_nftInfo[tokenId].lastUpdate;
        uint256 currentPower = s_nftInfo[tokenId].currentPower;

        if (lastUpdate == 0) {
            lastUpdate       = s_powerCalcTimestamp;
            currentPower     = maxNftPower;
        }

        // Calculate reduction amount
        uint256 powerReductionPercent = s_nftPowerReductionPercent * (block.timestamp - lastUpdate);
        uint256 powerReduction = Math.min(currentPower, (maxNftPower * powerReductionPercent) / PERCENTAGE_100);
        uint256 newPotentialPower = currentPower - powerReduction;

        if (minNftPower <= newPotentialPower) {
            return newPotentialPower;
        }

        if (minNftPower <= currentPower) {
            return minNftPower;
        }

        return currentPower;
    }

    // sends eth using low-level call as we don't care about returned data
    function _sendEth(address dest, uint256 amount) private {
        bool sendStatus;
        assembly {
            sendStatus := call(gas(), dest, amount, 0, 0, 0, 0)
        }
        require(sendStatus, "VNFT: failed to send eth");
    }

}