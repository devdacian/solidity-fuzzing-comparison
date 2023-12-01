// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//
// This contract is a simplified version of a real contract which
// was audited by Cyfrin in a private audit and contained the same bugs.
//
// Your mission, should you choose to accept it, is to find those bugs!
//
// This contract allows the creator to invite a select group of people
// to participate in a token sale. Users can exchange an allowed token
// for the token being sold. This could be used by a DAO to distribute
// their governance token in exchange for DAI, but having a lot more control
// over how that distribution takes place compared to using a uniswap pool.
//
// This contract has been intentionally simplified to remove much of
// the extra complexity in order to help you find the particular bugs without
// other distractions. Please read the comments carefully as they note
// specific findings that are excluded as the implementation has been
// purposefully kept simple to help you focus on finding the harder
// to find and more interesting bugs.
//
// This contract intentionally has no time-out period for the token sale
// to complete; lack of a time-out period resulting in the token sale never
// completing is not a valid finding as this has been intentionally 
// omitted to simplify the codebase.
//
// This contract intentionally does not support fee-on-transfer, rebasing
// ERC777 or any non-standard, weird ERC20s. It only supports ERC20s
// that conform to the ERC20 implementation. Any findings related to 
// weird/non-standard ERC20s are invalid. Any findings related to blacklists are invalid.
//
// This contract intentionally has no rescue function; any tokens that
// are sent to this contract are lost forever. Once this contract is
// created the fixed amount of tokens to be sold can't be changed. Any
// findings related to these issues are invalid.
//
// This contract should only contain 2 intentional High findings, but
// if you find others they were not intentional :-) This contract should
// not be used in any live/production environment; it is purely an
// educational bug-hunting exercise based on a real-world example.
//
contract TokenSale {
    // min buy precision enforced
    uint256 public constant MIN_BUY_PRECISION = 6;

    // sell precision always 18
    uint256 public constant SELL_PRECISION = 18;

    // smallest amount proposal creator can fund contract with
    uint256 public constant MIN_FUNDING = 100;

    // min number of buyers
    uint256 public constant MIN_BUYERS  = 3;

    // creator of this proposal. Any findings related to the creator
    // not being able to update this address are invalid; this has
    // intentionally been omitted to simplify the contract so you can
    // focus on finding the cool bug instead of lame/easy stuff. 
    // Eg: all findings related to blacklists are invalid; Proposal
    // creator can always receive and send tokens.
    address private immutable s_creator;

    // token to be sold by creator
    ERC20 private immutable s_sellToken;

    // token which buyers can use to buy the token being sold
    // for simplicity sake exchange rate is always 1:1
    // any findings related to not having a dynamic exchange rate are invalid
    ERC20 private immutable s_buyToken;

    // maximum amount any single buyer should be able to buy
    uint256 private immutable s_maxTokensPerBuyer;

    // total amount of tokens to be sold
    uint256 private immutable s_sellTokenTotalAmount;

    // total amount of tokens currently sold
    uint256 private s_sellTokenSoldAmount;

    // total number of allowed buyers
    uint256 private s_totalBuyers;

    // only permitted addresses can buy
    enum BuyerState {
        DISALLOWED,
        ALLOWED
    }

    mapping(address buyer => BuyerState) private s_buyers;


    // create the contract
    constructor(address[] memory allowList,
                address sellToken,
                address buyToken,
                uint256 maxTokensPerBuyer,
                uint256 sellTokenAmount) {
        require(sellToken != address(0), "TS: invalid sell token");
        require(buyToken  != address(0), "TS: invalid sell token");

        // save tokens to storage
        s_sellToken = ERC20(sellToken);
        s_buyToken  = ERC20(buyToken);

        // save tokens to stack since to prevent multiple storage reads during constructor
        ERC20 sToken = ERC20(sellToken);
        ERC20 bToken = ERC20(buyToken);

        // enforce precision
        require(sToken.decimals() == SELL_PRECISION, "TS: sell token invalid precision");
        require(bToken.decimals() >= MIN_BUY_PRECISION, "TS: buy token invalid min precision");
        require(bToken.decimals() <= SELL_PRECISION, "TS: buy token precision must <= sell token");

        // require minimum sell token amount
        require(sellTokenAmount >= MIN_FUNDING * 10 ** sToken.decimals(), "TS: Minimum funding required");

        // sanity check
        require(maxTokensPerBuyer <= sellTokenAmount, "TS: invalid max tokens per buyer");
        s_maxTokensPerBuyer = maxTokensPerBuyer;

        // cache list length
        uint256 allowListLength = allowList.length;

        // perform some sanity checks. NOTE: checks for duplicate inputs
        // are performed by entity creating the proposal who is trusted,
        // so the contract intentionally does not re-check for duplicate inputs. 
        // Findings related to not checking for duplicate inputs are invalid.
        require(allowListLength >= MIN_BUYERS, "TS: Minimum 3 buyers required");

        uint256 totalBuyers;

        // store addresses allowed to buy
        for(; totalBuyers<allowListLength; ++totalBuyers) {
            // sanity check to prevent address(0)
            address buyer = allowList[totalBuyers];
            require(buyer != address(0), "TS: address(0) invalid");

            s_buyers[buyer] = BuyerState.ALLOWED;
        }

        s_totalBuyers = totalBuyers;

        // update the token sale creator
        s_creator = msg.sender;

        // transfer the tokens to be sold into this contract
        //
        // fee-on-transfer & other weird stuff not suppported, see notes at top
        s_sellTokenTotalAmount = sellTokenAmount;

        // contract creator is trusted to immediately fund the contract after creation
        // with the correct amount; more complicated funding scheme not implemented
        // to avoid complexity. Any findings related to improper funding of contract
        // are invalid.
    }


    // buy some tokens from the token sale
    // no slippage required since exchange rate always 1:1
    // caller just specifies the amount of sell tokens they want to buy
    function buy(uint256 amountToBuy) external {
        // prevent sale if all tokens have been sold
        uint256 remainingSellTokens = getRemainingSellTokens();
        require(remainingSellTokens != 0, "TS: token sale is complete");

        // current buyer
        address buyer = msg.sender;

        // prevent buying if not allowed
        require(s_buyers[buyer] == BuyerState.ALLOWED, "TS: buyer not allowed");

        // if `amountToBuy` greater than remaining cap, cap it to buy the remainder
        if(amountToBuy > remainingSellTokens) {
            amountToBuy = remainingSellTokens;
        }

        // prevent user from buying more than max
        require(amountToBuy <= s_maxTokensPerBuyer, "TS: buy over max per user");

        // update storage to increase total bought
        s_sellTokenSoldAmount += amountToBuy;

        // transfer purchase tokens from buyer to creator
        SafeERC20.safeTransferFrom(s_buyToken, buyer, s_creator, _convert(amountToBuy, s_buyToken.decimals()));

        // transfer sell tokens from this contract to buyer
        SafeERC20.safeTransfer(s_sellToken, buyer, amountToBuy);
    }

    
    // ends the sale and refunds creator remaining unsold tokens
    function endSale() external {
        // cache creator address
        address creator = s_creator;

        // only creator can end the sale
        require(msg.sender == s_creator, "TS: only creator can end sale");

        // sale must not have been completed
        uint256 remainingSellTokens = getRemainingSellTokens();
        require(remainingSellTokens != 0, "TS: token sale is complete");

        // update storage with tokens sent to creator to mark the
        // sale as closed
        s_sellTokenSoldAmount += remainingSellTokens;

        // send remaining unsold tokens back to creator
        SafeERC20.safeTransfer(s_sellToken, creator, remainingSellTokens);
    }


    // used internally and externally to determine whether the sale
    // has been completed (no tokens remain unsold)
    function getRemainingSellTokens() public view returns(uint256) {
        return s_sellTokenTotalAmount - s_sellTokenSoldAmount;
    }


    // bunch of getters
    function getBuyTokenAddress() external view returns(address) {
        return address(s_buyToken);
    }
    function getSellTokenAddress() external view returns(address) {
        return address(s_sellToken);
    }
    function getMaxTokensPerBuyer() external view returns(uint256) {
        return s_maxTokensPerBuyer;
    }
    function getSellTokenTotalAmount() external view returns(uint256) {
        return s_sellTokenTotalAmount;
    }
    function getSellTokenSoldAmount() external view returns(uint256) {
        return s_sellTokenSoldAmount;
    }
    function getTotalAllowedBuyers() external view returns(uint256) {
        return s_totalBuyers;
    }
    function getCreator() external view returns(address) {
        return s_creator;
    }


    // handles conversions
    function _convert(uint256 amount_, uint256 destDecimals_) internal pure returns (uint256) {
        if (SELL_PRECISION > destDecimals_) {
            amount_ = amount_ / 10 ** (SELL_PRECISION - destDecimals_);
        } else if (SELL_PRECISION < destDecimals_) {
            amount_ = amount_ * 10 ** (destDecimals_ - SELL_PRECISION);
        }

        return amount_;
    }



}