// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// IAccount: interface chuẩn ERC-4337 — bất kỳ "ví hợp đồng" (smart contract wallet) nào muốn
// tương thích với hệ sinh thái Account Abstraction (bundler, paymaster...) đều phải implement
// đúng interface này, để 1 contract trung gian tên "EntryPoint" biết cách gọi vào ví kiểm tra
// chữ ký hợp lệ hay không.
import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
// Helpers.sol định nghĩa sẵn 2 hằng số quy ước của chuẩn ERC-4337:
// SIG_VALIDATION_SUCCESS (0) và SIG_VALIDATION_FAILED (1) — validateUserOp phải trả về đúng
// 1 trong 2 giá trị này (hoặc revert cho lỗi khác) để EntryPoint hiểu đúng kết quả kiểm tra.
import "@account-abstraction/contracts/core/Helpers.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Đây là bản "ví hợp đồng" (smart contract account) tối giản theo chuẩn ERC-4337 — khác ví
// thường (Externally Owned Account/EOA như MetaMask, chỉ điều khiển được bằng 1 private key
// duy nhất), ví này LÀ MỘT CONTRACT, cho phép tuỳ biến cách xác thực giao dịch (ở đây vẫn dùng
// chữ ký ECDSA của 1 owner, nhưng có thể mở rộng thành đa chữ ký, sinh trắc học, trả gas bằng
// token khác... mà không cần đổi hạ tầng ví).
//
// Luồng hoạt động thực tế (không diễn ra trong repo này, cần hạ tầng "bundler" riêng):
// 1. Người dùng ký 1 "UserOperation" (không phải giao dịch thường) bằng key của owner.
// 2. Gửi UserOperation đó cho 1 "bundler" (dịch vụ off-chain, vd Alchemy/Stackup) thay vì gửi
//    thẳng lên mạng như giao dịch thường.
// 3. Bundler gói nhiều UserOperation lại, gửi 1 giao dịch thật duy nhất tới EntryPoint.
// 4. EntryPoint (contract chuẩn, cùng địa chỉ trên mọi mạng) gọi validateUserOp() của TỪNG ví
//    liên quan để xác thực, rồi mới thực thi lệnh thật (execute()).
contract MirruxSmartAccount is IAccount {
    using ECDSA for bytes32;

    // entryPoint: địa chỉ contract EntryPoint chuẩn — đây LÀ hạ tầng dùng chung của toàn hệ sinh
    // thái ERC-4337 (không phải Mirrux tự deploy), mọi ví tương thích ERC-4337 đều trỏ về cùng
    // 1 (hoặc vài) địa chỉ EntryPoint cố định trên mỗi mạng.
    address public immutable entryPoint;
    // owner: địa chỉ ví EOA thật (vd MetaMask) có quyền ký lệnh cho smart account này hoạt động.
    address public owner;

    // Chặn không cho ai khác ngoài EntryPoint gọi các hàm nhạy cảm — vì EntryPoint đã tự kiểm tra
    // đúng chuẩn (nonce, gas, chống replay...) trước khi gọi vào đây, gọi trực tiếp bỏ qua
    // EntryPoint sẽ phá vỡ toàn bộ các lớp bảo vệ đó.
    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "MirruxSmartAccount: not from EntryPoint");
        _;
    }

    constructor(address _entryPoint, address _owner) {
        entryPoint = _entryPoint;
        owner = _owner;
    }

    // Hàm lõi mà chuẩn ERC-4337 bắt buộc phải có — EntryPoint gọi vào đây để hỏi "chữ ký này
    // có hợp lệ không". "calldata" (thay vì memory) cho tham số struct lớn giúp tiết kiệm gas,
    // vì dữ liệu được đọc thẳng từ input giao dịch, không copy vào bộ nhớ tạm trước.
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        // toEthSignedMessageHash: bọc thêm tiền tố "\x19Ethereum Signed Message:\n32" trước khi
        // hash — đây là quy ước chuẩn để chữ ký tạo bởi ví (MetaMask, ethers.js) khớp với cách
        // verify on-chain, tránh 1 chữ ký bị dùng sai ngữ cảnh (vd giả làm giao dịch thường).
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        // recover: từ (hash, chữ ký) suy ngược ra địa chỉ ví đã ký — không cần biết trước public
        // key, đây chính là cơ chế lõi giúp Ethereum xác thực chữ ký ECDSA.
        address recovered = hash.recover(userOp.signature);

        // Trả về đúng 1 trong 2 hằng số quy ước — KHÔNG revert khi chữ ký sai, vì bundler cần
        // gọi hàm này ở chế độ "mô phỏng" (không có chữ ký thật) để ước tính gas trước khi gửi
        // giao dịch thật; nếu revert thì bundler không mô phỏng được.
        validationData = recovered == owner ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;

        // Nếu smart account chưa nạp đủ ETH cho EntryPoint để trả gas trước, phải tự động
        // chuyển phần còn thiếu ("missingAccountFunds") sang cho EntryPoint (msg.sender lúc này
        // chính là EntryPoint, nhờ modifier onlyEntryPoint đã đảm bảo ở trên).
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            // Không require(success) ở đây theo đúng khuyến nghị chuẩn ERC-4337: nếu trả gas
            // thất bại, EntryPoint tự biết cách xử lý (huỷ cả UserOperation) mà không cần
            // account tự revert, tránh 1 lỗi nhỏ ở bước phụ này chặn luôn cả bước xác thực chữ ký.
            success;
        }
    }

    // execute: hàm THỰC SỰ làm việc (gọi sang 1 contract khác thay mặt owner) — chỉ chạy được
    // SAU KHI validateUserOp() đã xác nhận chữ ký hợp lệ, và cũng chỉ EntryPoint được gọi vào đây.
    function execute(address target, uint256 value, bytes calldata data) external onlyEntryPoint {
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, string(result));
    }

    // Cho phép smart account này NHẬN ETH trực tiếp (vd để tự nạp gas cho EntryPoint, hoặc nhận
    // tiền từ người khác) — thiếu hàm receive() thì mọi giao dịch gửi ETH thẳng vào địa chỉ này
    // sẽ bị revert.
    receive() external payable {}
}
