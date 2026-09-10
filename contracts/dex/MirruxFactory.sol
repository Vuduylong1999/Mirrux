// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MirruxPair.sol";

// Factory chịu trách nhiệm TẠO MỚI 1 pool (MirruxPair) cho mỗi cặp token, và ghi nhớ lại
// địa chỉ pool đó để tra cứu sau này — giống 1 "sổ đăng ký" trung tâm cho toàn bộ sàn.
//
// Bản Uniswap V2 thật dùng "CREATE2" (deploy contract với địa chỉ tính được TRƯỚC, dựa theo salt)
// để bất kỳ ai cũng tính ra được địa chỉ pool mà không cần hỏi factory on-chain. Ở đây dùng
// "new MirruxPair(...)" thông thường (địa chỉ chỉ biết SAU khi deploy xong) cho đơn giản —
// vẫn đủ chức năng cho mục đích portfolio, chỉ khác ở việc client phải gọi getPair() để tra cứu
// thay vì tự tính offline.
contract MirruxFactory {
    // Tra cứu 2 chiều: getPair[tokenA][tokenB] và getPair[tokenB][tokenA] đều trỏ tới cùng 1 pool,
    // để người gọi không cần nhớ đúng thứ tự đã tạo pool lúc đầu.
    mapping(address => mapping(address => address)) public getPair;
    // Danh sách toàn bộ pool đã tạo — tiện cho việc liệt kê tất cả cặp giao dịch trên sàn (UI/subgraph).
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair);

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "MirruxFactory: identical addresses");
        // Sắp xếp lại theo thứ tự địa chỉ tăng dần (token0 < token1) — quy ước chuẩn của Uniswap,
        // đảm bảo dù người gọi truyền (A, B) hay (B, A) thì vẫn luôn tạo/tìm đúng 1 pool duy nhất.
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MirruxFactory: zero address");
        require(getPair[token0][token1] == address(0), "MirruxFactory: pair already exists");

        pair = address(new MirruxPair(token0, token1));

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair);
    }
}
