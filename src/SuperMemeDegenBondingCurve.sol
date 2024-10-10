// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces/IUniswapV2Router02.sol";
import "./Interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";

/*
   ▄████████ ███    █▄     ▄███████▄    ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄      ▄████████   ▄▄▄▄███▄▄▄▄      ▄████████ 
  ███    ███ ███    ███   ███    ███   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ 
  ███    █▀  ███    ███   ███    ███   ███    █▀    ███    ███ ███   ███   ███   ███    █▀  ███   ███   ███   ███    █▀  
  ███        ███    ███   ███    ███  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███  ▄███▄▄▄     ███   ███   ███  ▄███▄▄▄     
▀███████████ ███    ███ ▀█████████▀  ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███ ▀▀███▀▀▀     ███   ███   ███ ▀▀███▀▀▀     
         ███ ███    ███   ███          ███    █▄  ▀███████████ ███   ███   ███   ███    █▄  ███   ███   ███   ███    █▄  
   ▄█    ███ ███    ███   ███          ███    ███   ███    ███ ███   ███   ███   ███    ███ ███   ███   ███   ███    ███ 
 ▄████████▀  ████████▀   ▄████▀        ██████████   ███    ███  ▀█   ███   █▀    ██████████  ▀█   ███   █▀    ██████████ 
                                                    ███    ███                                                           
*/
contract SuperMemeDegenBondingCurve is ERC20, ReentrancyGuard {
    event SentToDex(uint256 ethAmount, uint256 tokenAmount, uint256 timestamp);
    event Price(
        uint256 indexed price,
        uint256 indexed totalSupply,
        address indexed tokenAddress,
        uint256 amount
    );
    event tokensBought(
        uint256 indexed amount,
        uint256 cost,
        address indexed tokenAddress,
        address indexed buyer,
        uint256 totalSupply
    );
    event tokensSold(
        uint256 indexed amount,
        uint256 refund,
        address indexed tokenAddress,
        address indexed seller,
        uint256 totalSupply
    );

    uint256 public constant TOTAL_ETHER = 4 ether;
    uint256 public constant SCALE = 1e18; // Scaling factor
    uint256 public constant A = 234375; // Calculated constant A
    uint256 public constant scaledLiquidityThreshold = 200_000_000;

    uint256 liquidityThreshold = 200_000_000 * 10 ** 18;
    uint256 public MAX_SALE_SUPPLY = 1e9; // 1 billion tokens

    uint256 private constant tradeTax = 1000;
    uint256 private constant tradeTaxDivisor = 100000;

    uint256 public totalEtherCollected;
    uint256 public scaledSupply;

    address public devAddress;
    bool public devLocked;
    uint256 public devLockTime;

    bool public bondingCurveCompleted;

    address public revenueCollector;
    uint256 public totalRevenueCollected;
    uint256 public sendDexRevenue = 0.15 ether;

    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;

    address public factoryContract;

    constructor(
        string memory _name,
        string memory _symbol,
        bool _devLocked,
        uint256 _amount,
        address _devAdress,
        address _revenueCollector,
        uint256 _devLockDuration,
        uint256 _buyEth
    ) public payable ERC20(_name, _symbol) {
        factoryContract = msg.sender;
        revenueCollector = _revenueCollector;
        uniswapV2Router = IUniswapV2Router02(
            0x6682375ebC1dF04676c0c5050934272368e6e883
        );
        //base mainnet router address 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        //base sepolia router address 0x6682375ebC1dF04676c0c5050934272368e6e883
        _mint(address(this), liquidityThreshold);
        scaledSupply = scaledLiquidityThreshold;
        devAddress = _devAdress;
        devLocked = _devLocked;
        devLockTime = block.timestamp + _devLockDuration;
        if (_amount > 0) {
            devBuyTokens(_amount, _buyEth);
        }
    }
    function buyTokens(
        uint256 _amount,
        uint256 _slippage
    ) public payable nonReentrant {
        require(_amount > 0, "0 amount");
        require(!bondingCurveCompleted, "Curve done");
        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        uint256 slippageAmount = (totalCost * _slippage) / 10000;
        require(cost + tax <= msg.value, "Insufficient funds");
        require(
             msg.value >= totalCost + slippageAmount,
            "Slippage"
        );
        payTax(tax);
        uint256 excessEth = (msg.value > totalCost) ? msg.value - totalCost : 0;
        totalEtherCollected += cost;
        scaledSupply += _amount;
        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
            _amount = MAX_SALE_SUPPLY - (scaledSupply - _amount);
        }

        if (excessEth > 0) {
            payable(msg.sender).transfer(excessEth);
        }
        _mint(msg.sender, _amount * 10 ** 18);
        uint256 totalSup = totalSupply();
        uint256 lastPrice = calculateCost(1);
        emit tokensBought(_amount, cost, address(this), msg.sender, totalSup);
        emit Price(lastPrice, totalSup, address(this), _amount);

        if (bondingCurveCompleted) {
            sendToDex();
        }
    }
    function calculateCost(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = scaledSupply;
        uint256 newSupply = currentSupply + amount;
        uint256 cost = ((((A * ((newSupply ** 3) - (currentSupply ** 3))) *
            10 ** 5) / (3 * SCALE)) * 40000) / 77500;
        return cost;
    }
    function payTax(uint256 _tax) internal {
        (bool success, ) = revenueCollector.call{value: _tax, gas: 100000}("");
        require(success, "Transfer failed");
        totalRevenueCollected += _tax;
    }
    function sendToDex() public payable {
        require(bondingCurveCompleted, "Curve not done");
        payTax(sendDexRevenue);

        totalEtherCollected -= sendDexRevenue;
        uint256 _ethAmount = totalEtherCollected;
        uint256 _tokenAmount = liquidityThreshold;
        _approve(address(this), address(uniswapV2Router), _tokenAmount);
        uniswapV2Router.addLiquidityETH{value: _ethAmount}(
            address(this),
            _tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
        emit SentToDex(_ethAmount, _tokenAmount, block.timestamp);
    }
    function sellTokens(
        uint256 _amount,
        uint256 _minimumEthRequired
    ) public nonReentrant {
        require(!bondingCurveCompleted, "Curve done");

        uint256 refund = calculateRefund(_amount);
        uint256 tax = (refund * tradeTax) / tradeTaxDivisor;
        uint256 netRefund = refund - tax;

        require(address(this).balance >= netRefund, "Low ETH");
        require(balanceOf(msg.sender) >= _amount * 10 ** 18, "Low tokens");
        require(netRefund >= _minimumEthRequired, "Low refund");
        payTax(tax);
        _burn(msg.sender, _amount * 10 ** 18);
        totalEtherCollected -= netRefund + tax;
        scaledSupply -= _amount;

        payable(msg.sender).transfer(netRefund);

        uint256 totalSup = totalSupply();
        uint256 lastPrice = calculateCost(1);
        emit tokensSold(_amount, refund, address(this), msg.sender, totalSup);
        emit Price(lastPrice, totalSup, address(this), _amount);
    }

    function calculateRefund(uint256 _amount) public view returns (uint256) {
        uint256 currentSupply = scaledSupply;
        uint256 newSupply = currentSupply - _amount;
        uint256 refund = ((((A * ((currentSupply ** 3) - (newSupply ** 3))) *
            10 ** 5) / (3 * SCALE)) * 40000) / 77500;
        return refund;
    }
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        if (bondingCurveCompleted) {
            super._update(from, to, value);
        } else {
            if (
                from == devAddress && devLocked && block.timestamp < devLockTime
            ) {
                revert("Locked");
            } else if (from == address(this) || from == address(0)) {
                super._update(from, to, value);
            } else if (to == address(this) || to == address(0)) {
                super._update(from, to, value);
            } else {
                revert("No transfer");
            }
        }
    }
    function remainingTokens() public view returns (uint256) {
        return MAX_SALE_SUPPLY - scaledSupply;
    }


    function devBuyTokens(
        uint256 _amount,
        uint256 _buyEth
    ) internal nonReentrant {
        require(_amount > 0, "0 amount");
        require(!bondingCurveCompleted, "Curve done");
        require(msg.value >= _buyEth, "Insufficient funds");
        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        payTax(tax);
        uint256 excessEth = (_buyEth > totalCost) ? _buyEth - totalCost : 0;
        totalEtherCollected += cost;
        scaledSupply += _amount;
        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
            _amount = MAX_SALE_SUPPLY - (scaledSupply - _amount);
        }
        address buyer = (msg.sender == factoryContract)
            ? devAddress
            : msg.sender;

        if (excessEth > 0) {
            payable(buyer).transfer(excessEth);
        }
        _mint(buyer, _amount * 10 ** 18);
        uint256 totalSup = totalSupply();
        uint256 lastPrice = calculateCost(1);
        emit tokensBought(_amount, cost, address(this), buyer, totalSup);
        emit Price(lastPrice, totalSup, address(this), _amount);

        if (bondingCurveCompleted) {
            sendToDex();
        }
    }
}