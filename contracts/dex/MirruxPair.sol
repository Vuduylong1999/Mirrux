// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// MirruxPair là trái tim của AMM (Automated Market Maker) — 1 cặp giao dịch DUY NHẤT
// giữ cả 2 loại token (vd MRX/RWA) và tự định giá dựa trên công thức toán "x * y = k"
// (tích 2 lượng token trong pool luôn không đổi sau mỗi lần swap), thay vì dùng sổ lệnh
// (order book) như sàn tập trung truyền thống.
//
// Contract này TỰ NÓ cũng là 1 token ERC-20 (LP token — "chứng chỉ góp vốn thanh khoản"):
// ai gửi token vào pool sẽ nhận lại LP token đại diện phần đóng góp, đổi lại được cả gốc
// lẫn phí giao dịch tích luỹ sau này.
contract MirruxPair is ERC20 {
    // MINIMUM_LIQUIDITY: 1 lượng LP token cực nhỏ bị "khoá vĩnh viễn" (gửi cho address(0),
    // tức đốt bỏ) ngay lần thêm thanh khoản đầu tiên. Đây là kỹ thuật chống tấn công
    // thao túng giá lúc pool mới tạo (kẻ tấn công có thể lợi dụng pool trống để làm giá LP
    // token cực lệch, gây thiệt hại cho người góp vốn tiếp theo) — thực hành chuẩn của Uniswap V2.
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    // "immutable": địa chỉ 2 token trong cặp này cố định từ lúc deploy, không đổi được nữa.
    address public immutable token0;
    address public immutable token1;

    // reserve0/reserve1: số lượng token0/token1 mà pool ĐANG GHI NHẬN là của mình — không phải
    // lúc nào cũng bằng đúng token0.balanceOf(address(this)) thật, vì reserve chỉ cập nhật
    // (_update) sau khi swap/mint/burn hoàn tất, giúp tính giá dựa trên trạng thái ổn định
    // thay vì số dư có thể bị thao túng giữa chừng 1 giao dịch.
    uint256 private reserve0;
    uint256 private reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    constructor(address _token0, address _token1) ERC20("Mirrux LP Token", "MLP") {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        return (reserve0, reserve1);
    }

    // Đồng bộ lại reserve0/reserve1 theo đúng số dư thật hiện có trong contract — gọi sau
    // MỌI thao tác mint/burn/swap để lần tính toán tiếp theo luôn dựa trên dữ liệu mới nhất.
    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    // Hàm tính căn bậc 2 kiểu Babylon (Newton's method) — cần thiết vì Solidity không có
    // hàm sqrt() dựng sẵn. Dùng để tính LP token cấp cho người góp vốn ĐẦU TIÊN theo công thức
    // sqrt(amount0 * amount1), đảm bảo giá trị LP token không phụ thuộc thứ tự 2 token truyền vào.
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // mint: được Router gọi SAU KHI đã transfer token0/token1 thẳng vào địa chỉ pool này.
    // Tách rời "chuyển token vào" và "tính toán mint" là pattern chuẩn của Uniswap V2, giúp
    // Router có thể gộp nhiều bước lại thành 1 giao dịch duy nhất cho người dùng.
    function mint(address to) external returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        // amount = số token MỚI vừa được gửi vào, tính bằng hiệu giữa số dư thật và reserve cũ.
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // Lần góp vốn đầu tiên: LP token = sqrt(amount0 * amount1), trừ đi phần khoá vĩnh viễn.
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); // khoá vĩnh viễn, không ai rút lại được
        } else {
            // Các lần sau: LP token tỷ lệ theo phần đóng góp so với reserve hiện có, lấy giá trị
            // NHỎ HƠN giữa 2 cách tính (theo token0 và theo token1) để tránh người gửi lệch tỷ lệ
            // trục lợi (gửi thừa 1 loại token mà vẫn được tính đủ LP token).
            liquidity = _min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "MirruxPair: insufficient liquidity minted");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // burn: được Router gọi SAU KHI người dùng đã transfer LP token vào địa chỉ pool này
    // (để "trả lại" phần góp vốn). Đốt số LP token đó, trả lại token0/token1 tương ứng.
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        // Số LP token pool đang giữ hộ (do Router transfer vào trước khi gọi burn) chính là
        // số lượng người dùng muốn rút.
        uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        // Rút ra đúng tỷ lệ phần trăm mà "liquidity" chiếm trong tổng LP token đang lưu hành.
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "MirruxPair: insufficient liquidity burned");

        _burn(address(this), liquidity);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // swap: hàm lõi thực hiện đổi token, được Router gọi SAU KHI người dùng đã transfer token
    // đầu vào thẳng vào pool. "amount0Out"/"amount1Out" là số lượng token pool phải trả ra —
    // Router đã tính sẵn con số này theo công thức AMM trước khi gọi vào đây.
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "MirruxPair: insufficient output amount");
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "MirruxPair: insufficient liquidity");

        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // Suy ra số token THỰC SỰ đã được gửi vào pool để đổi lấy amountOut ở trên, bằng cách
        // so sánh số dư hiện tại với reserve TRỪ ĐI phần vừa trả ra — cách này không cần Router
        // phải "khai báo" trước số tiền vào, chỉ cần đã transfer đúng trước khi gọi swap().
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "MirruxPair: insufficient input amount");

        // Áp phí giao dịch 0.3% (997/1000) lên phần token gửi vào trước khi kiểm tra bất biến k —
        // đây chính là nguồn "lãi" trả cho người cung cấp thanh khoản (LP), vì phần phí đó ở lại
        // pool, không bị trả ra ngoài, làm tăng giá trị mỗi LP token theo thời gian.
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        // Bất biến cốt lõi của AMM: sau giao dịch, tích 2 số dư (đã trừ phí) KHÔNG ĐƯỢC nhỏ hơn
        // tích 2 reserve cũ (nhân 1000^2 để cùng đơn vị) — đảm bảo giá luôn di chuyển đúng hướng
        // cung/cầu, không ai lợi dụng swap để rút tiền pool miễn phí.
        require(
            balance0Adjusted * balance1Adjusted >= _reserve0 * _reserve1 * (1000 ** 2),
            "MirruxPair: K invariant violated"
        );

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
}
