const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MirruxAssetCollection", function () {
  async function deploy() {
    const [owner, alice] = await ethers.getSigners();
    const Collection = await ethers.getContractFactory("MirruxAssetCollection");
    const collection = await Collection.deploy("ipfs://mirrux/{id}.json");
    return { collection, owner, alice };
  }

  it("mints a given amount of a token id to an address", async function () {
    const { collection, alice } = await deploy();
    // "0x" là bytes rỗng — tham số "data" phụ của ERC-1155, không dùng tới nên để trống.
    await collection.mint(alice.address, 1, 500, "0x");
    // balanceOf ở ERC-1155 cần 2 tham số (địa chỉ + id token), khác ERC-20/721 chỉ cần địa chỉ,
    // vì 1 địa chỉ có thể giữ số lượng khác nhau của NHIỀU loại id cùng lúc.
    expect(await collection.balanceOf(alice.address, 1)).to.equal(500n);
  });

  it("mints multiple token ids in a single batch transaction", async function () {
    const { collection, alice } = await deploy();
    await collection.mintBatch(alice.address, [1, 2], [100, 200], "0x");
    expect(await collection.balanceOf(alice.address, 1)).to.equal(100n);
    expect(await collection.balanceOf(alice.address, 2)).to.equal(200n);
  });

  it("blocks non-owner from minting", async function () {
    const { collection, alice } = await deploy();
    await expect(
      collection.connect(alice).mint(alice.address, 1, 10, "0x")
    ).to.be.revertedWithCustomError(collection, "OwnableUnauthorizedAccount");
  });
});
