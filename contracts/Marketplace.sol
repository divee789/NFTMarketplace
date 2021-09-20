// contracts/Market.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import "./openzeppelin/utils/Counters.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";
import "./openzeppelin/token/ERC721/ERC721.sol";
import "./openzeppelin/access/Ownable.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    uint256 listingPrice;

    struct MarketItem {
        address nftContract;
        address payable seller;
        address payable owner;
        address payable currentBidder;
        uint256 itemId;
        uint256 price;
        uint256 sold;
        uint256 tokenId;
        uint256 currentBid;
        bytes32 marketType;
    }

    mapping(uint256 => MarketItem) public idToMarketItem;
    mapping(uint256 => mapping(address => uint256)) public fundsByBidder;
    mapping(uint256 => uint256) public auctionItemNumberOfBidders;
    mapping(uint256 => address[]) public auctionItemBidders;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        uint256 sold
    );

    event Bid(address bidder, uint256 bid, uint256 itemId);

    modifier notMarketItemOwner(uint256 id) {
        MarketItem memory item = idToMarketItem[id];
        if (msg.sender == item.seller) revert();
        _;
    }

    modifier marketItemOwner(uint256 id) {
        MarketItem memory item = idToMarketItem[id];
        if (msg.sender != item.seller) revert();
        _;
    }

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /* Set the listing price of the contract */
    function setListingPrice(uint256 price) external onlyOwner {
        listingPrice = price;
    }

    /* Places an item for sale on the marketplace */
    /* marketType can either be Auction or Fixed */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        bytes32 marketType
    ) public payable nonReentrant {
        require(price > 0, "Price must be greater than 0");
        require(
            msg.value == listingPrice,
            "Value must be equal to listing price"
        );

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            nftContract,
            payable(msg.sender),
            payable(address(this)),
            payable(msg.sender),
            itemId,
            price,
            1,
            tokenId,
            0,
            marketType
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        payable(owner()).transfer(listingPrice);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            1
        );
    }

    /* Bid for a market item on auction */
    function bidForMarketItem(uint256 itemId) public payable nonReentrant {
        require(msg.value > 0, "Bid must be greater than 0");
        require(
            idToMarketItem[itemId].marketType == "Auction",
            "Only auctions can be bidded on"
        );
        require(idToMarketItem[itemId].sold == 1, "Item has already been sold");
        uint256 bidderOld = fundsByBidder[itemId][msg.sender];
        uint256 minBid = (
            idToMarketItem[itemId].currentBid == 0
                ? idToMarketItem[itemId].price
                : idToMarketItem[itemId].currentBid
        );
        if (bidderOld == 0) {
            require(
                msg.value > minBid,
                "Bid must be greater than the current bid"
            );
            auctionItemNumberOfBidders[itemId]++;
            auctionItemBidders[itemId].push(msg.sender);
        } else {
            require(
                bidderOld + msg.value > minBid,
                "Your bid must be greater than the current bid"
            );
        }
        fundsByBidder[itemId][msg.sender] = msg.value + bidderOld;
        idToMarketItem[itemId].currentBidder = payable(msg.sender);
        idToMarketItem[itemId].currentBid = msg.value + bidderOld;
        emit Bid(msg.sender, msg.value + bidderOld, itemId);
    }

    /* End Auction */
    /* Transfers ownership of the item, as well as funds between parties */
    /* Returns bids back to the bidders */
    function endAuction(uint256 itemId)
        public
        payable
        nonReentrant
        marketItemOwner(itemId)
    {
        uint256 currentBid = idToMarketItem[itemId].currentBid;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        idToMarketItem[itemId].seller.transfer(currentBid);
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            idToMarketItem[itemId].currentBidder,
            tokenId
        );
        uint256 numberOfBidders = auctionItemNumberOfBidders[itemId];
        for (uint256 i = 0; i < numberOfBidders; i++) {
            address bidderToRefund = auctionItemBidders[itemId][i];
            if (bidderToRefund == idToMarketItem[itemId].currentBidder) {
                continue;
            }
            uint256 bidToBeRefunded = fundsByBidder[itemId][bidderToRefund];
            payable(bidderToRefund).transfer(bidToBeRefunded);
        }
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = 2;
        idToMarketItem[itemId].currentBid = 0;
    }

    /* Places a previously sold item for sale on the marketplace */
    /* marketType can either be Auction or Fixed */
    function resellMarketItem(
        uint256 itemId,
        uint256 price,
        bytes32 marketType
    ) public payable nonReentrant {
        require(idToMarketItem[itemId].sold == 2, "Item has not been sold");
        require(price > 0, "Price must be greater than 0");
        require(
            listingPrice == msg.value,
            "Value must be equal to listing price"
        );
        require(marketType == "Auction" || marketType == "Fixed", "marketType must be either Auction or Fixed");

        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            msg.sender,
            address(this),
            idToMarketItem[itemId].tokenId
        );

        idToMarketItem[itemId].sold = 1;
        idToMarketItem[itemId].price = price;
        idToMarketItem[itemId].marketType = marketType;
        idToMarketItem[itemId].seller = payable(msg.sender);
        idToMarketItem[itemId].owner = payable(address(this));
        idToMarketItem[itemId].currentBid = 0;
        payable(owner()).transfer(listingPrice);
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        idToMarketItem[itemId].seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = 2;
        _itemsSold.increment();
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
