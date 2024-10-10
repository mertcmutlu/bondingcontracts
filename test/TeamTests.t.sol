//Sinan Test
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SuperMemeDegenBondingCurve.sol";
import "../src/SuperMemeRefundableBondingCurve.sol";
import "../src/Factories/RefundableFactory.sol";
import "../src/Factories/SuperMemeRegistry.sol";
import {IUniswapFactory} from "../src/Interfaces/IUniswapFactory.sol";
//import uniswap pair
import {IUniswapV2Pair} from "../src/Interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../src/Interfaces/IUniswapV2Router02.sol";

contract TeamTests is Test {

    uint256 public dummyBuyAmount = 1000;
    uint256 public dummyBuyAmount2 = 1000000;
    IUniswapV2Pair public pair;
    IUniswapFactory public unifactory;    
    SuperMemeDegenBondingCurve public degenbondingcurve;
    SuperMemeRegistry public registry;
    RefundableFactory public factory;
    uint256 public createTokenRevenue = 0.00001 ether;
    IUniswapV2Router02 public router;
    SuperMemeDegenBondingCurve public tTokenInstanceDegen;
    SuperMemeRefundableBondingCurve public tTokenInstanceRefund;
    address[] public addresses;
    address private constant BASE_ADDRESS =
        0x1234567890123456789012345678901234567890; 



    function setUp() public {
        
        uint256 createTokenRevenue = 0.00001 ether;
        router = IUniswapV2Router02(address(0x5633464856F58Dfa9a358AfAf49841FEE990e30b));
        address fakeContract = address(0x12123123);
        unifactory = IUniswapFactory(address(0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6));

        addresses = generateMultipleAddresses(100);

        vm.startPrank(addresses[99]);
        registry = new SuperMemeRegistry();
        factory = new RefundableFactory(address(registry));
        
        registry.setFactory(address(factory));

        address testToken = factory.createToken{value: createTokenRevenue}(
            "SuperMeme",
            "MEME",
            0,
            addresses[99],
            0
        );
        tTokenInstanceRefund = SuperMemeRefundableBondingCurve(
                testToken
            );



        vm.stopPrank();

    }


    function testSinanTest1() public {
        vm.startPrank(addresses[0]);
        //user buys 200m tokens
        uint256 buyAmount = 200000000;
        uint256 cost = tTokenInstanceRefund.calculateCost(buyAmount);
        uint256 tax = cost / 100;
        uint256 totalCost = cost + tax;
        uint256 slippage = totalCost / 100;

        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100);
        console.log("user 0 buys 200m tokens");
        console.log("cost: ", totalCost);
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[0]), buyAmount * 10 ** 18);
        vm.stopPrank();
        vm.startPrank(addresses[1]);
         cost = tTokenInstanceRefund.calculateCost(buyAmount);
         tax = cost / 100;
         totalCost = cost + tax;
         slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100);
        console.log("         ");
        console.log("user 1 buys 200m tokens");
        console.log("cost: ", totalCost);
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[1]), buyAmount * 10 ** 18);
        //user 1 refunds
        
        console.log("          ");
        console.log("user 1 refunds");
        tTokenInstanceRefund.refund();
        console.log("             ");
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[1]), 0);
        vm.stopPrank();
        //next 4 users buy 100m tokens
        for (uint i = 2; i < 6; i++) {
            vm.startPrank(addresses[i]);
            buyAmount = 100000000;
            cost = tTokenInstanceRefund.calculateCost(buyAmount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100);
            console.log("         ");
            console.log("user ", i, " buys 100m tokens");
            console.log("          ");
            console.log("cost: ", totalCost);
            console.log("user ", i, " balance: ", tTokenInstanceRefund.balanceOf(addresses[i]));
            console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
            console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
            console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
            console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
            console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
            console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));

            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmount * 10 ** 18);
            vm.stopPrank();
        }
        //user 2 refunds
        vm.startPrank(addresses[2]);
        
        console.log("          ");
        console.log("user 2 refunds");
        tTokenInstanceRefund.refund();
        console.log("             ");
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
        console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
        console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
        console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[2]), 0);

        //next 2 users buy 100m tokens
        for (uint i = 6; i < 8; i++) {
            vm.startPrank(addresses[i]);
            buyAmount = 10000000;
            cost = tTokenInstanceRefund.calculateCost(buyAmount);
            tax = cost / 100;
            totalCost = cost + tax;
            slippage = totalCost / 100;
            tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100);
            console.log("         ");
            console.log("user ", i, " buys 10m tokens");
            console.log("          ");
            console.log("cost: ", totalCost);
            console.log("user ", i, " balance: ", tTokenInstanceRefund.balanceOf(addresses[i]));
            console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
            console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
            console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
            console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
            console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
            console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
            console.log("user 6 balance: ", tTokenInstanceRefund.balanceOf(addresses[6]));
            console.log("user 7 balance: ", tTokenInstanceRefund.balanceOf(addresses[7]));
            assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmount * 10 ** 18);
        }
        //user 3 refunds
        vm.startPrank(addresses[3]);
        
        console.log("          ");
        console.log("user 3 refunds");
        tTokenInstanceRefund.refund();
        console.log("             ");
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
        console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
        console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
        console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
        console.log("user 6 balance: ", tTokenInstanceRefund.balanceOf(addresses[6]));
        console.log("user 7 balance: ", tTokenInstanceRefund.balanceOf(addresses[7]));
        //assertEq(tTokenInstanceRefund.balanceOf(addresses[3]), 0);
        vm.stopPrank();

        //new user buys 50m tokens
        vm.startPrank(addresses[8]);
        buyAmount = 50000000;
        cost = tTokenInstanceRefund.calculateCost(buyAmount);
        tax = cost / 100;
        totalCost = cost + tax;
        slippage = totalCost / 100;
        tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100);
        console.log("         ");
        console.log("user 8 buys 50m tokens");
        console.log("          ");
        console.log("cost: ", totalCost);
        console.log("user 8 balance: ", tTokenInstanceRefund.balanceOf(addresses[8]));
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
        console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
        console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
        console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
        console.log("user 6 balance: ", tTokenInstanceRefund.balanceOf(addresses[6]));
        console.log("user 7 balance: ", tTokenInstanceRefund.balanceOf(addresses[7]));
        console.log("user 8 balance: ", tTokenInstanceRefund.balanceOf(addresses[8]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[8]), buyAmount * 10 ** 18);
        vm.stopPrank();

        //user 0 refunds
        vm.startPrank(addresses[0]);
        
        console.log("          ");
        console.log("user 0 refunds");
        tTokenInstanceRefund.refund();
        console.log("             ");
        console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
        console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
        console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
        console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
        console.log("user 6 balance: ", tTokenInstanceRefund.balanceOf(addresses[6]));
        console.log("user 7 balance: ", tTokenInstanceRefund.balanceOf(addresses[7]));
        console.log("user 8 balance: ", tTokenInstanceRefund.balanceOf(addresses[8]));
        assertEq(tTokenInstanceRefund.balanceOf(addresses[0]), 0);
        vm.stopPrank();

        //next 4 users buy 100m tokens
        // for (uint i = 9; i < 13; i++) {
        //     vm.startPrank(addresses[i]);
        //     buyAmount = 1000000;
        //     cost = tTokenInstanceRefund.calculateCost(buyAmount);
        //     tax = cost / 100;
        //     totalCost = cost + tax;
        //     slippage = cost / 100;
        //     tTokenInstanceRefund.buyTokens{value: totalCost + slippage}(buyAmount,100,totalCost);
        //     console.log("         ");
        //     console.log("user ", i, " buys 100m tokens");
        //     console.log("          ");
        //     console.log("cost: ", totalCost);
        //     console.log("user ", i, " balance: ", tTokenInstanceRefund.balanceOf(addresses[i]));
        //     console.log("user 0 balance: ", tTokenInstanceRefund.balanceOf(addresses[0]));
        //     console.log("user 1 balance: ", tTokenInstanceRefund.balanceOf(addresses[1]));
        //     console.log("user 2 balance: ", tTokenInstanceRefund.balanceOf(addresses[2]));
        //     console.log("user 3 balance: ", tTokenInstanceRefund.balanceOf(addresses[3]));
        //     console.log("user 4 balance: ", tTokenInstanceRefund.balanceOf(addresses[4]));
        //     console.log("user 5 balance: ", tTokenInstanceRefund.balanceOf(addresses[5]));
        //     console.log("user 6 balance: ", tTokenInstanceRefund.balanceOf(addresses[6]));
        //     console.log("user 7 balance: ", tTokenInstanceRefund.balanceOf(addresses[7]));
        //     console.log("user 8 balance: ", tTokenInstanceRefund.balanceOf(addresses[8]));
        //     console.log("user 9 balance: ", tTokenInstanceRefund.balanceOf(addresses[9]));
        //     console.log("user 10 balance: ", tTokenInstanceRefund.balanceOf(addresses[10]));
        //     console.log("user 11 balance: ", tTokenInstanceRefund.balanceOf(addresses[11]));
        //     console.log("user 12 balance: ", tTokenInstanceRefund.balanceOf(addresses[12]));
        //     assertEq(tTokenInstanceRefund.balanceOf(addresses[i]), buyAmount * 10 ** 18);
        //     vm.stopPrank();
        // }


        

    }
            

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

    }
