// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SnipingBotRunner
 * @author Franz Krekeler
 */

contract SnipingBotRunner is Ownable, ReentrancyGuard {
    using Address for address;

    struct bid {
        address bidder;
        address collection;
        bool active; // is the current bid struct valid
        uint userBidIndex; // index for userBids, map(user => bids[userBidIndex])
        uint256 maxBid; // in wei
    }

    /** @dev fees % and basis percision points.
     * e.g  0.1% and basis points 10,000
     *  fee: 10 and Bps: 10000
     * NUMBER * fee / feeBasePercisionUnits
     * e.g. NUMBER * 10 / 10000
     **/
    uint256 public feePercisionUnits; // Bps
    uint256 public bidPlacementFee; // system fee for placing a bid
    // fee for replacing an existing bid, sent to previous bidder
    uint256 public bidReplacementFee;
    uint256 public bidFulfilmentFee; // system fee for filling a bid

    uint256 public totalUsersFunds; // book keeping eth of all user funds

    mapping(address => uint256) public userFunds; // eth book checking per user
    mapping(address => bid) public collections; // current bid per collection
    mapping(address => bid[]) public userBids; // active user bids

    event withdrawl(address indexed sender, uint256 indexed message);
    event deposit(
        address indexed sender,
        uint256 indexed value,
        string message
    );
    event bidPlaced(
        address indexed sender,
        address indexed collection,
        uint256 fee
    );
    event bidCleared(address indexed sender, address indexed collection);
    event bidFulfilled(
        address indexed receiver,
        address indexed collection,
        uint256 fee
    );

    constructor(
        uint256 bidPlacementFeeVal,
        uint256 bidReplacementFeeVal,
        uint256 bidFulfilmentFeeVal,
        uint256 feePercisionUnitsVal
    ) {
        bidPlacementFee = bidPlacementFeeVal;
        bidReplacementFee = bidReplacementFeeVal;
        bidFulfilmentFee = bidFulfilmentFeeVal;
        feePercisionUnits = feePercisionUnitsVal;
    }

    ///@notice Do not use this to add balances, use addFunds()
    receive() external payable {
        emit deposit(msg.sender, msg.value, "received funds");
    }

    // allows owner to withdraw funds
    function withdrawOperatorFunds(address to) external onlyOwner {
        uint256 balanceMinusUserFunds = address(this).balance - totalUsersFunds;
        (bool success, ) = payable(to).call{value: balanceMinusUserFunds}("");
        require(success, "error withdrawing op funds");
        emit withdrawl(to, balanceMinusUserFunds);
    }

    // create a bid on a collection, paying an active bidder percentage fee
    // or update current user bid
    function addBid(address collection, uint256 maxBid)
        external
        payable
        returns (bool)
    {
        if (msg.value > 0) {
            addFunds();
        }
        require(userFunds[msg.sender] >= maxBid, "bid bigger than user funds");

        bid storage currentBid = collections[collection];
        /// @param systemFee Bid placement fee
        uint256 systemFee = (maxBid * bidPlacementFee) / feePercisionUnits;
        if (currentBid.active) {
            if (currentBid.bidder == msg.sender) {
                /// @notice if the bid is active by the user, update without fees
                currentBid.maxBid = maxBid;
                return true;
            } else {
                /// @dev give fee to current collection bidder for replacing his bid
                uint256 feeToPrevBidder = (currentBid.maxBid *
                    bidReplacementFee) / feePercisionUnits;
                require(
                    userFunds[msg.sender] > feeToPrevBidder,
                    "not enough funds to replace bid"
                );
                userFunds[currentBid.bidder] += feeToPrevBidder;
                userFunds[msg.sender] -= feeToPrevBidder;
                maxBid -= feeToPrevBidder;
                /// @dev remove current active bid before placing a new one
                _clearBid(currentBid);
            }
        }
        // take bid placement system fees
        totalUsersFunds -= systemFee;
        userFunds[msg.sender] -= systemFee;
        maxBid -= systemFee;
        require(maxBid > 0, "maxBid is too small");
        /// @dev add new bid
        currentBid.bidder = msg.sender;
        currentBid.collection = collection;
        currentBid.active = true;
        currentBid.maxBid = maxBid;
        currentBid.userBidIndex = userBids[msg.sender].length;
        userBids[msg.sender].push(currentBid);

        return true;
    }

    // add funds to user
    function addFunds() public payable {
        userFunds[msg.sender] += msg.value;
        totalUsersFunds += msg.value;
        emit deposit(msg.sender, msg.value, "added funds");
    }

    function clearBid(address collection) public {
        bid storage currentBid = collections[collection];
        if (
            currentBid.active &&
            ((currentBid.bidder == msg.sender) || (msg.sender == owner()))
        ) {
            _clearBid(currentBid);
        }
    }

    // clear a bid, pattern for saving some gas for next bid initiation
    function _clearBid(bid storage currentBid) internal {
        emit bidCleared(msg.sender, currentBid.collection);
        userBids[currentBid.bidder][currentBid.userBidIndex] = userBids[
            currentBid.bidder
        ][userBids[currentBid.bidder].length - 1];
        userBids[currentBid.bidder].pop();

        currentBid.active = false;
    }

    function removeAllUserBids() public {
        bid[] storage userbids = userBids[msg.sender];
        for (uint i = 0; i < userbids.length; i++) {
            // index 0, due to _clearBid(...) gas saving pattern
            _clearBid(userbids[0]);
        }
    }

    // clears all user bids and withdraws eth
    function withdrawFunds() external {
        require(userFunds[msg.sender] > 0, "no funds to withdraw");
        removeAllUserBids();
        uint256 withdraw = userFunds[msg.sender];
        userFunds[msg.sender] = 0;
        totalUsersFunds -= withdraw;
        (bool success, ) = payable(msg.sender).call{value: withdraw}("");
        require(success, "error, failed to send eth");
        emit withdrawl(msg.sender, withdraw);
    }

    function getCollectionBidder(address collection)
        public
        view
        returns (address)
    {
        return collections[collection].bidder;
    }

    function getCollectionMaxBid(address collection)
        public
        view
        returns (uint256)
    {
        return collections[collection].maxBid;
    }

    function isCollectionBidActive(address collection)
        public
        view
        returns (bool)
    {
        return collections[collection].active;
    }

    // https://eips.ethereum.org/EIPS/eip-721 - not required for current implementation
    function onERC721Received(
        address, // operator,
        address, // from
        uint256, // tokenId,btg
        bytes calldata // data
    ) external returns (bytes4) {
        // add transfer to user(?)
        return this.onERC721Received.selector;
    }

    // https://eips.ethereum.org/EIPS/eip-1155 - not required for current implementation
    function onERC1155Received(
        address, // operator
        address, // from
        uint256, // tokenId
        uint256, // amount
        bytes calldata // data
    ) external returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function snipe(
        address target,
        bytes calldata data,
        uint256 price,
        address collection,
        address bidder
    ) external payable onlyOwner {
        //uint256 initialGas = gasleft();

        require(userFunds[bidder] > price, "error, not enough user funds");
        // implement 'data' check with book keeping(?)
        target.call{value: price}(data);

        userFunds[bidder] -= price;
        // transaction fee for system
        uint256 txFee = (price * bidFulfilmentFee) / feePercisionUnits;
        require(userFunds[bidder] >= txFee, "error, not enough fee funds");
        userFunds[bidder] -= txFee;
        totalUsersFunds -= txFee;
        emit bidFulfilled(bidder, collection, txFee);
        clearBid(collection);
        //uint256 currentGas = gasleft();
        // implement gas fee accurance(?)
    }
}
