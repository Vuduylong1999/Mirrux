// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ERC721.sol: chuẩn NFT — mỗi token có 1 "id" duy nhất, KHÔNG thể chia nhỏ hay đổi ngang hàng
// với token khác (khác ERC-20, nơi 1 token giống hệt token khác cùng loại). Phù hợp đại diện
// 1 tài sản độc nhất, vd giấy chứng nhận sở hữu 1 căn nhà cụ thể.
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// ERC721URIStorage: extension cho phép GÁN RIÊNG 1 đường link metadata (tokenURI, thường trỏ tới
// file JSON mô tả tên/ảnh/thuộc tính) cho TỪNG token id — khác ERC721 gốc chỉ hỗ trợ 1 base URI
// dùng chung công thức cho mọi token. Cần thiết vì mỗi bất động sản có metadata khác nhau hẳn.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MirruxPropertyNFT is ERC721, ERC721URIStorage, Ownable {
    // Bộ đếm đơn giản để tự tăng id cho mỗi lần mint mới — không dùng thư viện Counters.sol
    // (đã bị OpenZeppelin xoá khỏi v5 vì 1 biến uint256 tự tăng là đủ, không cần trừu tượng hoá thêm).
    uint256 private _nextTokenId;

    constructor()
        ERC721("Mirrux Property", "mPROP")
        Ownable(msg.sender)
    {}

    // Chỉ owner (đại diện tổ chức phát hành/xác nhận pháp lý) được quyền mint ra 1 NFT bất động sản mới.
    // "uri": link tới file JSON mô tả tài sản (thường host trên IPFS để phi tập trung).
    function mint(address to, string memory uri) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        // _safeMint (thay vì _mint): kiểm tra thêm nếu "to" là 1 contract khác, contract đó phải
        // có hàm onERC721Received để xác nhận biết cách nhận NFT — tránh NFT bị "kẹt vĩnh viễn"
        // trong 1 contract không hỗ trợ ERC-721 (lỗi rất phổ biến nếu dùng _mint thường).
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    // 2 hàm dưới đây là bắt buộc phải override khi 1 contract kế thừa CẢ ERC721 và ERC721URIStorage,
    // vì cả 2 contract cha đều định nghĩa cùng tên hàm (tokenURI, supportsInterface) —
    // Solidity yêu cầu chỉ rõ contract con dùng phiên bản nào (ở đây gọi lại bản của URIStorage).
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // supportsInterface: cơ chế "khai báo" theo chuẩn ERC-165, giúp ví/sàn/marketplace tự động
    // nhận biết contract này có hỗ trợ ERC-721 hay không mà không cần đoán mò.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
