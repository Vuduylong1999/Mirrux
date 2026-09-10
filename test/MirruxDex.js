const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Mirrux DEX (Factory + Pair + Router)", function () {
  async function deploy() {
    const [owner, alice] = await ethers.getSigners();

    // Dùng lại MirruxToken (ERC-20 thường, không bị giới hạn whitelist) làm 2 token demo cho pool,
    // vì AMM ở đây chỉ cần token tuân chuẩn ERC-20 cơ bản, không liên quan tới ERC-3643/RWA.
    const Token = await ethers.getContractFactory("MirruxToken");
    const tokenA = await Token.deploy(ethers.parseEther("1000000"));
    const tokenB = await Token.deploy(ethers.parseEther("1000000"));

    const Factory = await ethers.getContractFactory("MirruxFactory");
    const factory = await Factory.deploy();

    const Router = await ethers.getContractFactory("MirruxRouter");
    const router = await Router.deploy(await factory.getAddress());

    // Cho phép Router rút token thay mình (bắt buộc theo chuẩn ERC-20, vì Router sẽ gọi
    // transferFrom bên trong addLiquidity/swap).
    await tokenA.approve(await router.getAddress(), ethers.MaxUint256);
    await tokenB.approve(await router.getAddress(), ethers.MaxUint256);

    const deadline = (await ethers.provider.getBlock("latest")).timestamp + 3600;

    return { factory, router, tokenA, tokenB, owner, alice, deadline };
  }

  it("creates a new pool on first addLiquidity call", async function () {
    const { router, tokenA, tokenB, owner, deadline } = await deploy();
    await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      deadline
    );
    const factoryContract = await ethers.getContractAt(
      "MirruxFactory",
      await router.factory()
    );
    expect(await factoryContract.allPairsLength()).to.equal(1n);
  });

  it("mints LP tokens proportional to the deposited liquidity", async function () {
    const { router, tokenA, tokenB, owner, deadline } = await deploy();
    await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      deadline
    );

    const factoryContract = await ethers.getContractAt("MirruxFactory", await router.factory());
    const pairAddress = await factoryContract.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    const pair = await ethers.getContractAt("MirruxPair", pairAddress);

    // liquidity = sqrt(1000 * 1000) - MINIMUM_LIQUIDITY (1000 wei bị khoá vĩnh viễn).
    const expected = ethers.parseEther("1000") - 1000n;
    expect(await pair.balanceOf(owner.address)).to.equal(expected);
  });

  it("swaps tokenA for tokenB following the constant-product formula", async function () {
    const { router, tokenA, tokenB, owner, alice, deadline } = await deploy();
    await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      deadline
    );

    await tokenA.transfer(alice.address, ethers.parseEther("100"));
    await tokenA.connect(alice).approve(await router.getAddress(), ethers.MaxUint256);

    const expectedOut = await router.getAmountOut(
      ethers.parseEther("100"),
      ethers.parseEther("1000"),
      ethers.parseEther("1000")
    );

    await router.connect(alice).swapExactTokensForTokens(
      ethers.parseEther("100"),
      0,
      [await tokenA.getAddress(), await tokenB.getAddress()],
      alice.address,
      deadline
    );

    expect(await tokenB.balanceOf(alice.address)).to.equal(expectedOut);
    // Vì có phí 0.3%, đổi 100 tokenA thu về ÍT HƠN 100 tokenB (giá bị trượt do phí + độ sâu pool).
    expect(expectedOut).to.be.lessThan(ethers.parseEther("100"));
  });

  it("lets a liquidity provider remove liquidity and get tokens back", async function () {
    const { router, tokenA, tokenB, owner, deadline } = await deploy();
    await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      deadline
    );

    const factoryContract = await ethers.getContractAt("MirruxFactory", await router.factory());
    const pairAddress = await factoryContract.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    const pair = await ethers.getContractAt("MirruxPair", pairAddress);

    const lpBalance = await pair.balanceOf(owner.address);
    await pair.approve(await router.getAddress(), lpBalance);

    const balanceBefore = await tokenA.balanceOf(owner.address);
    await router.removeLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      lpBalance,
      0,
      0,
      owner.address,
      deadline
    );
    expect(await tokenA.balanceOf(owner.address)).to.be.greaterThan(balanceBefore);
  });

  it("reverts a swap submitted after the deadline", async function () {
    const { router, tokenA, tokenB, owner, deadline } = await deploy();
    await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      deadline
    );

    const expiredDeadline = (await ethers.provider.getBlock("latest")).timestamp - 1;
    await expect(
      router.swapExactTokensForTokens(
        ethers.parseEther("10"),
        0,
        [await tokenA.getAddress(), await tokenB.getAddress()],
        owner.address,
        expiredDeadline
      )
    ).to.be.revertedWith("MirruxRouter: expired");
  });
});
