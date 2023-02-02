const { ethers } = require("hardhat");
const { expect } = require("chai");
const web3 = require("web3");

const fromWei = (num) => ethers.utils.formatEther(num);

const tokens = (n) => {
  return ethers.utils.parseUnits(n.toString(), "ether");
};

describe("BlockchainBrokers", async function () {
  //   let realEstate, escrow;
  let marketplace, property;
  let transaction;
  let buyer, seller, inspector, owner;

  beforeEach(async function () {
    // get signers
    [owner, buyer, seller, inspector] = await ethers.getSigners();

    // Get contract factory
    const Property = await ethers.getContractFactory("Property");
    const Marketplace = await ethers.getContractFactory("Marketplace");

    // deploy contracts
    property = await Property.deploy();
    // deploying escrow contract
    marketplace = await Marketplace.deploy(owner.address);

    // Mint
    transaction = await property
      .connect(seller)
      .mint(
        "https://ipfs.io/ipfs/QmQUozrHLAusXDxrvsESJ3PYB3rUeUuBAvVWw6nop2uu7c/2.png"
      );
    await transaction.wait();

    // approve
    transaction = await property
      .connect(seller)
      .approve(marketplace.address, 1);
    await transaction.wait();
  });

  describe("mint", async function () {
    it("Should mint the Property", async function () {
      // addr1 mints the NFTs
      await property
        .connect(seller)
        .mint(
          "https://ipfs.io/ipfs/QmQUozrHLAusXDxrvsESJ3PYB3rUeUuBAvVWw6nop2uu7c/2.png"
        );
      expect(await property.TotalListedProperties()).to.equal(2);
      expect(await property.balanceOf(seller.address)).to.equal(2);
      expect(await property.tokenURI(2)).to.equal(
        "https://ipfs.io/ipfs/QmQUozrHLAusXDxrvsESJ3PYB3rUeUuBAvVWw6nop2uu7c/2.png"
      );
    });
  });

  describe("deployment", async function () {
    it("Should track the name and symbol of the Property collection", async function () {
      expect(await property.name()).to.equal("Properties");
      expect(await property.symbol()).to.equal("DREAM");
      expect(await marketplace.owner()).to.equal(owner.address);
    });
  });

  describe("list", async function () {
    it("should check if the ownership of the property is transferred", async function () {
      // List property

      // list property for selling and match the emit event
      expect(
        await marketplace
          .connect(seller)
          .ListProperty(web3.utils.toWei("5", "ether"), property.address, 1)
      )
        .to.emit(marketplace, "Offered")
        .withArgs(
          1,
          property.address,
          1,
          web3.utils.toWei("5", "ether"),
          seller.address
        );
    });

    // new owner of propwert should be marketplace
    expect(await property.ownerOf(1)).to.equal(await marketplace.address);
  });

  describe("addInspector", async function () {
    it("should add an inspector", async function () {
      transaction = await marketplace
        .connect(owner)
        .addInspector(inspector.address);
      transaction.wait;

      expect(await marketplace.registeredLandInspectors(1)).to.equal(
        inspector.address
      );
    });

    it("should fail if called by anyone other than contract owner", async function () {

      await expect(marketplace.connect(seller).addInspector(seller.address)).to.be.revertedWith('Only owner can call this method');
      
    });
  });
});
