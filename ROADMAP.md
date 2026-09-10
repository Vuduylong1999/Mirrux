# Mirrux — Multi-chain DEX & Tokenization Platform (Portfolio Project)

Mục tiêu: build portfolio project khớp JD "Blockchain Developer (Solidity/Hardhat/ERC standards/ZK)".
Deploy testnet: **Sepolia** + **Base Sepolia**. Không lên mainnet, không cần audit.

## Phase 0 — Setup nền
- Khởi tạo Hardhat project, config 2 network (Sepolia, Base Sepolia).
- Cài OpenZeppelin, dotenv cho private key + RPC key.
- Tool: Node.js, Hardhat, `@openzeppelin/contracts`, Alchemy/Infura RPC free tier.
- Done khi: `npx hardhat compile` sạch, deploy 1 contract rỗng lên Sepolia, thấy tx trên Etherscan.

## Phase 1 — Core token (ERC-20 + ERC-4626)
- ERC-20 mint/burn có access control; vault ERC-4626 nhận token đó, sinh yield giả lập.
- Tool: OpenZeppelin `ERC20.sol`, `ERC4626.sol`, Hardhat test (Chai/Mocha).
- Done khi: test coverage ≥90%, deploy verify trên cả 2 network, có script deposit/withdraw demo.

## Phase 2 — Permissioned token (ERC-3643, RWA) — điểm nhấn khác biệt [DONE]
- Token có whitelist (Identity Registry rút gọn), admin role add/remove whitelist.
- Tool: OpenZeppelin `AccessControl`, tự viết registry (~100-150 dòng), tham khảo interface chuẩn ERC-3643.
- Done khi: test transfer thành công giữa 2 ví whitelist, revert khi ví không whitelist; README giải thích luồng KYC/whitelist.

## Phase 3 — NFT chuẩn (ERC-721 + ERC-1155)
- ERC-721: đại diện 1 tài sản duy nhất. ERC-1155: nhiều loại tài sản/fraction.
- Tool: OpenZeppelin có sẵn, customize metadata + mint logic.
- Done khi: deploy + mint thử, NFT hiện trên OpenSea testnet.

## Phase 4 — DEX layer (AMM)
- Fork rút gọn Uniswap V2 (Factory + Pair + Router), swap giữa token Phase 1/2.
- Tool: tham khảo code Uniswap V2 (MIT license), Hardhat test cho swap/liquidity.
- Done khi: test đúng công thức x*y=k, deploy + verify, script demo swap trên testnet.
- Cắt bớt nếu gấp thời gian: chỉ làm Pair+Router, bỏ Factory phức tạp.

## Phase 5 — Account Abstraction (ERC-4337) — optional
- Không viết EntryPoint từ đầu, dùng Alchemy Account Kit / Stackup. 1 Smart Account contract đơn giản.
- Tool: `@account-abstraction/contracts`, Alchemy AA SDK, bundler testnet free.
- Done khi: 1 tx demo qua UserOperation thành công, có log/screenshot.
- Cắt phase này đầu tiên nếu thiếu thời gian.

## Phase 6 — ZK integration
- Không tự viết circuit ZK. Deploy 1 contract (ERC-20 hoặc vault) lên zkSync Era Sepolia testnet.
- Tool: `@matterlabs/hardhat-zksync`, zkSync Sepolia testnet + faucet.
- Done khi: verify trên zkSync explorer; README ghi rõ khác biệt deploy ZK-rollup vs EVM thường (trả lời câu "technical challenge" trong JD).

## Phase 7 — CI/CD + polish
- GitHub Actions chạy test + lint mỗi push. README tổng hợp kiến trúc + link deploy mọi contract trên mọi network.
- Tool: GitHub Actions (free), Solhint / Foundry `forge fmt`.
- Done khi: badge tests passing xanh, mọi contract có link verify click được.

## Ưu tiên nếu hết giờ giữa chừng
Tối thiểu apply được: Phase 0 → 1 → 2 → 7.
Phase 3, 4 tăng độ rộng. Phase 5 cắt trước tiên nếu cần. Phase 6 (ZK) giữ nếu còn dư ≥2-3 ngày — JD nhấn mạnh ZK khá rõ.
