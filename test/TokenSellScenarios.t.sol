pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/Factories/DegenFactory.sol";
import "../src/Factories/SuperMemeRegistry.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
//import uniswap pair
import {IUniswapV2Pair} from "../src/Interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";

contract TokenSellScenarios is Test {
    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;
    IUniswapV2Pair public pair;
    IUniswapFactory public unifactory;    
    SuperMemeDegenBondingCurve public degenbondingcurve;
    uint256 public createTokenRevenue = 0.00001 ether;
    IUniswapV2Router02 public router;
    SuperMemeRegistry public registry;
    SuperMemeDegenBondingCurve public testTokenInstanceDegen;
    SuperMemeRefundableBondingCurve public testTokenInstanceRefund;
    SuperMemeDegenBondingCurve public testTokenInstanceDevLock;
    DegenFactory public factory;
    address public owner = address(0x123);
    address public addr1 = address(0x456);
    address public addr2 = address(0x789);
    address public addr3 = address(0x101112);
    function setUp() public {
        uint256 createTokenRevenue = 0.00001 ether;
        router = IUniswapV2Router02(address(0x5633464856F58Dfa9a358AfAf49841FEE990e30b));
        address fakeContract = address(0x12123123);
        unifactory = IUniswapFactory(address(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6));
        degenbondingcurve = new SuperMemeDegenBondingCurve(
            "SuperMeme",
            "MEME",
            false,
            0,
            owner,
            address(0x123),
            0,
            0
        );
        vm.deal(owner, 1000 ether);
        vm.deal(addr1, 1000 ether);
        vm.deal(addr2, 1000 ether);
        vm.startPrank(addr1);
        registry = new SuperMemeRegistry();
        factory = new DegenFactory(address(registry));
        registry.setFactory(address(factory));
        //Create a token
        address testToken = factory.createToken{value: createTokenRevenue}(
            "SuperMeme",
            "MEME",
            false,
            0,
            address(addr1),
            0,
            0
        );
        testTokenInstanceDegen = SuperMemeDegenBondingCurve(
                testToken
            );      

        uint256 amount = 100000000;
        uint256 cost = testTokenInstanceDegen.calculateCost(amount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;

        address testToken2 = factory.createToken{value: createTokenRevenue + totalCostWithSlippage}(
            "SuperMeme",
            "MEME",
            true,
            amount,
            address(addr1),
            1 weeks,
            totalCostWithSlippage
        ); 
        testTokenInstanceDevLock = SuperMemeDegenBondingCurve(
                testToken2
            );
        vm.stopPrank();
    }

    function testDeploy() public {
        assertEq(factory.revenueCollector(), address(0));
        assertEq(testTokenInstanceDegen.devAddress(), address(addr1));
        assertEq(testTokenInstanceDevLock.devLocked(), true);
    }

    function testBasicBuyAndSell() public {
        vm.startPrank(addr1);
        uint256 buyAmount = 1000;
        uint256 sellAmount = 500;
        uint256 cost = testTokenInstanceDegen.calculateCost(buyAmount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        testTokenInstanceDegen.buyTokens{value: totalCostWithSlippage}(buyAmount,100);
        assertEq(testTokenInstanceDegen.balanceOf(addr1), buyAmount * 10 **18);
        uint256 tokenBalance = testTokenInstanceDegen.balanceOf(addr1);
        testTokenInstanceDegen.sellTokens(sellAmount,100);
        assertEq(testTokenInstanceDegen.balanceOf(addr1), tokenBalance - sellAmount * 10 **18);
        testTokenInstanceDegen.sellTokens(sellAmount,100);
        assertEq(testTokenInstanceDegen.balanceOf(addr1), 0);
    }

    function testPriceIncrementsAndDecrements() public {
                address[] memory addresses = new address[](1000);
        for (uint256 i = 0; i < 100; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }

        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmount = 10000;
            uint256 cost = testTokenInstanceDegen.calculateCost(buyAmount);
            uint256 costPerToken = testTokenInstanceDegen.calculateCost(1);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            testTokenInstanceDegen.buyTokens{value: totalCostWithSlippage}(buyAmount,100);
            assertEq(testTokenInstanceDegen.balanceOf(addresses[i]), buyAmount * 10 **18);
            uint256 costAfterBuy = testTokenInstanceDegen.calculateCost(1);
            assertGt(costAfterBuy, costPerToken);
        }

        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            //uint256 sellAmount = 500;
            uint256 costPerToken = testTokenInstanceDegen.calculateCost(1);
            uint256 tokenBalance = testTokenInstanceDegen.balanceOf(addresses[i]);
            
            testTokenInstanceDegen.sellTokens(tokenBalance/10**18,100);
            assertEq(testTokenInstanceDegen.balanceOf(addresses[i]), 0);
            uint256 costAfterSell = testTokenInstanceDegen.calculateCost(1);
            assertLt(costAfterSell, costPerToken);
        }

        uint256 low = testTokenInstanceDegen.calculateCost(1);

        // buy for all users again
        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmount = 100000;
            uint256 cost = testTokenInstanceDegen.calculateCost(buyAmount);
            uint256 costPerToken = testTokenInstanceDegen.calculateCost(1);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            testTokenInstanceDegen.buyTokens{value: totalCostWithSlippage}(buyAmount,100);
            assertEq(testTokenInstanceDegen.balanceOf(addresses[i]), buyAmount * 10 **18);
            uint256 costAfterBuy = testTokenInstanceDegen.calculateCost(1);
            assertGt(costAfterBuy, costPerToken);
        }

        uint256 high = testTokenInstanceDegen.calculateCost(1);
        assertGt(high, low);
    }

    function testSellAfterBondComplete() public {
        vm.startPrank(addr1);
        uint256 buyAmount = 800000000;
        uint256 cost = testTokenInstanceDegen.calculateCost(buyAmount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        testTokenInstanceDegen.buyTokens{value: totalCostWithSlippage}(buyAmount,100);
        assertEq(testTokenInstanceDegen.balanceOf(addr1), buyAmount * 10 **18);
        uint256 tokenBalance = testTokenInstanceDegen.balanceOf(addr1);
        vm.expectRevert();
        testTokenInstanceDegen.sellTokens(buyAmount,100);
    }

    function testDevLockSell() public {
        vm.startPrank(addr1);
        assertEq(testTokenInstanceDevLock.devLocked(), true);
        assertEq(testTokenInstanceDevLock.devLockTime(), block.timestamp + 1 weeks);
        assertEq(testTokenInstanceDevLock.devAddress(), addr1);
        assertEq(testTokenInstanceDevLock.balanceOf(addr1), 100000000 * 10 ** 18);
        vm.expectRevert();
        testTokenInstanceDevLock.sellTokens(100000000,100);

        //buy with another address and sell
        vm.startPrank(addr2);
        uint256 buyAmount = 100000000;
        uint256 cost = testTokenInstanceDevLock.calculateCost(buyAmount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;
        testTokenInstanceDevLock.buyTokens{value: totalCostWithSlippage}(buyAmount,100);
        assertEq(testTokenInstanceDevLock.balanceOf(addr2), buyAmount * 10 **18);
        uint256 tokenBalance = testTokenInstanceDevLock.balanceOf(addr2);
        testTokenInstanceDevLock.sellTokens(buyAmount,100);
        assertEq(testTokenInstanceDevLock.balanceOf(addr2), 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        vm.startPrank(addr1);
        testTokenInstanceDevLock.sellTokens(100000000,100);
        assertEq(testTokenInstanceDevLock.balanceOf(addr1), 0);

    }

}

