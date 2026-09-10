// "expect" là hàm assertion của thư viện Chai (Behavior-Driven Testing), dùng để viết
// khẳng định kiểu "expect(giá trị).to.equal(giá trị mong muốn)".
const { expect } = require("chai");
// Lấy object "ethers" (nằm bên trong hre) trực tiếp — cách viết tắt phổ biến khi test,
// tương đương hre.ethers nhưng khỏi phải gõ "hre." mỗi lần.
const { ethers } = require("hardhat");

// "describe" nhóm các bài test lại theo tên (giống 1 "test suite"), giúp output test dễ đọc.
describe("MirruxToken", function () {
  // Hàm dùng chung để deploy 1 bản MirruxToken mới trước mỗi bài test — tránh việc các test
  // ảnh hưởng lẫn nhau (test A mint thêm token sẽ không làm sai kết quả test B).
  async function deploy() {
    // getSigners(): Hardhat tự tạo sẵn 20 ví ảo có sẵn ETH (chỉ tồn tại trong mạng test cục bộ,
    // không tốn phí, không liên quan gì tới ví MetaMask thật) để dùng làm các bên tham gia test.
    const [owner, alice] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MirruxToken");
    // parseEther("1000"): chuyển "1000" (dạng người đọc hiểu) thành số nguyên lớn có 18 chữ số 0
    // phía sau (đơn vị nhỏ nhất "wei" của token) — vì Solidity không có kiểu số thập phân,
    // mọi số tiền on-chain đều là số nguyên rất lớn, phải "nhân lên" theo quy ước 18 decimals.
    const token = await Token.deploy(ethers.parseEther("1000"));
    return { token, owner, alice };
  }

  // "it(...)" là 1 bài test cụ thể, mô tả bằng câu tiếng Anh ngắn gọn cho dễ đọc kết quả.
  it("mints initial supply to deployer", async function () {
    const { token, owner } = await deploy();
    // balanceOf(...) là hàm getter chuẩn ERC-20, đọc số dư token của 1 địa chỉ ví.
    expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("1000"));
  });

  it("lets owner mint more", async function () {
    const { token, owner, alice } = await deploy();
    await token.mint(alice.address, ethers.parseEther("50"));
    expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("50"));
  });

  it("blocks non-owner from minting", async function () {
    const { token, alice } = await deploy();
    // token.connect(alice): tạo ra 1 bản "kết nối" của contract nhưng ký giao dịch bằng ví alice
    // thay vì ví mặc định (owner) — mô phỏng việc "1 người khác không phải chủ sở hữu" gọi hàm.
    // "revertedWithCustomError": khẳng định giao dịch này PHẢI thất bại (revert) và đúng loại
    // lỗi tên "OwnableUnauthorizedAccount" (lỗi có sẵn trong contract Ownable.sol của OpenZeppelin).
    await expect(
      token.connect(alice).mint(alice.address, ethers.parseEther("1"))
    ).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
  });

  it("lets anyone burn their own tokens", async function () {
    const { token, owner } = await deploy();
    await token.burn(ethers.parseEther("100"));
    expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("900"));
  });
});
