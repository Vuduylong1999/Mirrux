const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MirruxVault", function () {
  async function deploy() {
    const [owner, alice] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MirruxToken");
    const token = await Token.deploy(ethers.parseEther("1000"));

    const Vault = await ethers.getContractFactory("MirruxVault");
    // getAddress() trả về địa chỉ (0x...) của contract "token" vừa deploy, để truyền vào
    // constructor của MirruxVault (tham số "asset" — vault cần biết địa chỉ token nó sẽ giữ hộ).
    const vault = await Vault.deploy(await token.getAddress());

    // Chuyển 200 token từ owner sang alice để alice có "vốn" đem gửi vào vault trong các test dưới.
    await token.transfer(alice.address, ethers.parseEther("200"));
    // approve(...): chuẩn ERC-20 yêu cầu chủ token phải "cho phép" (approve) 1 địa chỉ khác
    // được rút token thay mình TRƯỚC KHI địa chỉ đó gọi transferFrom. Vault gọi transferFrom
    // ngầm bên trong hàm deposit(), nên nếu thiếu approve() này, deposit sẽ bị revert.
    // ethers.MaxUint256: cho phép rút không giới hạn, tránh phải approve lại nhiều lần trong test.
    await token.connect(alice).approve(await vault.getAddress(), ethers.MaxUint256);

    return { token, vault, owner, alice };
  }

  it("deposits underlying and mints shares 1:1 initially", async function () {
    const { vault, alice } = await deploy();
    // deposit(số lượng asset, địa chỉ nhận share): hàm chuẩn ERC-4626, chuyển "asset" (MRX)
    // từ alice vào vault, rồi mint ra số "share" (vMRX) tương ứng, gửi cho alice.
    await vault.connect(alice).deposit(ethers.parseEther("100"), alice.address);
    expect(await vault.balanceOf(alice.address)).to.equal(ethers.parseEther("100"));
  });

  it("withdraws back the deposited amount", async function () {
    const { vault, alice } = await deploy();
    await vault.connect(alice).deposit(ethers.parseEther("100"), alice.address);
    // redeem(số lượng share muốn đổi, người nhận asset, chủ sở hữu share):
    // ngược lại với deposit — đốt share (vMRX) của alice, trả lại asset (MRX) tương ứng cho alice.
    await vault.connect(alice).redeem(ethers.parseEther("100"), alice.address, alice.address);
    // "0n": số 0 dạng BigInt — ethers v6 dùng kiểu BigInt của JavaScript cho mọi số on-chain
    // (vì số on-chain có thể lớn hơn giới hạn Number thường của JS).
    expect(await vault.balanceOf(alice.address)).to.equal(0n);
  });

  it("increases share value when yield is donated to the vault", async function () {
    const { token, vault, owner, alice } = await deploy();
    await vault.connect(alice).deposit(ethers.parseEther("100"), alice.address);

    // Mô phỏng "sinh lãi": không cần viết thêm logic gì trong contract — vì ERC4626 tính tỷ giá
    // share/asset dựa trên "tổng số asset vault đang giữ / tổng số share đã phát hành", nên chỉ
    // cần ai đó chuyển thẳng thêm token vào địa chỉ vault (không qua deposit chính thức),
    // tổng tài sản tăng lên trong khi tổng share không đổi → tỷ giá tăng → ai đang giữ share cũ
    // tự động lời thêm, y hệt cơ chế "lãi tích luỹ" của các vault DeFi thật ngoài đời.
    await token.transfer(await vault.getAddress(), ethers.parseEther("50"));

    const shares = await vault.balanceOf(alice.address);
    // convertToAssets(shares): hỏi vault "số share này hiện quy đổi ra bao nhiêu asset".
    const assetsNow = await vault.convertToAssets(shares);
    // OZ's virtual-shares rounding (anti-inflation-attack) can round down by 1 wei
    // (Cơ chế "virtual shares" của OpenZeppelin chống tấn công thao túng tỷ giá lúc vault mới
    // tạo, có thể làm tròn xuống lệch 1 đơn vị nhỏ nhất — đây là hành vi đúng theo thiết kế,
    // không phải bug, nên test chấp nhận sai lệch tối đa 1 wei).
    expect(assetsNow).to.be.closeTo(ethers.parseEther("150"), 1n);
  });
});
