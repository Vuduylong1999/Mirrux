const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const NFT = await ethers.getContractFactory("MirruxPropertyNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  console.log("MirruxPropertyNFT deployed to:", await nft.getAddress());

  const Collection = await ethers.getContractFactory("MirruxAssetCollection");
  const collection = await Collection.deploy("ipfs://mirrux/{id}.json");
  await collection.waitForDeployment();
  console.log("MirruxAssetCollection deployed to:", await collection.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
