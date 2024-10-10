pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/Factories/RefundableFactory.sol";
import "../src/Factories/DegenFactory.sol";
import "../src/Factories/SuperMemeRegistry.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
//import uniswap pair
import {IUniswapV2Pair} from "../src/Interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";

contract RefundScenariosTest is Test {

    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;
    IUniswapV2Pair public pair;
    IUniswapFactory public unifactory;    
    DegenFactory public degenFactory;
    RefundableFactory public refundableFactory;
    SuperMemeDegenBondingCurve public degenbondingcurve;
    SuperMemeRegistry public registry;
    uint256 public createTokenRevenue = 0.00001 ether;
    IUniswapV2Router02 public router;
    SuperMemeDegenBondingCurve public tTokenInstanceDegen;
    SuperMemeRefundableBondingCurve public tTokenInstanceRefund;
    address public owner = address(0x123);
    address public addr1 = address(0x456);
    address public addr2 = address(0x789);
    address public addr3 = address(0x101112);
    address public addr4 = address(0x131415);
    address public addr5 = address(0x161718);
    address public addr6 = address(0x192021);
    address public addr7 = address(0x222324);



    function setUp() public {
        
        uint256 createTokenRevenue = 0.00001 ether;
        router = IUniswapV2Router02(address(0x5633464856F58Dfa9a358AfAf49841FEE990e30b));
        address fakeContract = address(0x12123123);
        unifactory = IUniswapFactory(address(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6));
        vm.deal(owner, 1000 ether);
        vm.deal(addr1, 1000 ether);
        vm.deal(addr2, 1000 ether);
        vm.deal(addr3, 1000 ether);
        vm.deal(addr4, 1000 ether);
        vm.deal(addr5, 1000 ether);
        vm.deal(addr6, 1000 ether);
        vm.deal(addr7, 1000 ether);


        vm.startPrank(addr1);
        registry = new SuperMemeRegistry();
        degenFactory = new DegenFactory(address(registry));
        refundableFactory = new RefundableFactory(address(registry));
        registry.setFactory(address(degenFactory));
        registry.setFactory(address(refundableFactory));
        

        
        address testToken = refundableFactory.createToken{value: createTokenRevenue}(
            "SuperMeme",
            "MEME",
            0,
            address(addr1),
            0
        );
        
        tTokenInstanceRefund = SuperMemeRefundableBondingCurve(
                testToken
            );

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
        

        vm.stopPrank();
    }

    function testDeploy() public {
        assertEq(tTokenInstanceRefund.totalSupply(), 200000000 ether);
    }

    function testBuyerRefundsImmediately() public {
        vm.startPrank(addr1);
        uint256 cost = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax = cost / 100;
        uint256 slippage = 100;
        uint256 totalCost = cost + tax;
        slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr1), dummyBuyAmount * 10 ** 18);
        uint256 balanceBefore = address(addr1).balance;
        uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addr1);
        tTokenInstanceRefund.refund();
        uint256 balanceAfter = address(addr1).balance;
        uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addr1);
        assertGt(balanceAfter, balanceBefore);
        assertGt(tokenBalanceBefore, tokenBalanceAfter);
        vm.stopPrank();
    }

    function testBuyerRefundsWithDifferentAmounts() public {
        uint256[] memory amounts = new uint256[](7);
        amounts[0] = 1000;
        amounts[1] = 10000;
        amounts[2] = 100000;
        amounts[3] = 1000000;
        amounts[4] = 10000000;
        amounts[5] = 100000000;
        amounts[6] = 799999999;
        for (uint256 i = 0; i < amounts.length; i++) {
            vm.startPrank(addr1);
            address newToken = refundableFactory.createToken{value: createTokenRevenue}(
                "SuperMeme",
                "MEME",
                0,
                address(addr1),
                0
            );

            tTokenInstanceRefund = SuperMemeRefundableBondingCurve(
                    newToken
                );
            uint256 cost = tTokenInstanceRefund.calculateCost(amounts[i]);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(amounts[i], 100);
            assertEq(tTokenInstanceRefund.balanceOf(addr1), amounts[i] * 10 ** 18);
            uint256 balanceBefore = address(addr1).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addr1);
            
            tTokenInstanceRefund.refund();
            uint256 balanceAfter = address(addr1).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addr1);

            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);

            vm.stopPrank();
        }

    }

    function testBuyerRefundWithNextUsers() public {
        vm.startPrank(addr1);
        uint256 cost = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax = cost / 100;
        uint256 slippage = 100;
        uint256 totalCost = cost + tax;
        slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr1), dummyBuyAmount * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(addr2);
        uint256 cost2 = tTokenInstanceRefund.calculateCost(dummyBuyAmount2);
        uint256 tax2 = cost2 / 100;
        uint256 slippage2 = 100;
        uint256 totalCost2 = cost2 + tax2;
        slippage2 = totalCost2 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost2 + slippage2}(dummyBuyAmount2, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr2), dummyBuyAmount2 * 10 ** 18);
        uint256 balanceBeforeaddr2 = address(addr2).balance;
        uint256 tokenBalanceBeforeaddr2 = tTokenInstanceRefund.balanceOf(addr2);
        vm.stopPrank();

        vm.startPrank(addr3);
        uint256 cost3 = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax3 = cost3 / 100;
        uint256 slippage3 = 100;
        uint256 totalCost3 = cost3 + tax3;
        slippage3 = totalCost3 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost3 + slippage3}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr3), dummyBuyAmount * 10 ** 18);
        uint256 balanceBeforeaddr3 = address(addr3).balance;
        uint256 tokenBalanceBeforeaddr3 = tTokenInstanceRefund.balanceOf(addr3);
        vm.stopPrank();

        vm.startPrank(addr4);
        uint256 cost4 = tTokenInstanceRefund.calculateCost(dummyBuyAmount2);
        uint256 tax4 = cost4 / 100;
        uint256 slippage4 = 100;
        uint256 totalCost4 = cost4 + tax4;
        slippage4 = totalCost4 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost4 + slippage4}(dummyBuyAmount2, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr4), dummyBuyAmount2 * 10 ** 18);
        uint256 balanceBeforeaddr4 = address(addr4).balance;
        uint256 tokenBalanceBeforeaddr4 = tTokenInstanceRefund.balanceOf(addr4);
        vm.stopPrank();

        vm.startPrank(addr5);
        uint256 cost5 = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax5 = cost5 / 100;
        uint256 slippage5 = 100;
        uint256 totalCost5 = cost5 + tax5;
        slippage5 = totalCost5 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost5 + slippage5}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr5), dummyBuyAmount * 10 ** 18);
        uint256 balanceBeforeaddr5 = address(addr5).balance;
        uint256 tokenBalanceBeforeaddr5 = tTokenInstanceRefund.balanceOf(addr5);
        vm.stopPrank();

        //user 1 refunds
        vm.startPrank(addr1);
        uint256 balanceBefore = address(addr1).balance;
        uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addr1);
        tTokenInstanceRefund.refund();
        uint256 balanceAfter = address(addr1).balance;
        uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addr1);

        uint256 balanceAfteraddr2 = address(addr2).balance;
        uint256 tokenBalanceAfteraddr2 = tTokenInstanceRefund.balanceOf(addr2);
        uint256 balanceAfteraddr3 = address(addr3).balance;
        uint256 tokenBalanceAfteraddr3 = tTokenInstanceRefund.balanceOf(addr3);
        uint256 balanceAfteraddr4 = address(addr4).balance;
        uint256 tokenBalanceAfteraddr4 = tTokenInstanceRefund.balanceOf(addr4);
        uint256 balanceAfteraddr5 = address(addr5).balance;
        uint256 tokenBalanceAfteraddr5 = tTokenInstanceRefund.balanceOf(addr5);

        
        assertGt(balanceAfter, balanceBefore);
        
        assertGt(tokenBalanceBefore, tokenBalanceAfter);
        
        assertGt(tokenBalanceAfteraddr2, tokenBalanceBeforeaddr2);
        
        assertGt(tokenBalanceAfteraddr3, tokenBalanceBeforeaddr3);
        
        assertGt(tokenBalanceAfteraddr4, tokenBalanceBeforeaddr4);
        
        assertGt(tokenBalanceAfteraddr5, tokenBalanceBeforeaddr5);
        vm.stopPrank();
    }

    function testIntermediateBuyerRefundsWithoutNextUsers() public {
        vm.startPrank(addr1);
        uint256 cost = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax = cost / 100;
        uint256 slippage = 100;
        uint256 totalCost = cost + tax;
        slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr1), dummyBuyAmount * 10 ** 18);
        uint256 balanceBefore = address(addr1).balance;
        uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addr1);
        vm.stopPrank();

        vm.startPrank(addr2);
        uint256 cost2 = tTokenInstanceRefund.calculateCost(dummyBuyAmount2);
        uint256 tax2 = cost2 / 100;
        uint256 slippage2 = 100;
        uint256 totalCost2 = cost2 + tax2;
        slippage2 = totalCost2 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost2 + slippage2}(dummyBuyAmount2, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr2), dummyBuyAmount2 * 10 ** 18);
        uint256 balanceBeforeaddr2 = address(addr2).balance;
        uint256 tokenBalanceBeforeaddr2 = tTokenInstanceRefund.balanceOf(addr2);
        vm.stopPrank();

        vm.startPrank(addr3);
        uint256 cost3 = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax3 = cost3 / 100;
        uint256 slippage3 = 100;
        uint256 totalCost3 = cost3 + tax3;
        slippage3 = totalCost3 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost3 + slippage3}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr3), dummyBuyAmount * 10 ** 18);
        uint256 balanceBeforeaddr3 = address(addr3).balance;
        uint256 tokenBalanceBeforeaddr3 = tTokenInstanceRefund.balanceOf(addr3);
        vm.stopPrank();

        vm.startPrank(addr4);
        uint256 cost4 = tTokenInstanceRefund.calculateCost(dummyBuyAmount2);
        uint256 tax4 = cost4 / 100;
        uint256 slippage4 = 100;
        uint256 totalCost4 = cost4 + tax4;
         slippage4 = totalCost4 / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost4 + slippage4}(dummyBuyAmount2, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr4), dummyBuyAmount2 * 10 ** 18);
        uint256 balanceBeforeaddr4 = address(addr4).balance;
        uint256 tokenBalanceBeforeaddr4 = tTokenInstanceRefund.balanceOf(addr4);
        vm.stopPrank();
        vm.startPrank(addr2);
         balanceBeforeaddr2 = address(addr2).balance;
         tokenBalanceBeforeaddr2 = tTokenInstanceRefund.balanceOf(addr2);
        tTokenInstanceRefund.refund();
        uint256 balanceAfteraddr2 = address(addr2).balance;
        uint256 tokenBalanceAfteraddr2 = tTokenInstanceRefund.balanceOf(addr2);
        uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addr1);
        uint256 tokenBalanceAfteraddr3 = tTokenInstanceRefund.balanceOf(addr3);
        uint256 tokenBalanceAfteraddr4 = tTokenInstanceRefund.balanceOf(addr4);
        assertGt(balanceAfteraddr2, balanceBeforeaddr2);
        assertGt(tokenBalanceBeforeaddr2, tokenBalanceAfteraddr2);
        assertGt(tokenBalanceAfteraddr3, tokenBalanceBeforeaddr3);
        assertEq(tokenBalanceBefore, tokenBalanceAfter);
        assertGt(tokenBalanceAfteraddr4, tokenBalanceBeforeaddr4);
    }

    function testBulkBuysBulkRefunds() public {
        address[] memory addresses = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
             slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 balanceBefore = address(addresses[i]).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[i]);
            tTokenInstanceRefund.refund();
            uint256 balanceAfter = address(addresses[i]).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[i]);
            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);
            vm.stopPrank();
        }
    }

    function testRefundInTheMiddle() public {

        address[] memory addresses = new address[](50);
        uint256[] memory balancesToken = new uint256[](50);
        uint256[] memory balancesEth = new uint256[](50);
        for (uint256 i = 0; i < 50; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }
        

        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
             slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        
        vm.startPrank(addr1);
        uint256 cost = tTokenInstanceRefund.calculateCost(dummyBuyAmount);
        uint256 tax = cost / 100;
        uint256 slippage = 100;
        uint256 totalCost = cost + tax;
        slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(dummyBuyAmount, 100);
        assertEq(tTokenInstanceRefund.balanceOf(addr1), dummyBuyAmount * 10 ** 18);
        uint256 balanceBefore = address(addr1).balance;
        uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addr1);
        vm.stopPrank();
        

        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 balanceBefore = address(addresses[i]).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[i]);
            
            tTokenInstanceRefund.refund();
            
            uint256 balanceAfter = address(addresses[i]).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[i]);
            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);
            balancesToken[i] = tokenBalanceBefore;
            balancesEth[i] = balanceBefore;
            
            vm.stopPrank();
        }
        
        vm.startPrank(addr1);
        uint256 balanceBeforeaddr1 = address(addr1).balance;
        uint256 tokenBalanceBeforeaddr1 = tTokenInstanceRefund.balanceOf(addr1);
        tTokenInstanceRefund.refund();
        uint256 balanceAfteraddr1 = address(addr1).balance;
        uint256 tokenBalanceAfteraddr1 = tTokenInstanceRefund.balanceOf(addr1);
        
        assertGt(balanceAfteraddr1, balanceBeforeaddr1);
        
        assertGt(tokenBalanceBeforeaddr1,tokenBalanceAfteraddr1);
        vm.stopPrank();

        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            assertLt(tTokenInstanceRefund.balanceOf(addresses[i]),balancesToken[i]);
            assertGt(address(addresses[i]).balance, balancesEth[i]);
        }
    }

    function testBulkBuysandRefundsForGas1() public {
        address[] memory addresses = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        for (uint256 i = 0; i < 50; i++) {
               vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 300000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            //assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
                for (uint256 i = 0; i < 50; i++) {
               vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 300000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            //assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }


        //refund all users
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 balanceBefore = address(addresses[i]).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[i]);
            tTokenInstanceRefund.refund();
            uint256 balanceAfter = address(addresses[i]).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[i]);
            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);
            vm.stopPrank();
        }

    }

    function testOneUserBuysMultipleConsecutively() public {
        address[] memory addresses = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        //only one user buys 50 times
        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(addresses[0]);
            uint256 buyAmountForBulk = 300000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            //assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }

        //refund all users
        for (uint256 i = 1; i < 50; i++) {
            vm.startPrank(addresses[i]);
            uint256 balanceBefore = address(addresses[i]).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[i]);
            tTokenInstanceRefund.refund();
            uint256 balanceAfter = address(addresses[i]).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[i]);
            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);
            vm.stopPrank();
        }

        //address[0] refunds
        vm.startPrank(addresses[0]);
        uint256 balanceBefore = address(addresses[0]).balance;
        uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[0]);
        tTokenInstanceRefund.refund();
        uint256 balanceAfter = address(addresses[0]).balance;
        uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[0]);
        assertGt(balanceAfter, balanceBefore);
        assertGt(tokenBalanceBefore, tokenBalanceAfter);
        vm.stopPrank();
    }

    function test1000UsersBuy() public {
        address[] memory addresses = new address[](1000);
        for (uint256 i = 0; i < 1000; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.deal(addresses[i], 1000 ether);
        }
        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            uint256 buyAmountForBulk = 100000;
            uint256 cost = tTokenInstanceRefund.calculateCost(buyAmountForBulk);
            uint256 tax = cost / 100;
            uint256 slippage = 100;
            
            uint256 totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmountForBulk, 100);
            //assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmountForBulk * 10 ** 18);
            vm.stopPrank();
        }
        //refund all users
        for (uint256 i = 0; i < 100; i++) {
            vm.startPrank(addresses[i]);
            uint256 balanceBefore = address(addresses[i]).balance;
            uint256 tokenBalanceBefore = tTokenInstanceRefund.balanceOf(addresses[i]);
            tTokenInstanceRefund.refund();
            uint256 balanceAfter = address(addresses[i]).balance;
            uint256 tokenBalanceAfter = tTokenInstanceRefund.balanceOf(addresses[i]);
            assertGt(balanceAfter, balanceBefore);
            assertGt(tokenBalanceBefore, tokenBalanceAfter);
            vm.stopPrank();
        }
    }


    function testEvrenCase() public {
        vm.startPrank(addr1);
            uint256 buyAmount = 1000;
            uint256 cost = degenbondingcurve.calculateCost(buyAmount);
            uint256 tax = cost / 100;
            uint256 costWithTax = cost + tax;
            uint256 slippage = costWithTax / 100;
            uint256 buyEth = costWithTax + slippage;


            address newToken = refundableFactory.createToken{
                value: createTokenRevenue + buyEth
            }(
                "SuperMeme",
                "MEME",
                buyAmount,
                address(addr1),
                buyEth
            );
            SuperMemeRefundableBondingCurve newTokenInstance = SuperMemeRefundableBondingCurve(
                    newToken
                );
        vm.stopPrank();
        vm.startPrank(addr2);

        cost = newTokenInstance.calculateCost(buyAmount);
        tax = cost / 100;
        costWithTax = cost + tax;
        slippage = costWithTax / 100;
        uint256 totalCost = costWithTax + slippage;

        newTokenInstance.buyTokens{value: totalCost}(buyAmount, 100);
        assertEq(newTokenInstance.balanceOf(addr2), buyAmount * 10 ** 18);
        vm.stopPrank();
        vm.startPrank(addr1);

        newTokenInstance.refund();
        assertEq(newTokenInstance.balanceOf(addr1), 0);
        vm.stopPrank();

    }

    function testRefundWithoutBuy() public {
        vm.startPrank(addr1);
        vm.expectRevert();
        tTokenInstanceRefund.refund();
        assertEq(tTokenInstanceRefund.balanceOf(addr1), 0);
        vm.stopPrank();
    }

}