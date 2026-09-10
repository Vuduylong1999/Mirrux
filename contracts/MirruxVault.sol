// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ERC4626.sol: chuẩn "tokenized vault" của OpenZeppelin — cài sẵn toàn bộ logic deposit/withdraw/
// mint/redeem, cách tính tỷ lệ share/asset, và cả cơ chế chống "inflation attack" (kẻ tấn công
// gửi thẳng token vào contract để thao túng tỷ giá share, gây thiệt hại cho người gửi tiền
// đầu tiên). Không import cái này thì phải tự viết công thức đổi share <-> asset và tự vá
// từng lỗ hổng bảo mật đó — rất dễ sai.
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

// IERC20.sol: chỉ là "interface" (bản khai báo hàm, không có logic) của chuẩn ERC-20.
// Dùng để khai báo tham số "asset" có kiểu là "1 địa chỉ contract nào đó tuân theo chuẩn ERC-20",
// mà không cần quan tâm nó cụ thể là contract gì (ở đây sẽ là MirruxToken).
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ERC4626 tự nó đã là 1 loại token ERC-20 đặc biệt (gọi là "share token" — đại diện phần vốn
// góp vào vault), nên contract này chỉ cần kế thừa ERC4626 (đã bao gồm ERC20 bên trong).
contract MirruxVault is ERC4626 {
    // "asset" là contract token gốc mà vault này sẽ giữ hộ (ở đây sẽ truyền vào là MirruxToken).
    constructor(IERC20 asset)
        // ERC4626(asset): báo cho vault biết "tài sản nền" của nó là token nào.
        ERC4626(asset)
        // ERC20(...): vault cũng phát hành ra 1 loại token riêng gọi là "share" (vMRX) —
        // mỗi khi ai gửi MirruxToken vào vault, họ nhận lại vMRX đại diện phần vốn góp,
        // và có thể đổi lại MRX (kèm lãi nếu có) bất cứ lúc nào bằng cách redeem share đó.
        ERC20("Mirrux Vault Share", "vMRX")
    {}
    // Constructor body để trống vì mọi logic khởi tạo cần thiết đã nằm trong 2 lời gọi
    // constructor cha (ERC4626 và ERC20) ở trên rồi — không cần viết gì thêm.
}
