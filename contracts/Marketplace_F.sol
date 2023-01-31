//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";




contract Marketplace is ReentrancyGuard, Ownable {
     // state variables
    address payable public immutable feeAccount; // account that recieves fees
    uint public immutable feePercent; // fee percentage on sales
    uint public itemCount;


    struct Item {
     uint ItemId;
     uint tokenId;
     uint sellingprice;
     uint downPayment;

     address nftAddress;
     address payable seller; 
     address lender;
     address inspector; 

     bool onmarket;  // if caution money is deposited then [false]
     bool sold;   
     bool inspectionPassed;
     mapping(address => bool) approval;
    }

    mapping (uint => Item) public items;

    constructor(uint _feePercent)
    {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    // function makeItem(IERC721 _nft, uint _price, uint _tokenId ) external nonReentrant  {
    //     require(_price > 0, "price must be greater than 0");

    //     // increment itemCount;
    //     itemCount++;

    //     // transfer the NFT 
    //     _nft.transferFrom(msg.sender, address(this), _tokenId);

    //     items[itemCount] = Item(
    //         itemCount,
    //         _nft,
    //         _tokenId,
    //         _price,
    //         payable(msg.sender),
    //         false
    //     );

    //     emit Offered(
    //         itemCount,
    //         address(_nft),
    //         _tokenId,
    //         _price,
    //         msg.sender

    //     );
    // }


    // constructor(address _nftAddress, address payable _seller, address _inspector, address _lender ) {
    //     Item.seller = _seller;
    //     Item.inspector = _inspector;
    //     Item.lender = _lender;
    //     Item.nftAddress = _nftAddress;
    // }

    // function list(uint _nftID) public {
    //     IERC721(Item.nftAddress).transferFrom(Item.seller, address(this), _nftID);
    // }

}
