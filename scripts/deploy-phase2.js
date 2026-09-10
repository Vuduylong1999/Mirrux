const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  // Bước 1: deploy registry trước — token cần địa chỉ registry ngay lúc khởi tạo.
  const Registry = await ethers.getContractFactory("IdentityRegistry");
  const registry = await Registry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("IdentityRegistry deployed to:", registryAddress);

  // Lấy ví đang deploy (chính là "signer" mặc định, ký bằng PRIVATE_KEY trong .env).
  const [deployer] = await ethers.getSigners();

  // Bước 2: tự whitelist ví của mình TRƯỚC khi deploy token, vì token sẽ mint ngay cho ví này
  // trong constructor — thiếu bước verify() này thì giao dịch deploy sẽ revert (thất bại).
  const verifyTx = await registry.verify(deployer.address);
  await verifyTx.wait();
  console.log("Deployer whitelisted:", deployer.address);

  // Bước 3: deploy token RWA, gắn với registry vừa tạo.
  const Token = await ethers.getContractFactory("MirruxRWAToken");
  const token = await Token.deploy(registryAddress, ethers.parseEther("1000"));
  await token.waitForDeployment();
  console.log("MirruxRWAToken deployed to:", await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
