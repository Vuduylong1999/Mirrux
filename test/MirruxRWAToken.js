const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MirruxRWAToken", function () {
  async function deploy() {
    const [owner, alice, bob] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("IdentityRegistry");
    const registry = await Registry.deploy();

    // Whitelist owner TRƯỚC khi deploy token, vì constructor của MirruxRWAToken sẽ _mint
    // cho owner ngay lập tức — nếu owner chưa được xác minh, dòng mint đó sẽ revert.
    await registry.verify(owner.address);

    const Token = await ethers.getContractFactory("MirruxRWAToken");
    const token = await Token.deploy(await registry.getAddress(), ethers.parseEther("1000"));

    return { registry, token, owner, alice, bob };
  }

  it("mints initial supply to the whitelisted deployer", async function () {
    const { token, owner } = await deploy();
    expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("1000"));
  });

  it("allows transfer between two whitelisted addresses", async function () {
    const { registry, token, owner, alice } = await deploy();
    await registry.verify(alice.address);
    await token.transfer(alice.address, ethers.parseEther("100"));
    expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("100"));
  });

  it("reverts transfer to a non-whitelisted address", async function () {
    const { token, owner, bob } = await deploy();
    // bob chưa từng được registry.verify(...), nên _update phải chặn giao dịch này lại.
    await expect(
      token.transfer(bob.address, ethers.parseEther("10"))
    ).to.be.revertedWith("MirruxRWAToken: recipient not verified");
  });

  it("reverts transfer once a previously-verified address is unverified", async function () {
    const { registry, token, owner, alice } = await deploy();
    await registry.verify(alice.address);
    await token.transfer(alice.address, ethers.parseEther("100"));

    // Mô phỏng tình huống thật: cơ quan KYC rút quyền của alice (vd phát hiện vi phạm).
    await registry.unverify(alice.address);

    // alice giờ không được phép gửi token đi nữa, dù trước đó từng hợp lệ.
    await expect(
      token.connect(alice).transfer(owner.address, ethers.parseEther("50"))
    ).to.be.revertedWith("MirruxRWAToken: sender not verified");
  });

  it("only lets the registry owner manage the whitelist", async function () {
    const { registry, alice } = await deploy();
    await expect(
      registry.connect(alice).verify(alice.address)
    ).to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
  });
});
