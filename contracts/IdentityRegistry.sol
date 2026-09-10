// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

// Đây là bản rút gọn của "Identity Registry" trong chuẩn ERC-3643 thật (chuẩn đầy đủ có thêm
// claim topics, trusted issuers, on-chain KYC document...). Ở đây chỉ giữ phần cốt lõi nhất:
// 1 danh sách địa chỉ ví nào được coi là "đã xác minh" (verified/whitelisted), vì mục đích
// portfolio là chứng minh hiểu ĐÚNG cơ chế cốt lõi (permissioned transfer), không phải build
// lại toàn bộ hệ sinh thái Tokeny/ERC-3643 (việc đó vượt quá phạm vi 1 project cá nhân).
contract IdentityRegistry is Ownable {
    // mapping giống 1 "bảng băm" (hash table) lưu trên blockchain: tra cứu địa chỉ ví ->
    // true/false rất nhanh (O(1)), không cần duyệt qua danh sách như mảng (array).
    mapping(address => bool) private _verified;

    // "event" là cách contract "phát tín hiệu" ra ngoài (ghi vào log của giao dịch) mỗi khi
    // có gì đó xảy ra — không lưu vào storage (rẻ hơn nhiều so với biến state), nhưng
    // các ứng dụng off-chain (dashboard, subgraph...) có thể lắng nghe event này để cập nhật UI
    // real-time mà không cần liên tục hỏi lại contract.
    event Verified(address indexed account);
    event Unverified(address indexed account);

    // Ownable(msg.sender): người deploy contract này là admin duy nhất được quyền
    // thêm/xoá whitelist (mô phỏng vai trò "cơ quan cấp phép KYC" ngoài đời thật).
    constructor() Ownable(msg.sender) {}

    // Thêm 1 địa chỉ vào danh sách được phép nắm giữ/giao dịch token RWA.
    function verify(address account) external onlyOwner {
        _verified[account] = true;
        emit Verified(account);
    }

    // Gỡ 1 địa chỉ khỏi whitelist — ví dụ khi phát hiện vi phạm luật hoặc KYC hết hạn.
    function unverify(address account) external onlyOwner {
        _verified[account] = false;
        emit Unverified(account);
    }

    // "view": hàm chỉ đọc dữ liệu, không tốn gas khi gọi từ bên ngoài (off-chain).
    // Contract khác (MirruxRWAToken) sẽ gọi hàm này mỗi lần có giao dịch transfer để kiểm tra quyền.
    function isVerified(address account) external view returns (bool) {
        return _verified[account];
    }
}
