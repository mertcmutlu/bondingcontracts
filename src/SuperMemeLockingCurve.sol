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
contract SuperMemeLockingCurve is ERC20, ReentrancyGuard {
    event SentToDex(uint256 ethAmount, uint256 tokenAmount, uint256 timestamp);
    event LockTime(address indexed useraddress, uint256 indexed lockTime);
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
        uint256 lockTime
    );
    event tokensSold(
        uint256 indexed amount,
        uint256 refund,
        address indexed tokenAddress,
        address indexed seller,
        uint256 totalSupply
    );

    uint256 public MAX_SALE_SUPPLY = 1e9; // 1 billion tokens
    uint256 public constant TOTAL_ETHER = 4 ether;
    uint256 public constant SCALE = 1e18; // Scaling factor
    uint256 public constant A = 234375; // Calculated constant A
    uint256 liquidityThreshold = 200_000_000 * 10 ** 18;
    uint256 public constant scaledLiquidityThreshold = 200_000_000;

    uint256 private constant tradeTax = 1000;
    uint256 private constant tradeTaxDivisor = 100000;

    uint256 public totalEtherCollected;
    uint256 public scaledSupply;

    address public devAddress;

    bool public bondingCurveCompleted;
    bool public scaledBondingCurveCompleted;
    bool public dexStage;

    address public revenueCollector;
    uint256 public totalRevenueCollected;
    uint256 public sendDexRevenue = 0.15 ether;

    uint256 public tMax;
    mapping(address => uint256) public lockTime;
    uint256 public previousLockTime;
    uint256 public firstLockTime;
    uint256 public allLocksExpire;
    uint256 public previousLockTimeStamp;
    address public lastUser;

    uint256 public constant scaledBondingCurveThreshold = 650_000_000;
    uint256 public constant voterCut = 0.005 ether;

    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;

    address public factoryContract;
    address[] public sendToDexVoters;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _amount,
        address _devAdress,
        address _revenueCollector,
        uint256 _buyEth,
        uint256 _tMax
    ) public payable ERC20(_name, _symbol) {
        tMax = _tMax;
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
        if (_amount > 0) {
            devBuyTokens(_amount, _buyEth);
        }
    }
    function buyTokens(
        uint256 _amount,
        uint256 _slippage
    ) public payable nonReentrant {
        require(checkRemainingLockTime(msg.sender) == 0, "Already Bought In");
        require(_amount > 0, "0 amount");
        require(!bondingCurveCompleted && !dexStage, "Curve done");

        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        uint256 slippageAmount = (totalCost * _slippage) / 10000;

        require(totalCost <= msg.value, "Insufficient funds");
        require(
            msg.value >= totalCost + slippageAmount,
            "Slippage"
        );
        payTax(tax);
        uint256 excessEth = (msg.value > totalCost) ? msg.value - totalCost : 0;

        calculateLockingDuration(msg.sender);
        totalEtherCollected += cost;
        scaledSupply += _amount;

        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
            _amount = MAX_SALE_SUPPLY - (scaledSupply - _amount);
        } else if (scaledSupply >= scaledBondingCurveThreshold) {
            scaledBondingCurveCompleted = true;
        }

        if (excessEth > 0) {
            payable(msg.sender).transfer(excessEth);
        }

        _mint(msg.sender, _amount * 10 ** 18);
        uint256 totalSup = totalSupply();
        uint256 lastPrice = calculateCost(1);
        
        emit tokensBought(_amount, cost, address(this), msg.sender, lockTime[msg.sender]);
        emit Price(lastPrice, totalSup, address(this), _amount);
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

    function sendToDex() public payable nonReentrant {
        require(
            bondingCurveCompleted || scaledBondingCurveCompleted,
            "Curve not done"
        );
        require(!dexStage, "Already sent");
        if (sendToDexVoters.length == 0) {
            require(balanceOf(msg.sender) >= 1000000 * 10 ** 18, "Low tokens");
            sendToDexVoters.push(msg.sender);
            return;
        } else {
            bool alreadyVoted = false;
            for (uint256 i = 0; i < sendToDexVoters.length; i++) {
                if (sendToDexVoters[i] == msg.sender) {
                    alreadyVoted = true;
                    return;
                }
            }
            if (!alreadyVoted) {
                require(
                    balanceOf(msg.sender) >= 2000000 * 10 ** 18,
                    "Low tokens"
                );
                sendToDexVoters.push(msg.sender);
            }
        }
        if (sendToDexVoters.length >= 5) {
            for (uint256 i = 0; i < sendToDexVoters.length; i++) {
                payable(sendToDexVoters[i]).transfer(voterCut);
            }
            for (uint256 i = 0; i < sendToDexVoters.length; i++) {
                sendToDexVoters.pop();
            }
            sendDexRevenue = (sendDexRevenue * scaledSupply) / MAX_SALE_SUPPLY;
            payTax(sendDexRevenue);
            totalEtherCollected -= sendDexRevenue;
            uint256 _ethAmount = totalEtherCollected - voterCut * 5;
            uint256 _tokenAmount = liquidityThreshold;
            _approve(address(this), address(uniswapV2Router), _tokenAmount);
            uniswapV2Router.addLiquidityETH{value: _ethAmount}(
                address(this),
                _tokenAmount,
                0,
                0,
                address(this),
                block.timestamp + 100
            );
            dexStage = true;
            emit SentToDex(_ethAmount, _tokenAmount, block.timestamp);
        }
    }

    function sellTokens(uint256 _amount, uint256 _minimumEthRequired) public nonReentrant {
        require(_amount > 0, "0 amount");
        require(!bondingCurveCompleted && !dexStage, "Curve done");
        uint256 refund = calculateRefund(_amount);
        uint256 tax = (refund * tradeTax) / tradeTaxDivisor;
        uint256 netRefund = refund - tax;
        require(address(this).balance >= netRefund, "Low ETH");
        require(balanceOf(msg.sender) >= _amount * 10 ** 18, "Low tokens");
        require(netRefund >= _minimumEthRequired,   "Slippage");
        payTax(tax);
        _burn(msg.sender, _amount * 10 ** 18);
        totalEtherCollected -= (netRefund + tax);
        scaledSupply -= _amount;

        payable(msg.sender).transfer(netRefund);
        if (
            scaledSupply < scaledBondingCurveThreshold &&
            scaledBondingCurveCompleted
        ) {
            scaledBondingCurveCompleted = false;
        }
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
        if (
            (from != address(this) && from != address(0)) &&
            to == address(this) &&
            !dexStage
        ) {
            revert("No transfer new");
        }
        if (dexStage) {
            if (checkRemainingLockTime(from) == 0) {
                super._update(from, to, value);
            } else {
                revert("No transfer");
            }
        } else {
            if (
                from == address(this) || from == address(0) || to == address(0)
            ) {
                if (checkRemainingLockTime(from) == 0) {
                    super._update(from, to, value);
                } else {
                    revert("No transfer");
                }
            } else {
                revert("No transfer");
            }
        }
    }
    function remainingTokens() public view returns (uint256) {
        return MAX_SALE_SUPPLY - scaledSupply;
    }
    function calculateLockingDuration(
        address _address
    ) internal returns (uint256) {
        if (allLocksExpire != 0 && allLocksExpire < block.timestamp) {
            lockTime[_address] = 0;
            return lockTime[_address];
        }
        if (previousLockTime == 0 && allLocksExpire == 0) {
            previousLockTime = tMax;
            lockTime[_address] = block.timestamp + tMax;
            firstLockTime = block.timestamp;
            allLocksExpire = block.timestamp + tMax;
            previousLockTimeStamp = block.timestamp;
            lastUser = _address;
            return lockTime[_address];
        } else {
            uint256 s = scaledSupply - 200_000_000;
            uint256 timePassed = block.timestamp - firstLockTime;
            uint256 newLockTime = checkRemainingLockTime(lastUser);
            uint256 scaledReduction = (s * newLockTime) /
                (MAX_SALE_SUPPLY*16);

            newLockTime = (scaledReduction > previousLockTime)
                ? 0
                : newLockTime - scaledReduction;
            if (firstLockTime + timePassed > block.timestamp + newLockTime) {
                previousLockTimeStamp = block.timestamp;
                lockTime[_address] = 0;
                return lockTime[_address];
            }
            lockTime[_address] = block.timestamp + newLockTime;
            previousLockTimeStamp = block.timestamp;
            previousLockTime = newLockTime;
            lastUser = _address;
            return lockTime[_address];
        }
    }
    function checkRemainingLockTime(
        address _address
    ) public view returns (uint256) {
        if (allLocksExpire != 0 && allLocksExpire <= block.timestamp) {
            return 0;
        }
        if (lockTime[_address] != 0) {
            return
                (lockTime[_address] < block.timestamp)
                    ? 0
                    : lockTime[_address] - block.timestamp;
        } else {
            return 0;
        }
    }

    function calculateNextLockTime() public view returns (uint256) {
    if (allLocksExpire != 0 && allLocksExpire < block.timestamp) {
        return 0;
    }
    uint256 tempPreviousLockTime = previousLockTime;
    uint256 tempFirstLockTime = firstLockTime;
    uint256 tempAllLocksExpire = allLocksExpire;
    uint256 s = scaledSupply - 200_000_000;

    if (tempPreviousLockTime == 0 && tempAllLocksExpire == 0) {
        return block.timestamp + tMax;
    } else {
        uint256 timePassed = block.timestamp - tempFirstLockTime;
        uint256 newLockTime = checkRemainingLockTime(lastUser);
        uint256 scaledReduction = (s * newLockTime) /
            (MAX_SALE_SUPPLY*16);

        newLockTime = (scaledReduction > tempPreviousLockTime)
            ? 0
            : newLockTime - scaledReduction;
        if (tempFirstLockTime + timePassed > block.timestamp + newLockTime) {
            return 0;
        }

        return block.timestamp + newLockTime;
    }
}
    function getSendToDexVoters() public view returns (address[] memory) {
        return sendToDexVoters;
    }


    function devBuyTokens(
        uint256 _amount,
        uint256 _buyEth
    ) internal nonReentrant {
        require(_amount > 0, "0 amount");
        uint256 cost = calculateCost(_amount);
        uint256 tax = (cost * tradeTax) / tradeTaxDivisor;
        uint256 totalCost = cost + tax;
        require(msg.value >= totalCost, "Insufficient funds");
        payTax(tax);
        uint256 excessEth = (_buyEth > totalCost) ? _buyEth - totalCost : 0;
                address buyer = (msg.sender == factoryContract)
            ? devAddress
            : msg.sender;

        calculateLockingDuration(buyer);
        totalEtherCollected += cost;
        scaledSupply += _amount;

        if (scaledSupply >= MAX_SALE_SUPPLY) {
            bondingCurveCompleted = true;
            _amount = MAX_SALE_SUPPLY - (scaledSupply - _amount);
        } else if (scaledSupply >= scaledBondingCurveThreshold) {
            scaledBondingCurveCompleted = true;
        }

        if (excessEth > 0) {
            payable(buyer).transfer(excessEth);
        }

        _mint(buyer, _amount * 10 ** 18);
        uint256 totalSup = totalSupply();
        uint256 lastPrice = calculateCost(1);
        
        emit tokensBought(_amount, cost, address(this), buyer, lockTime[buyer]);
        emit Price(lastPrice, totalSup, address(this), _amount);
    }
}
