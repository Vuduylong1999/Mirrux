// SPDX-License-Identifier: MIT
// Dòng trên là khai báo giấy phép mã nguồn (bắt buộc theo convention của Solidity compiler,
// thiếu dòng này compiler vẫn chạy nhưng sẽ cảnh báo warning). MIT = ai cũng được dùng lại code tự do.

// "pragma" là chỉ thị cho trình biên dịch (compiler), không phải code thực thi.
// "pragma solidity ^0.8.24" nghĩa là: file này yêu cầu compiler bản 0.8.24 trở lên,
// dấu ^ cho phép các bản vá nhỏ hơn (0.8.25, 0.8.26...) nhưng KHÔNG cho phép nhảy lên 0.9.x
// (vì 0.9 có thể phá vỡ cú pháp/logic tương thích ngược). Nếu thiếu dòng này, compiler
// sẽ từ chối biên dịch vì không biết dùng luật ngữ pháp/ngữ nghĩa của phiên bản nào.
pragma solidity ^0.8.24;

// "contract" giống "class" trong lập trình hướng đối tượng, nhưng khi deploy lên blockchain
// nó trở thành 1 chương trình độc lập có địa chỉ riêng, chạy trên EVM (Ethereum Virtual Machine).
contract Greeter {
    // "public" tự động sinh ra 1 hàm getter tên "greeting()" để đọc giá trị từ bên ngoài (miễn phí, không tốn gas)
    // mà không cần tự viết hàm get. Biến này được lưu vĩnh viễn trên blockchain (gọi là "storage").
    string public greeting;

    // "constructor" là hàm chỉ chạy đúng 1 lần, ngay lúc contract được deploy — dùng để khởi tạo giá trị ban đầu.
    // "memory" nghĩa là tham số này chỉ tồn tại tạm thời trong bộ nhớ lúc thực thi hàm, không lưu vào storage.
    constructor(string memory _greeting) {
        greeting = _greeting;
    }
}
