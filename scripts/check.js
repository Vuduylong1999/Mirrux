const hre = require("hardhat");

async function main() {
  // getContractAt(tên contract, địa chỉ): KHÔNG deploy gì mới, chỉ "trỏ" vào 1 contract
  // đã tồn tại sẵn trên blockchain ở địa chỉ chỉ định, dùng ABI của "Greeter" để biết
  // contract đó có những hàm gì mà gọi cho đúng.
  const greeter = await hre.ethers.getContractAt("Greeter", "0x263E63e9D090238301738d97ca2451a147e810C0");

  // Gọi hàm "greeting()" — đây là hàm getter tự sinh từ biến "public string greeting" trong Greeter.sol.
  // Vì đây là hàm "view" (chỉ đọc, không ghi dữ liệu), nó KHÔNG tốn gas và không cần ký giao dịch,
  // chỉ là 1 lệnh gọi (call) hỏi trực tiếp node RPC trả lời ngay lập tức.
  console.log("On-chain greeting value:", await greeter.greeting());
}
main();
