# Mirrux

Portfolio project: 1 nền tảng mô phỏng **DEX (sàn giao dịch phi tập trung)** + **tokenization
platform (token hoá tài sản thật)**, xây bằng Solidity + Hardhat. Đây là project cá nhân/portfolio
để luyện tập và chứng minh hiểu các chuẩn EVM/ERC phổ biến — không phải sản phẩm production.

Xem [ROADMAP.md](./ROADMAP.md) để biết kế hoạch triển khai theo từng phase.

## Kiến trúc

| Contract | Chuẩn | Vai trò |
|---|---|---|
| `contracts/MirruxToken.sol` | ERC-20 | Token thường (MRX), owner-gated mint, ai cũng burn được token của mình. |
| `contracts/MirruxVault.sol` | ERC-4626 | Vault nhận MRX, phát hành share token (vMRX). "Lãi" mô phỏng bằng cách donate thêm token vào vault, làm tăng tỷ giá share. |
| `contracts/IdentityRegistry.sol` | (hỗ trợ ERC-3643) | Whitelist rút gọn — `verify()`/`unverify()` (chỉ owner), `isVerified()` để tra cứu. |
| `contracts/MirruxRWAToken.sol` | ERC-3643-style | Token đại diện tài sản thật (RWA), chặn transfer nếu người gửi/nhận chưa được `IdentityRegistry` xác minh. |
| `contracts/MirruxPropertyNFT.sol` | ERC-721 | NFT đại diện 1 tài sản duy nhất, mỗi token có metadata URI riêng. |
| `contracts/MirruxAssetCollection.sol` | ERC-1155 | Nhiều loại tài sản/suất góp vốn trong 1 contract, hỗ trợ mint batch. |
| `contracts/dex/MirruxPair.sol` | Custom (Uniswap V2-style) | Pool AMM (x·y=k), LP token, phí 0.3%/swap. |
| `contracts/dex/MirruxFactory.sol` | Custom | Tạo/tra cứu pool theo từng cặp token. |
| `contracts/dex/MirruxRouter.sol` | Custom | addLiquidity/removeLiquidity/swap (hỗ trợ multi-hop), có deadline chống trượt giá. |
| `contracts/MirruxSmartAccount.sol` | ERC-4337 | Ví hợp đồng (smart account), xác thực chữ ký owner qua ECDSA, chỉ EntryPoint gọi được các hàm nhạy cảm. |

## Cài đặt & chạy test

```bash
npm install
npm run compile
npm test
npm run lint
```

## Deploy

```bash
npx hardhat run scripts/deploy-phase1.js --network sepolia   # tương tự cho phase2/3/4/5
npx hardhat run scripts/deploy-phase1.js --network baseSepolia
npx hardhat deploy-zksync --network zkSyncSepolia --script deploy-token.js
```

Cần file `.env` (copy từ `.env.example`) với `PRIVATE_KEY`, `SEPOLIA_RPC_URL`,
`BASE_SEPOLIA_RPC_URL`, `ETHERSCAN_API_KEY`.

## Contract đã deploy & verify

### Sepolia (`sepolia.etherscan.io`)

| Contract | Địa chỉ |
|---|---|
| MirruxToken (MRX) | [0x7105cC28Df810dd63bdba3aF30D18f2187657631](https://sepolia.etherscan.io/address/0x7105cC28Df810dd63bdba3aF30D18f2187657631#code) |
| MirruxVault (vMRX) | [0x78C87519D32d0126b3d82955b412f4371783B94C](https://sepolia.etherscan.io/address/0x78C87519D32d0126b3d82955b412f4371783B94C#code) |
| IdentityRegistry | [0x9250B9a3ead6c3B3fc667899890acE94a368bd14](https://sepolia.etherscan.io/address/0x9250B9a3ead6c3B3fc667899890acE94a368bd14#code) |
| MirruxRWAToken (mRWA) | [0x9F3A97a99A66D12e35dB911e49726A8174311E3A](https://sepolia.etherscan.io/address/0x9F3A97a99A66D12e35dB911e49726A8174311E3A#code) |
| MirruxPropertyNFT | [0x6A082B052315b9791eeA2b9844d01CC86Ae6d71a](https://sepolia.etherscan.io/address/0x6A082B052315b9791eeA2b9844d01CC86Ae6d71a#code) |
| MirruxAssetCollection | [0x710B740CD705158014bf90904d12Bfe5416323EA](https://sepolia.etherscan.io/address/0x710B740CD705158014bf90904d12Bfe5416323EA#code) |
| MirruxFactory | [0x04F58249c024e025CEd5D1Aa755328deFb5fD4D1](https://sepolia.etherscan.io/address/0x04F58249c024e025CEd5D1Aa755328deFb5fD4D1#code) |
| MirruxRouter | [0xee2d79a17DBD83B17e114EE3212a9c2DFdFaE58E](https://sepolia.etherscan.io/address/0xee2d79a17DBD83B17e114EE3212a9c2DFdFaE58E#code) |
| MirruxSmartAccount | [0xB74e2094EF033Fad63702bE2E1A7e5E28Add509e](https://sepolia.etherscan.io/address/0xB74e2094EF033Fad63702bE2E1A7e5E28Add509e#code) |

MirruxSmartAccount trỏ vào EntryPoint v0.7 chuẩn chung của ERC-4337
(`0x0000000071727De22E5E9d8BAf0edAc6f37da032`, không phải contract của Mirrux).

### zkSync Era Sepolia (`sepolia.explorer.zksync.io`)

| Contract | Địa chỉ |
|---|---|
| MirruxToken (MRX) | [0xbfc56228c38E7bB7D63b6d773C591e1c50758B6c](https://sepolia.explorer.zksync.io/address/0xbfc56228c38E7bB7D63b6d773C591e1c50758B6c) |

### Base Sepolia

Chưa deploy — hạ tầng (network config, script) đã sẵn sàng trong `hardhat.config.js`, chỉ cần
ví có Base Sepolia ETH rồi chạy lại các script `deploy-phase*.js` với `--network baseSepolia`.

## Kỹ thuật đáng chú ý

- **ERC-3643-style permissioned token**: `MirruxRWAToken` override hook `_update` (thay vì viết
  lại từng hàm transfer) để chặn giao dịch nếu người gửi/nhận chưa whitelist trong
  `IdentityRegistry` — đảm bảo không có luồng nào (transfer/transferFrom/mint/burn) lọt qua kiểm tra.
- **AMM tự viết theo Uniswap V2**: `MirruxPair` implement đúng bất biến x·y=k, cơ chế MINIMUM_LIQUIDITY
  chống inflation attack, và Router hỗ trợ swap multi-hop qua nhiều pool liên tiếp.
- **ERC-4337 account abstraction**: `MirruxSmartAccount` implement `IAccount` từ package chuẩn
  `@account-abstraction/contracts`, trỏ vào EntryPoint v0.7 thật đã deploy sẵn trên Sepolia.
- **ZK deploy (zkSync Era)**: dùng zksolc (compiler riêng biên dịch Solidity thành bytecode tương
  thích zkEVM) thay vì solc thường — cùng 1 source code Solidity, khác hoàn toàn máy ảo đích.
