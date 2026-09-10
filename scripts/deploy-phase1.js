const hre = require("hardhat");
// Destructure sẵn "ethers" ra từ hre để đỡ gõ "hre.ethers" nhiều lần bên dưới.
const { ethers } = hre;

async function main() {
  // Bước 1: deploy MirruxToken trước, vì MirruxVault cần biết địa chỉ của nó ngay lúc khởi tạo.
  const Token = await ethers.getContractFactory("MirruxToken");
  const token = await Token.deploy(ethers.parseEther("1000"));
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("MirruxToken deployed to:", tokenAddress);

  // Bước 2: deploy MirruxVault, truyền địa chỉ token vừa deploy làm "asset" nền cho vault.
  const Vault = await ethers.getContractFactory("MirruxVault");
  const vault = await Vault.deploy(tokenAddress);
  await vault.waitForDeployment();
  console.log("MirruxVault deployed to:", await vault.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
