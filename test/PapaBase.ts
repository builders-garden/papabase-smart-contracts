import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("PapaBase", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPapaBaseContract() {

    const usdcTokenAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    const accrossContract = "0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64"

    // Contracts are deployed using the first signer/account by default
    const [owner, user1, user2, user3] = await ethers.getSigners();
    // impersonated signers
    const impersonatedSigner = await ethers.getImpersonatedSigner("0xA7B9874D15742358fB455Dd56f97C6d19ad74f5C");
    // usdc on Base instance
    const usdc = await ethers.getContractAt("IERC20", usdcTokenAddress);

    const PapaBase = await ethers.getContractFactory("PapaBase");
    const papaBase = await PapaBase.deploy(owner, usdcTokenAddress, accrossContract);

    return { papaBase, owner, user1, user2, user3, impersonatedSigner, usdc};
  }

  describe("Deployment", function () {
    it("deployment check", async function () {
      const { papaBase, owner, user1 } = await loadFixture(deployPapaBaseContract);

      // Test deployment
      expect(await papaBase.usdcTokenAddress()).to.equal("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913");
      expect(await papaBase.papaBaseAdmin()).to.equal(owner.address);
    });

    it("create a new papa campaign", async function () {
      const { papaBase, owner } = await loadFixture(deployPapaBaseContract);
      const tx = await papaBase.createCampaign("test campaign", "just a test");
      const receipt = await tx.wait();
      //check campaign created
      expect(await papaBase.campaignCount()).to.equal(1);
      //check campaign details
      const campaign = await papaBase.campaigns(1);
      expect(campaign.name).to.equal("test campaign");
      //check campaing creation event
      //console.log(receipt?.logs)
    });

    it("create a new papa campaign and donate", async function () {
      const { papaBase, impersonatedSigner, usdc } = await loadFixture(deployPapaBaseContract);
      console.log(impersonatedSigner.address, "impersonatedSigner")
      const tx = await papaBase.createCampaign("test campaign", "just a test");
      const receipt = await tx.wait();
      //check campaign created
      expect(await papaBase.campaignCount()).to.equal(1);
      //check campaign details
      const campaign = await papaBase.campaigns(1);
      expect(campaign.name).to.equal("test campaign");
      //check campaing creation event
      //console.log(receipt?.logs)

      // approve usdc to contract
      const approveTx = await usdc.connect(impersonatedSigner).approve(papaBase, 100000000000);

      //donate to campaign
      const donateTx = await papaBase.connect(impersonatedSigner).depositFunds(1, 1000000);
      const donateReceipt = await donateTx.wait();
      //check donation event
      console.log(donateReceipt?.logs)
    });
  });
});
