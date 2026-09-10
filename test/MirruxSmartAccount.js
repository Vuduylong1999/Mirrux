const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MirruxSmartAccount", function () {
  async function deploy() {
    const [ownerEOA, fakeEntryPoint, attacker] = await ethers.getSigners();

    // Trong test đơn vị (unit test) này, KHÔNG deploy contract EntryPoint thật (rất nặng, cần
    // toàn bộ hạ tầng staking/deposit của ERC-4337) — thay vào đó dùng luôn 1 ví thường
    // (fakeEntryPoint) làm "giả lập EntryPoint", vì modifier onlyEntryPoint chỉ kiểm tra
    // msg.sender có đúng địa chỉ đã lưu hay không, không quan tâm địa chỉ đó có phải EntryPoint
    // THẬT hay không. Điều này đủ để kiểm chứng ĐÚNG logic xác thực chữ ký + phân quyền của
    // MirruxSmartAccount, tách biệt khỏi việc kiểm thử toàn bộ hạ tầng ERC-4337 (việc đó thuộc
    // về bộ test của chính package @account-abstraction/contracts, không phải của Mirrux).
    const Account = await ethers.getContractFactory("MirruxSmartAccount");
    const account = await Account.deploy(fakeEntryPoint.address, ownerEOA.address);

    return { account, ownerEOA, fakeEntryPoint, attacker };
  }

  // Tạo 1 UserOperation "rỗng" (chỉ điền đủ field bắt buộc theo struct PackedUserOperation của
  // ERC-4337 v0.7) — vì test này chỉ quan tâm tới việc validateUserOp() kiểm tra chữ ký đúng/sai,
  // các trường gas/nonce để giá trị mặc định 0 là đủ.
  function emptyUserOp(sender) {
    return {
      sender,
      nonce: 0,
      initCode: "0x",
      callData: "0x",
      accountGasLimits: ethers.ZeroHash,
      preVerificationGas: 0,
      gasFees: ethers.ZeroHash,
      paymasterAndData: "0x",
      signature: "0x",
    };
  }

  it("accepts a UserOperation signed by the account owner", async function () {
    const { account, ownerEOA, fakeEntryPoint } = await deploy();
    const accountAddress = await account.getAddress();

    const userOpHash = ethers.hexlify(ethers.randomBytes(32));
    // signMessage TỰ ĐỘNG thêm tiền tố "\x19Ethereum Signed Message:\n32" trước khi ký — đúng
    // khớp với cách contract dùng toEthSignedMessageHash() để verify lại, nên không cần tự thêm
    // tiền tố thủ công ở phía test.
    const signature = await ownerEOA.signMessage(ethers.getBytes(userOpHash));

    const userOp = emptyUserOp(accountAddress);
    userOp.signature = signature;

    // .connect(fakeEntryPoint): gọi hàm với msg.sender = fakeEntryPoint, để vượt qua modifier
    // onlyEntryPoint (mô phỏng đúng luồng thật: chỉ EntryPoint được phép gọi validateUserOp).
    const validationData = await account.connect(fakeEntryPoint).validateUserOp.staticCall(
      userOp,
      userOpHash,
      0
    );
    expect(validationData).to.equal(0n); // SIG_VALIDATION_SUCCESS
  });

  it("rejects a UserOperation signed by someone other than the owner", async function () {
    const { account, fakeEntryPoint, attacker } = await deploy();
    const accountAddress = await account.getAddress();

    const userOpHash = ethers.hexlify(ethers.randomBytes(32));
    // Chữ ký hợp lệ về mặt kỹ thuật, nhưng ký bởi "attacker" — không phải owner thật của account.
    const signature = await attacker.signMessage(ethers.getBytes(userOpHash));

    const userOp = emptyUserOp(accountAddress);
    userOp.signature = signature;

    const validationData = await account.connect(fakeEntryPoint).validateUserOp.staticCall(
      userOp,
      userOpHash,
      0
    );
    expect(validationData).to.equal(1n); // SIG_VALIDATION_FAILED — không revert, chỉ trả về mã lỗi
  });

  it("blocks validateUserOp when called by anyone other than the EntryPoint", async function () {
    const { account, ownerEOA, attacker } = await deploy();
    const accountAddress = await account.getAddress();
    const userOpHash = ethers.hexlify(ethers.randomBytes(32));
    const signature = await ownerEOA.signMessage(ethers.getBytes(userOpHash));
    const userOp = emptyUserOp(accountAddress);
    userOp.signature = signature;

    // "attacker" không phải fakeEntryPoint đã đăng ký lúc deploy -> phải bị chặn ngay từ modifier,
    // dù chữ ký gửi kèm hoàn toàn hợp lệ.
    await expect(
      account.connect(attacker).validateUserOp(userOp, userOpHash, 0)
    ).to.be.revertedWith("MirruxSmartAccount: not from EntryPoint");
  });

  it("only lets the EntryPoint call execute()", async function () {
    const { account, attacker } = await deploy();
    await expect(
      account.connect(attacker).execute(attacker.address, 0, "0x")
    ).to.be.revertedWith("MirruxSmartAccount: not from EntryPoint");
  });
});
