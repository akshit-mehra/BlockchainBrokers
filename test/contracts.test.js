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
  let buyer, seller, inspector, lender;

  beforeEach(async function () {
    // get signers
    [buyer, seller, inspector, lender] = await ethers.getSigners();

    // Get contract factory
    const Property = await ethers.getContractFactory("Property");
    const Marketplace = await ethers.getContractFactory("Marketplace");

    // deploy contracts
    property = await Property.deploy();
    // deploying escrow contract
    marketplace = await Marketplace.deploy(
      property.address,
      seller.address,
      inspector.address,
      lender.address
    );

    // Mint
    transaction = await property
      .connect(seller)
      .mint(
        "https://ipfs.io/ipfs/QmQUozrHLAusXDxrvsESJ3PYB3rUeUuBAvVWw6nop2uu7c/2.png"
      );
    await transaction.wait();

    // approve
    transaction = await property.connect(seller).approve(marketplace.address, 1);
    await transaction.wait();
  });

  describe("mint", async function () {
    it("Should mint the Property", async function () {});
  });

  describe("deployment", async function () {
    it("Should track the name and symbol of the Property collection", async function () {
      expect(await property.name()).to.equal("Properties");
      expect(await property.symbol()).to.equal("DREAM");
    });

    it("nft address of marketplace = property.address", async function () {
      const result = await marketplace.nftAddress();
      expect(result).to.equal(await property.address);
    });
  });

  describe("list", async function () {
    it("should check if the ownership of the property is transferred", async function () {
      // List property
      transaction = await marketplace.connect(seller).list(1);
      await transaction.wait();

      expect(await property.ownerOf(1)).to.equal(await marketplace.address);
    });
  });
});
