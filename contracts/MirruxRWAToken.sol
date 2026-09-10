// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IdentityRegistry.sol";

// Token đại diện quyền sở hữu 1 tài sản thật (RWA — Real World Asset, vd bất động sản, trái phiếu).
// Khác ERC-20 thường ở chỗ: không phải ai cũng được giữ/giao dịch token này — chỉ những địa chỉ
// đã được xác minh (KYC) trong IdentityRegistry mới được phép, để tuân theo luật chứng khoán/tài sản.
contract MirruxRWAToken is ERC20, Ownable {
    // "immutable": giá trị chỉ được gán 1 lần trong constructor, sau đó không đổi được nữa.
    // Compiler lưu giá trị này thẳng vào bytecode (không phải slot storage), nên đọc rẻ hơn
    // nhiều so với 1 biến state thường — hợp lý vì địa chỉ registry là cấu hình cố định lúc deploy,
    // không có lý do gì phải đổi sau này (nếu cần đổi, nên deploy token mới với registry mới).
    IdentityRegistry public immutable registry;

    constructor(IdentityRegistry _registry, uint256 initialSupply)
        ERC20("Mirrux RWA Token", "mRWA")
        Ownable(msg.sender)
    {
        registry = _registry;
        // Chủ deploy phải tự whitelist mình trước (ở ngoài, gọi registry.verify(...)) TRƯỚC KHI
        // gọi constructor này, nếu không dòng _mint bên dưới sẽ revert vì chưa được xác minh.
        _mint(msg.sender, initialSupply);
    }

    // _update là "hook" nội bộ mà OpenZeppelin ERC20 (bản v5) gọi ngầm ở MỌI thao tác thay đổi
    // số dư: transfer, transferFrom, _mint, _burn đều đi qua đúng 1 hàm này ở tầng thấp nhất.
    // Ghi đè (override) hàm này là cách "chèn" thêm điều kiện kiểm tra whitelist vào TẤT CẢ
    // các luồng đó cùng lúc, thay vì phải tự viết lại từng hàm transfer/transferFrom riêng lẻ
    // (viết riêng dễ sót 1 luồng, tạo lỗ hổng bỏ qua whitelist).
    function _update(address from, address to, uint256 value) internal override {
        // from == address(0) nghĩa là đây là lệnh MINT (tạo token mới, không có "người gửi" thật).
        // Chỉ cần kiểm tra người NHẬN (to) đã whitelist chưa.
        if (from != address(0)) {
            require(registry.isVerified(from), "MirruxRWAToken: sender not verified");
        }
        // to == address(0) nghĩa là lệnh BURN (đốt token, không có "người nhận" thật).
        if (to != address(0)) {
            require(registry.isVerified(to), "MirruxRWAToken: recipient not verified");
        }
        // super._update(...): sau khi kiểm tra xong, gọi lại logic gốc của OpenZeppelin để
        // thực sự cập nhật số dư — không gọi dòng này thì số dư sẽ không bao giờ thay đổi.
        super._update(from, to, value);
    }
}
