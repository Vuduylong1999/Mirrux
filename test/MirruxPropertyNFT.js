const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MirruxPropertyNFT", function () {
  async function deploy() {
    const [owner, alice] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("MirruxPropertyNFT");
    const nft = await NFT.deploy();
    return { nft, owner, alice };
  }

  it("mints token id 0 first, then increments", async function () {
    const { nft, alice } = await deploy();
    // Vì mint() trả về tokenId, ta dùng "callStatic" để mô phỏng gọi hàm và ĐỌC giá trị trả về
    // mà KHÔNG thực sự gửi giao dịch (tránh phải parse log sự kiện Transfer để suy ra id).
    const firstId = await nft.mint.staticCall(alice.address, "ipfs://house-1.json");
    expect(firstId).to.equal(0n);

    await nft.mint(alice.address, "ipfs://house-1.json");
    const secondId = await nft.mint.staticCall(alice.address, "ipfs://house-2.json");
    expect(secondId).to.equal(1n);
  });

  it("stores per-token metadata URI", async function () {
    const { nft, alice } = await deploy();
    await nft.mint(alice.address, "ipfs://house-1.json");
    expect(await nft.tokenURI(0)).to.equal("ipfs://house-1.json");
  });

  it("blocks non-owner from minting", async function () {
    const { nft, alice } = await deploy();
    await expect(
      nft.connect(alice).mint(alice.address, "ipfs://x.json")
    ).to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount");
  });

  it("assigns ownership of the minted token to the recipient", async function () {
    const { nft, alice } = await deploy();
    await nft.mint(alice.address, "ipfs://house-1.json");
    expect(await nft.ownerOf(0)).to.equal(alice.address);
  });
});
