//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is ReentrancyGuard, Ownable {
    // state variables
    address payable public immutable feeAccount; // account that recieves fees
    address payable public immutable escrowAccount; // account that hold money during the process
    uint public immutable feePercent; // fee percentage on sales
    uint public itemCount;

    uint public landInspectorId;
    mapping(uint => address) public registeredLandInspectors; // record of all the approved land inspectors

    // Add a new land inspector [Can only be called by owner of the contract]
    function addLandinspector(
        address _inspector
    ) public onlyOwner returns (uint) {
        landInspectorId++;
        registeredLandInspectors[landInspectorId] = _inspector;

        return landInspectorId;
    }

    // Data type to store all the information about the Property
    struct Item {
        uint ItemId;
        uint tokenId;
        uint sellingPrice;

        uint moneyPayed;
        IERC721 nftAddress; // the nft address of the property
        address payable seller;
        address payable buyer; // one who has deposited caution money for that property
        address appraisedBy;
        address documentVerifiedBy;

        bool onmarket; // if caution money is deposited then [false]

        bool validDocuments;
        bool appraised;
    }

    mapping(uint => Item) public items;

    // event when property is listed
    event Offered(
        uint ItemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );

    // event for when the documents are either verified or rejected
    event DocumetEvent(uint ItemId, address verifiedBy, bool result);

    // event for when price of a property is changed
    event PriceChange(uint itemId, uint newprice, address seller);

    event Booked(
        uint itemId,
        address nft,
        uint tokenId,
        uint moneyPayed,
        address seller,
        address buyer

    );

    event Bought(
        uint ItemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    event cancelled(uint itemId, address cancelledBy);

    event rejected(uint itemId, address rejectedBy, uint inpectorId);

    function _onlyBuyer(uint _propertyID) private view {
        require(
            msg.sender == items[_propertyID].buyer,
            "Only buyer can call this method"
        );
    }

    function _onlySeller(uint _propertyID) private view {
        require(
            msg.sender == items[_propertyID].seller,
            "Only seller can call this method"
        );
    }

    function _onlyInspector(uint _inspectorId) private view {
        require(
            _inspectorId > 0 && _inspectorId <= landInspectorId,
            "inspector ID is invalid"
        );
        require(
            msg.sender == registeredLandInspectors[_inspectorId],
            "Only inspector can call this method"
        );
    }

    // modifiers needed to control who can call the functionsa
    modifier onlyBuyer(uint256 _propertyID) {
        _onlyBuyer(_propertyID);
        _;
    }

    modifier onlySeller(uint _propertyID) {
        _onlySeller(_propertyID);
        _;
    }

    modifier onlyInspector(uint _inspectorId) {
        _onlyInspector(_inspectorId);
        _;
    }

    // fee account stores the margin(fees) on transaction
    // and
    //  escrow account stores the money till the transaction is complete
    constructor(uint _feePercent, address _feeaccount) {
        escrowAccount = payable(msg.sender);
        feeAccount = payable(_feeaccount);
        feePercent = _feePercent;
    }

    // STEP 1:
    // Seller can list new property using this method
    function ListProperty(
        uint _price,
        IERC721 _nft,
        uint _tokenId
    ) external nonReentrant {
        require(_price > 0, "price must be greater than 0");

        // increment itemCount;
        itemCount++;

        // transfer the NFT
        _nft.transferFrom(msg.sender, address(this), _tokenId);

        items[itemCount] = Item({
            ItemId: itemCount,
            tokenId: _tokenId,
            sellingPrice: _price,
            // cautionMoney: _cautionAmount,
            moneyPayed: 0,
            nftAddress: _nft,
            seller: payable(msg.sender),
            buyer: payable(address(0)),
            appraisedBy: address(0),
            documentVerifiedBy: address(0),

            onmarket: false, // not on market till documents are verified

            validDocuments: false,

            appraised: false
        });

        emit Offered(itemCount, address(_nft), _tokenId, _price, msg.sender);
    }

    // STEP 2:
    // Document verification
    function verifyDocuments(
        uint _itemid,
        uint _inspectorId,
        bool _res
    ) public onlyInspector(_inspectorId) {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");

        items[_itemid].documentVerifiedBy = msg.sender;

        items[_itemid].validDocuments = _res;
        items[_itemid].onmarket = _res;

        emit DocumetEvent(_itemid, msg.sender, _res);
    }

    // Step 3:
    // Allow seller to change the price of the property
    function changePrice(
        uint _itemid,
        uint _newprice
    ) public onlySeller(_itemid) {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");

        // do not allow to change when caution money already deposited
        require(
            items[_itemid].moneyPayed != 0,
            "Cannot change price when caution money already payed"
        );

        items[_itemid].sellingPrice = _newprice;
        emit PriceChange(_itemid, _newprice, msg.sender);
    }

    // Step 4:
    // Allow buyer to deposit the caution amout for the property
    // update moneyPayed
    function depositCautionMoney(uint _itemid) external payable nonReentrant {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");

        // check for enough monet to deposit as caution money
        require(items[_itemid].moneyPayed != 0, "property already booked");
        require(
            msg.value*100 >= items[_itemid].sellingPrice*15,
            "not enough ether to cover caution money and gas fee"
        );
        // check if property is already  booked or sold
        
        require(items[_itemid].onmarket, "property not on market");
        require(
            items[_itemid].validDocuments,
            "sellers property documents are not valid"
        );

        // update item caution money deposited status to true

        items[_itemid].onmarket = false;
        items[_itemid].moneyPayed = msg.value;
        items[_itemid].buyer = payable(msg.sender);

        emit Booked(
            _itemid,
            address(items[_itemid].nftAddress),
            items[_itemid].tokenId,
            items[_itemid].moneyPayed,
            items[_itemid].seller,
            items[_itemid].buyer
        );
    }

    // Step 5:
    // If seller delists the property (backs off) buyer gets moeny back
    function delist(uint _itemid) public onlySeller(_itemid) nonReentrant {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");
        if (items[_itemid].moneyPayed == 0) {
            items[_itemid].onmarket = false;
        } else {
            // refund the caution money back to the buyer
            items[_itemid].buyer.transfer(items[_itemid].moneyPayed);

            items[_itemid].moneyPayed = 0;
            items[_itemid].onmarket = false;
            items[_itemid].buyer = payable(address(0));
        }

        emit cancelled(_itemid, msg.sender);
    }

    // Allow buyer to backfoff [seller keeps caution money]
    function backoff(uint _itemid) public onlyBuyer(_itemid) nonReentrant {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");

        items[_itemid].seller.transfer((items[_itemid].sellingPrice*15)/100); // give caution money to the seller
        // any amount payed extra than the caution money is retured back to the buyer
        items[_itemid].buyer.transfer(
            items[_itemid].moneyPayed - (items[_itemid].sellingPrice*15)/100
        );

        items[_itemid].moneyPayed = 0;

        items[_itemid].onmarket = true;
        items[_itemid].buyer = payable(address(0));

        emit cancelled(_itemid, msg.sender);
    }


    // if appriasal failed refund buyers money
    function appraialResult(
        uint _itemid,
        uint _inspectorid,
        bool _res
    ) public onlyInspector(_inspectorid) {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");
        require(
            items[_itemid].validDocuments,
            "Documents for property are not valid"
        );

        items[_itemid].appraised = _res;

        items[_itemid].appraisedBy = msg.sender;

        if (!_res) {
            // if inspection failed remove property from market
            items[_itemid].onmarket = false;

            if (items[_itemid].moneyPayed*100 > items[_itemid].sellingPrice*15) {
                // if caution money payed by buyer then refund it
                items[_itemid].buyer.transfer(items[_itemid].moneyPayed);
                items[_itemid].moneyPayed = 0;

                items[_itemid].buyer = payable(address(0));
            }
        }

        emit rejected(_itemid, msg.sender, _inspectorid);
    }

    // Step 7:
    // Finalize purchase of the property
    // Amount to be payed = (sellingPrice - monetPayed)
    // transfer ownership of the property
    function finalizesale(uint _itemid) external payable onlyBuyer(_itemid) {
        require(_itemid > 0 && _itemid <= itemCount, "Item does not exist");
        require(
            msg.value >=
                items[_itemid].sellingPrice - items[_itemid].moneyPayed,
            "not enough ether to cover item price and gas fee"
        );
        require(items[_itemid].onmarket, "Property not on sale");
        require(items[_itemid].moneyPayed*100 >= items[_itemid].sellingPrice*15, "caution money not payed");

        require(items[_itemid].validDocuments, "Documents need to be verified");

        require(
            items[_itemid].appraised,
            "property has not been appraised"
        );

        // transfer money to the seller;
        items[_itemid].seller.transfer(items[_itemid].sellingPrice);
        // transfer the property to the buyer
        items[_itemid].nftAddress.transferFrom(
            address(this),
            msg.sender,
            items[_itemid].tokenId
        );

        emit Bought(
            _itemid,
            address(items[_itemid].nftAddress),
            items[_itemid].tokenId,
            items[_itemid].sellingPrice,
            items[_itemid].seller,
            items[_itemid].buyer
        );

        // delist the property
        items[_itemid].moneyPayed = 0;
        items[_itemid].seller = payable(msg.sender);
        items[_itemid].buyer = payable(address(0));

        items[_itemid].appraisedBy = address(0);
        items[_itemid].documentVerifiedBy = address(0);


        items[_itemid].onmarket = false;

        items[_itemid].validDocuments = false;
        items[_itemid].appraised = false;

    }
}
