pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/Factories/DegenFactory.sol";
import "../src/Factories/SuperMemeRegistry.sol";
import "../src/Factories/RefundableFactory.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
//import uniswap pair
import {IUniswapV2Pair} from "../src/Interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";

contract ChatGPTTest is Test {
    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;
    IUniswapV2Pair public pair;
    IUniswapFactory public unifactory;
    SuperMemeDegenBondingCurve public degenbondingcurve;
    DegenFactory public degenFactory;
    RefundableFactory public refundableFactory;
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
    address public addr8 = address(0x252627);
    address public addr9 = address(0x282930);
    address public addr10 = address(0x313233);


    function setUp() public {
        createTokenRevenue = 0.00001 ether;
        router = IUniswapV2Router02(
            address(0x5633464856F58Dfa9a358AfAf49841FEE990e30b)
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
        vm.deal(addr8, 1000 ether);
        vm.deal(addr9, 1000 ether);
        vm.deal(addr10, 1000 ether);


        vm.startPrank(addr1);
        registry = new SuperMemeRegistry();
        refundableFactory = new RefundableFactory(address(registry));
        registry.setFactory(address(refundableFactory));

        address testToken = refundableFactory.createToken{value: createTokenRevenue, gas: 20000000000}(
            "SuperMeme",
            "MEME",
            0,
            address(addr1),
            0
        );

        tTokenInstanceRefund = SuperMemeRefundableBondingCurve(testToken);

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

function testInitialBalances() public {
    // Check that the token contract has the correct initial supply (if applicable)
    uint256 initialSupply = tTokenInstanceRefund.totalSupply();
    assertGt(initialSupply, 0); // Ensure initial supply is greater than 0
}

function testCreateTokenWithFactory() public {
    // Check that the token was created with the correct parameters
    assertEq(tTokenInstanceRefund.name(), "SuperMeme");
    assertEq(tTokenInstanceRefund.symbol(), "MEME");

    // Check that addr1 is the owner/dev of the token
    assertEq(tTokenInstanceRefund.devAddress(), addr1);
}

function testDegenBondingCurveSetup() public {
    // Check that the degen bonding curve contract has the correct parameters
    assertEq(degenbondingcurve.name(), "SuperMeme");
    assertEq(degenbondingcurve.symbol(), "MEME");
    assertEq(degenbondingcurve.devAddress(), owner);
}
function testBuyTokensAndRefund() public {
    uint256 amountToBuy = 5000;  // Amount of tokens to buy
    uint256 slippage = 100; // 1% slippage
    uint256 initialEthBalance = addr1.balance;
    uint256 initialContractEthBalance = address(tTokenInstanceRefund).balance;
    
    vm.startPrank(addr1);

    // Buy tokens
    uint256 cost = tTokenInstanceRefund.calculateCost(amountToBuy);
    uint256 tax = cost / 100;
    uint256 totalCost = cost + tax;
    uint256 slip = (totalCost * slippage) / 10000;
    uint256 totalWithSlip = totalCost + slip;
    tTokenInstanceRefund.buyTokens{value: totalWithSlip}(amountToBuy, slippage);
    assertEq(tTokenInstanceRefund.balanceOf(addr1), amountToBuy * 10 ** 18);
    uint256 initialSupply = tTokenInstanceRefund.totalSupply();
    tTokenInstanceRefund.refund();
    assertEq(tTokenInstanceRefund.balanceOf(addr1), 0);
    assertLt(tTokenInstanceRefund.totalSupply(), initialSupply); // Ensure the supply has decreased
    assertGt(addr1.balance, initialEthBalance - totalCost); // addr1 should get most of their ETH back

    vm.stopPrank();
}
function testRefundAfterBondingCurveCompletion() public {
    uint256 amountToBuy = 800000000;  // Amount of tokens to buy
    uint256 slippage = 100; // 1% slippage
    uint256 cost = tTokenInstanceRefund.calculateCost(amountToBuy);
    uint256 tax = cost / 100;
    uint256 totalCost = cost + tax;
    uint256 slip = (totalCost * slippage) / 10000;
    uint256 totalWithSlip = totalCost + slip;
    vm.startPrank(addr1);
    tTokenInstanceRefund.buyTokens{value: totalWithSlip}(tTokenInstanceRefund.MAX_SALE_SUPPLY() - tTokenInstanceRefund.scaledSupply(), 100);

    // Ensure bonding curve is marked as completed
    assertTrue(tTokenInstanceRefund.bondingCurveCompleted());

    // Attempt refund
    vm.expectRevert("Curve done");
    tTokenInstanceRefund.refund();
    vm.expectRevert("Curve done");
    tTokenInstanceRefund.buyTokens{value: totalWithSlip}(1, 100);

    vm.stopPrank();
}
function testRefundWithoutPurchase() public {
    vm.startPrank(addr2); // addr2 has not purchased any tokens

    vm.expectRevert(); // Expect a revert or a specific error message
    tTokenInstanceRefund.refund();

    vm.stopPrank();
}

function testRefundAfterPartialTokenBurn() public {
   uint256 amountToBuy = 799000000;  // Amount of tokens to buy
    uint256 slippage = 100; // 1% slippage
    uint256 cost = tTokenInstanceRefund.calculateCost(amountToBuy);
    uint256 tax = cost / 100;
    uint256 totalCost = cost + tax;
    uint256 slip = (totalCost * slippage) / 10000;
    uint256 totalWithSlip = totalCost + slip;
    vm.startPrank(addr1);
    tTokenInstanceRefund.buyTokens{value: totalWithSlip}(amountToBuy, 100);

    tTokenInstanceRefund.refund();
    assertEq(tTokenInstanceRefund.balanceOf(addr1), 0);
    // Ensure that the total supply reflects the burn and refund
    assertEq(tTokenInstanceRefund.totalSupply(), 200000000 * 10**18);
    vm.stopPrank();
}

function testStressBuyTokens() public {
    uint256 slippage = 100; // 1% slippage
    uint256 initialSupply = tTokenInstanceRefund.totalSupply();
    uint256 totalEtherSpent = 0;

    // Define the number of purchases and the amount of tokens per purchase
    uint256 numberOfPurchases = 100; // Number of times to buy tokens
    uint256 tokensPerPurchase = 10000; // Number of tokens per purchase

    vm.startPrank(addr1);

    for (uint256 i = 0; i < numberOfPurchases; i++) {
        uint256 cost = tTokenInstanceRefund.calculateCost(tokensPerPurchase);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;
        uint256 totalCostWithSlippage = totalCost + slippage;

        // Send ETH to buy tokens
        tTokenInstanceRefund.buyTokens{value: totalCostWithSlippage}(tokensPerPurchase, 100);
        
        // Accumulate total Ether spent
        totalEtherSpent += totalCost - tax;

        // Check token balance after each purchase
        assertEq(tTokenInstanceRefund.balanceOf(addr1), (i + 1) * tokensPerPurchase * 10 ** 18);
    }

    assertEq(tTokenInstanceRefund.totalSupply(), initialSupply + (numberOfPurchases * tokensPerPurchase * 10 ** 18));
    assertEq(tTokenInstanceRefund.totalEtherCollected(), totalEtherSpent);

    vm.stopPrank();
}

function testStressRefundProcess() public {
    uint256 initialSupply = tTokenInstanceRefund.totalSupply();
    uint256 numberOfPurchases = 50; // Number of times to buy tokens
    uint256 tokensPerPurchase = 10000; // Number of tokens per purchase
    uint256 slippage = 100; // 1% slippage
    uint256 totalCost;
    uint256 initialEthBalance = addr1.balance;

    vm.startPrank(addr1);

    // Step 1: Perform multiple token purchases
    for (uint256 i = 0; i < numberOfPurchases; i++) {
        uint256 cost = tTokenInstanceRefund.calculateCost(tokensPerPurchase);
        uint256 tax = cost / 100;
        uint256 totalPurchaseCost = cost + tax;
        uint256 slippage = totalPurchaseCost / 100;
        uint256 totalPurchaseCostWithSlippage = totalPurchaseCost + slippage;
        tTokenInstanceRefund.buyTokens{value: totalPurchaseCostWithSlippage}(tokensPerPurchase, 100);
        totalCost += totalPurchaseCost;
    }

    uint256 totalTokensBought = tokensPerPurchase * numberOfPurchases * 10 ** 18;
    assertEq(tTokenInstanceRefund.balanceOf(addr1), totalTokensBought);
    tTokenInstanceRefund.refund();

    assertEq(tTokenInstanceRefund.balanceOf(addr1), 0);

    uint256 newSupply = tTokenInstanceRefund.totalSupply();
    assertEq(newSupply, initialSupply);

    uint256 finalEthBalance = addr1.balance;
    assertLt(finalEthBalance, initialEthBalance);

    vm.stopPrank();
}

function testMultipleUsersRefundProcess() public {
    uint256 tokensPerPurchase = 1000000; // Number of tokens per purchase
    uint256 slippage = 100; // 1% slippage
    uint256 totalCost;

    address[] memory users = new address[](10);
    users[0] = addr1;
    users[1] = addr2;
    users[2] = addr3;
    users[3] = addr4;
    users[4] = addr5;
    users[5] = addr6;
    users[6] = addr7;
    users[7] = addr8;
    users[8] = addr9;
    users[9] = addr10;
    // Step 1: Multiple users perform token purchases
    for (uint256 i = 0; i < users.length; i++) {
        vm.startPrank(users[i]);
        uint256 cost = tTokenInstanceRefund.calculateCost(tokensPerPurchase);
        uint256 tax = cost / 100;
        uint256 totalPurchaseCost = cost + tax;
        uint256 slippage = totalPurchaseCost / 100;
        uint256 totalPurchaseCostWithSlippage = totalPurchaseCost + slippage;
        tTokenInstanceRefund.buyTokens{value: totalPurchaseCostWithSlippage}(tokensPerPurchase, 100);
        totalCost += totalPurchaseCost;
        vm.stopPrank();
    }
    for (uint256 i = 0; i < users.length; i++) {
        vm.startPrank(users[i]);
        tTokenInstanceRefund.refund();
        //assertEq(tTokenInstanceRefund.balanceOf(users[i]), 0);
        vm.stopPrank();
    }
    uint256 newSupply = tTokenInstanceRefund.totalSupply();
    assertLt(newSupply, tTokenInstanceRefund.MAX_SALE_SUPPLY() * 10 ** 18);
}


}
