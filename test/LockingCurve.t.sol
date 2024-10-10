// Solidity Version: 0.8.0


pragma solidity ^0.8.0;



import "forge-std/Test.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/SuperMemeLockingCurve.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
//import uniswap pair
import {IUniswapV2Pair} from "../src/Interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";
import {SuperMemeTokenCalculator} from "../src/SuperMemeTokenCalculator.sol";

contract LockingCurve is Test {
    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;
    IUniswapV2Pair public pair;
    IUniswapFactory public unifactory;
    IUniswapV2Router02 public router;
    SuperMemeTokenCalculator public tokenCalculator;

    SuperMemeLockingCurve public lockingCurve;

    uint256 public createTokenRevenue = 0.00001 ether;
    address private constant BASE_ADDRESS =
        0x1234567890123456789012345678901234567890; // Example base address

    address public owner = address(0x123);
    address public addr1 = address(0x456);
    address public addr2 = address(0x789);
    address public addr3 = address(0x101112);
    address public addr4 = address(0x131415);
    address public addr5 = address(0x161718);
    address public addr6 = address(0x192021);
    address public addr7 = address(0x222324);

    address[] public addresses;

    function generateAddress(uint256 index) public pure returns (address) {
        // Generate an address based on a base address and an index
        // This is just a simple example and does not produce unique private keys
        return
            address(
                uint160(
                    uint256(keccak256(abi.encodePacked(BASE_ADDRESS, index)))
                )
            );
    }

    function generateMultipleAddresses(
        uint256 count
    ) public returns (address[] memory) {
        require(count > 0, "Count must be greater than zero");

        address[] memory addresses = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addresses[i] = generateAddress(i);
            vm.deal(addresses[i], 1000 ether);
        }

        return addresses;
    }

    function setUp() public {
        addresses = generateMultipleAddresses(5);

        //base mainnet router address 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        //base sepolia router address 0x6682375ebC1dF04676c0c5050934272368e6e883

        uint256 createTokenRevenue = 0.00001 ether;
        router = IUniswapV2Router02(
            address(0x6682375ebC1dF04676c0c5050934272368e6e883)
        );
        address fakeContract = address(0x12123123);
        unifactory = IUniswapFactory(
            address(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6)
        );


        vm.deal(owner, 1000 ether);
        vm.deal(addr1, 1000 ether);
        vm.deal(addr2, 1000 ether);
        vm.deal(addr3, 1000 ether);
        vm.deal(addr4, 1000 ether);
        vm.deal(addr5, 1000 ether);
        vm.deal(addr6, 1000 ether);
        vm.deal(addr7, 1000 ether);

        tokenCalculator = new SuperMemeTokenCalculator();

        lockingCurve = new SuperMemeLockingCurve(
            "SuperMeme",
            "MEME",
            0,
            owner,
            address(0x123),
            0,
            1 days
        );

        vm.stopPrank();
    }
    function secondsToHumanReadable(
        uint256 totalSeconds
    ) public pure returns (string memory) {
        if (totalSeconds == 0) {
            return "0 seconds";
        }

        uint256 secondsInMinute = 60;
        uint256 secondsInHour = 3600;
        uint256 secondsInDay = 86400;
        uint256 days1 = totalSeconds / secondsInDay;
        uint256 hours1 = (totalSeconds % secondsInDay) / secondsInHour;
        uint256 minutes1 = (totalSeconds % secondsInHour) / secondsInMinute;
        uint256 seconds1 = totalSeconds % secondsInMinute;
        //return 0 as zero as well

        return
            string(
                abi.encodePacked(
                    days1 > 0
                        ? string(abi.encodePacked(uint2str(days1), " days, "))
                        : "",
                    hours1 > 0
                        ? string(abi.encodePacked(uint2str(hours1), " hours, "))
                        : "",
                    minutes1 > 0
                        ? string(
                            abi.encodePacked(uint2str(minutes1), " minutes, ")
                        )
                        : "",
                    seconds1 > 0
                        ? string(
                            abi.encodePacked(uint2str(seconds1), " seconds")
                        )
                        : ""
                )
            );
    }

    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        return string(bstr);
    }

    function testDeploy() public {
        assertEq(lockingCurve.revenueCollector(), address(0x123));
    }

    function testBuyCheckLocks() public {
        vm.startPrank(addr1);
        uint256 amount = 10000000;
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        uint256 nextLockTime = lockingCurve.calculateNextLockTime();
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        uint256 lockTime = lockingCurve.lockTime(addr1);
        assertEq(lockTime, nextLockTime);
        uint256 pureLockTime = lockTime - block.timestamp;
        console.log("lockTime", lockTime);
        console.log("pureLockTime", secondsToHumanReadable(pureLockTime));
        vm.stopPrank();
    }

    function testBuyCheckLocksMultiple() public {
        //loop throuugh addresses
        for (uint256 i = 0; i < addresses.length; i++) {
            console.log("user numner", i);
            vm.startPrank(addresses[i]);
            uint256 amount = 10000000;
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            console.log("block timestamp", block.timestamp);
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            console.log("block timestamp", block.timestamp);
            console.log("lockTime", lockTime);
            console.log("nextLockTime", nextLockTime);
            assertEq(lockTime, nextLockTime);
            uint256 initLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 scaledSupply = lockingCurve.scaledSupply();
            uint256 totalSupply = lockingCurve.MAX_SALE_SUPPLY();
            //log the curves progression please
            uint256 curveProgression = (scaledSupply * 100) / totalSupply;
            console.log("curveProgression", curveProgression);
            console.log("pureLockTime", secondsToHumanReadable(initLockTime));
            console.log("token bought amount", amount);
            console.log("     ");
            vm.stopPrank();
        }
    }

    function testBuyChecksPassTime() public {
        //loop throuugh 5 users and buy and pass 1 day for each
        for (uint256 i = 0; i < 5; i++) {
            console.log("user number", i);
            vm.startPrank(addresses[i]);
            uint256 amount = 10000000;
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            console.log("enters next");
            uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            console.log("exits next");
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            console.log("user", i, "bought tokens");
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            console.log("lockTime", lockTime);
            assertEq(lockTime, nextLockTime);
            uint256 initLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 scaledSupply = lockingCurve.scaledSupply();
            uint256 totalSupply = lockingCurve.MAX_SALE_SUPPLY();
            //log the curves progression please

            uint256 curveProgression = (scaledSupply * 100) / totalSupply;
            vm.warp(block.timestamp + 1 days);
            console.log("one day passes", block.timestamp);
            console.log("lock time underflow", lockTime);
            console.log("block timestamp", block.timestamp);
            uint256 remainingLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;

            console.log("before underfow", remainingLockTime);
            console.log(
                "remainingLockTime",
                secondsToHumanReadable(remainingLockTime)
            );
            vm.stopPrank();
        }

    }

    function testOneUserBuysCheckDecreasingLockTime() public {
        vm.startPrank(addr1);
        uint256 amount = 10000000;
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        uint256 nextLockTime = lockingCurve.calculateNextLockTime();
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        for (uint256 i = 0; i < 5; i++) {
            uint256 newTimeStamp = 1 days * i;
            vm.warp(newTimeStamp);
            console.log("one day passes", block.timestamp);
            uint256 lockTime = lockingCurve.lockTime(addr1);
            uint256 remainingLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 remaininLockTimeFromContract = lockingCurve
                .checkRemainingLockTime(addr1);
            assertEq(remainingLockTime, remaininLockTimeFromContract);
            console.log(
                "remainingLockTime",
                secondsToHumanReadable(remainingLockTime)
            );
        }
        vm.stopPrank();
    }

    function testMultipleUserBuysCheckDecreasingLockTime() public {
        //loop throuugh 5 users and buy and pass 1 day for each
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(addresses[i]);
            uint256 amount = 50000000;
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[i]), amount * 10 ** 18);
            console.log("user", i, "bought tokens");
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            assertEq(lockTime, nextLockTime);
            uint256 initLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 scaledSupply = lockingCurve.scaledSupply();
            uint256 totalSupply = lockingCurve.MAX_SALE_SUPPLY();
            //log the curves progression please

            uint256 curveProgression = (scaledSupply * 100) / totalSupply;

            uint256 remainingLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 remaininLockTimeFromContract = lockingCurve
                .checkRemainingLockTime(addresses[i]);
            assertEq(remainingLockTime, remaininLockTimeFromContract);
            //log the remaining lock time for all users
            for (uint256 j = 0; j < 5; j++) {
                lockTime = lockingCurve.lockTime(addresses[j]);
                remainingLockTime = (lockTime < block.timestamp)
                    ? 0
                    : lockTime - block.timestamp;
                console.log(
                    "user",
                    j,
                    "remainingLockTime",
                    secondsToHumanReadable(remainingLockTime)
                );
            }
            vm.warp(block.timestamp + 8 hours);
            console.log("8 hours passes", block.timestamp);
            vm.stopPrank();
        }
    }

    function testOneUserBuysTransfer() public {
        vm.startPrank(addr1);
        uint256 amount = 10000000;
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
               uint256 nextLockTime = lockingCurve.calculateNextLockTime();
        uint256 totalCostWithSlippage = totalCost + slippage;
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(addr1), amount * 10 ** 18);

        uint256 lockTime = lockingCurve.lockTime(addr1);
        assertEq(lockTime, nextLockTime);
        uint256 initLockTime = (lockTime < block.timestamp)
            ? 0
            : lockTime - block.timestamp;
        uint256 scaledSupply = lockingCurve.scaledSupply();
        uint256 totalSupply = lockingCurve.MAX_SALE_SUPPLY();
        vm.expectRevert();
        lockingCurve.transfer(addr2, amount);
        vm.expectRevert();
        lockingCurve.sellTokens(amount, 100);
        vm.expectRevert();
        lockingCurve.transferFrom(addr1, addr2, amount);
        vm.warp(block.timestamp + 4 days);
        console.log(lockingCurve.balanceOf(addr1));
        lockingCurve.sellTokens(amount / 2, 100);
        assertEq(lockingCurve.balanceOf(addr1), (amount / 2) * 10 ** 18);
        vm.expectRevert();
        lockingCurve.transfer(addr2, amount);
        vm.expectRevert();
        lockingCurve.transfer(address(lockingCurve), (amount / 2) * 10 ** 18);
        vm.stopPrank();
    }

    function testBuyMultipleUsersSellAfterLockExpiry() public {
        //loop throuugh 5 users and buy and pass 1 day for each
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(addresses[i]);
            uint256 amount = 50000000;
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
                   uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[i]), amount * 10 ** 18);

            console.log("user", i, "bought tokens");
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            assertEq(lockTime, nextLockTime);
            uint256 initLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 scaledSupply = lockingCurve.scaledSupply();
            uint256 totalSupply = lockingCurve.MAX_SALE_SUPPLY();
            //log the curves progression please

            uint256 curveProgression = (scaledSupply * 100) / totalSupply;

            uint256 remainingLockTime = (lockTime < block.timestamp)
                ? 0
                : lockTime - block.timestamp;
            uint256 remaininLockTimeFromContract = lockingCurve
                .checkRemainingLockTime(addresses[i]);
            console.log("before asser");
            assertEq(remainingLockTime, remaininLockTimeFromContract);
            //log the remaining lock time for all users
            for (uint256 j = 0; j < 5; j++) {
                lockTime = lockingCurve.lockTime(addresses[j]);
                remainingLockTime = (lockTime < block.timestamp)
                    ? 0
                    : lockTime - block.timestamp;
                console.log(
                    "user",
                    j,
                    "remainingLockTime",
                    secondsToHumanReadable(remainingLockTime)
                );
            }
        }
        vm.warp(block.timestamp + 1 days);
        for (uint256 j = 0; j < 5; j++) {
            uint256 lockTime = lockingCurve.checkRemainingLockTime(
                addresses[j]
            );
            console.log(
                "user",
                j,
                "remainingLockTime",
                secondsToHumanReadable(lockTime)
            );
        }
    }

    function testCheckLocksAtDexStage() public {
        //buy with 5 users 2 hours apart each
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(addresses[i]);
            uint256 amount = 150000000;
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
                   uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[i]), amount * 10 ** 18);
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            assertEq(lockTime, nextLockTime);
            uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
                addresses[i]
            );
            vm.warp(block.timestamp + 2 hours);
            console.log("curve status", lockingCurve.scaledSupply());
            vm.stopPrank();
        }
        for (uint256 j = 0; j < 5; j++) {
            vm.startPrank(addresses[j]);
            console.log("user", j, "voting to send to dex");
            lockingCurve.sendToDex();
            vm.stopPrank();
        }
        //check if the pool exists
        address[] memory path = new address[](2);
        path[0] = address(lockingCurve);
        path[1] = router.WETH();

        uint256[] memory amounts = router.getAmountsOut(10000000 ether, path);
        console.log("amounts", amounts[0]);
        console.log("amounts", amounts[1]);
        //address 1 tries to sell tokens in dex
        vm.startPrank(addresses[0]);
        lockingCurve.approve(address(router), 10000000 ether);
        vm.expectRevert();
        router.swapExactTokensForETH(
            10000000 ether,
            0,
            path,
            addresses[0],
            block.timestamp + 10 minutes
        );
        vm.warp(block.timestamp + 10 days);
        console.log(
            "remainingLockTime",
            lockingCurve.checkRemainingLockTime(addresses[0])
        );
        console.log("balance of user 1", lockingCurve.balanceOf(addresses[0]));
        console.log("dex stage", lockingCurve.dexStage());
        lockingCurve.approve(address(router), 10000000 ether);
        amounts = router.swapExactTokensForETH(
            10000000 ether,
            10000 gwei,
            path,
            addresses[0],
            block.timestamp + 10 minutes + 10 days
        );
        console.log("amounts", amounts[0]);
        console.log("amounts", amounts[1]);
    }

    function testSendToDexCase1() public {
        //buy with 5 users 2 hours apart each
        uint256 amount = 150000000;
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        for (uint256 i = 0; i < 5; i++) {
            console.log("user number", i);
            amount = 150000000;
            cost = lockingCurve.calculateCost(amount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            totalCostWithSlippage = totalCost + slippage;
                   uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            vm.startPrank(addresses[i]);

            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[i]), amount * 10 ** 18);
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            assertEq(lockTime, nextLockTime);
            uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
                addresses[i]
            );
            vm.warp(block.timestamp + 2 hours);
            console.log("curve status", lockingCurve.scaledSupply());
            vm.stopPrank();
        }

        //user 1 and 2 votes to send to dex
        for (uint256 j = 0; j < 2; j++) {
            vm.startPrank(addresses[j]);
            console.log("user", j, "voting to send to dex");
            lockingCurve.sendToDex();
            vm.stopPrank();
        }
        assert(lockingCurve.dexStage() == false);
        assert(lockingCurve.scaledBondingCurveCompleted() == true);

        vm.warp(block.timestamp + 10 days);

        //user 1 and 2 sell their tokens
        for (uint256 j = 0; j < 2; j++) {
            vm.startPrank(addresses[j]);
            console.log("user", j, "selling tokens");
            lockingCurve.sellTokens(amount, 0);
            vm.stopPrank();
        }
        assert(lockingCurve.dexStage() == false);
        assert(lockingCurve.bondingCurveCompleted() == false);
        assert(lockingCurve.scaledBondingCurveCompleted() == true);




        //user 1 and 2 rebuy
        for (uint256 j = 0; j < 2; j++) {
            vm.startPrank(addresses[j]);
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[j]), amount * 10 ** 18);
            vm.stopPrank();
        }
        console.log("scaledBondingCurveCompleted", lockingCurve.scaledBondingCurveCompleted());
        assertEq(lockingCurve.scaledBondingCurveCompleted(), true);

        //check if users received their eth rewards
        uint256[] memory eth_amounts = new uint256[](5);
        for (uint256 j = 0; j < 5; j++) {
            eth_amounts[j] = address(addresses[j]).balance;
        }

        //all users vote to send to dex
        for (uint256 j = 0; j < 5; j++) {
            vm.startPrank(addresses[j]);
            lockingCurve.sendToDex();
            vm.stopPrank();
        }

        for (uint256 j = 0; j < 5; j++) {
            assertGt(address(addresses[j]).balance, eth_amounts[j]);
        }
        assertEq(lockingCurve.dexStage(), true);
        assertEq(lockingCurve.bondingCurveCompleted(), false);

        vm.startPrank(addresses[0]);
        address[] memory path = new address[](2);
        path[0] = address(lockingCurve);
        path[1] = router.WETH();
        uint256[] memory amounts = router.getAmountsOut(10000000 ether, path);

        lockingCurve.approve(address(router), 10000000 ether);
        amounts = router.swapExactTokensForETH(
            10000000 ether,
            10000 gwei,
            path,
            addresses[0],
            block.timestamp + 10 minutes
        );
        console.log("amounts", amounts[0]);
        console.log("amounts", amounts[1]);
        vm.stopPrank();

        //check if the users can sellTokens to the locking curve
        for (uint256 j = 0; j < 5; j++) {
            vm.startPrank(addresses[j]);
            vm.expectRevert();
            lockingCurve.sellTokens(amount, 0);
            vm.stopPrank();
        }
        console.log("scaledBondingCurveCompleted", lockingCurve.scaledBondingCurveCompleted());
        assertEq(lockingCurve.dexStage(), true);

        //check if the users can buy tokens from the locking curve
        for (uint256 j = 0; j < 5; j++) {
            vm.startPrank(addresses[j]);
            amount = 150000000;
            cost = lockingCurve.calculateCost(amount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            totalCostWithSlippage = totalCost + slippage;
            vm.expectRevert();
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            vm.stopPrank();
        }
    }

    function testCase2Locking() public {
               //buy with 5 users 2 hours apart each
        uint256 amount = 150000000;
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        for (uint256 i = 0; i < 5; i++) {
            amount = 150000000;
            cost = lockingCurve.calculateCost(amount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            totalCostWithSlippage = totalCost + slippage;
                   uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            vm.startPrank(addresses[i]);

            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(addresses[i]), amount * 10 ** 18);
            uint256 lockTime = lockingCurve.lockTime(addresses[i]);
            assertEq(lockTime, nextLockTime);
            uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
                addresses[i]
            );
            uint256 passTime =  2 hours * (i +1);
            vm.warp(block.timestamp + passTime);
            console.log("current timestamp", block.timestamp);
            console.log("remainingLockTime", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(addresses[i])));
            vm.stopPrank();
        }


        console.log("scaledBondingCurveCompleted", lockingCurve.scaledBondingCurveCompleted());
        vm.startPrank(addresses[3]);
        amount = 150000000;
        lockingCurve.sellTokens(amount, 100);
        assertEq(lockingCurve.balanceOf(addresses[3]), 0);
    }

    function testSinanCase3() public {
        uint256[] memory initialLocks = new uint256[](40);
        uint256[] memory buyTimes = new uint256[](40);
        uint256 totalHoursPassed = 0;
        address[] memory new_addresses = generateMultipleAddresses(40);
        //deal eth to them
        for (uint256 i = 0; i < new_addresses.length; i++) {
            vm.deal(new_addresses[i], 1 ether);
        }

        //user 0 buys 0.01 ether worth of tokens
        vm.startPrank(new_addresses[0]);
        uint256 scaledSupply = lockingCurve.scaledSupply();
        uint256 amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.01 ether);
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        uint256 nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[0] = nextLockTime - block.timestamp;
        buyTimes[0] = block.timestamp;
        console.log("user 0 is going to buy 0.01 ether worth of tokens");
        console.log("calculated next lock for user 0 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[0]), amount * 10 ** 18);
        uint256 lockTime = lockingCurve.lockTime(new_addresses[0]);
        console.log("actual lock time for user 0 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[0]
        );
        console.log("contract lock remaining time for user 0 is", secondsToHumanReadable(contractLockRemaining));

        //user 2 buys 0.01 ether worth of tokens
        vm.startPrank(new_addresses[1]);
        scaledSupply = lockingCurve.scaledSupply();
        amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.01 ether);
        cost = lockingCurve.calculateCost(amount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        totalCostWithSlippage = totalCost + slippage;
        nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[1] = nextLockTime- block.timestamp;
        buyTimes[1] = block.timestamp;
        console.log("user 1 is going to buy 0.01 ether worth of tokens");
        console.log("calculated next lock for user 1 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[1]), amount * 10 ** 18);
        lockTime = lockingCurve.lockTime(new_addresses[1]);
        console.log("actual lock time for user 1 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[1]
        );
        console.log("contract lock remaining time for user 1 is", secondsToHumanReadable(contractLockRemaining));

        // 2 hours passes
        console.log("   ");
        console.log("1 hours passes");
        console.log("   ");
        vm.warp(block.timestamp + 1 hours);
        totalHoursPassed += 1;
        assertEq(block.timestamp- buyTimes[0], 1 hours);

        // user 2,3,4 buys 0.01 ether worth of tokens
        for (uint256 i = 2; i < 5; i++) {
            vm.startPrank(new_addresses[i]);
            scaledSupply = lockingCurve.scaledSupply();
            amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.01 ether);
            cost = lockingCurve.calculateCost(amount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            totalCostWithSlippage = totalCost + slippage;
            nextLockTime = lockingCurve.calculateNextLockTime();
            initialLocks[i] = nextLockTime- block.timestamp;
            buyTimes[i] = block.timestamp;
            console.log("user", i, "is going to buy 0.01 ether worth of tokens");
            console.log("calculated next lock for user", i, "is", secondsToHumanReadable(nextLockTime - block.timestamp));
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(new_addresses[i]), amount * 10 ** 18);
            lockTime = lockingCurve.lockTime(new_addresses[i]);
            console.log("actual lock time for user", i, "is,", secondsToHumanReadable(lockTime- block.timestamp));
            assertEq(lockTime, nextLockTime);
            contractLockRemaining = lockingCurve.checkRemainingLockTime(
                new_addresses[i]
            );
            console.log("contract lock remaining time for user", i, "is", secondsToHumanReadable(contractLockRemaining));
            vm.stopPrank();
        }
        

        vm.startPrank(new_addresses[5]);
        //user buys 0.01 ether
        scaledSupply = lockingCurve.scaledSupply();
        amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.01 ether);
        cost = lockingCurve.calculateCost(amount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        totalCostWithSlippage = totalCost + slippage;
        nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[5] = nextLockTime- block.timestamp;
        buyTimes[5] = block.timestamp;
        console.log("USER 5 is going to buy 0.01 ether worth of tokens");
        console.log("calculated next lock for USER 5 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[5]), amount * 10 ** 18);
        lockTime = lockingCurve.lockTime(new_addresses[5]);
        console.log("actual lock time for USER 5 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[5]
        );
        console.log("contract lock remaining time for USER 5 is", secondsToHumanReadable(contractLockRemaining));
        vm.stopPrank();
        


        // 1 hour passes
        console.log("   ");
        console.log("1 hour passes");
        console.log("   ");
        vm.warp(block.timestamp + 1 hours);
        totalHoursPassed += 1;
        assertEq(block.timestamp- buyTimes[0], 2 hours);

        // user ,6,7,8,9 buys 0.02 ether worth of tokens
        for (uint256 i = 6; i < 10; i++) {
            console.log("     ");
            vm.startPrank(new_addresses[i]);
            scaledSupply = lockingCurve.scaledSupply();
            amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.02 ether);
            cost = lockingCurve.calculateCost(amount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            totalCostWithSlippage = totalCost + slippage;
            nextLockTime = lockingCurve.calculateNextLockTime();
            initialLocks[i] = nextLockTime- block.timestamp;
            buyTimes[i] = block.timestamp;
            console.log("user", i, "is going to buy 0.02 ether worth of tokens");
            console.log("calculated next lock for user", i, "is", secondsToHumanReadable(nextLockTime - block.timestamp));
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(lockingCurve.balanceOf(new_addresses[i]), amount * 10 ** 18);
            lockTime = lockingCurve.lockTime(new_addresses[i]);
            console.log("actual lock time for user", i, "is,", secondsToHumanReadable(lockTime- block.timestamp));
            assertEq(lockTime, nextLockTime);
            contractLockRemaining = lockingCurve.checkRemainingLockTime(
                new_addresses[i]
            );
            console.log("contract lock remaining time for user", i, "is", secondsToHumanReadable(contractLockRemaining));
            vm.stopPrank();
        }

        //1 hour passes
        console.log("   ");
        console.log("1 hour passes");
        console.log("   ");
        vm.warp(block.timestamp + 1 hours);
        totalHoursPassed += 1;
        assertEq(block.timestamp- buyTimes[0], 3 hours);
        
        console.log(" ");
        console.log("total hours passed", totalHoursPassed);
        console.log(" ");
        for (uint256 i = 0; i < 9; i++) {
            console.log("    ");
            console.log("user",(i), "remaining lock time is", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(new_addresses[i])));
            uint256 passedTime = block.timestamp - buyTimes[i];
            console.log("user", (i),secondsToHumanReadable(passedTime), " passed since initial lock");
            console.log("user", (i), "initial lock time was", secondsToHumanReadable(initialLocks[i]));
        }
    
    vm.startPrank(new_addresses[10]);
    //user buys 0.5 ether
    scaledSupply = lockingCurve.scaledSupply();
    amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.5 ether);
    cost = lockingCurve.calculateCost(amount);
    tax = cost / 100;
    totalCost = cost + tax;
    slippage = totalCost / 100;
    totalCostWithSlippage = totalCost + slippage;
    nextLockTime = lockingCurve.calculateNextLockTime();
    initialLocks[10] = nextLockTime- block.timestamp;
    buyTimes[10] = block.timestamp;
    console.log("USER 10 is going to buy 0.5 ether worth of tokens");
    console.log("calculated next lock for USER 10 is", secondsToHumanReadable(nextLockTime - block.timestamp));
    lockingCurve.buyTokens{value: totalCostWithSlippage}(
        amount,
        100
    );
    assertEq(lockingCurve.balanceOf(new_addresses[10]), amount * 10 ** 18);
    lockTime = lockingCurve.lockTime(new_addresses[10]);
    console.log("actual lock time for USER 10 is,", secondsToHumanReadable(lockTime- block.timestamp));
    assertEq(lockTime, nextLockTime);
    contractLockRemaining = lockingCurve.checkRemainingLockTime(
        new_addresses[10]
    );
    console.log("contract lock remaining time for USER 10 is", secondsToHumanReadable(contractLockRemaining));
    vm.stopPrank();

    //0.03 ether
    vm.startPrank(new_addresses[11]);
    //user buys 0.03 ether
    scaledSupply = lockingCurve.scaledSupply();
    amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.03 ether);
    cost = lockingCurve.calculateCost(amount);
    tax = cost / 100;
    totalCost = cost + tax;
    slippage = totalCost / 100;
    totalCostWithSlippage = totalCost + slippage;
    nextLockTime = lockingCurve.calculateNextLockTime();
    initialLocks[11] = nextLockTime- block.timestamp;
    buyTimes[11] = block.timestamp;
    console.log("USER 11 is going to buy 0.03 ether worth of tokens");
    console.log("calculated next lock for USER 11 is", secondsToHumanReadable(nextLockTime - block.timestamp));
    lockingCurve.buyTokens{value: totalCostWithSlippage}(
        amount,
        100
    );
    assertEq(lockingCurve.balanceOf(new_addresses[11]), amount * 10 ** 18);
    lockTime = lockingCurve.lockTime(new_addresses[11]);
    console.log("actual lock time for USER 11 is,", secondsToHumanReadable(lockTime- block.timestamp));
    assertEq(lockTime, nextLockTime);
    contractLockRemaining = lockingCurve.checkRemainingLockTime(
        new_addresses[11]
    );
    console.log("contract lock remaining time for USER 11 is", secondsToHumanReadable(contractLockRemaining));
    vm.stopPrank();

    //2 hours passes
    console.log("   ");
    console.log("2 hours passes");
    console.log("   ");

    vm.warp(block.timestamp + 2 hours);
    totalHoursPassed += 2;
    assertEq(block.timestamp- buyTimes[0], 5 hours);

    //users  12 13 14 buys 0.03 ether
    for  (uint256 i = 12; i < 15; i++) {
        console.log("     ");
        vm.startPrank(new_addresses[i]);
        scaledSupply = lockingCurve.scaledSupply();
        amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.03 ether);
        cost = lockingCurve.calculateCost(amount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        totalCostWithSlippage = totalCost + slippage;
        nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[i] = nextLockTime- block.timestamp;
        buyTimes[i] = block.timestamp;
        console.log("user", i, "is going to buy 0.03 ether worth of tokens");
        console.log("calculated next lock for user", i, "is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[i]), amount * 10 ** 18);
        lockTime = lockingCurve.lockTime(new_addresses[i]);
        console.log("actual lock time for user", i, "is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[i]
        );
        console.log("contract lock remaining time for user", i, "is", secondsToHumanReadable(contractLockRemaining));
        vm.stopPrank();
    }

    //2 hours passes
    console.log("   ");
    console.log("2 hours passes");
    console.log("   ");

    vm.warp(block.timestamp + 2 hours);
    totalHoursPassed += 2;
    assertEq(block.timestamp- buyTimes[0], 7 hours);

    //user 15 buys 0.1 ether
    vm.startPrank(new_addresses[15]);
    scaledSupply = lockingCurve.scaledSupply();
    amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.1 ether);
    cost = lockingCurve.calculateCost(amount);
    tax = cost / 100;
    totalCost = cost + tax;
    slippage = totalCost / 100;
    totalCostWithSlippage = totalCost + slippage;
    nextLockTime = lockingCurve.calculateNextLockTime();
    initialLocks[15] = nextLockTime- block.timestamp;
    buyTimes[15] = block.timestamp;
    console.log("user 15 is going to buy 0.1 ether worth of tokens");
    console.log("calculated next lock for user 15 is", secondsToHumanReadable(nextLockTime - block.timestamp));
    lockingCurve.buyTokens{value: totalCostWithSlippage}(
        amount,
        100
    );

    //user 16 buys 0.04 ether
    vm.startPrank(new_addresses[16]);
    scaledSupply = lockingCurve.scaledSupply();
    amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.04 ether);
    cost = lockingCurve.calculateCost(amount);
    tax = cost / 100;
    totalCost = cost + tax;
    slippage = totalCost / 100;
    totalCostWithSlippage = totalCost + slippage;
    nextLockTime = lockingCurve.calculateNextLockTime();
    initialLocks[16] = nextLockTime- block.timestamp;
    buyTimes[16] = block.timestamp;
    console.log("user 16 is going to buy 0.04 ether worth of tokens");
    console.log("calculated next lock for user 16 is", secondsToHumanReadable(nextLockTime - block.timestamp));
    lockingCurve.buyTokens{value: totalCostWithSlippage}(
        amount,
        100
    );

    //3 hours passes
    console.log("   ");
    console.log("3 hours passes");
    console.log("   ");
    
    vm.warp(block.timestamp + 3 hours);
    totalHoursPassed += 3;
    assertEq(block.timestamp- buyTimes[0], 10 hours);

    console.log(" ");
    console.log("total hours passed", totalHoursPassed);
    console.log(" ");
    for (uint256 i = 0; i < 17; i++) {
        console.log("    ");
        console.log("user",(i), "remaining lock time is", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(new_addresses[i])));
        uint256 passedTime = block.timestamp - buyTimes[i];
        console.log("user", (i),secondsToHumanReadable(passedTime), " passed since initial lock");
        console.log("user", (i), "initial lock time was", secondsToHumanReadable(initialLocks[i]));
    }
    console.log("passed time", secondsToHumanReadable(block.timestamp- buyTimes[0]));
    }


    function testSinanCase4() public {
        uint256[] memory initialLocks = new uint256[](5);
        uint256[] memory buyTimes = new uint256[](5);
        uint256 totalHoursPassed = 0;
        address[] memory new_addresses = generateMultipleAddresses(5);
        //deal eth to them
        for (uint256 i = 0; i < new_addresses.length; i++) {
            vm.deal(new_addresses[i], 1 ether);
        }

        //user 0 buys 0.01 ether worth of tokens
        vm.startPrank(new_addresses[0]);
        uint256 scaledSupply = lockingCurve.scaledSupply();
        uint256 amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.002 ether);
        uint256 cost = lockingCurve.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        uint256 nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[0] = nextLockTime - block.timestamp;
        buyTimes[0] = block.timestamp;
        console.log("user 0 is going to buy 0.002 ether worth of tokens");
        console.log("calculated next lock for user 0 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[0]), amount * 10 ** 18);
        uint256 lockTime = lockingCurve.lockTime(new_addresses[0]);
        console.log("actual lock time for user 0 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[0]
        );
        console.log("contract lock remaining time for user 0 is", secondsToHumanReadable(contractLockRemaining));

        //user 2 buys 0.5 ether worth of tokens
        // 5 minutes passes

        vm.warp(block.timestamp + 5 minutes);

        vm.startPrank(new_addresses[1]);
        scaledSupply = lockingCurve.scaledSupply();
        amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.5 ether);
        cost = lockingCurve.calculateCost(amount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        totalCostWithSlippage = totalCost + slippage;
        nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[1] = nextLockTime - block.timestamp;
        buyTimes[1] = block.timestamp;
        console.log("user 1 is going to buy 0.5 ether worth of tokens");
        console.log("calculated next lock for user 1 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[1]), amount * 10 ** 18);
        lockTime = lockingCurve.lockTime(new_addresses[1]);
        console.log("actual lock time for user 1 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[1]
        );
        console.log("contract lock remaining time for user 1 is", secondsToHumanReadable(contractLockRemaining));

        // 20 hours passes
        console.log("   ");
        console.log("20 hours passes");
        console.log("   ");
        vm.warp(block.timestamp + 20 hours);

        // user 2 buys 0.5 ether worth of tokens
        vm.startPrank(new_addresses[2]);
        scaledSupply = lockingCurve.scaledSupply();
        amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.5 ether);
        cost = lockingCurve.calculateCost(amount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        totalCostWithSlippage = totalCost + slippage;
        nextLockTime = lockingCurve.calculateNextLockTime();
        initialLocks[2] = nextLockTime- block.timestamp;
        buyTimes[2] = block.timestamp;
        console.log("user 2 is going to buy 0.5 ether worth of tokens");
        console.log("calculated next lock for user 2 is", secondsToHumanReadable(nextLockTime - block.timestamp));
        lockingCurve.buyTokens{value: totalCostWithSlippage}(
            amount,
            100
        );
        assertEq(lockingCurve.balanceOf(new_addresses[2]), amount * 10 ** 18);
        lockTime = lockingCurve.lockTime(new_addresses[2]);
        console.log("actual lock time for user 2 is,", secondsToHumanReadable(lockTime- block.timestamp));
        assertEq(lockTime, nextLockTime);
        contractLockRemaining = lockingCurve.checkRemainingLockTime(
            new_addresses[2]
        );
        console.log("contract lock remaining time for user 2 is", secondsToHumanReadable(contractLockRemaining));
        vm.stopPrank();

        //check the lock times for all users
        console.log("user 0 remaining lock time is", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(new_addresses[0])));
        console.log("user 1 remaining lock time is", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(new_addresses[1])));
        console.log("user 2 remaining lock time is", secondsToHumanReadable(lockingCurve.checkRemainingLockTime(new_addresses[2])));

    }

    function testSinanCase5() public {
        //each user buys 0.04 eth for 10 users
                uint256[] memory initialLocks = new uint256[](100);
        uint256[] memory buyTimes = new uint256[](100);
        uint256 totalHoursPassed = 0;
        address[] memory new_addresses = generateMultipleAddresses(100);
        //deal eth to them
        for (uint256 i = 0; i < new_addresses.length; i++) {
            vm.deal(new_addresses[i], 1 ether);
        }

        //each user buys 0.04 eth worth of tokens
        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(new_addresses[i]);
            uint256 scaledSupply = lockingCurve.scaledSupply();
            uint256 amount = tokenCalculator.calculateTokensForEth(scaledSupply, 1000 , 0.04 ether);
            uint256 cost = lockingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            uint256 nextLockTime = lockingCurve.calculateNextLockTime();
            initialLocks[i] = nextLockTime - block.timestamp;
            buyTimes[i] = block.timestamp;
            //console.log("user", i, "is going to buy 0.04 ether worth of tokens");
            console.log("calculated next lock for user", i, "is", secondsToHumanReadable(nextLockTime - block.timestamp));
            uint256 totalEthCollected = lockingCurve.totalEtherCollected();
            uint256 totalSupply = lockingCurve.scaledSupply();
            console.log("total ether collected", totalEthCollected);
            console.log("total supply", totalSupply- 200_000_000);
            lockingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            //assertEq(lockingCurve.balanceOf(new_addresses[i]), amount * 10 ** 18);
            uint256 lockTime = lockingCurve.lockTime(new_addresses[i]);
            console.log("actual lock time for user", i, "is,", secondsToHumanReadable(lockTime- block.timestamp));
            //assertEq(lockTime, nextLockTime);
            uint256 contractLockRemaining = lockingCurve.checkRemainingLockTime(
                new_addresses[i]
            );
            vm.warp(block.timestamp + 5 minutes);
            //console.log("contract lock remaining time for user", i, "is", secondsToHumanReadable(contractLockRemaining));
            vm.stopPrank();
        }
    }

}
