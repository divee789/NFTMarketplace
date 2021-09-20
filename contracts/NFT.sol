//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/utils/Counters.sol";
import "./openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";

contract DivineNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address contractAddress;

    constructor(address marketplaceAddress) ERC721("DivineVerse", "DVT") {
        contractAddress = marketplaceAddress;
    }

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

//     /**
//   Owner can set the fee for an auction.
//   @param newFee - Auction Price
//    */

//     function setAuctionFee(uint256 newFee) public onlyOwner {
//         auctionFee = newFee;
//     }

//     /**
//   Owner can put a token on auction.
//   @param tokenId - token id 
//   @param price - minimum price required
//   @param endTime - end time of auction
//    */
//     function putOnAuction(
//         uint256 tokenId,
//         uint256 price,
//         uint256 endTime
//     ) public payable {
//         require(
//             _isApprovedOrOwner(msg.sender, tokenId),
//             "caller not an owner or approved"
//         );
//         require(NFTs[tokenId].isOnSale == false, "Already on sale");
//         require(price > 0, "Price must be greater than 0");
//         require(
//             msg.value >= auctionFee,
//             "Not enough BNB to pay the auctionFee"
//         );

//         NFTs[tokenId].minPrice = price;
//         NFTs[tokenId].endTime = endTime;
//         NFTs[tokenId].seller = payable(msg.sender);
//         NFTs[tokenId].bid = 0;
//         NFTs[tokenId].isOnSale = true;

//         emit OnSale(tokenId, price, endTime);
//     }

//     /**
//   Bid for a token on sale. Bid amount has to be higher than current bid or minimum price.
//   Accepts bnb as the function is payable
//   @param tokenId - token id 
//    */
//     function bid(uint256 tokenId) public payable {
//         require(_owners[tokenId] != msg.sender, "Owner cannot bid");
//         require(NFTs[tokenId].isOnSale == true, "Not on sale");
//         require(NFTs[tokenId].endTime > block.timestamp, "Sale ended");
        
//         if (NFTs[tokenId].bid == 0) {
//             require(
//                 msg.value > NFTs[tokenId].minPrice,
//                 "value sent is lower than min price"
//             );
//         } else {
//             require(
//                 msg.value > NFTs[tokenId].bid,
//                 "value sent is lower than current bid"
//             );

//             UserBalances[NFTs[tokenId].bidder] = UserBalances[NFTs[tokenId].bidder] + NFTs[tokenId].bid;
//         }

//         NFTs[tokenId].bidder = payable(msg.sender);
//         NFTs[tokenId].bid = msg.value;
//         emit Bid(tokenId, NFTs[tokenId].bidder, msg.value);
//     }
}
