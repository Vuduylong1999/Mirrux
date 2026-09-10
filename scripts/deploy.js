// "hre" = Hardhat Runtime Environment: object toàn cục chứa mọi thứ Hardhat cung cấp
// (ethers, network hiện tại, config...). Khi require("hardhat"), Hardhat tự đọc file
// hardhat.config.js ở thư mục gốc, dựng lên object hre này dựa theo config đó (network nào
// đang chọn qua flag --network, solidity version nào, v.v.) rồi trả về cho mình dùng.
// Nói cách khác: "hardhat" ở đây không phải 1 thư viện tĩnh, mà là runtime được nạp cấu hình
// động từ hardhat.config.js ngay lúc require.
const hre = require("hardhat");

async function main() {
  // getContractFactory("Greeter"): tìm trong artifacts (thư mục Hardhat tự sinh ra sau khi compile)
  // bytecode + ABI của contract tên "Greeter", rồi bọc lại thành 1 "factory" (nhà máy) —
  // 1 object JS biết cách tạo ra instance của contract đó trên blockchain.
  const Greeter = await hre.ethers.getContractFactory("Greeter");

  // .deploy(...) gọi hàm constructor của contract, tạo 1 giao dịch (transaction) gửi bytecode
  // lên mạng đang chọn (qua RPC URL trong hardhat.config.js). Tham số truyền vào đây khớp
  // với tham số của constructor trong Greeter.sol.
  const greeter = await Greeter.deploy("Mirrux Phase 0 OK");

  // waitForDeployment(): giao dịch deploy cần được mạng "đào" (mine) vào 1 block mới được coi
  // là hoàn tất. Dòng này chờ cho tới khi block đó được xác nhận, tránh trường hợp đọc địa chỉ
  // contract quá sớm khi giao dịch chưa thực sự lên chain.
  await greeter.waitForDeployment();

  // getAddress(): trả về địa chỉ (0x...) mà contract vừa được cấp trên blockchain — địa chỉ này
  // cố định vĩnh viễn, ai cũng tra được trên block explorer (Etherscan).
  console.log("Greeter deployed to:", await greeter.getAddress());
}

// Script chạy 1 lần rồi thoát. Nếu có lỗi (vd hết gas, network lỗi), in lỗi ra và thoát với
// exit code 1 để báo cho hệ thống/CI biết script chạy thất bại.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
