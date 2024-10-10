// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces/IUniswapV2Router02.sol";
import "./Interfaces/IUniswapV2Pair.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

contract SuperMemeRefundableBondingCurve is ERC20, ReentrancyGuard {
    uint256 public MAX_SALE_SUPPLY = 1e9; // 1 billion tokens
    uint256 public constant TOTAL_ETHER = 4 ether;
    uint256 public MAXIMUM_TOTAL_ETHER = 4 ether;
    uint256 public constant SCALE = 1e18; // Scaling factor
    uint256 public constant A = 234375; // Calculated constant A
    uint256 liquidityThreshold = 200_000_000 * 10 ** 18;
    uint256 public constant scaledLiquidityThreshold = 200_000_000;
    uint256 public constant buyPointScale = 10000;

    uint256 public scaledSupply;

    address public revenueCollector;
    uint256 public totalRevenueCollected;
    uint256 public totalRefundedTokens;
    uint256 public totalEtherCollected;

    uint256 public tradeTax = 1000;
    uint256 public tradeTaxDivisor = 100000;
    uint256 public sendDexRevenue = 0.15 ether;

    bool public bondingCurveCompleted;
    bool public refundOnly;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;

    event SentToDex(uint256 ethAmount, uint256 tokenAmount, uint256 timestamp);
    event Price(
        uint256 indexed _price,
        uint256 indexed _totalSupply,
        address indexed _tokenAddress,
        uint256 _amount
    );

    event tokensBought(
        uint256 indexed amount,
        uint256 cost,
        address indexed tokenAddress,
        address indexed buyer,
        uint256 totalSupply
    );
    event tokensRefunded(
        uint256 indexed amount,
        uint256 refund,
        address indexed _tokenAddress,
        address indexed _refunder,
        uint256 _price
    );

    uint256 public buyCount;
    mapping(uint256 => address) public buyIndex;
    mapping(uint256 => uint256) public buyCost;
    mapping(uint256 => bool) public isRefund;
    mapping(uint256 => uint256) public cumulativeEthCollected;
    mapping(address => uint256[]) public userBuysPoints;
    mapping(address => uint256[]) public userBuyPointsEthPaid;
    mapping(address => uint256[]) public userBuyPointPercentages;
    mapping(address => uint256) public totalEthPaidUser;
    mapping(address => uint256) public userBalanceScaled;
    mapping(address => bool) public userRefunded;

    address public devAddress;
    uint256 public devLockDuration;
    address public factoryContract;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _amount,
        address _devAdress,
        address _revenueCollector,
        uint256 _ethBuy
    ) public payable ERC20(_name, _symbol) {
        factoryContract = msg.sender;
        revenueCollector = _revenueCollector;
        _mint(address(this), liquidityThreshold);
        scaledSupply = scaledLiquidityThreshold;
        uniswapV2Router = IUniswapV2Router02(
            0x6682375ebC1dF04676c0c5050934272368e6e883
        );
        //base mainnet router address 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        //base sepolia router address 0x6682375ebC1dF04676c0c5050934272368e6e883
        devAddress = _devAdress;
        if (_amount > 0) {
            devBuyTokens(_amount, _ethBuy);
        }
    }
    function buyTokens(
        uint256 _amount,
        uint256 _slippage
    ) public payable nonReentrant {
        require(!userRefunded[msg.sender], "Refunded");
        require(!bondingCurveCompleted, "Curve done");
        require(_amount > 0, "0 amount");
        require(refundOnly, "Refund only");

        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        uint256 slippageAmount = (totalCost * _slippage) / 10000;
        require(
            msg.value >= totalCost + slippageAmount,
            "Slippage"
        );
        require(msg.value >= totalCost, "Insufficient ETH");

        payTax(tax);

        uint256 excessEth = (msg.value - totalCost > 0) ? msg.value - totalCost : 0;
        address buyer = msg.sender;
        if (excessEth > 0) {
            payable(buyer).transfer(excessEth);
        }
        buyCount += 1;
        buyIndex[buyCount] = buyer;
        buyCost[buyCount] = msg.value - tax;
        userBuysPoints[buyer].push(buyCount);
        userBuyPointsEthPaid[buyer].push(msg.value - tax);

        totalEthPaidUser[buyer] += cost;
        totalEtherCollected += cost;
        cumulativeEthCollected[buyCount] +=
            cumulativeEthCollected[buyCount - 1] +
            msg.value -
            tax;
        calculateUserBuyPointPercentages(buyer);
        userBalanceScaled[buyer] += _amount;
        scaledSupply += _amount;
        _mint(buyer, _amount * 10 ** 18);

        uint256 totalSup = totalSupply();
        uint256 price = calculateCost(1);
        emit tokensBought(_amount, cost, address(this), buyer, totalSup);
        emit Price(price, totalSup, address(this), _amount);

        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
        }
        if (bondingCurveCompleted) {
            sendToDex();
        }
    }
    function calculateUserBuyPointPercentages(address _buyer) internal {
        uint256[] memory userBuyPoints = userBuysPoints[_buyer];
        for (uint256 i = 0; i < userBuyPoints.length; i++) {
            uint256 buyPoint = userBuyPoints[i];
            uint256 cost = buyCost[buyPoint];
            uint256 percentage = (cost * buyPointScale) /
                totalEthPaidUser[_buyer];
            userBuyPointPercentages[_buyer].push(percentage);
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
        (bool success, ) = revenueCollector.call{value: _tax, gas: 50000}("");
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
    function refund() public nonReentrant {
        require(userBuysPoints[msg.sender].length > 0, "No buy");
        require(!userRefunded[msg.sender], "Refunded");
        require(!bondingCurveCompleted, "Curve done");
        (uint256 toTheCurve, uint256 toBeDistributed) = calculateTokensRefund();
        require(
            balanceOf(msg.sender) >= (toTheCurve + toBeDistributed),
            "Low balance"
        );
        uint256 amountToBeRefundedEth = totalEthPaidUser[msg.sender];
        require(address(this).balance >= amountToBeRefundedEth, "Low ETH");
        uint256 tax = (amountToBeRefundedEth * tradeTax) / tradeTaxDivisor;
        uint256 _totalPrecision = (toTheCurve + toBeDistributed);
        uint256 _precision = (balanceOf(msg.sender) > _totalPrecision) ? balanceOf(msg.sender) - (_totalPrecision) : 0;
        payTax(tax);
        _burn(msg.sender, toTheCurve);
        _transfer(msg.sender, address(this), toBeDistributed + _precision);
        uint256[] memory userBuyPoints = userBuysPoints[msg.sender];

        for (uint256 i = 0; i < userBuyPoints.length; i++) {
            uint256 buyPoint = userBuyPoints[i];
            uint256 ethPaidByOtherUsersInBetween = cumulativeEthCollected[
                buyCount
            ] - cumulativeEthCollected[buyPoint];
            for (uint256 j = buyCount; j >= buyPoint; j--) {
                if (buyIndex[j] == address(0)) {
                    break;
                } else if (j == buyPoint) {
                    break;
                } else if (
                    buyIndex[j] == msg.sender || userRefunded[buyIndex[j]]
                ) {
                    continue;
                } else {
                    //check if the user has already been refunded
                    uint256 refundAmountForInstance = (userBuyPointPercentages[
                        buyIndex[j]
                    ][i] * toBeDistributed) / buyPointScale;

                    uint256 refundAmountForUser = (buyCost[j] *
                        refundAmountForInstance) / ethPaidByOtherUsersInBetween;
                    userBalanceScaled[buyIndex[j]] += refundAmountForUser / 10 ** 18;
                    _transfer(address(this), buyIndex[j], refundAmountForUser);
                }
            }
            
            
        }
        userRefunded[msg.sender] = true;
        userBalanceScaled[msg.sender] = 0;  
        MAX_SALE_SUPPLY -= toBeDistributed / 10 ** 18;
        if (MAX_SALE_SUPPLY <= 650_000_000) {
            refundOnly = true;
        }
        uint256 finalRefundAmount = (amountToBeRefundedEth - tax);
        payable(msg.sender).transfer(finalRefundAmount);

        totalEtherCollected -= amountToBeRefundedEth;
        totalRefundedTokens += toTheCurve;
        scaledSupply -= toTheCurve / 10 ** 18;
        uint256 totalSup = totalSupply();
        uint256 price = calculateCost(1);
        emit tokensRefunded(
            toTheCurve,
            finalRefundAmount,
            address(this),
            msg.sender,
            toBeDistributed
        );
        emit Price(price, totalSup, address(this), toTheCurve);
    }
    function calculateTokensRefund() public view returns (uint256, uint256) {
        uint256 userBalance = userBalanceScaled[msg.sender];
        uint256 currentSupply = scaledSupply;
        uint256 totalEthPaidUserVar = totalEthPaidUser[msg.sender];
        uint256 supplyDifference = (totalEthPaidUserVar * 77500 * 3 * SCALE) /
            (40000 * A * 10 ** 5);
        uint256 newSupplyCubed = currentSupply ** 3 - supplyDifference;
        uint256 newSupply = cubeRoot(newSupplyCubed);
        uint256 _amount = currentSupply - newSupply;

        if (_amount > userBalance) {
            _amount = userBalance;
        }
        uint256 amountToBeRedistributed = userBalance - _amount;
        return (_amount * 10 ** 18, amountToBeRedistributed * 10 ** 18);
    }
    function cubeRoot(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 3;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / (z * z) + 2 * z) / 3;
        }
        return y;
    }
    function remainingTokens() public view returns (uint256) {
        return MAX_SALE_SUPPLY - scaledSupply;
    }
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        if (bondingCurveCompleted) {
            super._update(from, to, value);
        } else {
            if (from == address(this) || from == address(0)) {
                super._update(from, to, value);
            } else if (to == address(this) || to == address(0)) {
                super._update(from, to, value);
            } else {
                revert("No transfer");
            }
        }
    }

    function devBuyTokens(
        uint256 _amount,
        uint256 _ethBuy
    ) internal nonReentrant {
        require(_amount > 0, "0 amount");
        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        require(msg.value >= totalCost, "Insufficient ETH");
        payTax(tax);
        uint256 excessEth = (_ethBuy - totalCost > 0) ? _ethBuy - totalCost : 0;
        address buyer = (msg.sender == factoryContract)
            ? devAddress
            : msg.sender;
        if (excessEth > 0) {
            payable(buyer).transfer(excessEth);
        }
        buyCount += 1;
        buyIndex[buyCount] = buyer;
        buyCost[buyCount] = _ethBuy - tax;
        userBuysPoints[buyer].push(buyCount);
        userBuyPointsEthPaid[buyer].push(_ethBuy - tax);

        totalEthPaidUser[buyer] += cost;
        totalEtherCollected += cost;
        cumulativeEthCollected[buyCount] +=
            cumulativeEthCollected[buyCount - 1] +
            _ethBuy -
            tax;
        calculateUserBuyPointPercentages(buyer);
        userBalanceScaled[buyer] += _amount;
        scaledSupply += _amount;
        _mint(buyer, _amount * 10 ** 18);

        uint256 totalSup = totalSupply();
        uint256 price = calculateCost(1);
        emit tokensBought(_amount, cost, address(this), buyer, totalSup);
        emit Price(price, totalSup, address(this), _amount);

        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
        }
        if (bondingCurveCompleted) {
            sendToDex();
        }
    }

}
