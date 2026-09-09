const hre = require("hardhat");

async function main() {
  const Greeter = await hre.ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("Mirrux Phase 0 OK");
  await greeter.waitForDeployment();
  console.log("Greeter deployed to:", await greeter.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
