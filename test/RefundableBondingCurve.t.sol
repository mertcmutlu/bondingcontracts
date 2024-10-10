pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Factories/DegenFactory.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/SuperMemeRevenueCollector.sol";
import "../src/Factories/SuperMemeRegistry.sol";
import "../src/Factories/RefundableFactory.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";



contract RefundableBondingCurveTest is Test {
    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;

    DegenFactory public degenFactory;
    SuperMemeDegenBondingCurve public degenbondingcurve;
    SuperMemeRegistry public registry;
    SuperMemeRevenueCollector public revenueCollector;
    IUniswapV2Router02 public router;
    SuperMemeRefundableBondingCurve public refundableBondingCurve;
    RefundableFactory public refundableFactory;


    address public owner = address(0x123);
    address public addr1 = address(0x456);
    address public addr2 = address(0x789);
    address public addr3 = address(0x101112);

    uint256 public createTokenRevenue = 0.00001 ether;


    function setUp() public {
        vm.deal(owner, 1000 ether);
        vm.deal(addr1, 1000 ether);
        vm.deal(addr2, 1000 ether);
        vm.deal(addr3, 1000 ether);

            //base mainnet router address 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
        //base sepolia router address 0x6682375ebC1dF04676c0c5050934272368e6e883
        router = IUniswapV2Router02(0x6682375ebC1dF04676c0c5050934272368e6e883);

        vm.startPrank(owner);
        registry = new SuperMemeRegistry();
        degenFactory = new DegenFactory(address(registry));
        refundableFactory = new RefundableFactory(address(registry));

        registry.setFactory(address(degenFactory));
        registry.setFactory(address(refundableFactory));
        

        degenbondingcurve = SuperMemeDegenBondingCurve(degenFactory.createToken{value: createTokenRevenue}("name", "symbol", false,0, owner, 0, 0));
        refundableBondingCurve = SuperMemeRefundableBondingCurve(refundableFactory.createToken{value: createTokenRevenue}("name", "symbol", 0, owner, 0));
        vm.stopPrank();
    }

    function test_createToken() public {
        assertEq(refundableBondingCurve.scaledSupply(),200000000);   
    }
    function testCompleteCurveRefundable() public {
        uint256 amount = 800000000;
        vm.startPrank(addr1);
            uint256 cost = refundableBondingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            refundableBondingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(refundableBondingCurve.balanceOf(address(addr1)), amount * 10 ** 18);
            assertEq(refundableBondingCurve.bondingCurveCompleted(), true);
    }

    function testCompleteCurveBuyRefundable() public {
        uint256 amount = 800000000;
        vm.startPrank(addr1);
            uint256 cost = refundableBondingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            refundableBondingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(refundableBondingCurve.balanceOf(address(addr1)), amount * 10 ** 18);
            assertEq(refundableBondingCurve.bondingCurveCompleted(), true);

            vm.expectRevert("Curve done");
            refundableBondingCurve.buyTokens{value: totalCostWithSlippage}(
                    amount,
                    100
                );
            vm.expectRevert("Curve done");
            refundableBondingCurve.refund();
        vm.stopPrank();
    }

    function testCompleteCurveTradeRefundable() public {
        uint256 amount = 800000000;
        vm.startPrank(addr1);
            uint256 cost = refundableBondingCurve.calculateCost(amount);
            uint256 tax = cost / 100;
            uint256 totalCost = cost + tax;
            uint256 slippage = totalCost / 100;
            uint256 totalCostWithSlippage = totalCost + slippage;
            refundableBondingCurve.buyTokens{value: totalCostWithSlippage}(
                amount,
                100
            );
            assertEq(refundableBondingCurve.balanceOf(address(addr1)), amount * 10 ** 18);
            assertEq(refundableBondingCurve.bondingCurveCompleted(), true);

            address[] memory path = new address[](2);
            path[0] = address(refundableBondingCurve);
            path[1] = router.WETH();

        refundableBondingCurve.approve(address(router), amount * 10 ** 18);
        router.swapExactTokensForETH(
            amount * 10 ** 18,
            0,
            path,
            address(addr1),
            block.timestamp + 10 minutes
        );
            assertEq(refundableBondingCurve.balanceOf(address(addr1)), 0);
        vm.stopPrank();
    }
}