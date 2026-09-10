// require(...) là cú pháp Node.js để nạp 1 thư viện đã cài (nằm trong node_modules).
// "@nomicfoundation/hardhat-toolbox" là bộ plugin trọn gói của Hardhat: gồm ethers.js (thư viện
// giao tiếp với blockchain), Chai matcher cho test, plugin verify contract lên Etherscan, v.v.
// Không require dòng này thì các lệnh như hre.ethers, hardhat-verify, hardhat test sẽ không hoạt động.
require("@nomicfoundation/hardhat-toolbox");

// dotenv đọc file .env ở thư mục gốc và nạp các biến trong đó vào process.env (biến môi trường của Node).
// Mục đích: giữ private key / API key ngoài source code (file .env đã bị .gitignore chặn không commit lên git).
require("dotenv").config();

// Lấy từng biến môi trường ra thành hằng số JS để dùng bên dưới cho gọn.
const { SEPOLIA_RPC_URL, BASE_SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

// Dòng comment kiểu /** @type ... */ này là JSDoc, chỉ giúp VSCode gợi ý (autocomplete) các field
// hợp lệ của object config bên dưới — không ảnh hưởng lúc chạy code.
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Cấu hình trình biên dịch Solidity.
  solidity: {
    version: "0.8.24", // phiên bản compiler Solidity — phải khớp với "pragma solidity" khai báo trong các file .sol
    settings: {
      // optimizer: bật tối ưu hoá bytecode để tiết kiệm gas khi contract chạy trên mạng thật.
      // "runs: 200" là số lần ước tính contract sẽ được gọi trong vòng đời của nó — con số Hardhat khuyến nghị mặc định,
      // ảnh hưởng cách compiler cân bằng giữa "code nhỏ, deploy rẻ" và "code chạy nhanh, gọi hàm rẻ".
      optimizer: { enabled: true, runs: 200 },
      // evmVersion: chọn "phiên bản" của máy ảo EVM để biên dịch bytecode tương thích.
      // OpenZeppelin v5.6 dùng opcode "mcopy" (chỉ có từ bản nâng cấp Cancun của Ethereum),
      // nếu để evmVersion cũ hơn (vd "paris") thì compile sẽ báo lỗi "mcopy not found".
      evmVersion: "cancun",
    },
  },
  // Khai báo các mạng blockchain mà Hardhat có thể kết nối tới khi chạy lệnh --network <tên>.
  networks: {
    sepolia: {
      // url: địa chỉ RPC node (do Alchemy cung cấp) — đây là "cổng" để Hardhat gửi giao dịch lên mạng Sepolia thật.
      url: SEPOLIA_RPC_URL || "",
      // accounts: danh sách private key dùng để ký giao dịch. Ở đây chỉ có 1 ví, để trong mảng vì Hardhat
      // cho phép cấu hình nhiều ví cùng lúc (accounts[0], accounts[1], ...).
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      // chainId: mã định danh duy nhất của mạng Sepolia trên toàn hệ sinh thái Ethereum, dùng để
      // tránh nhầm lẫn/replay giao dịch giữa các mạng khác nhau.
      chainId: 11155111,
    },
    baseSepolia: {
      url: BASE_SEPOLIA_RPC_URL || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 84532,
    },
  },
  // Cấu hình cho plugin hardhat-verify (nằm trong toolbox) để tự động verify source code
  // lên block explorer sau khi deploy. Etherscan API v2 dùng chung 1 API key cho mọi chain
  // (Sepolia, Base Sepolia...) thay vì phải xin riêng từng site như trước.
  etherscan: {
    apiKey: ETHERSCAN_API_KEY || "",
  },
};
