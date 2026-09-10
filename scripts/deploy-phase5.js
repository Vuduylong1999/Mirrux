const hre = require("hardhat");
const { ethers } = hre;

// Địa chỉ EntryPoint v0.7 CHUẨN CHUNG của toàn hệ sinh thái ERC-4337 — được Ethereum Foundation
// deploy theo cơ chế "deterministic deployment" (cùng 1 địa chỉ trên MỌI mạng EVM tương thích,
// gồm cả Sepolia). Mirrux KHÔNG tự deploy contract này, chỉ trỏ smart account của mình vào đó.
const ENTRY_POINT_V07 = "0x0000000071727De22E5E9d8BAf0edAc6f37da032";

async function main() {
  const [deployer] = await ethers.getSigners();

  const Account = await ethers.getContractFactory("MirruxSmartAccount");
  // owner = chính ví đang deploy, để tao có thể tự ký UserOperation demo sau này nếu cần.
  const account = await Account.deploy(ENTRY_POINT_V07, deployer.address);
  await account.waitForDeployment();
  console.log("MirruxSmartAccount deployed to:", await account.getAddress());
  console.log("Using EntryPoint:", ENTRY_POINT_V07);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
