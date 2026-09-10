// Script này CHỈ chạy được với "--network zkSyncSepolia", không dùng chung task "hardhat run"
// như các script Sepolia/Base Sepolia thường — phải chạy qua task riêng "deploy-zksync" mà
// plugin @matterlabs/hardhat-zksync cung cấp, vì luồng deploy zkSync cần ký giao dịch theo
// định dạng riêng (paymaster, factory deps cho contract...) mà ethers.js thường không biết.

const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");
const { Wallet } = require("zksync-ethers");

module.exports = async function (hre) {
  // Wallet ở đây KHÔNG phải "ethers.Wallet" thường, mà là bản mở rộng riêng của zksync-ethers,
  // biết cách ký đúng định dạng giao dịch zkSync (khác cấu trúc transaction chuẩn EVM 1 chút).
  const wallet = new Wallet(process.env.PRIVATE_KEY);
  // Deployer: helper của plugin, biết cách nạp artifact (bytecode đã biên dịch bằng zksolc)
  // và gửi giao dịch deploy đúng chuẩn zkSync.
  const deployer = new Deployer(hre, wallet);

  // loadArtifact tìm theo TÊN contract, không phải đường dẫn file — giống ethers.getContractFactory
  // ở luồng EVM thường, nhưng đọc từ thư mục artifacts-zk (do zksolc sinh ra, tách biệt hoàn toàn
  // với thư mục artifacts thường của solc, để không lẫn lộn 2 loại bytecode khác máy ảo).
  const artifact = await deployer.loadArtifact("MirruxToken");

  // Truyền dạng chuỗi (không phải BigInt) vào tham số constructor — plugin deploy của zkSync
  // ghi lại lịch sử deploy bằng JSON.stringify(), mà JSON không hỗ trợ serialize kiểu BigInt
  // (kiểu dữ liệu ethers.parseEther trả về), nên phải tự quy đổi ra chuỗi số nguyên trước.
  const initialSupply = hre.ethers.parseEther("1000").toString();
  const token = await deployer.deploy(artifact, [initialSupply]);
  await token.waitForDeployment();

  console.log("MirruxToken (zkSync Era Sepolia) deployed to:", await token.getAddress());
};
