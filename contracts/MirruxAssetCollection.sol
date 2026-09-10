// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ERC1155.sol: chuẩn "lai" giữa ERC-20 và ERC-721 — 1 CONTRACT DUY NHẤT quản lý được nhiều
// "loại" token khác nhau (mỗi loại có 1 "id" riêng), và mỗi loại lại có thể có số lượng > 1
// (giống ERC-20, có thể chia phần), khác ERC-721 (mỗi id chỉ tồn tại đúng 1 bản duy nhất).
// Hợp lý để đại diện "1 tài sản chia thành N phần bằng nhau" — vd 1 quỹ đầu tư chia 1000 suất góp vốn,
// tất cả cùng 1 loại (cùng id) nhưng ai cũng có thể giữ nhiều suất.
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MirruxAssetCollection is ERC1155, Ownable {
    // "uri_": ERC-1155 dùng 1 công thức chung cho mọi id (thường chứa "{id}" để client tự thay
    // bằng id thật khi tra cứu metadata) — khác ERC-721 phải lưu URI riêng cho từng token.
    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    // mint 1 loại tài sản (id) với số lượng "amount" phần, gửi cho "to".
    // "bytes memory data": tham số phụ theo chuẩn ERC-1155 (thường để rỗng "0x"), cho phép gửi kèm
    // dữ liệu tuỳ ý tới hàm callback của người nhận nếu người nhận là contract.
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    // mintBatch: tạo NHIỀU loại id cùng lúc trong 1 giao dịch duy nhất — tiết kiệm gas hơn nhiều
    // so với gọi mint() lặp lại từng id một (mỗi giao dịch đều tốn phí cố định "base gas").
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }
}
