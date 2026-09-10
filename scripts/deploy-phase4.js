const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const Factory = await ethers.getContractFactory("MirruxFactory");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("MirruxFactory deployed to:", factoryAddress);

  // MirruxPair KHÔNG deploy tay ở đây — factory.createPair(...) sẽ tự "new MirruxPair(...)"
  // bên trong, ngay lần đầu ai đó gọi router.addLiquidity() cho 1 cặp token mới.
  const Router = await ethers.getContractFactory("MirruxRouter");
  const router = await Router.deploy(factoryAddress);
  await router.waitForDeployment();
  console.log("MirruxRouter deployed to:", await router.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
