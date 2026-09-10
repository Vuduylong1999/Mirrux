// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// import: nạp code Solidity từ 1 file khác vào file này. Ở đây là 2 contract chuẩn của
// thư viện OpenZeppelin (đã được cộng đồng audit kỹ, dùng lại thay vì tự viết từ đầu để
// tránh bug bảo mật phổ biến).

// ERC20.sol: cài sẵn toàn bộ logic chuẩn ERC-20 (transfer, approve, balanceOf, totalSupply...).
// Không import cái này thì phải tự viết lại hàng trăm dòng logic transfer/allowance chuẩn,
// dễ sai và không tương thích với ví/sàn giao dịch khác (vốn đều mong đợi đúng chuẩn ERC-20).
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Ownable.sol: cung cấp sẵn cơ chế "chủ sở hữu" — 1 địa chỉ ví duy nhất (owner) được quyền
// gọi các hàm đánh dấu "onlyOwner". Không có cái này, ai cũng có thể gọi hàm mint() vô hạn,
// phá vỡ toàn bộ nguồn cung token.
import "@openzeppelin/contracts/access/Ownable.sol";

// "is ERC20, Ownable": contract này kế thừa (extends) cả 2 contract cha ở trên — giống
// implement nhiều interface/kế thừa nhiều class trong OOP.
contract MirruxToken is ERC20, Ownable {
    // constructor chạy 1 lần lúc deploy.
    // ERC20("Mirrux Token", "MRX"): gọi constructor của contract cha ERC20, đặt tên đầy đủ
    // và ký hiệu viết tắt (symbol) cho token — 2 giá trị này hiện lên ví MetaMask/explorer.
    // Ownable(msg.sender): gọi constructor của contract cha Ownable, đặt "msg.sender"
    // (địa chỉ ví đang gửi giao dịch deploy này) làm owner ban đầu.
    constructor(uint256 initialSupply) ERC20("Mirrux Token", "MRX") Ownable(msg.sender) {
        // _mint là hàm nội bộ (internal) có sẵn trong ERC20.sol, tạo ra "initialSupply" token
        // mới và cộng vào số dư của msg.sender. Đây là cách duy nhất token "xuất hiện" lần đầu.
        _mint(msg.sender, initialSupply);
    }

    // "external": hàm chỉ gọi được từ bên ngoài contract (qua giao dịch), không gọi được
    // từ nội bộ contract khác qua kế thừa — tiết kiệm gas hơn "public" 1 chút cho trường hợp này.
    // "onlyOwner": modifier từ Ownable.sol, tự động revert (huỷ giao dịch) nếu người gọi
    // không phải địa chỉ owner đã lưu — đây là chỗ chặn không cho ai cũng mint tuỳ ý.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Ai cũng gọi được (không có onlyOwner) vì đốt token của chính mình không ảnh hưởng ai khác.
    // _burn là hàm nội bộ trong ERC20.sol, trừ "amount" khỏi số dư msg.sender và giảm totalSupply.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
