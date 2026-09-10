// require(...) là cú pháp Node.js để nạp 1 thư viện đã cài (nằm trong node_modules).
// "@nomicfoundation/hardhat-toolbox" là bộ plugin trọn gói của Hardhat: gồm ethers.js (thư viện
// giao tiếp với blockchain), Chai matcher cho test, plugin verify contract lên Etherscan, v.v.
// Không require dòng này thì các lệnh như hre.ethers, hardhat-verify, hardhat test sẽ không hoạt động.
require("@nomicfoundation/hardhat-toolbox");
// Plugin riêng của Matter Labs (đội phát triển zkSync) — dạy Hardhat cách biên dịch contract
// bằng "zksolc" (1 compiler riêng, KHÁC solc thường) và cách deploy/verify đúng định dạng giao
// dịch mà mạng zkSync Era yêu cầu (khác cấu trúc giao dịch chuẩn Ethereum ở vài chỗ nội bộ).
require("@matterlabs/hardhat-zksync");

// dotenv đọc file .env ở thư mục gốc và nạp các biến trong đó vào process.env (biến môi trường của Node).
// Mục đích: giữ private key / API key ngoài source code (file .env đã bị .gitignore chặn không commit lên git).
require("dotenv").config();

// Lấy từng biến môi trường ra thành hằng số JS để dùng bên dưới cho gọn.
const { SEPOLIA_RPC_URL, BASE_SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

// Dòng comment kiểu /** @type ... */ này là JSDoc, chỉ giúp VSCode gợi ý (autocomplete) các field
// hợp lệ của object config bên dưới — không ảnh hưởng lúc chạy code.
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // zksolc: cấu hình compiler riêng cho zkSync — mạng này chạy trên 1 loại máy ảo khác EVM
  // thường (gọi là zkEVM), nên bytecode Solidity thường KHÔNG chạy được thẳng trên đó.
  // zksolc biên dịch lại source code Solidity y hệt (không cần sửa file .sol nào) thành
  // bytecode tương thích zkEVM — đây chính là điểm khác biệt lớn nhất so với deploy lên
  // Sepolia/Base Sepolia (2 mạng đó dùng EVM chuẩn, chỉ cần solc thường).
  zksolc: {
    // Node.js bản mới (v24+) có lỗi tương thích với cơ chế tự tải zksolc của plugin
    // ("maxRedirections is not supported"), nên trỏ thẳng vào binary đã tải sẵn thủ công
    // (v1.5.7) thay vì để plugin tự tải qua mạng — khi dùng compilerPath thì KHÔNG được khai
    // báo "version" nữa, vì bản thân file binary đã ngầm định phiên bản rồi.
    compilerSource: "binary",
    settings: {
      // path.join(__dirname, ...) tạo ra 1 absolute path đúng định dạng hệ điều hành đang chạy
      // (dùng "\\" trên Windows, "/" trên Linux/Mac) — bắt buộc phải absolute vì compilerPath
      // được nối thẳng vào 1 dòng lệnh chạy qua cmd.exe (Windows), mà cmd.exe không hiểu cú
      // pháp relative path kiểu Unix ("./...").
      compilerPath: require("path").join(__dirname, ".zksolc-bin", "zksolc-v1.5.7.exe"),
    },
  },
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
      // viaIR: bật pipeline biên dịch mới (qua bước trung gian "Yul IR") thay vì sinh bytecode
      // trực tiếp — cần thiết vì MirruxRouter.swapExactTokensForTokens() có quá nhiều biến local
      // cùng lúc, vượt quá 16 "slot" mà EVM cho phép ở chế độ biên dịch cũ ("stack too deep").
      viaIR: true,
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
    zkSyncSepolia: {
      // RPC công khai chính thức của zkSync Era Sepolia testnet — không cần Alchemy/Infura riêng.
      url: "https://sepolia.era.zksync.dev",
      // ethNetwork: zkSync là 1 "Layer 2", mọi giao dịch cuối cùng đều được "chốt" (settle) lại
      // trên 1 mạng Layer 1 tương ứng — khai báo rõ L1 đó là Sepolia (không phải Ethereum mainnet)
      // để plugin biết dùng đúng testnet khi cần đối chiếu 2 tầng.
      ethNetwork: "sepolia",
      // zksync: true là cờ BẮT BUỘC để Hardhat biết mạng này cần dùng zksolc + luồng giao dịch
      // đặc thù của zkSync thay vì luồng EVM thường (khác hẳn Sepolia/Base Sepolia ở trên).
      zksync: true,
      chainId: 300,
      // verifyURL: địa chỉ API riêng của block explorer zkSync (không phải Etherscan) để plugin
      // gửi source code lên verify sau khi deploy.
      verifyURL: "https://explorer.sepolia.era.zksync.dev/contract_verification",
    },
  },
  // Cấu hình cho plugin hardhat-verify (nằm trong toolbox) để tự động verify source code
  // lên block explorer sau khi deploy. Etherscan API v2 dùng chung 1 API key cho mọi chain
  // (Sepolia, Base Sepolia...) thay vì phải xin riêng từng site như trước.
  etherscan: {
    apiKey: ETHERSCAN_API_KEY || "",
  },
};
