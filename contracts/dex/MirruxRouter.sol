// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MirruxFactory.sol";
import "./MirruxPair.sol";

// Router là "cửa ngõ" mà người dùng thực sự tương tác — Pair/Factory ở tầng dưới đã đủ để
// vận hành AMM, nhưng gọi thẳng vào chúng đòi hỏi tự tính toán tỷ lệ, tự transfer token theo
// đúng thứ tự... rất dễ sai. Router gộp tất cả các bước đó lại thành 1 lần gọi hàm duy nhất,
// kèm theo các lớp bảo vệ người dùng (deadline, slippage) mà Pair KHÔNG tự có.
contract MirruxRouter {
    MirruxFactory public immutable factory;

    // "deadline": mọi hàm ghi dữ liệu bên dưới đều nhận tham số này — nếu giao dịch bị kẹt
    // trong mempool quá lâu (vd mạng nghẽn) rồi mới được đào, giá thị trường có thể đã đổi khác
    // xa so với lúc người dùng ký giao dịch. Modifier này chặn giao dịch "cũ" thực thi trễ,
    // tránh người dùng bị trượt giá (slippage) ngoài ý muốn.
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "MirruxRouter: expired");
        _;
    }

    constructor(address _factory) {
        factory = MirruxFactory(_factory);
    }

    // Tìm địa chỉ pool đã tạo, tự động tạo mới nếu chưa tồn tại — giúp addLiquidity dùng được
    // ngay cả với cặp token hoàn toàn mới, không cần gọi createPair() riêng trước.
    function _getOrCreatePair(address tokenA, address tokenB) private returns (address pair) {
        pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = factory.createPair(tokenA, tokenB);
        }
    }

    // Tính "amountB tương xứng với amountA" theo đúng tỷ lệ reserve hiện có của pool — dùng để
    // xác định mình nên góp bao nhiêu token B nếu đã quyết định góp 1 lượng token A cụ thể,
    // tránh làm lệch tỷ lệ pool (lệch tỷ lệ = một phần vốn góp bị "phí" vì không tính ra LP token).
    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) private pure returns (uint256 amountB) {
        require(amountA > 0, "MirruxRouter: insufficient amount");
        require(reserveA > 0 && reserveB > 0, "MirruxRouter: insufficient liquidity");
        amountB = (amountA * reserveB) / reserveA;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = _getOrCreatePair(tokenA, tokenB);
        (uint256 reserveA, uint256 reserveB) = _reservesOf(pair, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            // Pool trống (lần góp vốn đầu tiên) — chấp nhận đúng số lượng người dùng muốn góp,
            // vì chưa có tỷ lệ nào để đối chiếu, chính người góp đầu tiên là người "định giá" ban đầu.
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // Thử khớp theo tỷ lệ hiện có của pool, ưu tiên dùng tối đa amountADesired trước.
            uint256 amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "MirruxRouter: insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // Nếu góp đủ amountBDesired thì amountA sẽ vượt mong muốn — thử chiều ngược lại.
                uint256 amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "MirruxRouter: excessive A amount");
                require(amountAOptimal >= amountAMin, "MirruxRouter: insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

        // Chuyển thẳng token vào pool TRƯỚC KHI gọi mint() — đúng pattern mà MirruxPair.mint() yêu cầu.
        IERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        liquidity = MirruxPair(pair).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "MirruxRouter: pair does not exist");

        // Chuyển LP token vào pool TRƯỚC KHI gọi burn() — đúng pattern mà MirruxPair.burn() yêu cầu.
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = MirruxPair(pair).burn(to);

        (address token0, ) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "MirruxRouter: insufficient A amount");
        require(amountB >= amountBMin, "MirruxRouter: insufficient B amount");
    }

    // Công thức chuẩn Uniswap V2 để tính số token nhận được khi swap, đã trừ sẵn phí 0.3%.
    // Đây chính là công thức "x*y=k" viết dưới dạng tính amountOut trực tiếp từ amountIn.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "MirruxRouter: insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "MirruxRouter: insufficient liquidity");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _reservesOf(address pair, address tokenA, address tokenB)
        private
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, ) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint256 reserve0, uint256 reserve1) = MirruxPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // "path": danh sách địa chỉ token theo thứ tự đi qua, vd [MRX, RWA, USDC] nghĩa là đổi
    // MRX -> RWA -> USDC qua 2 pool liên tiếp (multi-hop) — cho phép swap giữa 2 token dù
    // KHÔNG có pool trực tiếp giữa chúng, miễn có đường đi qua các pool trung gian đã tồn tại.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length >= 2, "MirruxRouter: invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        // Tính trước TOÀN BỘ số lượng ở mỗi bước của path, dựa trên reserve HIỆN TẠI của từng pool
        // (chưa thực hiện swap thật) — để biết chắc kết quả cuối cùng trước khi động vào token thật.
        for (uint256 i; i < path.length - 1; i++) {
            address pair = factory.getPair(path[i], path[i + 1]);
            require(pair != address(0), "MirruxRouter: pair does not exist");
            (uint256 reserveIn, uint256 reserveOut) = _reservesOf(pair, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        require(amounts[path.length - 1] >= amountOutMin, "MirruxRouter: insufficient output amount");

        // Chuyển token đầu vào từ user thẳng vào pool ĐẦU TIÊN trong path.
        address firstPair = factory.getPair(path[0], path[1]);
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amountIn);

        // Lần lượt gọi swap() trên từng pool theo path — mỗi bước gửi thẳng token OUT sang địa chỉ
        // pool TIẾP THEO (hoặc "to" nếu là bước cuối cùng), không cần vòng qua ví Router ở giữa,
        // tiết kiệm gas so với việc transfer qua lại nhiều lần.
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = input < output ? (input, output) : (output, input);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address pair = factory.getPair(input, output);
            address recipient = i < path.length - 2 ? factory.getPair(output, path[i + 2]) : to;
            MirruxPair(pair).swap(amount0Out, amount1Out, recipient);
        }
    }
}
